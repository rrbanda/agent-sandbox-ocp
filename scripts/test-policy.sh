#!/bin/bash
# Test MCP Gateway + OPA Policy
# Run this from a pod with curl inside the cluster

set -e

MCP_GATEWAY="http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
HOST_HEADER="Host: mcp.127-0-0-1.sslip.io"

echo "=== Initialize MCP Session ==="
curl -s -D /tmp/headers -X POST "$MCP_GATEWAY" \
  -H "Content-Type: application/json" \
  -H "$HOST_HEADER" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' > /dev/null

SESSION=$(grep -i "mcp-session-id:" /tmp/headers | cut -d: -f2- | tr -d " \r\n")
echo "Session: $SESSION"
echo ""

echo "=== Test 1: Blocked URL (malicious.com) ==="
echo -n "Result: "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$MCP_GATEWAY" \
  -H "Content-Type: application/json" \
  -H "$HOST_HEADER" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://malicious.com"}}}')
echo "HTTP $HTTP_CODE (expected: 403)"
echo ""

echo "=== Test 2: Allowed URL (httpbin.org) ==="
echo -n "Result: "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$MCP_GATEWAY" \
  -H "Content-Type: application/json" \
  -H "$HOST_HEADER" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://httpbin.org/get"}}}')
echo "HTTP $HTTP_CODE (expected: 200)"
echo ""

echo "=== Test 3: IMDS (169.254.169.254) ==="
echo -n "Result: "
HTTP_CODE=$(curl -s -w "%{http_code}" -o /dev/null -X POST "$MCP_GATEWAY" \
  -H "Content-Type: application/json" \
  -H "$HOST_HEADER" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"http://169.254.169.254/latest/meta-data"}}}')
echo "HTTP $HTTP_CODE (expected: 403)"
echo ""

echo "=== Summary ==="
echo "OPA Policy Test Complete"
