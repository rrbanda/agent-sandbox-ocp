# Section 4: Security Hardening

**Duration**: 10 minutes  
**Persona**: 👷 Platform Admin

## Overview

Now that the agent is deployed and working, you'll add the remaining security layers:

- **Layer 2**: Istio egress control (restrict external API access)
- **Layer 3**: OPA tool policy (block cryptocurrency conversions)


## Why Harden After Deployment?

| Without Hardening | With Hardening |
|-------------------|----------------|
| Agent can call ANY external API | Only approved APIs (frankfurter, googleapis) |
| All currency conversions work | BTC, ETH, DOGE blocked |
| No audit trail | All policy decisions logged |

By hardening after deployment, you:
1. **Understand the baseline** - See what the agent does unrestricted
2. **Apply targeted controls** - Know exactly what you're restricting
3. **Verify the difference** - Test before and after


## Step 1: Apply Egress Control (Layer 2)

Configure Istio to only allow approved external APIs:

```bash
cd manifests/currency-kagenti

# Apply ServiceEntry
oc apply -f security/01-service-entry.yaml
```

### What It Does

```yaml
# security/01-service-entry.yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: allowed-external-apis
spec:
  hosts:
    - api.frankfurter.app           # Currency rates - ALLOWED
    - generativelanguage.googleapis.com  # Gemini API - ALLOWED
  ports:
    - number: 443
      protocol: HTTPS
  location: MESH_EXTERNAL
```

| Host | Purpose |
|------|---------|
| `api.frankfurter.app` | Exchange rate API |
| `generativelanguage.googleapis.com` | Gemini LLM API |
| **Everything else** | **BLOCKED by default** |


## Step 2: Apply OPA Policy (Layer 3)

Configure OPA to block cryptocurrency conversions:

```bash
# Apply AuthPolicy
oc apply -f security/02-authpolicy.yaml
```

### What It Does

```yaml
# security/02-authpolicy.yaml (key parts)
apiVersion: kuadrant.io/v1beta2
kind: AuthPolicy
metadata:
  name: block-crypto-policy
spec:
  rules:
    authorization:
      opa:
        rego: |
          package currency_policy
          
          blocked_currencies := ["BTC", "ETH", "DOGE", "XRP", "SOL", "ADA"]
          
          # Block if source currency is crypto
          deny if {
            input.context.request.http.body.params.arguments.currency_from in blocked_currencies
          }
          
          # Block if target currency is crypto
          deny if {
            input.context.request.http.body.params.arguments.currency_to in blocked_currencies
          }
          
          allow if { not deny }
```

| Currency | Status |
|----------|--------|
| USD, EUR, GBP, JPY |  Allowed |
| BTC, ETH, DOGE, XRP, SOL, ADA |  Blocked |


## Step 3: Verify Security is Applied

### Check ServiceEntry

```bash
# List ServiceEntries
oc get serviceentry -n currency-kagenti

# Describe to see hosts
oc describe serviceentry allowed-external-apis -n currency-kagenti
```

### Check AuthPolicy

```bash
# List AuthPolicies
oc get authpolicy -n currency-kagenti

# Check status
oc describe authpolicy block-crypto-policy -n currency-kagenti
```


## Step 4: Test Blocked Operations

### Test Cryptocurrency Conversion (Should Be BLOCKED)

```bash
AGENT_URL=$(oc get route currency-agent -n currency-kagenti \
  -o jsonpath='https://{.spec.host}')

# This should be BLOCKED now
curl -X POST "$AGENT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to BTC"}],
        "messageId": "crypto-test"
      }
    }
  }'
```

### Expected Response

The agent should indicate it cannot complete the request:

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "message": {
      "role": "assistant",
      "parts": [
        {"text": "I'm sorry, but I'm not able to convert to cryptocurrency..."}
      ]
    }
  }
}
```

Or you might see an HTTP 403 error in the tool call.


## Step 5: Test Allowed Operations (Should Still Work)

```bash
# This should still WORK
curl -X POST "$AGENT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "2",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to EUR"}],
        "messageId": "fiat-test"
      }
    }
  }'
```

### Expected Response

```json
{
  "jsonrpc": "2.0",
  "id": "2",
  "result": {
    "message": {
      "role": "assistant",
      "parts": [
        {"text": "Based on today's rate, 100 USD is approximately 92.45 EUR..."}
      ]
    }
  }
}
```


## Security Layers Summary

All three layers are now active:

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Defense in Depth - ACTIVE                             │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│   Layer 1: Kata VM Isolation                               ACTIVE     │
│   ─────────────────────────────────────────────────────────────────     │
│   Agent runs in isolated micro-VM                                       │
│   Configured in: agent/05-currency-agent.yaml                           │
│                                                                         │
│   Layer 2: Istio Egress Control                            ACTIVE     │
│   ─────────────────────────────────────────────────────────────────     │
│   Only frankfurter.app and googleapis.com allowed                       │
│   Configured in: security/01-service-entry.yaml                         │
│                                                                         │
│   Layer 3: OPA Tool Policy                                 ACTIVE     │
│   ─────────────────────────────────────────────────────────────────     │
│   Cryptocurrency conversions blocked                                    │
│   Configured in: security/02-authpolicy.yaml                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```


## Summary

You've now:

-  Applied Istio egress control (Layer 2)
-  Applied OPA tool policy (Layer 3)
-  Tested that BTC/ETH is blocked
-  Verified that USD/EUR still works

All three security layers are now protecting the agent!


## Next

Monitor the agent and view traces:

👉 [Section 5: Monitor & Tune](../05-monitor-and-tune/index.md)

