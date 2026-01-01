# Install Kagenti

**Duration**: 20 minutes

Kagenti is a Kubernetes-native AI agent platform that provides agent deployment, MCP Gateway, and observability. Installing Kagenti also installs Istio, Keycloak, cert-manager, and other dependencies.

---

## What Gets Installed

| Component | Namespace | Purpose |
|-----------|-----------|---------|
| **Kagenti Controller** | kagenti-system | Manages Agent and AgentBuild CRDs |
| **Kagenti UI** | kagenti-system | Web interface for agent management |
| **MCP Gateway** | mcp-system, gateway-system | Routes tool calls, enforces policies |
| **Istio** | istio-system, istio-cni | Service mesh for egress control |
| **Keycloak** | keycloak | Authentication and authorization |
| **cert-manager** | cert-manager | TLS certificate management |
| **Phoenix** | kagenti-system | Observability dashboard |

---

## Installation Methods

=== "Automated Script (Recommended)"

    The install script handles all steps including known workarounds:
    
    ```bash
    # Ensure secrets file exists
    cat /tmp/.secrets.yaml
    
    # Run install script
    cd /path/to/agent-sandbox-ocp
    ./scripts/install-kagenti.sh
    ```
    
    The script will:
    
    1. Check prerequisites
    2. Remove conflicting cert-manager (if needed)
    3. Configure OVN for Istio
    4. Install Gateway API CRDs
    5. Install kagenti-deps (Istio, Keycloak, etc.)
    6. Install MCP Gateway
    7. Apply required workarounds
    8. Install Kagenti platform
    
    **Skip to [Verify Installation](#verify-installation) after the script completes.**

=== "Manual Installation"

    Follow the step-by-step instructions below.

---

## Manual Installation Steps

### Step 1: Set Environment Variables

```bash
# Get cluster domain
export DOMAIN=apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')
echo "Domain: $DOMAIN"

# Set versions
export KAGENTI_VERSION="0.2.0-alpha.2"
export GATEWAY_VERSION="0.4.0"
```

### Step 2: Remove Existing cert-manager (if present)

Kagenti installs its own cert-manager. If Red Hat's version exists, it will conflict.

```bash
# Check if cert-manager exists
oc get ns cert-manager-operator 2>/dev/null && echo "Found - needs removal"
oc get ns cert-manager 2>/dev/null && echo "Found - needs removal"
```

If found, remove it:

```bash
# Remove cert-manager deployments
oc delete deploy cert-manager cert-manager-cainjector cert-manager-webhook \
  -n cert-manager 2>/dev/null || true

# Remove subscriptions
oc delete subscription -n cert-manager-operator --all 2>/dev/null || true
oc delete csv -n cert-manager-operator --all 2>/dev/null || true

# Delete namespaces
oc delete ns cert-manager cert-manager-operator --wait=false 2>/dev/null || true

# Wait for cleanup
sleep 15
```

### Step 3: Install Gateway API CRDs

!!! warning "Critical Step - Often Missing from Docs"
    The MCP Gateway requires Gateway API CRDs, but kagenti-deps doesn't install them.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml

# Verify
oc get crd httproutes.gateway.networking.k8s.io
```

### Step 4: Create gateway-system Namespace

The Kagenti chart expects this namespace to exist and wants to manage it:

```bash
# Create namespace
oc create namespace gateway-system

# Pre-label for Helm adoption
oc label namespace gateway-system app.kubernetes.io/managed-by=Helm --overwrite
oc annotate namespace gateway-system meta.helm.sh/release-name=kagenti --overwrite
oc annotate namespace gateway-system meta.helm.sh/release-namespace=kagenti-system --overwrite
```

### Step 5: Install kagenti-deps

This installs Istio, Keycloak, cert-manager, Tekton, and other dependencies:

```bash
helm install --create-namespace -n kagenti-system kagenti-deps \
  oci://ghcr.io/kagenti/kagenti/kagenti-deps \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set components.spire.enabled=false \
  --set domain=${DOMAIN} \
  --timeout 20m
```

!!! note "Why disable SPIRE?"
    SPIRE requires SpiffeCSIDriver CRDs that don't exist on standard OpenShift clusters.

Wait for completion (5-10 minutes).

### Step 6: Install MCP Gateway

```bash
helm install mcp-gateway oci://ghcr.io/kagenti/charts/mcp-gateway \
  --create-namespace --namespace mcp-system \
  --version $GATEWAY_VERSION \
  --timeout 10m
```

### Step 7: Fix MCP Gateway (Required Workaround)

!!! bug "Chart Bug in v0.4.0"
    The MCP Gateway chart passes `--mcp-broker-config-address` flag, but the current image doesn't support it. This causes the broker-router to crash.

Apply the fix immediately:

```bash
oc patch deployment mcp-gateway-broker-router -n mcp-system --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": [
    "./mcp_gateway",
    "--mcp-gateway-config=/config/config.yaml",
    "--mcp-broker-public-address=0.0.0.0:8080",
    "--mcp-router-address=0.0.0.0:50051",
    "--mcp-gateway-public-host=mcp.127-0-0-1.sslip.io",
    "--log-level=-4"
  ]}
]'

