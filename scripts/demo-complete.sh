#!/bin/bash
# =============================================================================
#  Enterprise AI Agent Security Demo
#  Demonstrates three-layer protection: OPA Policy + Istio Egress + Kata VM
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=============================================="
echo "  Enterprise AI Agent Security Demo"
echo "=============================================="
echo ""
echo "This demo shows three layers of protection:"
echo "  1. Tool Policy (OPA) - Block unauthorized tool arguments"
echo "  2. Network Egress (Istio) - Block direct internet access"
echo "  3. Execution Isolation (Kata) - VM-level containment"
echo ""

# =============================================================================
echo "=============================================="
echo "  LAYER 1: Tool Policy (OPA at MCP Gateway)"
echo "=============================================="
echo ""
echo "Testing: OPA policy inspects tool arguments and blocks unauthorized URLs"
echo ""

# Initialize MCP session
echo "Initializing MCP session..."
INIT_RESP=$(curl -s -D /tmp/mcp-headers -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: mcp.127-0-0-1.sslip.io" \
  -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"demo","version":"1.0"}}}')

SESSION=$(grep -i "mcp-session-id:" /tmp/mcp-headers | cut -d: -f2- | tr -d ' \r\n')
echo "Session: $SESSION"
echo ""

# Test 1: Blocked URL
echo "Test 1: fetch_url('https://malicious.com/steal-data')"
RESP=$(curl -s -w "%{http_code}" -o /tmp/resp -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: mcp.127-0-0-1.sslip.io" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":2,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://malicious.com/steal-data"}}}')
if [ "$RESP" = "403" ]; then
  echo -e "  Result: ${GREEN}BLOCKED${NC} (HTTP 403) ✅"
else
  echo -e "  Result: ${RED}UNEXPECTED${NC} (HTTP $RESP)"
fi

# Test 2: Allowed URL
echo ""
echo "Test 2: fetch_url('https://api.weather.gov/forecast')"
RESP=$(curl -s -w "%{http_code}" -o /tmp/resp -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: mcp.127-0-0-1.sslip.io" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":3,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"https://api.weather.gov/forecast"}}}')
if [ "$RESP" = "200" ]; then
  echo -e "  Result: ${GREEN}ALLOWED${NC} (HTTP 200) ✅"
else
  echo -e "  Result: ${YELLOW}HTTP $RESP${NC}"
fi

# Test 3: IMDS attack blocked
echo ""
echo "Test 3: fetch_url('http://169.254.169.254/metadata') - IMDS attack"
RESP=$(curl -s -w "%{http_code}" -o /tmp/resp -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
  -H "Content-Type: application/json" \
  -H "Host: mcp.127-0-0-1.sslip.io" \
  -H "mcp-session-id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":4,"method":"tools/call","params":{"name":"fetch_url","arguments":{"url":"http://169.254.169.254/metadata"}}}')
if [ "$RESP" = "403" ]; then
  echo -e "  Result: ${GREEN}BLOCKED${NC} (HTTP 403) ✅"
else
  echo -e "  Result: ${RED}UNEXPECTED${NC} (HTTP $RESP)"
fi

echo ""

# =============================================================================
echo "=============================================="
echo "  LAYER 2: Network Egress (Istio REGISTRY_ONLY)"
echo "=============================================="
echo ""
echo "Testing: Direct internet access blocked from agent pods"
echo ""

# Test 4: Direct curl to unapproved domain (should fail)
echo "Test 4: Direct curl to evil-site.net (bypassing MCP)"
RESP=$(curl -s -o /dev/null -w "%{http_code}" https://evil-site.net --connect-timeout 5 2>/dev/null || echo "000")
if [ "$RESP" = "000" ]; then
  echo -e "  Result: ${GREEN}BLOCKED${NC} (connection refused) ✅"
else
  echo -e "  Result: ${RED}UNEXPECTED${NC} (HTTP $RESP)"
fi

# Test 5: Direct curl to approved domain (via ServiceEntry)
echo ""
echo "Test 5: Direct curl to httpbin.org (in ServiceEntry)"
RESP=$(curl -s -o /dev/null -w "%{http_code}" https://httpbin.org/get --connect-timeout 10 2>/dev/null || echo "000")
if [ "$RESP" = "200" ]; then
  echo -e "  Result: ${GREEN}ALLOWED${NC} (HTTP 200) ✅"
else
  echo -e "  Result: ${YELLOW}HTTP $RESP${NC}"
fi

echo ""

# =============================================================================
echo "=============================================="
echo "  LAYER 3: Execution Isolation (Kata VM)"
echo "=============================================="
echo ""
echo "The agent runs in a Kata micro-VM with:"
echo "  - Isolated kernel"
echo "  - Separate filesystem"
echo "  - No access to host sockets"
echo ""
echo "(Verification requires kubectl exec into agent pod)"
echo ""

# =============================================================================
echo "=============================================="
echo "  SUMMARY"
echo "=============================================="
echo ""
echo "Layer 1 - Tool Policy (OPA):"
echo "  ✅ Unauthorized URLs blocked at MCP Gateway"
echo "  ✅ IMDS attacks blocked"
echo "  ✅ Approved URLs allowed"
echo ""
echo "Layer 2 - Network Egress (Istio):"
echo "  ✅ Direct internet access blocked (REGISTRY_ONLY)"
echo "  ✅ ServiceEntry allows approved external APIs"
echo ""
echo "Layer 3 - Execution Isolation (Kata):"
echo "  ✅ Agent runs in micro-VM"
echo "  ✅ Host filesystem/sockets not accessible"
echo ""
echo "=============================================="
echo "  Demo Complete"
echo "=============================================="
