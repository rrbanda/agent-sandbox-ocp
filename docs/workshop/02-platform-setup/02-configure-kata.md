# Step 02: Configure Kata Runtime

**Time**: 10-15 minutes (mostly waiting for nodes)  
**Persona**: 👷 Platform Admin

## What You'll Do

Apply a `KataConfig` resource to enable the Kata runtime on worker nodes. This is required for agents to run in VM isolation.

---

## Why This Matters

The OSC Operator is installed, but nodes don't have the Kata runtime yet. The `KataConfig` tells the operator to:

| Action | Description |
|--------|-------------|
| Install Kata binaries | QEMU, kata-runtime on each worker |
| Register RuntimeClass | `kata` becomes available for pods |
| Configure hypervisor | QEMU settings for micro-VMs |

After this step, pods can use `runtimeClassName: kata` to run in VMs.

---

## Step 1: Check Current State

Verify no KataConfig exists yet:

```bash
oc get kataconfig
```

Expected: `No resources found`

Check RuntimeClass doesn't exist:

```bash
oc get runtimeclass kata
```

Expected: `Error from server (NotFound)...`

---

## Step 2: Apply KataConfig

```bash
oc apply -f - <<EOF
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: example-kataconfig
spec:
  enablePeerPods: false
  logLevel: info
EOF
```

Or use the provided manifest:

```bash
oc apply -f manifests/currency-demo/00-kataconfig.yaml
```

---

## Step 3: Monitor Installation

The operator installs Kata on each worker node. This takes **5-15 minutes**.

### Watch KataConfig Status

```bash
oc get kataconfig example-kataconfig -w
```

### Watch Machine Config Pool

```bash
# The operator creates a MachineConfigPool
oc get mcp kata-oc -w

# Wait for UPDATED=True, UPDATING=False, DEGRADED=False
```

### Check Node Progress

```bash
# Watch nodes update
watch -n 5 'oc get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status,KATA:.metadata.labels.node\\.kubernetes\\.io/kata'
```

---

## Step 4: Verify RuntimeClass Exists

Once installation completes, the `kata` RuntimeClass should exist:

```bash
oc get runtimeclass kata
```

Expected output:
```
NAME   HANDLER   AGE
kata   kata      2m
```

---

## Step 5: Verify Node Configuration

Check which nodes have Kata installed:

```bash
# Check KataConfig status
oc get kataconfig example-kataconfig -o yaml | grep -A 30 "status:"
```

Look for:
```yaml
status:
  conditions:
  - status: "True"
    type: InProgress
  installationStatus:
    completed:
      completedNodesCount: 3
      completedNodesList:
      - worker-0
      - worker-1
      - worker-2
```

---

## Step 6: Test Kata Runtime

Create a test pod to verify Kata works:

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Pod
metadata:
  name: kata-test
  namespace: default
spec:
  runtimeClassName: kata
  containers:
  - name: test
    image: registry.access.redhat.com/ubi9/ubi-minimal:latest
    command: ["sleep", "300"]
EOF
```

Verify the pod is running:

```bash
oc get pod kata-test -o wide
```

Check the pod is using Kata:

```bash
# The node should show it's running a Kata workload
oc describe pod kata-test | grep -i runtime
```

Cleanup:

```bash
oc delete pod kata-test
```

---

## Understanding KataConfig

```yaml
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: example-kataconfig
spec:
  enablePeerPods: false    # Local VMs (not cloud VMs)
  logLevel: info           # Logging verbosity
  # Optional: Target specific nodes
  # kataConfigPoolSelector:
  #   matchLabels:
  #     node-role.kubernetes.io/kata: ""
```

| Field | Description |
|-------|-------------|
| `enablePeerPods` | `false` = local QEMU VMs, `true` = cloud provider VMs |
| `logLevel` | `debug`, `info`, `warn`, `error` |
| `kataConfigPoolSelector` | Target specific nodes (default: all workers) |

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         KataConfig Applied                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. OSC Operator detects KataConfig                                     │
│                    ↓                                                    │
│  2. Creates MachineConfig for Kata                                      │
│                    ↓                                                    │
│  3. MachineConfigPool "kata-oc" triggers updates                        │
│                    ↓                                                    │
│  4. Nodes reboot with Kata binaries installed                           │
│                    ↓                                                    │
│  5. RuntimeClass "kata" created                                         │
│                    ↓                                                    │
│  6. Pods can use runtimeClassName: kata                                 │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Verification Summary

Run this check:

```bash
echo "=== Kata Configuration Check ===" && \
echo "" && \
echo "1. KataConfig:" && \
oc get kataconfig 2>/dev/null || echo "   Not configured" && \
echo "" && \
echo "2. RuntimeClass:" && \
oc get runtimeclass kata 2>/dev/null || echo "   Not available" && \
echo "" && \
echo "3. MachineConfigPool:" && \
oc get mcp kata-oc 2>/dev/null | grep -E "kata-oc|NAME" || echo "   Not found"
```

All checks must pass before agents can use Kata runtime.

---

## Troubleshooting

### KataConfig Stuck in "Installing"

```bash
# Check MachineConfigPool status
oc describe mcp kata-oc

# Check for pending node updates
oc get nodes -o custom-columns=NAME:.metadata.name,READY:.status.conditions[?(@.type=="Ready")].status
```

Nodes need to reboot. If stuck, check:
- Node cordoning issues
- PodDisruptionBudget blocking reboots

### RuntimeClass Not Created

```bash
# Check KataConfig status
oc describe kataconfig example-kataconfig

# Check operator logs
oc logs -n openshift-sandboxed-containers-operator -l control-plane=controller-manager
```

### Pods Fail with "kata" Runtime

```bash
# Describe the failing pod
oc describe pod <pod-name>

# Check node has Kata
oc get nodes -l node.kubernetes.io/kata=true
```

---

## Next Step

👉 [Step 03: Create Agent Namespace](03-create-namespace.md)
