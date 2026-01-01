# Kagenti Installation Guide for OpenShift

This guide provides step-by-step instructions for installing Kagenti on OpenShift, including all fixes and workarounds discovered during testing.

> **Tested on**: OpenShift 4.18.20  
> **Kagenti Version**: 0.2.0-alpha.2  
> **MCP Gateway Version**: 0.4.0

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Pre-Installation Checklist](#pre-installation-checklist)
3. [Installation](#installation)
4. [Verification](#verification)
5. [Access URLs](#access-urls)
6. [Known Issues & Workarounds](#known-issues--workarounds)
7. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `oc` | ≥4.16.0 | OpenShift CLI |
| `helm` | ≥3.18.0 | Kubernetes package manager |
| `kubectl` | ≥1.32.1 | Kubernetes CLI |

### Required Credentials

Before starting, gather these credentials and save to `/tmp/.secrets.yaml`:

```yaml
secrets:
  githubUser: YOUR_GITHUB_USERNAME
  githubToken: "YOUR_GITHUB_PAT"      # Scopes: repo, read:packages
  openaiApiKey: "YOUR_OPENAI_OR_GEMINI_KEY"
  slackBotToken: ""                    # Optional
  adminSlackBotToken: ""               # Optional
  quayUser: YOUR_QUAY_USERNAME         # Optional, for image builds
  quayToken: "YOUR_QUAY_TOKEN"         # Optional, for image builds
```

### Cluster Requirements

- OpenShift 4.16+ with cluster-admin access
- Minimum 16GB RAM available across worker nodes
- Network type: OVNKubernetes (default for OpenShift 4.x)

---

## Pre-Installation Checklist

Complete these steps **before** running the installation. Each step addresses a specific requirement or potential conflict.

### Step 1: Login to OpenShift

```bash
oc login https://api.<cluster>:6443 -u admin -p <password> --insecure-skip-tls-verify
```

### Step 2: Remove Existing cert-manager (IF ALREADY INSTALLED)

> ⚠️ **Why?** Kagenti installs its own cert-manager. If Red Hat's cert-manager Operator is already installed on your cluster, it will conflict with Kagenti's installation.

**Check if cert-manager exists:**

```bash
oc get ns cert-manager-operator
oc get ns cert-manager
```

**If EITHER namespace exists, remove cert-manager:**

```bash
# Remove deployments and services
oc delete deploy cert-manager cert-manager-cainjector cert-manager-webhook -n cert-manager 2>/dev/null
oc delete service cert-manager cert-manager-webhook -n cert-manager 2>/dev/null

# Remove the operator subscription and CSV
oc delete subscription -n cert-manager-operator --all 2>/dev/null
oc delete csv -n cert-manager-operator --all 2>/dev/null

# Delete namespaces
oc delete ns cert-manager cert-manager-operator --wait=false

# Wait for namespaces to terminate (may take 1-2 minutes)
watch "oc get ns | grep cert-manager"
```

> 💡 If cert-manager is NOT installed, skip this step. Kagenti will install it automatically.

### Step 3: Configure OVN for Istio Ambient Mode

> ⚠️ **Why?** Istio Ambient Mode requires `routingViaHost: true` in OVN configuration for proper traffic routing.

```bash
# Verify network type is OVNKubernetes
oc get network.config/cluster -o jsonpath='{.spec.networkType}'

# Enable local gateway mode
oc patch network.operator.openshift.io cluster --type=merge \
  -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}'
```

### Step 4: Install Gateway API CRDs

> ⚠️ **CRITICAL - MISSING FROM OFFICIAL DOCS!**  
> The `kagenti-deps` chart does NOT install Gateway API CRDs, but the MCP Gateway requires them. Install them manually BEFORE proceeding.

```bash
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
```

**Verify installation:**

```bash
oc get crd | grep gateway.networking.k8s.io
```

Expected output:
```
gatewayclasses.gateway.networking.k8s.io      
gateways.gateway.networking.k8s.io            
grpcroutes.gateway.networking.k8s.io          
httproutes.gateway.networking.k8s.io          
referencegrants.gateway.networking.k8s.io     
```

### Step 5: Create Required Namespace

> ⚠️ **CRITICAL - MISSING FROM OFFICIAL DOCS!**  
> The `gateway-system` namespace must exist before installing the Kagenti platform chart.

```bash
oc create namespace gateway-system
```

### Step 6: Set Environment Variables

```bash
export DOMAIN=apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')
export KAGENTI_VERSION="0.2.0-alpha.2"
export GATEWAY_VERSION="0.4.0"

echo "DOMAIN=$DOMAIN"
echo "KAGENTI_VERSION=$KAGENTI_VERSION"
```

---

## Installation

### Step 1: Install kagenti-deps

This installs: **Istio (Ambient Mode), Keycloak, cert-manager, Tekton, OTEL, ToolHive**

```bash
helm install --create-namespace -n kagenti-system kagenti-deps \
  oci://ghcr.io/kagenti/kagenti/kagenti-deps \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set components.spire.enabled=false \
  --set domain=${DOMAIN} \
  --timeout 20m
```

> ⚠️ **Note:** We set `components.spire.enabled=false` because the SPIRE Operator CRDs (`SpiffeCSIDriver`) are not available on standard OpenShift clusters without additional operator installation.

**Wait for pods to be ready (~5-10 minutes):**

```bash
oc get pods -n kagenti-system -w
oc get pods -n keycloak -w
oc get pods -n istio-system -w
```

### Step 2: Install MCP Gateway

```bash
helm install mcp-gateway oci://ghcr.io/kagenti/charts/mcp-gateway \
  --create-namespace --namespace mcp-system \
  --version $GATEWAY_VERSION \
  --timeout 10m
```

### Step 3: Fix MCP Gateway broker-router

> ⚠️ **REQUIRED WORKAROUND - Chart Bug!**  
> The MCP Gateway chart 0.4.0 passes `--mcp-broker-config-address` flag to the broker-router, but the current image doesn't support this flag. This causes a crash.
>
> **Root Cause:** Version mismatch between chart (0.4.0) and image (latest)  
> **Status:** Should be reported as a bug to https://github.com/kagenti/mcp-gateway

**Apply fix immediately** (don't wait for the pod to crash):

```bash
# Apply fix by removing the unsupported flag
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

# Wait for pod to restart
sleep 10
oc get pods -n mcp-system
# Both pods should show Running
```

### Step 4: Install Kagenti Platform

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

## Verification

### Check All Pods

```bash
echo "=== kagenti-system ==="
oc get pods -n kagenti-system

echo "=== keycloak ==="
oc get pods -n keycloak

echo "=== mcp-system ==="
oc get pods -n mcp-system

echo "=== gateway-system ==="
oc get pods -n gateway-system
```

### Expected Running Pods

| Namespace | Pod | Expected Status |
|-----------|-----|-----------------|
| kagenti-system | kagenti-controller-manager-* | Running |
| kagenti-system | kagenti-ui-* | Running |
| kagenti-system | mcp-inspector-* | Running |
| kagenti-system | otel-collector-* | Running |
| kagenti-system | phoenix-0 | Running |
| keycloak | keycloak-0 | Running |
| keycloak | postgres-kc-0 | Running |
| mcp-system | mcp-gateway-broker-router-* | Running |
| mcp-system | mcp-gateway-controller-* | Running |
| gateway-system | mcp-gateway-istio-* | Running |

### Get Access URLs

```bash
echo "Kagenti UI: https://$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
echo "Keycloak: https://$(oc get route keycloak -n keycloak -o jsonpath='{.status.ingress[0].host}')"
```

### Get Keycloak Credentials

```bash
oc get secret keycloak-initial-admin -n keycloak \
  -o go-template='Username: {{.data.username | base64decode}}  Password: {{.data.password | base64decode}}{{"\n"}}'
```

---

## Access URLs

| Service | URL Pattern |
|---------|-------------|
| **Kagenti UI** | `https://kagenti-ui-kagenti-system.apps.<cluster>/` |
| **Keycloak** | `https://keycloak-keycloak.apps.<cluster>/` |
| **MCP Inspector** | `https://mcp-inspector-kagenti-system.apps.<cluster>/` |
| **Phoenix (Traces)** | `https://phoenix-kagenti-system.apps.<cluster>/` |
| **MCP Gateway** | `https://mcp-gateway-gateway-system.apps.<cluster>/` |

---

## Known Issues & Workarounds

### Issue 1: Gateway API CRDs Not Installed

**Symptom:** MCP Gateway controller crashes with:
```
no matches for kind "HTTPRoute" in version "gateway.networking.k8s.io/v1"
```

**Solution:** Install Gateway API CRDs before installation (Pre-Installation Step 4)

---

### Issue 2: SPIRE Operator CRDs Missing

**Symptom:** kagenti-deps installation fails with:
```
no matches for kind "SpiffeCSIDriver" in version "operator.openshift.io/v1alpha1"
```

**Solution:** Disable SPIRE during installation:
```bash
--set components.spire.enabled=false
```

---

### Issue 3: gateway-system Namespace Missing

**Symptom:** Kagenti platform installation fails with:
```
namespaces "gateway-system" not found
```

**Solution:** Create namespace before installation (Pre-Installation Step 5)

---

### Issue 4: MCP Gateway broker-router CrashLoopBackOff

**Symptom:** Pod crashes with:
```
flag provided but not defined: -mcp-broker-config-address
```

**Cause:** Chart 0.4.0 uses a flag that the current image doesn't support.

**Solution:** Patch the deployment (Installation Step 3)

---

### Issue 5: Existing cert-manager Conflicts

**Symptom:** cert-manager pods fail to start or have conflicts.

**Cause:** Red Hat's cert-manager Operator was already installed.

**Solution:** Remove existing cert-manager before installation (Pre-Installation Step 2)

---

## Troubleshooting

### Namespace Stuck in Terminating

```bash
NAMESPACE="stuck-namespace-name"
oc get namespace $NAMESPACE -o json | jq '.spec.finalizers = []' | \
  oc replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -
```

### etcd Connection Errors During Install

**Symptom:** Random `rpc error: code = Unavailable` errors

**Solution:** These are transient. Wait a few seconds and retry the helm command.

### Keycloak Pod Not Starting

Check if PostgreSQL is ready first:
```bash
oc get pods -n keycloak
oc logs -n keycloak postgres-kc-0
```

### Istio Pods Not Starting

Check if CNI is properly configured:
```bash
oc get pods -n istio-cni
oc get pods -n istio-ztunnel
```

---

## What Gets Installed

### Namespaces Created

| Namespace | Purpose |
|-----------|---------|
| `kagenti-system` | Core Kagenti platform |
| `keycloak` | Authentication (Keycloak + PostgreSQL) |
| `istio-system` | Istio control plane |
| `istio-cni` | Istio CNI plugin |
| `istio-ztunnel` | Istio ztunnel (ambient mode) |
| `cert-manager` | TLS certificate management |
| `mcp-system` | MCP Gateway components |
| `gateway-system` | Istio gateway for MCP |

### Components Installed

| Component | Purpose |
|-----------|---------|
| **Kagenti Controller** | Manages Agent and MCPServer CRDs |
| **Kagenti UI** | Web interface for agent management |
| **Keycloak** | OAuth2/OIDC authentication |
| **Istio (Ambient)** | Service mesh, mTLS |
| **MCP Gateway** | Routes MCP traffic, policy enforcement |
| **MCP Inspector** | Debug MCP connections |
| **Phoenix** | OpenTelemetry trace viewer |
| **OTEL Collector** | Telemetry collection |
| **Tekton** | CI/CD pipelines for agent builds |
| **ToolHive** | MCP tool management |
| **cert-manager** | TLS certificate automation |

---

## Quick Reference: Complete Install Commands

```bash
# Set variables
export DOMAIN=apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')
export KAGENTI_VERSION="0.2.0-alpha.2"
export GATEWAY_VERSION="0.4.0"

# Pre-requisites (run these FIRST)
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
oc create namespace gateway-system

# Install kagenti-deps
helm install --create-namespace -n kagenti-system kagenti-deps \
  oci://ghcr.io/kagenti/kagenti/kagenti-deps \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set components.spire.enabled=false \
  --set domain=${DOMAIN} \
  --timeout 20m

# Install MCP Gateway
helm install mcp-gateway oci://ghcr.io/kagenti/charts/mcp-gateway \
  --create-namespace --namespace mcp-system \
  --version $GATEWAY_VERSION \
  --timeout 10m

# Fix MCP Gateway (apply immediately)
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

# Install Kagenti platform
helm upgrade --install -n kagenti-system \
  -f /tmp/.secrets.yaml kagenti oci://ghcr.io/kagenti/kagenti/kagenti \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set domain=${DOMAIN} \
  --set agentOAuthSecret.spiffePrefix=spiffe://${DOMAIN}/sa \
  --set uiOAuthSecret.useServiceAccountCA=false \
  --set agentOAuthSecret.useServiceAccountCA=false \
  --timeout 15m

# Get access info
echo "UI: https://$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.status.ingress[0].host}')"
oc get secret keycloak-initial-admin -n keycloak -o go-template='Keycloak: {{.data.username | base64decode}} / {{.data.password | base64decode}}{{"\n"}}'
```

---

## References

- [Kagenti GitHub](https://github.com/kagenti/kagenti)
- [Kagenti Official Installation Docs](https://github.com/kagenti/kagenti/blob/main/docs/install.md)
- [MCP Gateway](https://github.com/kagenti/mcp-gateway)
- [Gateway API](https://gateway-api.sigs.k8s.io/)
- [Istio Ambient Mode](https://istio.io/latest/docs/ambient/)
