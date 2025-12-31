# Step 03: Test Egress Control

**Time**: 5 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Verify that egress control is working by testing both allowed and blocked destinations.

---

## Test 1: Allowed API

The Currency API should be accessible:

```bash
# Test from the agent pod
oc exec -n currency-kagenti deployment/currency-agent -c agent -- \
  python3 -c "
import urllib.request
import ssl

ctx = ssl.create_default_context()
req = urllib.request.Request('https://api.frankfurter.app/latest?from=USD&to=EUR')
resp = urllib.request.urlopen(req, context=ctx, timeout=10)
print('✓ Currency API accessible')
print(resp.read().decode()[:100])
"
```

Expected: `✓ Currency API accessible` with JSON response

---

## Test 2: Blocked API

An API not in ServiceEntry should be blocked:

```bash
# Test blocked destination
oc exec -n currency-kagenti deployment/currency-agent -c agent -- \
  python3 -c "
import urllib.request
import ssl

ctx = ssl.create_default_context()
req = urllib.request.Request('https://api.openai.com/v1/models')
try:
    resp = urllib.request.urlopen(req, context=ctx, timeout=5)
    print('✗ ERROR: Connection should have been blocked!')
except Exception as e:
    print('✓ Correctly blocked:', type(e).__name__)
"
```

Expected: `✓ Correctly blocked: URLError` or connection timeout

---

## Test 3: Using Test Pod

For more extensive testing, create a test pod:

```bash
# Create test pod in the namespace
oc run egress-test -n currency-kagenti --rm -it --restart=Never \
  --image=registry.access.redhat.com/ubi9/ubi-minimal:latest \
  --labels="sidecar.istio.io/inject=true" \
  -- bash -c '
    echo "=== Testing Egress Control ==="
    echo ""
    echo "1. Testing allowed API (frankfurter.app):"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" https://api.frankfurter.app/latest --max-time 5 || echo "   Connection failed"
    echo ""
    echo "2. Testing blocked API (api.openai.com):"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" https://api.openai.com/ --max-time 5 || echo "   Connection blocked (expected)"
    echo ""
    echo "3. Testing blocked arbitrary host:"
    curl -s -o /dev/null -w "   HTTP %{http_code}\n" https://evil.com/ --max-time 5 || echo "   Connection blocked (expected)"
  '
```

---

## Understanding the Results

| Test | Expected Result | What It Means |
|------|-----------------|---------------|
| `api.frankfurter.app` | HTTP 200 or JSON response | ✓ ServiceEntry working |
| `api.openai.com` | Connection timeout/refused | ✓ Not in ServiceEntry, blocked |
| `evil.com` | Connection timeout/refused | ✓ Not in ServiceEntry, blocked |

---

## Check Istio Proxy Logs

To see what's being blocked:

```bash
# View proxy logs
oc logs -n currency-kagenti deployment/currency-agent -c istio-proxy --tail=20 | grep -E "outbound|blackhole"
```

Look for:
- `cluster_out` - Successful outbound connections
- `BlackHoleCluster` - Blocked connections

---

## Before vs After

| Metric | Before ServiceEntry | After ServiceEntry |
|--------|---------------------|---------------------|
| External APIs accessible | All | Only 2 (frankfurter, googleapis) |
| `evil.com` reachable | Yes | No |
| Data exfiltration risk | High | Mitigated |

---

## Verification Summary

```bash
echo "=== Egress Control Verification ===" && \
echo "" && \
echo "1. ServiceEntry exists:" && \
oc get serviceentry -n currency-kagenti && \
echo "" && \
echo "2. Agent pod has Istio sidecar:" && \
oc get pod -n currency-kagenti -l app.kubernetes.io/name=currency-agent -o jsonpath='{.items[0].spec.containers[*].name}' && \
echo "" && \
echo "" && \
echo "3. Testing allowed API:" && \
oc exec -n currency-kagenti deployment/currency-agent -c agent -- \
  python3 -c "import urllib.request; print('✓' if urllib.request.urlopen('https://api.frankfurter.app/latest', timeout=5).status == 200 else '✗')" 2>/dev/null || echo "✗ Failed"
```

---

## Troubleshooting

### All Connections Fail

**Cause**: Istio sidecar not injected or not running.

```bash
# Check sidecar
oc get pod -n currency-kagenti -l app.kubernetes.io/name=currency-agent -o yaml | grep -c istio-proxy

# Restart to inject sidecar
oc rollout restart deployment currency-agent -n currency-kagenti
```

### Allowed API is Blocked

**Cause**: ServiceEntry not in correct namespace or wrong hostname.

```bash
# Verify ServiceEntry
oc describe serviceentry allowed-external-apis -n currency-kagenti

# Check hosts match exactly (including subdomains)
```

### Can't Reach Internal Services

**Cause**: ServiceEntry is only for external services. Internal services should work automatically.

```bash
# Test internal service
oc exec -n currency-kagenti deployment/currency-agent -- \
  curl -s http://currency-mcp-server.currency-kagenti.svc:8080/health
```

---

## Next Step

Egress control is working. Now let's add tool-level policy enforcement.

👉 [Step 04: Configure Policy](04-configure-policy.md)

