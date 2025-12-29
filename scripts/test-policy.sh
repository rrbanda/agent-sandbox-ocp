#!/bin/bash
# Demo: MCP Gateway + Authorino OPA Policy blocking fetch_url by URL
# This script demonstrates that the MCP Gateway can block tool calls
# based on OPA policies that inspect tool arguments.

set -e

GATEWAY_HOST="${GATEWAY_HOST:-mcp-gateway-istio.gateway-system.svc.cluster.local}"
GATEWAY_PORT="${GATEWAY_PORT:-8080}"
MCP_HOST="${MCP_HOST:-mcp.127-0-0-1.sslip.io}"

echo "============================================================"
echo "  DEMO: MCP Gateway + Authorino blocks fetch_url by URL"
echo "============================================================"
echo ""
echo "The OPA policy inspects tools/call requests and blocks"
echo "fetch_url calls to non-approved URLs."
echo ""
echo "Gateway: $GATEWAY_HOST:$GATEWAY_PORT"
echo ""

# Initialize session
echo "=== 1. Initialize MCP session ==="
INIT_RESP=$(curl -s -D /tmp/headers -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: $MCP_HOST" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"demo","version":"1.0"}}}')

SESSION_ID=$(grep -i "mcp-session-id:" /tmp/headers | cut -d: -f2- | tr -d ' \r\n')
if [ -z "$SESSION_ID" ]; then
  echo "✗ Failed to get session ID"
  exit 1
fi
echo "✓ Session established"
echo ""

# Test function
test_url() {
  local desc="$1"
  local url="$2"
  local expected="$3"
  
  RESP=$(curl -s -w "%{http_code}" -o /tmp/resp -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/mcp" \
    -H "Content-Type: application/json" \
    -H "Host: $MCP_HOST" \
    -H "mcp-session-id: $SESSION_ID" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":99,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"$url\"}}}")
  
  if [ "$RESP" = "$expected" ]; then
    if [ "$expected" = "403" ]; then
      echo "✓ BLOCKED: $desc"
      echo "  URL: $url → HTTP $RESP (denied by OPA policy)"
    else
      echo "✓ ALLOWED: $desc"
      echo "  URL: $url → HTTP $RESP"
    fi
  else
    echo "✗ UNEXPECTED: $desc - Expected $expected, got $RESP"
  fi
}

echo "=== 2. Testing URL blocking with OPA policy ==="
echo ""

echo "--- BLOCKED URLs (not in approved list) ---"
test_url "Malicious site" "https://malicious.com/steal-data" "403"
test_url "Random external" "https://evil-site.net/api" "403"
test_url "IMDS attack" "http://169.254.169.254/metadata" "403"
echo ""

echo "--- ALLOWED URLs (in approved list) ---"
test_url "Weather API" "https://api.weather.gov/forecast" "200"
test_url "HTTPBin" "https://httpbin.org/get" "200"
test_url "Example.com" "https://example.com/page" "200"
echo ""

echo "============================================================"
echo "  DEMO COMPLETE: OPA policy blocks fetch_url by URL pattern"
echo "============================================================"
