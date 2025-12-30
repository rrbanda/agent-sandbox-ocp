# Troubleshooting Guide

## 1. Controller CrashLoopBackOff

**Symptom:** `kagenti-controller-manager` repeatedly crashes with "connection refused" to Kubernetes API

**Cause:** Namespace has `istio.io/dataplane-mode: ambient` label which intercepts API traffic

**Fix:**
```bash
oc label namespace kagenti-system istio.io/dataplane-mode-
oc delete pod -n kagenti-system -l control-plane=controller-manager
```

## 2. OPA Policy Not Blocking Requests

**Symptom:** All MCP tool calls succeed even for unauthorized URLs

**Cause:** Request body not being forwarded to Authorino

**Fix:** Ensure Istio mesh config has `includeRequestBodyInCheck`:
```bash
oc get istio default -n istio-system -o yaml | grep -A5 includeRequestBodyInCheck
```

If missing, apply:
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

## 3. Kata Pods Stuck in Pending

**Symptom:** Pods with `runtimeClassName: kata` never schedule

**Causes:**
1. No nodes have the required label
2. RuntimeClass nodeSelector doesn't match node labels
3. KataConfig not ready

**Fix:**
```bash
# Check RuntimeClass nodeSelector
oc get runtimeclass kata -o jsonpath='{.scheduling.nodeSelector}'

# Check which nodes have the label
oc get nodes -l node-role.kubernetes.io/kata-oc

# If no nodes, label one:
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""
```

## 4. Kata Pods OOM Killed

**Symptom:** Kata pods crash with OOMKilled

**Cause:** Insufficient memory for QEMU micro-VM

**Fix:** Set at least 2Gi memory:
```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

## 5. Direct Internet Access Still Working

**Symptom:** Pods can still `curl` external URLs directly

**Cause:** `outboundTrafficPolicy` not set to `REGISTRY_ONLY`

**Check:**
```bash
oc get istio default -n istio-system -o jsonpath='{.spec.values.meshConfig.outboundTrafficPolicy.mode}'
```

**Fix:**
```bash
oc patch istio default -n istio-system --type=merge -p '
{
  "spec": {
    "values": {
      "meshConfig": {
        "outboundTrafficPolicy": {
          "mode": "REGISTRY_ONLY"
        }
      }
    }
  }
}'
```

## 6. "RBAC: access denied" for All Requests

**Symptom:** All MCP requests return 403

**Cause:** Istio can't reach Authorino

**Fix:**
```bash
# Ensure kuadrant-system has Istio labels
oc label namespace kuadrant-system istio-discovery=enabled --overwrite

# Restart Authorino
oc rollout restart deployment/authorino -n kuadrant-system
```

## Verification Commands

```bash
# All components running?
oc get pods -n kagenti-system
oc get pods -n mcp-system
oc get pods -n gateway-system
oc get pods -n kuadrant-system

# AuthPolicy enforced?
oc get authpolicy -A

# Istio mode?
oc get istio default -n istio-system -o jsonpath='{.spec.values.meshConfig.outboundTrafficPolicy.mode}'

# Kata RuntimeClass?
oc get runtimeclass kata

# ServiceEntry for external APIs?
oc get serviceentry -n istio-system
```
