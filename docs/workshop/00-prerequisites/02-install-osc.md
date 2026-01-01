# Install OpenShift Sandboxed Containers

**Duration**: 10 minutes

OpenShift Sandboxed Containers (OSC) provides the Kata Containers runtime for VM-based workload isolation. This is **Layer 1** of our defense-in-depth strategy.

---

## What OSC Provides

| Component | Purpose |
|-----------|---------|
| **OSC Operator** | Manages Kata runtime installation |
| **KataConfig** | Configures which nodes run Kata |
| **RuntimeClass** | `kata` runtime class for pods |

---

## Install via OpenShift Console

### Step 1: Install the Operator

1. Open the OpenShift Console
2. Navigate to **Operators → OperatorHub**
3. Search for **"OpenShift sandboxed containers"**
4. Click **Install**
5. Accept default settings and click **Install**

Wait for the operator to install (1-2 minutes).

### Step 2: Create KataConfig

1. Navigate to **Operators → Installed Operators**
2. Click **OpenShift sandboxed containers Operator**
3. Click the **KataConfig** tab
4. Click **Create KataConfig**
5. Use this YAML:

```yaml
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: cluster
spec:
  kataConfigPoolSelector:
    matchLabels:
      node-role.kubernetes.io/kata: ""
```

6. Click **Create**

!!! note "Node Selection"
    The `kataConfigPoolSelector` above selects nodes with the `kata` label. To run Kata on all worker nodes, use:
    
    ```yaml
    spec:
      kataConfigPoolSelector: null
    ```

---

## Install via CLI

### Step 1: Create Namespace and Operator Group

```bash
cat << EOF | oc apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: openshift-sandboxed-containers-operator
---
apiVersion: operators.coreos.com/v1
kind: OperatorGroup
metadata:
  name: sandboxed-containers-operator-group
  namespace: openshift-sandboxed-containers-operator
spec:
  targetNamespaces:
    - openshift-sandboxed-containers-operator
EOF
```

### Step 2: Create Subscription

```bash
cat << EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: sandboxed-containers-operator
  namespace: openshift-sandboxed-containers-operator
spec:
  channel: stable
  installPlanApproval: Automatic
  name: sandboxed-containers-operator
  source: redhat-operators
  sourceNamespace: openshift-marketplace
EOF
```

### Step 3: Wait for Operator

```bash
# Wait for CSV to succeed
oc get csv -n openshift-sandboxed-containers-operator -w

# Should show:
# NAME                            DISPLAY   VERSION   PHASE
# sandboxed-containers-operator   ...       1.x.x     Succeeded
```

### Step 4: Create KataConfig

```bash
cat << EOF | oc apply -f -
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: cluster
spec:
  kataConfigPoolSelector: null  # All worker nodes
EOF
```

---

## Wait for Node Configuration

KataConfig triggers a MachineConfig update on worker nodes. This takes 5-10 minutes.

```bash
# Watch node status
oc get nodes -w

# Nodes will show: SchedulingDisabled → NotReady → Ready
```

You can also watch the KataConfig status:

```bash
oc get kataconfig cluster -o jsonpath='{.status.conditions[*].type}{"\n"}{.status.conditions[*].status}'
```

---

## Verify Installation

### Check RuntimeClass

```bash
oc get runtimeclass kata
```

Expected output:
```
NAME   HANDLER   AGE
kata   kata      5m
```

### Check Kata Pods

```bash
oc get pods -n openshift-sandboxed-containers-operator
```

Expected output:
```
NAME                                       READY   STATUS    RESTARTS   AGE
controller-manager-xxxxx                   2/2     Running   0          10m
```

### Test Kata Pod (Optional)

Create a test pod to verify Kata works:

```bash
cat << EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: kata-test
  namespace: default
spec:
  runtimeClassName: kata
  containers:
  - name: test
    image: registry.access.redhat.com/ubi9/ubi-minimal
    command: ["sleep", "infinity"]
EOF

# Wait for pod
oc wait --for=condition=Ready pod/kata-test -n default --timeout=120s

# Verify it's running in a VM (check for kata-agent process)
oc exec kata-test -- cat /proc/1/cgroup | grep kata

# Cleanup
oc delete pod kata-test -n default
```

---

## Troubleshooting

### Nodes stuck in NotReady

```bash
# Check MachineConfigPool status
oc get mcp worker

# Check for failed MachineConfigs
oc describe mcp worker | grep -A5 "Conditions"
```

### KataConfig not progressing

```bash
# Check operator logs
oc logs -n openshift-sandboxed-containers-operator deployment/controller-manager -c manager

# Check KataConfig conditions
oc describe kataconfig cluster
```

---

## OSC Installed

OpenShift Sandboxed Containers is now installed. Any pod with `runtimeClassName: kata` will run in a hardware-isolated VM.

This is **Layer 1** of our defense-in-depth:

| Layer | Status | Technology |
|-------|--------|------------|
| **1. VM Isolation** | ✅ Installed | OSC / Kata |
| 2. Network Egress | ⏳ Next (with Kagenti) | Istio |
| 3. Tool Policy | ⏳ Next (with Kagenti) | Kuadrant / OPA |

👉 **[Step 3: Install Kagenti](03-install-kagenti.md)**

