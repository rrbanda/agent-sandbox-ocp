# Step 02: Install Istio Service Mesh

**Time**: 10 minutes

## What You'll Do

Install Istio for network egress control. Kagenti uses Istio to enforce which external APIs agents can reach.

## Why This Is Needed

Without egress control, an AI agent could send data to any external server. Istio's ServiceEntry feature allows you to explicitly allowlist which external hosts are permitted.

## Steps

### Option A: Install via Kagenti Dependencies (Recommended)

If you're installing Kagenti via Helm, Istio is included in the `kagenti-deps` chart. Skip to [Step 04: Deploy Kagenti](04-deploy-kagenti.md).

### Option B: Install Standalone

If you need to install Istio separately:

#### 1. Install Istio Operator

```bash
# Add Istio Helm repo
helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# Install Istio base
helm install istio-base istio/base -n istio-system --create-namespace

# Install Istiod
helm install istiod istio/istiod -n istio-system --wait
```

#### 2. Verify Installation

```bash
oc get pods -n istio-system

# Expected output:
# NAME                      READY   STATUS    RESTARTS   AGE
# istiod-xxxxxxxxx-xxxxx   1/1     Running   0          2m
```

#### 3. Enable Ambient Mode (Optional)

For Kagenti, ambient mode is recommended:

```bash
# Label namespace for ambient mode
oc label namespace agent-sandbox istio.io/dataplane-mode=ambient
```

## Verify Istio Is Ready

```bash
# Check istiod is running
oc get pods -n istio-system -l app=istiod

# Check Istio CRDs are available
oc get crd | grep istio
```

---

👉 [Next: Install Kuadrant](03-install-kuadrant.md)

