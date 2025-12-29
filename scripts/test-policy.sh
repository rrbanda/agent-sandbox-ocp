#!/bin/bash
# Test script for OPA policy verification
# Tests that URL blocking and tool argument inspection works

set -e

GATEWAY_HOST="${GATEWAY_HOST:-mcp-gateway-istio.gateway-system.svc.cluster.local}"
GATEWAY_PORT="${GATEWAY_PORT:-8080}"
MCP_HOST="${MCP_HOST:-mcp.127-0-0-1.sslip.io}"

echo "=============================================="
echo "  MCP GATEWAY + AUTHORINO OPA POLICY TEST"
echo "=============================================="
echo ""
echo "Gateway: $GATEWAY_HOST:$GATEWAY_PORT"
echo "Host header: $MCP_HOST"
echo ""

# Initialize session
echo "=== 1. Initialize MCP session ==="
INIT_RESP=$(curl -s -D /tmp/headers -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: $MCP_HOST" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}')

SESSION_ID=$(grep -i "mcp-session-id:" /tmp/headers | cut -d: -f2- | tr -d ' \r\n')
if [ -z "$SESSION_ID" ]; then
  echo "✗ Failed to get session ID"
  exit 1
fi
echo "✓ Session initialized"

run_test() {
  local name=$1
  local expected_code=$2
  local body=$3
  
  RESP=$(curl -s -w "%{http_code}" -o /tmp/resp -X POST "http://$GATEWAY_HOST:$GATEWAY_PORT/mcp" \
    -H "Content-Type: application/json" \
    -H "Host: $MCP_HOST" \
    -H "mcp-session-id: $SESSION_ID" \
    -d "$body")
  
  if [ "$RESP" = "$expected_code" ]; then
    echo "✓ $name - HTTP $RESP"
  else
    echo "✗ $name - Expected $expected_code, got $RESP"
    cat /tmp/resp
    echo ""
  fi
}

echo ""
echo "=== 2. Test tools/list (should PASS) ==="
run_test "tools/list" "200" '{"jsonrpc":"2.0","id":2,"method":"tools/list","params":{}}'

echo ""
echo "=== 3. fetch_url: MALICIOUS URL (should be BLOCKED) ==="
run_test "fetch_url → malicious.com" "403" '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://malicious.com/steal"}}}'

echo ""
echo "=== 4. fetch_url: APPROVED URL (should PASS) ==="
run_test "fetch_url → api.weather.gov" "200" '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://api.weather.gov/forecast"}}}'

echo ""
echo "=== 5. fetch_url: APPROVED URL (should PASS) ==="
run_test "fetch_url → httpbin.org" "200" '{"jsonrpc":"2.0","id":5,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://httpbin.org/get"}}}'

echo ""
echo "=== 6. weather: RESTRICTED city (should be BLOCKED) ==="
run_test "weather → Moscow" "403" '{"jsonrpc":"2.0","id":6,"method":"tools/call","params":{"name":"weather_get_weather","arguments":{"city":"Moscow"}}}'

echo ""
echo "=== 7. weather: ALLOWED city (should PASS) ==="
run_test "weather → New York" "200" '{"jsonrpc":"2.0","id":7,"method":"tools/call","params":{"name":"weather_get_weather","arguments":{"city":"New York"}}}'

echo ""
echo "=============================================="
echo "  TEST COMPLETE"
echo "=============================================="
