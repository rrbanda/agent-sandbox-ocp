# Verify Setup

**Duration**: 5 minutes

Before starting the workshop, verify all components are installed and running correctly.

---

## Quick Verification

Run this single command to check everything:

```bash
echo "=== Checking OSC ===" && \
oc get runtimeclass kata && \
echo "" && \
echo "=== Checking Kagenti ===" && \
oc get pods -n kagenti-system | grep -E "NAME|Running" && \
echo "" && \
echo "=== Checking MCP Gateway ===" && \
oc get pods -n mcp-system | grep -E "NAME|Running" && \
echo "" && \
echo "=== Checking Keycloak ===" && \
oc get pods -n keycloak | grep -E "NAME|Running" && \
echo "" && \
echo "=== Checking Gateway ===" && \
oc get pods -n gateway-system | grep -E "NAME|Running" && \
echo "" && \
echo "✅ All components verified!"
```

---

## Detailed Verification

### Layer 1: OSC / Kata

```bash
# RuntimeClass exists
oc get runtimeclass kata
```

Expected:
```
NAME   HANDLER   AGE
kata   kata      1h
```

### Kagenti System

```bash
oc get pods -n kagenti-system
```

Expected (all Running):
```
NAME                                          READY   STATUS    
kagenti-controller-manager-xxxxx              1/1     Running   
kagenti-ui-xxxxx                              1/1     Running   
mcp-inspector-xxxxx                           1/1     Running   
otel-collector-xxxxx                          1/1     Running   
phoenix-0                                     1/1     Running   
postgres-otel-0                               1/1     Running   
```

### MCP Gateway

```bash
oc get pods -n mcp-system
```

Expected (all Running):
```
NAME                                         READY   STATUS    
mcp-gateway-broker-router-xxxxx              1/1     Running   
mcp-gateway-controller-xxxxx                 1/1     Running   
```

### Keycloak

```bash
oc get pods -n keycloak
```

Expected (all Running):
```
NAME                             READY   STATUS    
keycloak-0                       1/1     Running   
postgres-kc-0                    1/1     Running   
rhbk-operator-xxxxx              1/1     Running   
```

### Gateway System

```bash
oc get pods -n gateway-system
```

Expected:
```
NAME                                 READY   STATUS    
mcp-gateway-istio-xxxxx              1/1     Running   
```

---

## Check CRDs

Verify Kagenti CRDs are installed:

```bash
oc get crd | grep -E "kagenti|agent"
```

Expected:
```
agentbuilds.agent.kagenti.dev
agentcards.agent.kagenti.dev
agents.agent.kagenti.dev
mcpservers.mcp.kagenti.com
mcpvirtualservers.mcp.kagenti.com
```

---

## Access URLs

Get the URLs for web interfaces:

```bash
echo "Kagenti UI:    https://$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
echo "Keycloak:      https://$(oc get route keycloak -n keycloak -o jsonpath='{.status.ingress[0].host}')"
echo "MCP Inspector: https://$(oc get route mcp-inspector -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
echo "Phoenix:       https://$(oc get route phoenix -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
```

### Test Kagenti UI Access

1. Open the Kagenti UI URL in your browser
2. You should see a login page
3. Get Keycloak credentials:

```bash
oc get secret keycloak-initial-admin -n keycloak \
  -o go-template='Username: {{.data.username | base64decode}}
Password: {{.data.password | base64decode}}{{"\n"}}'
```

---

## Verification Checklist

| Component | Check | Status |
|-----------|-------|--------|
| OSC Operator | `oc get csv -n openshift-sandboxed-containers-operator` | ✅ Succeeded |
| RuntimeClass | `oc get runtimeclass kata` | ✅ Exists |
| Kagenti Controller | `oc get pods -n kagenti-system -l app.kubernetes.io/name=kagenti` | ✅ Running |
| MCP Gateway | `oc get pods -n mcp-system` | ✅ All Running |
| Keycloak | `oc get pods -n keycloak -l app=keycloak` | ✅ Running |
| Gateway Envoy | `oc get pods -n gateway-system` | ✅ Running |
| Kagenti CRDs | `oc get crd agents.agent.kagenti.dev` | ✅ Exists |
| Kagenti UI | Open URL in browser | ✅ Loads |

---

## Common Issues

### Pods in CrashLoopBackOff

```bash
# Check logs for the crashing pod
oc logs -n <namespace> <pod-name>

# Check events
oc get events -n <namespace> --sort-by='.lastTimestamp'
```

### Routes not accessible

```bash
# Check route status
oc get route -n kagenti-system

# Verify ingress controller is running
oc get pods -n openshift-ingress
```

### CRDs missing

If CRDs are missing, the Kagenti helm chart may not have installed correctly:

```bash
# Check helm release
helm list -n kagenti-system

# Check for errors
helm status kagenti -n kagenti-system
```

---

## All Systems Ready!

Your cluster now has:

| Layer | Component | Status |
|-------|-----------|--------|
| **1. VM Isolation** | OSC / Kata | ✅ Ready |
| **2. Network Egress** | Istio | ✅ Ready |
| **3. Tool Policy** | Kuadrant / OPA | ✅ Ready |
| **Platform** | Kagenti | ✅ Ready |

You're ready to start the workshop!

---

## Next Steps

👉 **[Part 1: Foundations](../01-foundations/index.md)** - Understand why agents need special security

Or if you're already familiar with the concepts:

👉 **[Part 2: Inner Loop](../02-inner-loop/index.md)** - Build and test your agent

