# Step 01: Install OpenShift Sandboxed Containers

**Time**: 10 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Install the OpenShift Sandboxed Containers (OSC) Operator, which provides Kata Containers for VM-based pod isolation.

---

## Why OSC Is Needed

AI agents execute code that may be influenced by untrusted inputs. Regular containers share the host kernel, creating risks:

| Risk | Without OSC | With OSC (Kata) |
|------|-------------|-----------------|
| Kernel exploits | Agent could escape container | Agent is in separate VM with own kernel |
| Container breakout | Access other containers | Isolated by hardware virtualization |
| Host filesystem access | Potential exposure | No access to host filesystem |

Kata Containers run each agent pod in a **lightweight VM with its own kernel**, providing hardware-level isolation.

!!! info "Deep Dive"
    For a comprehensive explanation, see [OSC Explained](../../concepts/osc-explained.md).

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         Worker Node                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────────────┐      ┌─────────────────────────┐          │
│  │   Regular Container     │      │   Kata VM               │          │
│  │   (shared kernel)       │      │   ┌─────────────────┐   │          │
│  │                         │      │   │ Agent Container │   │          │
│  │  ┌─────┐ ┌─────┐       │      │   │ (own kernel)    │   │          │
│  │  │Pod A│ │Pod B│       │      │   └─────────────────┘   │          │
│  │  └─────┘ └─────┘       │      │   Guest Kernel          │          │
│  └────────────────────────┘      └─────────────────────────┘          │
│                                                                         │
│  ─────────────────────────────────────────────────────────────────     │
│                         Host Kernel                                     │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Install via OperatorHub (Console)

1. Open the OpenShift Console
2. Go to **Operators** → **OperatorHub**
3. Search for **"OpenShift sandboxed containers"**
4. Click **Install**
5. Accept defaults:
   - Update channel: `stable`
   - Installation mode: `All namespaces`
   - Namespace: `openshift-sandboxed-containers-operator`
   - Approval: `Automatic`
6. Click **Install**

---

## Step 2: Verify Operator Installation

### 2.1 Check ClusterServiceVersion

```bash
oc get csv -n openshift-sandboxed-containers-operator | grep sandboxed
```

Expected output:
```
sandboxed-containers-operator.v1.8.1   OpenShift sandboxed containers Operator   Succeeded
```

!!! warning "Wait for `Succeeded`"
    The `PHASE` must show `Succeeded` before proceeding.

### 2.2 Check Operator Pods

```bash
oc get pods -n openshift-sandboxed-containers-operator
```

Expected output:
```
NAME                                                       READY   STATUS    RESTARTS   AGE
sandboxed-containers-operator-controller-manager-xxxxx     2/2     Running   0          2m
```

### 2.3 Verify CRD Exists

The operator should create the `KataConfig` CRD:

```bash
oc get crd | grep kata
```

Expected:
```
kataconfigs.kataconfiguration.openshift.io   2024-12-30T12:00:00Z
```

---

## Step 3: Verify API Resources

```bash
oc api-resources | grep kata
```

Expected:
```
kataconfigs  kataconfiguration.openshift.io/v1  false  KataConfig
```

---

## What's Next

The operator is installed, but the Kata runtime is **not yet enabled on nodes**. That happens when you apply a `KataConfig` resource in [Module 02: Platform Setup](../02-platform-setup/02-configure-kata.md).

After `KataConfig` is applied:
- Kata binaries are installed on worker nodes
- The `kata` RuntimeClass becomes available
- Pods can use `runtimeClassName: kata`

---

## Verification Summary

Run this comprehensive check:

```bash
echo "=== OSC Installation Check ===" && \
echo "" && \
echo "1. CSV Status:" && \
oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -E "sandboxed|NAME" && \
echo "" && \
echo "2. Operator Pods:" && \
oc get pods -n openshift-sandboxed-containers-operator 2>/dev/null | grep -E "controller|NAME" && \
echo "" && \
echo "3. KataConfig CRD:" && \
oc get crd kataconfigs.kataconfiguration.openshift.io 2>/dev/null || echo "   Not found"
```

All checks must pass before proceeding.

---

## Troubleshooting

### Operator Not in OperatorHub

**Cause**: No access to Red Hat registry or insufficient permissions.

**Fix**:
```bash
# Check if catalog sources are available
oc get catalogsource -n openshift-marketplace

# Check for errors
oc get events -n openshift-marketplace --sort-by='.lastTimestamp'
```

### CSV Phase is Not "Succeeded"

```bash
# Check CSV status
oc describe csv -n openshift-sandboxed-containers-operator $(oc get csv -n openshift-sandboxed-containers-operator -o name | head -1)

# Look for conditions and events
```

### Operator Pod Not Running

```bash
# Describe the pod
oc describe pod -n openshift-sandboxed-containers-operator -l control-plane=controller-manager

# Check events
oc get events -n openshift-sandboxed-containers-operator --sort-by='.lastTimestamp'
```

---

## Next Step

👉 [Step 02: Install Istio](02-install-istio.md)
