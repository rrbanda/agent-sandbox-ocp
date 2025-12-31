# Step 05: Test Tool Policy

**Time**: 5 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Verify that the OPA policy correctly blocks cryptocurrency conversions while allowing fiat currency conversions.

---

## Test 1: Allowed Request (USD → EUR)

Send a fiat currency conversion request:

```bash
# Get the route URL
ROUTE_URL=$(oc get route currency-agent -n currency-kagenti -o jsonpath='https://{.spec.host}')

# Send allowed request
curl -X POST "$ROUTE_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to EUR"}]
      },
      "messageId": "test-1"
    }
  }'
```

Expected: Successful response with exchange rate

---

## Test 2: Blocked Request (USD → BTC)

Send a cryptocurrency conversion request:

```bash
curl -X POST "$ROUTE_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "2",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to BTC"}]
      },
      "messageId": "test-2"
    }
  }'
```

Expected: Error response (403 Forbidden or policy violation message)

---

## Test 3: Direct MCP Server Test

Test the MCP server directly (bypassing agent):

### Allowed Tool Call

```bash
MCP_URL="http://currency-mcp-server.currency-kagenti.svc.cluster.local:8080/mcp"

oc exec -n currency-kagenti deployment/currency-agent -c agent -- \
  python3 -c "
import urllib.request
import json

data = json.dumps({
    'jsonrpc': '2.0',
    'method': 'tools/call',
    'id': '1',
    'params': {
        'name': 'get_exchange_rate',
        'arguments': {
            'currency_from': 'USD',
            'currency_to': 'EUR',
            'amount': 100
        }
    }
}).encode()

req = urllib.request.Request('$MCP_URL', data=data, headers={
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream'
})
try:
    resp = urllib.request.urlopen(req, timeout=10)
    print('✓ USD→EUR: Allowed')
    print(resp.read().decode()[:200])
except Exception as e:
    print('✗ USD→EUR: Error -', e)
"
```

### Blocked Tool Call (via Gateway)

```bash
# When routed through MCP Gateway with AuthPolicy, BTC should be blocked
GATEWAY_URL="http://mcp-gateway.kagenti-system.svc.cluster.local:8080/currency-mcp/mcp"

oc exec -n currency-kagenti deployment/currency-agent -c agent -- \
  python3 -c "
import urllib.request
import json

data = json.dumps({
    'jsonrpc': '2.0',
    'method': 'tools/call',
    'id': '2',
    'params': {
        'name': 'get_exchange_rate',
        'arguments': {
            'currency_from': 'USD',
            'currency_to': 'BTC',
            'amount': 100
        }
    }
}).encode()

req = urllib.request.Request('$GATEWAY_URL', data=data, headers={
    'Content-Type': 'application/json',
    'Accept': 'application/json, text/event-stream'
})
try:
    resp = urllib.request.urlopen(req, timeout=10)
    print('✗ USD→BTC: Should have been blocked!')
except urllib.error.HTTPError as e:
    if e.code == 403:
        print('✓ USD→BTC: Correctly blocked (403 Forbidden)')
    else:
        print('? USD→BTC: Error', e.code, e.reason)
except Exception as e:
    print('? USD→BTC: Error -', e)
"
```

---

## Expected Results

| Test | Currency Pair | Expected Result |
|------|---------------|-----------------|
| Test 1 | USD → EUR | ✓ Success with rate |
| Test 2 | USD → BTC | ✗ Blocked (403/error) |
| Test 3a | USD → EUR (direct) | ✓ Success |
| Test 3b | USD → BTC (via gateway) | ✗ Blocked |

---

## Verification Summary

```bash
echo "=== Tool Policy Verification ===" && \
echo "" && \
echo "1. AuthPolicy exists:" && \
oc get authpolicy -n currency-kagenti && \
echo "" && \
echo "2. HTTPRoute exists:" && \
oc get httproute -n currency-kagenti && \
echo "" && \
echo "3. Authorino running:" && \
oc get pods -n kuadrant-system | grep authorino
```

---

## Check Policy Logs

View Authorino logs for policy decisions:

```bash
oc logs -n kuadrant-system -l app=authorino --tail=50 | grep -E "allow|deny|decision"
```

---

## Before vs After

| Capability | Before Policy | After Policy |
|------------|---------------|--------------|
| USD → EUR | ✓ Allowed | ✓ Allowed |
| USD → BTC | ✓ Allowed | ✗ Blocked |
| ETH → USD | ✓ Allowed | ✗ Blocked |
| Policy audit | No visibility | All decisions logged |

---

## Module Complete! 🎉

You've successfully configured:

| Security Layer | What You Configured |
|----------------|---------------------|
| **Layer 1: VM Isolation** | Kata runtime (from Module 02) |
| **Layer 2: Network Egress** | ServiceEntry allowlist |
| **Layer 3: Tool Policy** | OPA AuthPolicy |

---

## Complete Security Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AI Agent Security - All Layers Active                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Agent Request: "Convert 100 USD to BTC"                                │
│                          ↓                                              │
│  Layer 3: Tool Policy ────────────→ ✗ BTC in blocked list              │
│                          ↓            (Request blocked)                 │
│  (If allowed)                                                           │
│                          ↓                                              │
│  Layer 2: Network Egress ─────────→ Only approved APIs                 │
│                          ↓                                              │
│  Layer 1: VM Isolation ───────────→ Can't escape micro-VM              │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Next Steps

| Action | Link |
|--------|------|
| View traces in Phoenix | [Module 04: Observe Traces](../04-deploy-and-test/05-observe-traces.md) |
| Clean up resources | [Appendix: Cleanup](../06-appendix/cleanup.md) |
| Explore next steps | [Appendix: What's Next](../06-appendix/next-steps.md) |

