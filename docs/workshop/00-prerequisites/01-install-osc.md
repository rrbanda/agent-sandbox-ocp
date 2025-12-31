# Step 01: Install OpenShift Sandboxed Containers

**Time**: 10 minutes

## What You'll Do

Install the OpenShift Sandboxed Containers (OSC) Operator, which provides Kata Containers for VM-based pod isolation.

## Why This Is Needed

Kata Containers run each AI agent pod in a lightweight VM with its own kernel. This provides hardware-level isolation - even if an agent is compromised, it cannot escape the VM.

!!! info "Deep Dive: Understanding OSC"
    For a comprehensive explanation of what OSC is, how it works, and why it's relevant for AI agents, see [OSC Explained](../../concepts/osc-explained.md).

## Steps

### 1. Install via OperatorHub

1. Open the OpenShift Console
2. Go to **Operators** → **OperatorHub**
3. Search for **"OpenShift sandboxed containers"**
4. Click **Install**
5. Accept defaults:
   - Update channel: `stable`
   - Installation mode: `All namespaces`
   - Approval: `Automatic`
6. Click **Install**

### 2. Verify Installation

```bash
# Check the operator is installed
oc get csv -n openshift-sandboxed-containers-operator | grep sandboxed

# Expected output:
# sandboxed-containers-operator.v1.x.x   OpenShift sandboxed containers   Succeeded
```

### 3. Check Operator Pods

```bash
oc get pods -n openshift-sandboxed-containers-operator

# Expected: controller-manager pod running
```

## What's Next

The operator is installed, but Kata runtime isn't enabled on nodes yet. That happens when you apply KataConfig in [Module 02](../02-platform-setup/02-configure-kata.md).

## Troubleshooting

### Operator Not in OperatorHub

- Ensure you're logged in as cluster-admin
- Check cluster has access to Red Hat registry

### Installation Stuck

```bash
oc describe csv -n openshift-sandboxed-containers-operator
```

---

👉 [Next: Install Istio](02-install-istio.md)

