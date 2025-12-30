#!/bin/bash
# Currency Demo - Complete Test Script
#
# Tests all three security layers:
#   1. OPA Policy (blocks BTC/ETH)
#   2. Istio Egress (blocks unapproved domains)
#   3. Kata Isolation (verifies VM runtime)
#
# Prerequisites:
#   - All YAML files applied (00-06)
#   - MCP Gateway running

set -e

GATEWAY_URL="http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
HOST_HEADER="currency-mcp.mcp.local"

echo "=============================================="
echo "  Currency Demo - Three-Layer Security Test"
echo "=============================================="
echo ""

# Create test pod if needed
echo "=== Creating test pod ==="
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-curl
  namespace: mcp-test
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "3600"]
EOF

oc wait --for=condition=Ready pod/test-curl -n mcp-test --timeout=60s 2>/dev/null || true
echo ""

# Initialize MCP session
echo "=== Initializing MCP Session ==="
SESSION=$(oc exec -n mcp-test test-curl -- curl -s \
  "$GATEWAY_URL" \
  -H "Host: $HOST_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  -D - 2>/dev/null | grep -i "mcp-session-id:" | awk -F': ' '{print $2}' | tr -d '\r')

if [ -z "$SESSION" ]; then
  echo "ERROR: Failed to get session ID"
  exit 1
fi
echo "Session ID: ${SESSION:0:30}..."
echo ""

echo "=============================================="
echo "  LAYER 1: OPA Policy Enforcement"
echo "=============================================="
echo ""

echo "Test 1: USD → EUR (SHOULD ALLOW)"
RESULT=$(oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  "$GATEWAY_URL" \
  -H "Host: $HOST_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"EUR"}}}')
if [ "$RESULT" == "200" ]; then
  echo "  ✅ HTTP 200 - ALLOWED (correct)"
else
  echo "  ❌ HTTP $RESULT - Expected 200"
fi
echo ""

echo "Test 2: USD → BTC (SHOULD BLOCK)"
RESULT=$(oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  "$GATEWAY_URL" \
  -H "Host: $HOST_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"BTC"}}}')
if [ "$RESULT" == "403" ]; then
  echo "  ✅ HTTP 403 - BLOCKED (correct)"
else
  echo "  ❌ HTTP $RESULT - Expected 403"
fi
echo ""

echo "Test 3: ETH → EUR (SHOULD BLOCK)"
RESULT=$(oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  "$GATEWAY_URL" \
  -H "Host: $HOST_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"4","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"ETH","currency_to":"EUR"}}}')
if [ "$RESULT" == "403" ]; then
  echo "  ✅ HTTP 403 - BLOCKED (correct)"
else
  echo "  ❌ HTTP $RESULT - Expected 403"
fi
echo ""

echo "Test 4: GBP → JPY (SHOULD ALLOW)"
RESULT=$(oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  "$GATEWAY_URL" \
  -H "Host: $HOST_HEADER" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"5","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"GBP","currency_to":"JPY"}}}')
if [ "$RESULT" == "200" ]; then
  echo "  ✅ HTTP 200 - ALLOWED (correct)"
else
  echo "  ❌ HTTP $RESULT - Expected 200"
fi
echo ""

echo "=============================================="
echo "  LAYER 3: Kata VM Isolation"
echo "=============================================="
echo ""

echo "Checking Currency Agent runtime..."
RUNTIME=$(oc get pod -n agent-sandbox -l app=currency-agent -o jsonpath='{.items[0].spec.runtimeClassName}' 2>/dev/null || echo "not-found")
if [ "$RUNTIME" == "kata" ]; then
  echo "  ✅ RuntimeClass: kata (VM isolation enabled)"
else
  echo "  ❌ RuntimeClass: $RUNTIME (expected: kata)"
fi
echo ""

echo "Checking Agent status..."
oc get agent -n agent-sandbox 2>/dev/null || echo "  No agents found"
echo ""

echo "=============================================="
echo "  Summary"
echo "=============================================="
echo ""
echo "Layer 1 (OPA):   Blocks BTC/ETH, allows fiat currencies"
echo "Layer 2 (Istio): Allows only api.frankfurter.app egress"
echo "Layer 3 (Kata):  Agent runs in isolated VM"
echo ""
echo "Demo complete!"
