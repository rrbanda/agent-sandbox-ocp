# Step 04: Deploy Kagenti Platform

**Time**: 20 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Deploy the Kagenti platform, which provides:

- **Kagenti Operator** - Manages Agent and AgentBuild CRDs
- **Pipeline Infrastructure** - Tekton-based source-to-image builds
- **MCP Gateway** - Routes tool calls to MCP servers
- **Observability** - Phoenix for LLM tracing

After this step, developers can deploy agents using Kagenti CRs.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Kagenti Platform                                 │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐         │
│  │ Kagenti         │  │ Pipeline        │  │ Observability   │         │
│  │ Controller      │  │ Infrastructure  │  │                 │         │
│  │                 │  │                 │  │                 │         │
│  │ • Agent CRD     │  │ • Tekton Tasks  │  │ • Phoenix       │         │
│  │ • AgentBuild    │  │ • ConfigMaps    │  │ • OTEL          │         │
│  │ • Tool CRD      │  │ • RBAC          │  │ • MCP Inspector │         │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘         │
│                                                                         │
│  Namespace: kagenti-system                                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

- Helm 3.x installed
- Cluster admin access
- OSC Operator installed (Step 01)
- KataConfig applied (will be done in Module 02)

---

## Step 1: Add Kagenti Helm Repository

```bash
helm repo add kagenti https://kagenti.github.io/kagenti
helm repo update
```

Verify:
```bash
helm search repo kagenti
```

Expected output:
```
NAME                    CHART VERSION   APP VERSION   DESCRIPTION
kagenti/kagenti         0.2.0-alpha.19  0.2.0         Kagenti - AI Agent Platform for Kubernetes
kagenti/kagenti-deps    0.2.0-alpha.19  0.2.0         Kagenti Dependencies
```

---

## Step 2: Install Dependencies

The `kagenti-deps` chart installs required dependencies:

| Component | Purpose |
|-----------|---------|
| Istio | Service mesh for egress control |
| Kuadrant | API policy enforcement |
| Keycloak | Authentication |
| Cert-Manager | TLS certificates |

```bash
helm install kagenti-deps kagenti/kagenti-deps \
  -n kagenti-system \
  --create-namespace \
  --wait \
  --timeout 15m
```

!!! note "This takes 10-15 minutes"
    The dependencies include operators that need to provision resources.

### Verify Dependencies

```bash
echo "=== Checking Dependencies ===" && \
echo "" && \
echo "Istio:" && \
oc get pods -n istio-system | grep -E "istiod|NAME" && \
echo "" && \
echo "Kuadrant:" && \
oc get pods -n kuadrant-system | grep -E "authorino|NAME" && \
echo "" && \
echo "Keycloak:" && \
oc get pods -n keycloak | grep -E "keycloak|NAME"
```

---

## Step 3: Install Kagenti

Get your cluster domain:

```bash
CLUSTER_DOMAIN=$(oc get ingresses.config cluster -o jsonpath='{.spec.domain}')
echo "Cluster domain: $CLUSTER_DOMAIN"
```

Install Kagenti:

```bash
helm install kagenti kagenti/kagenti \
  -n kagenti-system \
  --set global.clusterDomain="${CLUSTER_DOMAIN}" \
  --wait \
  --timeout 10m
```

---

## Step 4: Verify Kagenti Installation

### 4.1 Check Pods

```bash
oc get pods -n kagenti-system
```

Expected output:
```
NAME                                          READY   STATUS    RESTARTS   AGE
kagenti-controller-manager-xxxxx-xxxxx        1/1     Running   0          2m
kagenti-ui-xxxxx-xxxxx                        1/1     Running   0          2m
mcp-inspector-xxxxx-xxxxx                     1/1     Running   0          2m
otel-collector-xxxxx-xxxxx                    1/1     Running   0          2m
phoenix-0                                     1/1     Running   0          2m
```

### 4.2 Check CRDs

Kagenti installs these Custom Resource Definitions:

```bash
oc get crd | grep kagenti
```

Expected:
```
agentbuilds.agent.kagenti.dev
agents.agent.kagenti.dev
tools.agent.kagenti.dev
```

### 4.3 Check Helm Releases

```bash
helm list -n kagenti-system
```

Expected:
```
NAME          NAMESPACE        REVISION  STATUS    CHART
kagenti       kagenti-system   1         deployed  kagenti-0.2.0-alpha.19
kagenti-deps  kagenti-system   1         deployed  kagenti-deps-0.2.0-alpha.19
```

---

## Step 5: Verify Pipeline Infrastructure

Kagenti includes Tekton pipeline components for AgentBuild. Verify they exist:

### 5.1 Pipeline Step ConfigMaps

```bash
oc get configmaps -n kagenti-system -l kagenti.operator.dev/tekton=step
```

Expected ConfigMaps:
```
NAME                    DATA   AGE
buildah-build-step      1      2m
buildpack-step          1      2m
check-dockerfile-step   1      2m
check-subfolder-step    1      2m
github-clone-step       1      2m
```

### 5.2 Verify a Step ConfigMap

```bash
oc get configmap github-clone-step -n kagenti-system -o jsonpath='{.data.task-spec\.yaml}' | head -20
```

Should show a Tekton task spec with steps for git cloning.

---

## Step 6: Access Kagenti UI

Get the Kagenti UI URL:

```bash
oc get route kagenti-ui -n kagenti-system -o jsonpath='https://{.spec.host}'
```

Open in browser to verify access.

---

## Step 7: Verify Phoenix (Observability)

Check Phoenix is running:

```bash
oc get pods -n kagenti-system -l app.kubernetes.io/name=phoenix
```

Get Phoenix URL:

```bash
oc get route phoenix -n kagenti-system -o jsonpath='https://{.spec.host}' 2>/dev/null || \
echo "Phoenix route not exposed (access via port-forward)"
```

---

## What Platform Admins Have Configured

After this step, the platform provides:

| Capability | For Developers |
|------------|----------------|
| Agent CRD | Deploy agents as Kubernetes resources |
| AgentBuild CRD | Build images from source (Git) |
| Pipeline Steps | Automated git clone, build, push |
| Kata Runtime | VM isolation for agent workloads |
| Observability | Trace LLM calls in Phoenix |

---

## What's Left for Developers

Developers will need to:

1. **Create namespace-specific resources** in their agent namespace:
   - Pipeline template ConfigMap
   - Registry secrets
   - GitHub token secrets
   - RBAC for pipeline SA

2. **Write and test agent code** locally with Google ADK

3. **Create AgentBuild CRs** to build from source

4. **Create Agent CRs** to deploy

This is covered in the Developer modules.

---

## Troubleshooting

### Helm Install Fails

```bash
# Check Helm status
helm status kagenti -n kagenti-system
helm status kagenti-deps -n kagenti-system

# Check events
oc get events -n kagenti-system --sort-by='.lastTimestamp' | tail -20
```

### Pods Not Starting

```bash
# Describe the failing pod
oc describe pod -n kagenti-system <pod-name>

# Check logs
oc logs -n kagenti-system <pod-name>
```

### CRDs Not Created

```bash
# Check if operator is running
oc get pods -n kagenti-system | grep controller

# Check operator logs
oc logs -n kagenti-system -l control-plane=controller-manager
```

### Missing Pipeline ConfigMaps

```bash
# Reinstall Kagenti
helm upgrade kagenti kagenti/kagenti -n kagenti-system --reuse-values
```

---

## Next Step

👉 [Step 05: Verify Setup](05-verify-setup.md)
