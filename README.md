# Agent Sandbox on OpenShift

## The Problem

AI agents with tool access can be dangerous. An agent with a `fetch_url` tool could:
- Exfiltrate data to `https://malicious.com`
- Access cloud metadata at `http://169.254.169.254`
- Attack internal services

**How do you let agents use tools while preventing misuse?**

## The Solution

This repository demonstrates enterprise-grade agent isolation on OpenShift, inspired by [Anthropic's Sandbox Runtime (SRT)](https://github.com/anthropic-experimental/sandbox-runtime):

| Layer | Technology | Protection |
|-------|------------|------------|
| **Execution** | OpenShift Sandboxed Containers (Kata) | VM-level isolation - agent runs in micro-VM |
| **Network** | Kagenti MCP Gateway + Authorino | Policy-based URL blocking at the gateway |
| **Policy** | OPA (Open Policy Agent) | Inspect tool arguments, block unauthorized calls |

> **How it compares to SRT:** Anthropic's SRT uses OS-level sandboxing (bubblewrap/sandbox-exec). This demo uses **VM-level isolation** via Kata Containers, which provides **stronger isolation** (separate kernel, filesystem, network namespace) at the cost of higher overhead.

---

## How It Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          OpenShift Cluster                              │
│                                                                         │
│   Agent calls:                                                          │
│   fetch_url("https://malicious.com")                                    │
│         │                                                               │
│         ▼                                                               │
│   ┌───────────────┐     ┌──────────────────┐     ┌──────────────────┐   │
│   │   AI Agent    │────▶│   MCP Gateway    │────▶│    Authorino     │   │
│   │  (Kata VM)    │     │    (Envoy)       │     │   (OPA Policy)   │   │
│   └───────────────┘     └──────────────────┘     └──────────────────┘   │
│                                │                         │              │
│                                │                         ▼              │
│                                │                 ┌──────────────────┐   │
│                                │                 │  URL approved?   │   │
│                                │                 │  ❌ malicious.com │   │
│                                │                 │  ✅ weather.gov   │   │
│                                │                 └──────────────────┘   │
│                                │                         │              │
│                                ▼                         ▼              │
│                         ┌──────────────────┐      403 FORBIDDEN        │
│                         │   MCP Server     │      or 200 OK            │
│                         │  (fetch, etc)    │                            │
│                         └──────────────────┘                            │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

**The OPA policy:**
```rego
deny[msg] {
  body.method == "tools/call"
  body.params.name == "fetch_url"
  url := body.params.arguments.url
  not startswith(url, "https://api.weather.gov")
  not startswith(url, "https://httpbin.org")
  msg := "URL not approved"
}
```

---

## Prerequisites

- [ ] OpenShift 4.14+ cluster with admin access
- [ ] `oc` CLI configured and logged in
- [ ] `helm` CLI installed (v3.10+)

---

## Installation

### Step 1: Install OpenShift Sandboxed Containers Operator

```bash
oc create namespace openshift-sandboxed-containers-operator

cat <<EOF | oc apply -f -
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

# Wait for operator (2-3 minutes)
sleep 120
oc get csv -n openshift-sandboxed-containers-operator | grep sandboxed
```

### Step 2: Label Worker Nodes for Kata

```bash
# List worker nodes
oc get nodes -l node-role.kubernetes.io/worker

# Label node for Kata (replace NODE_NAME)
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""

# Verify
oc get nodes -l node-role.kubernetes.io/kata-oc
```

### Step 3: Apply KataConfig

```bash
oc apply -f manifests/osc/kataconfig.yaml

# Wait for installation (10-15 minutes per node)
watch oc get kataconfig example-kataconfig -o jsonpath='{.status}'

# Verify RuntimeClass
oc get runtimeclass kata
```

### Step 4: Install Kuadrant Operator

```bash
cat <<EOF | oc apply -f -
apiVersion: operators.coreos.com/v1alpha1
kind: Subscription
metadata:
  name: kuadrant-operator
  namespace: openshift-operators
spec:
  channel: stable
  installPlanApproval: Automatic
  name: kuadrant-operator
  source: community-operators
  sourceNamespace: openshift-marketplace
EOF

# Wait (2-3 minutes)
sleep 120

# Create Kuadrant instance
oc create namespace kuadrant-system

cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF

# Verify Authorino
sleep 60
oc get pods -n kuadrant-system -l authorino-resource=authorino
```

### Step 5: Install Kagenti

Follow the [Kagenti OpenShift Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md).

Quick summary:
```bash
git clone https://github.com/kagenti/kagenti.git
cd kagenti

helm install kagenti-deps charts/kagenti-deps \
  -n kagenti-system --create-namespace \
  --set openshift=true

# Wait for Istio (5-10 minutes)
sleep 300
oc get pods -n istio-system

helm install kagenti charts/kagenti \
  -n kagenti-system \
  --set openshift=true

# Verify
oc get pods -n kagenti-system
oc get pods -n mcp-system
oc get pods -n gateway-system
```

### Step 6: Configure Istio for Sidecar Mode

> ⚠️ OPA body inspection requires sidecar mode, not ambient.

```bash
# Check current mode
oc get istio default -n istio-system -o jsonpath='{.spec.values.profile}'

# If "ambient", switch to sidecar:
oc patch istio default -n istio-system --type=json -p='[
  {"op": "remove", "path": "/spec/values/profile"}
]'

oc create namespace istio-cni --dry-run=client -o yaml | oc apply -f -
oc rollout restart deployment/istiod -n istio-system
sleep 30
```

### Step 7: Enable Request Body Forwarding

```bash
oc patch istio default -n istio-system --type=merge --patch '
spec:
  values:
    meshConfig:
      extensionProviders:
      - name: kuadrant-authorization
        envoyExtAuthzGrpc:
          service: authorino-authorino-authorization.kuadrant-system.svc.cluster.local
          port: 50051
          timeout: 5s
          includeRequestBodyInCheck:
            maxRequestBytes: 8192
            allowPartialMessage: true
'
```

### Step 8: Enable Sidecar Injection

```bash
./scripts/setup-namespaces.sh
```

### Step 9: Apply OPA Policy

```bash
oc apply -f manifests/policies/url-blocking-policy.yaml

sleep 30

# Verify - should output "True"
oc get authpolicy mcp-tools-auth -n gateway-system \
  -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}'
```

### Step 10: Deploy Sandboxed Agent (Optional)

```bash
oc apply -f manifests/osc/sandboxed-agent.yaml

sleep 60

# Verify Kata runtime - should output "kata"
oc get pod -n agent-sandbox -o jsonpath='{.items[0].spec.runtimeClassName}'
```

---

## Demo: Test the Policy

Run the test script:
```bash
./scripts/test-policy.sh
```

Or test manually:
```bash
oc run policy-test --rm -it --restart=Never --image=curlimages/curl:latest -- sh -c '
  # Initialize MCP session
  curl -s -D /tmp/h -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" \
    -H "Host: mcp.127-0-0-1.sslip.io" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}" > /dev/null
  
  SESSION=$(grep -i "mcp-session-id:" /tmp/h | cut -d: -f2- | tr -d " \r\n")
  
  echo "=== BLOCKED: malicious URL ==="
  curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://malicious.com\"}}}"
  
  echo "=== ALLOWED: approved URL ==="
  curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://httpbin.org/get\"}}}"
'
```

---

## ✅ Results

After completing the steps, you should see:

### URL Blocking

| Tool Call | URL | Result |
|-----------|-----|--------|
| `fetch_url` | `https://malicious.com/steal-data` | **BLOCKED** (403) |
| `fetch_url` | `https://evil-site.net/api` | **BLOCKED** (403) |
| `fetch_url` | `http://169.254.169.254/metadata` | **BLOCKED** (403) |
| `fetch_url` | `https://api.weather.gov/forecast` | **ALLOWED** (200) |
| `fetch_url` | `https://httpbin.org/get` | **ALLOWED** (200) |

### Sandboxed Agent

```
$ oc get pod -n agent-sandbox -o wide
NAME               READY   STATUS    RUNTIME
sandboxed-agent    1/1     Running   kata     ✅ VM isolation
```

---

## SRT Capabilities Mapping

This demo provides **SRT-inspired** capabilities for AI agent security on OpenShift:

| Anthropic SRT Capability | This Demo | Notes |
|--------------------------|-----------|-------|
| Network URL restriction | ✅ OPA policy | Blocks unauthorized URLs at gateway |
| Filesystem isolation | ✅ Kata micro-VM | **Stronger** - complete VM isolation |
| Unix socket restrictions | ✅ Kata micro-VM | Host sockets not visible in VM by default |
| Tool argument inspection | ✅ Authorino + OPA | Inspect any tool parameter |
| Policy-driven control | ✅ AuthPolicy CRD | Declarative, auditable |
| Execution isolation | ✅ VM-backed pods | Hardware-level isolation |
| Violation monitoring | ⚠️ Authorino logs | Not real-time alerts like SRT |

### Key Differences from SRT

| Aspect | Anthropic SRT | This Demo |
|--------|---------------|-----------|
| **Approach** | OS-level sandboxing (bubblewrap) | VM-level isolation (Kata) |
| **Isolation strength** | Process-level | **Stronger** - full VM |
| **Network control** | Proxy-based filtering | Gateway + OPA policy |
| **Unix sockets** | Explicit blocklist | **Isolated by default** - VM has no host access |
| **Overhead** | Lightweight | Higher (VM per pod) |

> **Note:** Kata VMs provide stronger isolation than SRT's OS primitives. Host Unix sockets, filesystems, and kernel are completely isolated - the agent runs in a separate VM with its own kernel.

---

## Key Technical Details

### Memory for Kata Pods

Kata requires **2Gi minimum** due to QEMU overhead:
```yaml
resources:
  limits:
    memory: "2Gi"
```

### Istio Sidecar Mode

OPA body inspection only works in sidecar mode, not ambient mode.

### Body Forwarding

The `includeRequestBodyInCheck` setting is required for OPA to see tool arguments.

---

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md).

Quick checks:
```bash
# All pods running?
oc get pods -n istio-system
oc get pods -n kuadrant-system
oc get pods -n mcp-system

# Policy enforced?
oc get authpolicy -A -o wide

# Check logs
oc logs -n kuadrant-system -l authorino-resource=authorino --tail=20
```

---

## Project Structure

```
.
├── manifests/
│   ├── istio/          # Istio ext_authz config
│   ├── osc/            # KataConfig, sandboxed agent
│   ├── policies/       # OPA AuthPolicy
│   └── mcp-servers/    # MCP server registration
├── scripts/
│   ├── setup-namespaces.sh
│   └── test-policy.sh
└── docs/
    └── troubleshooting.md
```

---

## References

- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway platform
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://www.anthropic.com/news/sandbox-runtime) - Reference architecture

## License

Apache 2.0
