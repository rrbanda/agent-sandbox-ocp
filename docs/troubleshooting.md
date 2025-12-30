# Troubleshooting Guide

## 1. Controller CrashLoopBackOff

**Symptom:** `kagenti-controller-manager` repeatedly crashes with "connection refused"

**Cause:** Namespace has `istio.io/dataplane-mode: ambient` label

**Fix:**
```bash
oc label namespace kagenti-system istio.io/dataplane-mode-
oc delete pod -n kagenti-system -l control-plane=controller-manager
```

## 2. OPA Policy Not Blocking Requests

**Symptom:** All tool calls succeed even for BTC/ETH

**Cause:** Request body not forwarded to Authorino

**Check:**
```bash
oc get istio default -n istio-system -o yaml | grep -A5 includeRequestBodyInCheck
```

**Fix:**
```bash
oc patch istio default -n istio-system --type=merge -p '
{
  "spec": {
    "values": {
      "meshConfig": {
        "extensionProviders": [
          {
            "name": "kuadrant-authorization",
            "envoyExtAuthzGrpc": {
              "service": "authorino-authorino-authorization.kuadrant-system.svc.cluster.local",
              "port": 50051,
              "timeout": "5s",
              "includeRequestBodyInCheck": {
                "maxRequestBytes": 8192,
                "allowPartialMessage": true
              }
            }
          }
        ]
      }
    }
  }
}'
```

## 3. 502 Bad Gateway

**Symptom:** Gateway returns 502 when testing

**Cause:** Test pod has Istio sidecar injected

**Fix:** Recreate pod with sidecar disabled:
```bash
oc delete pod test-curl -n mcp-test
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
```

## 4. MCP Server SSL Errors

**Symptom:** `SSL: UNEXPECTED_EOF_WHILE_READING` in MCP server logs

**Cause:** Istio sidecar intercepting HTTPS traffic

**Fix:** Ensure `02-currency-mcp-server.yaml` has:
```yaml
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

## 5. Kata Pods Stuck in Pending

**Symptom:** Pods with `runtimeClassName: kata` never schedule

**Fix:**
```bash
# Check which nodes have the Kata label
oc get nodes -l node-role.kubernetes.io/kata-oc

# If none, label a node:
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""

# Verify RuntimeClass exists
oc get runtimeclass kata
```

## 6. Kata Pods OOM Killed

**Symptom:** Kata pods crash with OOMKilled

**Fix:** Set at least 2Gi memory in `05-currency-agent.yaml`:
```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

## 7. HTTPRoute Not Working (404)

**Symptom:** Gateway returns 404

**Cause:** Host header doesn't match HTTPRoute

**Fix:** Use correct Host header:
```bash
curl -H "Host: currency-mcp.mcp.local" \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp
```

## 8. Agent Can't Connect to MCP Server

**Symptom:** Agent logs show connection errors

**Check:**
```bash
# MCP server running?
oc get pods -n mcp-test -l app=currency-mcp-server

# HTTPRoute configured?
oc get httproute -n mcp-test

# Agent env correct?
oc get agent -n agent-sandbox currency-agent -o yaml | grep MCP_SERVER_URL
```

## Verification Commands

```bash
# All components running?
oc get pods -n kagenti-system
oc get pods -n gateway-system
oc get pods -n kuadrant-system
oc get pods -n mcp-test
oc get pods -n agent-sandbox

# AuthPolicy applied?
oc get authpolicy -n gateway-system

# Kata RuntimeClass exists?
oc get runtimeclass kata

# Agent status?
oc get agent -n agent-sandbox
```
