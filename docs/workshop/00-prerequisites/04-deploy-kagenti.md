# Step 04: Deploy Kagenti

**Time**: 15 minutes

## What You'll Do

Deploy the Kagenti platform using Helm. This includes the Agent operator, MCP Gateway, and observability components.

## What Kagenti Provides

| Component | Purpose |
|-----------|---------|
| Kagenti Controller | Manages Agent CRDs |
| MCP Gateway | Routes tool calls to MCP servers |
| Phoenix | LLM observability and tracing |
| Kagenti UI | Web interface for managing agents |
| MCP Inspector | Debug MCP tool calls |

## Prerequisites

- Helm 3.x installed
- Cluster admin access
- OSC, Istio, and Kuadrant operators installed (or use kagenti-deps)

## Steps

### 1. Add Kagenti Helm Repository

```bash
helm repo add kagenti https://kagenti.github.io/kagenti
helm repo update
```

### 2. Install Dependencies (if not already installed)

The `kagenti-deps` chart installs Istio, Kuadrant, Keycloak, and other dependencies:

```bash
helm install kagenti-deps kagenti/kagenti-deps \
  -n kagenti-system \
  --create-namespace \
  --wait
```

### 3. Install Kagenti

```bash
# Set your cluster domain
CLUSTER_DOMAIN="apps.cluster-nngf2.dynamic.redhatworkshops.io"

helm install kagenti kagenti/kagenti \
  -n kagenti-system \
  --set keycloak.url="https://keycloak-keycloak.${CLUSTER_DOMAIN}" \
  --set agentOAuthSecret.spiffePrefix="spiffe://${CLUSTER_DOMAIN}/sa" \
  --wait
```

### 4. Verify Installation

```bash
oc get pods -n kagenti-system

# Expected output:
# NAME                                          READY   STATUS
# kagenti-controller-manager-xxxxx             1/1     Running
# kagenti-ui-xxxxx                             1/1     Running
# mcp-inspector-xxxxx                          1/1     Running
# otel-collector-xxxxx                         1/1     Running
# phoenix-0                                    1/1     Running
```

### 5. Check Helm Releases

```bash
helm list -n kagenti-system

# Expected output:
# NAME          NAMESPACE        REVISION  STATUS    CHART
# kagenti       kagenti-system   1         deployed  kagenti-0.2.0-alpha.2
# kagenti-deps  kagenti-system   1         deployed  kagenti-deps-0.2.0-alpha.2
```

## Access Kagenti UI

```bash
# Get the Kagenti UI URL
oc get route kagenti-ui -n kagenti-system -o jsonpath='{.spec.host}'
```

Open in browser to verify the UI is accessible.

## Troubleshooting

### Pods Not Starting

Check events:
```bash
oc get events -n kagenti-system --sort-by='.lastTimestamp' | tail -20
```

### Helm Install Fails

Check Helm status:
```bash
helm status kagenti -n kagenti-system
helm status kagenti-deps -n kagenti-system
```

### Missing Dependencies

Ensure kagenti-deps was installed first, or install operators manually.

---

👉 [Next: Verify Setup](05-verify-setup.md)

