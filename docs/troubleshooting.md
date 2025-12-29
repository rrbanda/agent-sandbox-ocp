# Troubleshooting Guide

## Common Issues

### 1. "RBAC: access denied" for all requests

**Symptom**: All MCP requests return 403 with "RBAC: access denied"

**Cause**: Istio can't reach Authorino ext_authz service

**Solutions**:
1. Ensure `kuadrant-system` namespace has Istio labels:
   ```bash
   oc label namespace kuadrant-system istio-discovery=enabled istio-injection=enabled --overwrite
   ```

2. Restart Authorino to get sidecar:
   ```bash
   oc rollout restart deployment/authorino -n kuadrant-system
   ```

3. Check that Authorino cluster is healthy:
   ```bash
   oc port-forward -n gateway-system deployment/mcp-gateway-istio 15000:15000 &
   curl -s localhost:15000/clusters | grep "authorino.*health"
   ```

### 2. "no healthy upstream" (HTTP 503)

**Symptom**: Requests return 503 "no healthy upstream"

**Cause**: MCP broker or Authorino pods not ready

**Solutions**:
1. Check MCP broker status:
   ```bash
   oc get pods -n mcp-system
   oc get endpoints mcp-gateway-broker -n mcp-system
   ```

2. Ensure mcp-system has sidecar injection:
   ```bash
   oc label namespace mcp-system istio-discovery=enabled istio-injection=enabled --overwrite
   oc delete pods -n mcp-system --all
   ```

### 3. OPA policy not blocking requests

**Symptom**: All requests pass through even when they should be blocked

**Cause**: Request body not being forwarded to Authorino

**Solution**: Enable body forwarding in Istio mesh config:
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

### 4. Kata pods stuck in "Pending"

**Symptom**: Pods with `runtimeClassName: kata` stay in Pending

**Cause**: Node selector mismatch or KataConfig not ready

**Solutions**:
1. Check KataConfig status:
   ```bash
   oc get kataconfig -o yaml | grep -A20 "status:"
   ```

2. Check RuntimeClass node selector:
   ```bash
   oc get runtimeclass kata -o yaml
   ```

3. Ensure nodes have the correct label:
   ```bash
   oc get nodes -l node-role.kubernetes.io/kata-oc
   ```

### 5. Kata pods OOM killed

**Symptom**: Pods crash with "OOMKilled" or kernel logs show `qemu-kvm` killed

**Cause**: Insufficient memory for Kata micro-VM

**Solution**: Set at least 2Gi memory for Kata pods:
```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

### 6. Istio ambient mode limitations

**Symptom**: AuthPolicy shows "Enforced: True" but ext_authz doesn't work

**Cause**: Istio in ambient mode has limited ext_authz support for ingress gateways

**Solution**: Switch to sidecar mode:
```bash
oc patch istio default -n istio-system --type=json -p='[
  {"op": "remove", "path": "/spec/values/profile"},
  {"op": "remove", "path": "/spec/values/pilot/trustedZtunnelNamespace"}
]'

# Create istio-cni namespace if missing
oc create namespace istio-cni
```

## Verification Commands

### Check Authorino is receiving requests
```bash
oc logs deployment/authorino -n kuadrant-system --tail=20 | grep "incoming authorization"
```

### Check AuthPolicy status
```bash
oc get authpolicy -n gateway-system -o wide
```

### Check AuthConfig status
```bash
oc get authconfig -n gateway-system
```

### Check gateway logs for errors
```bash
oc logs deployment/mcp-gateway-istio -n gateway-system --tail=20
```
