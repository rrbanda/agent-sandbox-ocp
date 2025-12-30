#!/bin/bash
# Quick test: OPA policy enforcement at MCP Gateway

echo "=== OPA Policy Test ==="

# Initialize
curl -s -D /tmp/h -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: mcp.127-0-0-1.sslip.io" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' > /dev/null

SESSION=$(grep -i "mcp-session-id:" /tmp/h | cut -d: -f2- | tr -d ' \r\n')

# Test blocked
echo -n "fetch_url(malicious.com): "
curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://malicious.com"}}}'

# Test allowed
echo -n "fetch_url(httpbin.org): "
curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://httpbin.org/get"}}}'

echo ""
echo "Expected: malicious.com -> 403, httpbin.org -> 200"
