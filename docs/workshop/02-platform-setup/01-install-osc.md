# Step 01: Install OpenShift Sandboxed Containers

**Time**: 5 minutes

## What You'll Do

Install the OpenShift Sandboxed Containers (OSC) Operator, which provides Kata Containers runtime for VM-based pod isolation.

## Why This Matters

Regular containers share the host kernel. If an AI agent is compromised, it could:
- Exploit kernel vulnerabilities
- Access other containers on the same node
- Read host filesystem

Kata Containers run each pod in a lightweight VM with its own kernel, providing hardware-level isolation.

## Steps

### 1. Open the OpenShift Console

Navigate to your OpenShift console:

```
https://console-openshift-console.apps.<your-cluster-domain>
```

### 2. Install the Operator

1. Go to **Operators** → **OperatorHub**
2. Search for **"OpenShift sandboxed containers"**
3. Click **Install**
4. Accept the default settings:
   - Update channel: `stable`
   - Installation mode: `All namespaces`
   - Approval: `Automatic`
5. Click **Install**

### 3. Verify Installation (CLI)

```bash
# Check the operator is running
oc get pods -n openshift-sandboxed-containers-operator

# Expected output:
# NAME                                                  READY   STATUS    RESTARTS   AGE
# sandboxed-containers-operator-controller-manager-xxx  2/2     Running   0          2m
```

### 4. Check Operator Status

```bash
oc get csv -n openshift-sandboxed-containers-operator

# Expected output:
# NAME                                   DISPLAY                              PHASE
# sandboxed-containers-operator.v1.x.x   OpenShift sandboxed containers       Succeeded
```

## Troubleshooting

### Operator Not Installing

If the operator doesn't appear in OperatorHub:
- Ensure you're logged in as cluster-admin
- Check if your cluster has access to the Red Hat registry

### Pods Not Starting

If operator pods are not starting:
```bash
oc describe pod -n openshift-sandboxed-containers-operator -l control-plane=controller-manager
```

## Next Step

👉 [Step 02: Configure Kata Runtime](02-configure-kata.md)