# Wait for restart
sleep 10
oc get pods -n mcp-system
```

### Step 8: Install Kagenti Platform

```bash
helm upgrade --install -n kagenti-system \
  -f /tmp/.secrets.yaml kagenti oci://ghcr.io/kagenti/kagenti/kagenti \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set domain=${DOMAIN} \
  --set agentOAuthSecret.spiffePrefix=spiffe://${DOMAIN}/sa \
  --set uiOAuthSecret.useServiceAccountCA=false \
  --set agentOAuthSecret.useServiceAccountCA=false \
  --timeout 15m
```

---

## Verify Installation

### Check All Pods

```bash
echo "=== kagenti-system ==="
oc get pods -n kagenti-system

echo ""
echo "=== mcp-system ==="
oc get pods -n mcp-system

echo ""
echo "=== keycloak ==="
oc get pods -n keycloak

echo ""
echo "=== gateway-system ==="
oc get pods -n gateway-system
```

All pods should show `Running` status.

### Expected Pod Status

| Namespace | Pods | Status |
|-----------|------|--------|
| kagenti-system | kagenti-controller-manager, kagenti-ui, mcp-inspector, otel-collector, phoenix, postgres-otel | Running |
| mcp-system | mcp-gateway-broker-router, mcp-gateway-controller | Running |
| keycloak | keycloak, postgres-kc, rhbk-operator | Running |
| gateway-system | mcp-gateway-istio | Running |

### Get Access URLs

```bash
echo "Kagenti UI:    https://$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
echo "Keycloak:      https://$(oc get route keycloak -n keycloak -o jsonpath='{.status.ingress[0].host}')"
echo "MCP Inspector: https://$(oc get route mcp-inspector -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
```

### Get Keycloak Credentials

```bash
oc get secret keycloak-initial-admin -n keycloak \
  -o go-template='Username: {{.data.username | base64decode}}
Password: {{.data.password | base64decode}}{{"\n"}}'
```

---

## Troubleshooting

### Issue: cert-manager namespace stuck terminating

```bash
# Force delete finalizers
NAMESPACE=cert-manager
oc get namespace $NAMESPACE -o json | \
  jq '.spec.finalizers = []' | \
  oc replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -
```

### Issue: MCP Gateway broker-router CrashLoopBackOff

Symptom:
```
flag provided but not defined: -mcp-broker-config-address
```

Solution: Apply the patch from Step 7.

### Issue: Gateway API CRDs not found

Symptom:
```
no matches for kind "HTTPRoute" in version "gateway.networking.k8s.io/v1"
```

Solution: Install Gateway API CRDs from Step 3.

### Issue: kagenti chart fails with "gateway-system exists"

Symptom:
```
Namespace "gateway-system" exists and cannot be imported
```

Solution: Pre-label the namespace for Helm adoption (Step 4).

---

## What's Installed

After installation, you have:

| Layer | Component | Status |
|-------|-----------|--------|
| **Platform** | Kagenti Controller, UI, CRDs | ✅ Ready |
| **MCP Gateway** | Envoy-based tool routing | ✅ Ready |
| **Layer 2** | Istio service mesh | ✅ Ready |
| **Layer 3** | Kuadrant/Authorino | ✅ Ready |
| **Auth** | Keycloak | ✅ Ready |
| **Observability** | Phoenix, OTEL Collector | ✅ Ready |

---

## Next Step

👉 **[Step 4: Verify Setup](04-verify-setup.md)**

