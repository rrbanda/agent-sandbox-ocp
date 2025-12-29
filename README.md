# Agent Sandbox on OpenShift

> **Enterprise-grade AI agent isolation using OpenShift Sandboxed Containers (OSC) and Kagenti MCP Gateway with OPA policy enforcement**

This repository demonstrates how to achieve [Anthropic SRT (Sandbox Runtime)](https://www.anthropic.com/news/sandbox-runtime) equivalent capabilities on OpenShift.

## ✅ Verified Demo Results

### URL Blocking via OPA Policy

The MCP Gateway intercepts `tools/call` requests and blocks based on OPA policies:

| Tool Call | URL | Result |
|-----------|-----|--------|
| `fetch_url` | `https://malicious.com/steal-data` | ✅ **BLOCKED** (403) |
| `fetch_url` | `https://evil-site.net/api` | ✅ **BLOCKED** (403) |
| `fetch_url` | `http://169.254.169.254/metadata` | ✅ **BLOCKED** (403) |
| `fetch_url` | `https://api.weather.gov/forecast` | ✅ **ALLOWED** (200) |
| `fetch_url` | `https://httpbin.org/get` | ✅ **ALLOWED** (200) |

### Sandboxed Agent (Kata Runtime)

```
Pod: weather-time-agent-5776df7cb6-bfstw
RuntimeClass: kata
Status: Running ✅ VM-level isolation!
```

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] OpenShift 4.14+ cluster with admin access
- [ ] `oc` CLI configured and logged in
- [ ] `helm` CLI installed (v3.10+)

---

## Step-by-Step Installation

### Step 1: Install OpenShift Sandboxed Containers Operator

```bash
# Create namespace first
oc create namespace openshift-sandboxed-containers-operator

# Install OSC operator
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

# Wait for operator to be ready (can take 2-3 minutes)
sleep 120
oc get csv -n openshift-sandboxed-containers-operator | grep sandboxed
```

### Step 2: Label Worker Nodes for Kata

```bash
# List worker nodes
oc get nodes -l node-role.kubernetes.io/worker

# Label nodes for Kata (replace NODE_NAME with your worker node)
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""

# Verify
oc get nodes -l node-role.kubernetes.io/kata-oc
```

### Step 3: Apply KataConfig

```bash
# Apply KataConfig
oc apply -f manifests/osc/kataconfig.yaml

# Wait for Kata installation (can take 10-15 minutes per node)
# Monitor progress:
watch oc get kataconfig example-kataconfig -o jsonpath='{.status}'

# Verify RuntimeClass is created
oc get runtimeclass kata
```

### Step 4: Install Kuadrant Operator (Includes Authorino)

```bash
# Install Kuadrant operator
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

# Wait for operator (can take 2-3 minutes)
sleep 120
oc get csv -n openshift-operators | grep kuadrant

# Create namespace and Kuadrant instance
oc create namespace kuadrant-system

cat <<EOF | oc apply -f -
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF

# Wait and verify Authorino is running
sleep 60
oc get pods -n kuadrant-system -l authorino-resource=authorino
```

### Step 5: Install Kagenti

Follow the [Kagenti OpenShift Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md)

**Quick summary:**

```bash
# Clone Kagenti
git clone https://github.com/kagenti/kagenti.git
cd kagenti

# Install dependencies chart
helm install kagenti-deps charts/kagenti-deps \
  -n kagenti-system --create-namespace \
  --set openshift=true

# Wait for Istio (can take 5-10 minutes)
sleep 300
oc get pods -n istio-system

# Install Kagenti chart  
helm install kagenti charts/kagenti \
  -n kagenti-system \
  --set openshift=true

# Verify all components
oc get pods -n kagenti-system
oc get pods -n mcp-system
oc get pods -n gateway-system
```

### Step 6: Switch Istio to Sidecar Mode (if using ambient)

> ⚠️ **Important**: OPA body inspection requires sidecar mode, not ambient mode.

```bash
# Check current mode
oc get istio default -n istio-system -o jsonpath='{.spec.values.profile}'
# If output is "ambient", switch to sidecar:

# Remove ambient profile
oc patch istio default -n istio-system --type=json -p='[
  {"op": "remove", "path": "/spec/values/profile"}
]'

# Create istio-cni namespace if missing
oc create namespace istio-cni --dry-run=client -o yaml | oc apply -f -

# Restart Istiod
oc rollout restart deployment/istiod -n istio-system
sleep 30
```

### Step 7: Configure Istio for Request Body Forwarding

```bash
# Apply ext_authz config - enables OPA to inspect tool arguments
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

# Verify
oc get istio default -n istio-system -o yaml | grep -A10 extensionProviders
```

### Step 8: Enable Sidecar Injection

```bash
./scripts/setup-namespaces.sh
```

### Step 9: Apply OPA Policy

```bash
# Apply the policy
oc apply -f manifests/policies/url-blocking-policy.yaml

# Wait for policy to be enforced
sleep 30

# Verify policy is enforced
oc get authpolicy mcp-tools-auth -n gateway-system -o jsonpath='{.status.conditions[?(@.type=="Enforced")].status}'
# Should output: True
```

### Step 10: Deploy Sandboxed Agent (Optional)

```bash
# Deploy agent with Kata runtime
oc apply -f manifests/osc/sandboxed-agent.yaml

# Wait for pod
sleep 60

# Verify it's using Kata
oc get pod -n agent-sandbox -o jsonpath='{.items[0].spec.runtimeClassName}'
# Should output: kata
```

### Step 11: Run Demo Test

```bash
./scripts/test-policy.sh
```

Or run manually:

```bash
oc run policy-test --rm -it --restart=Never --image=curlimages/curl:latest -- sh -c '
  curl -s -D /tmp/h -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" \
    -H "Host: mcp.127-0-0-1.sslip.io" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"test\",\"version\":\"1.0\"}}}" > /dev/null
  
  SESSION=$(grep -i "mcp-session-id:" /tmp/h | cut -d: -f2- | tr -d " \r\n")
  
  echo "=== Test BLOCKED URL (should be 403) ==="
  curl -s -w "HTTP: %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://malicious.com\"}}}"
  
  echo "=== Test ALLOWED URL (should be 200) ==="
  curl -s -w "HTTP: %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://httpbin.org/get\"}}}"
'
```

**Expected Output:**
```
=== Test BLOCKED URL (should be 403) ===
HTTP: 403
=== Test ALLOWED URL (should be 200) ===
HTTP: 200
```

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        OpenShift Cluster                            │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐     ┌─────────────────┐     ┌───────────────┐  │
│  │   AI Agent      │────▶│   MCP Gateway   │────▶│  Authorino    │  │
│  │  (Kata VM)      │     │   (Envoy)       │     │  (OPA Policy) │  │
│  └─────────────────┘     └─────────────────┘     └───────────────┘  │
│         │                        │                      │           │
│         │ VM Isolation           │ Tool Call Routing    │ Policy    │
│         ▼                        ▼                      ▼           │
│  ┌─────────────────┐     ┌─────────────────┐     ┌───────────────┐  │
│  │ Filesystem      │     │   MCP Servers   │     │  Allow/Deny   │  │
│  │ Isolation       │     │   (fetch, etc)  │     │  Decisions    │  │
│  └─────────────────┘     └─────────────────┘     └───────────────┘  │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

## SRT Capabilities Mapping

| SRT Capability | OSC | Kagenti + OPA |
|----------------|-----|---------------|
| Filesystem read/write isolation | ✅ VM-backed pods | - |
| Network access restriction by URL | - | ✅ OPA policy |
| Tool execution gating | - | ✅ AuthPolicy |
| Tool argument inspection | - | ✅ Authorino + Rego |
| Policy-driven control | - | ✅ Declarative policies |
| Auditable decisions | - | ✅ Authorino logs |
| Execution isolation | ✅ Kata micro-VM | - |
| Blast radius containment | ✅ VM isolation | ✅ Policy scope |

## Key Configuration Details

### Istio Mode: Sidecar (Not Ambient)

For OPA body inspection to work, Istio must be in **sidecar mode**. Ambient mode has limited ext_authz support.

### Memory for Kata Pods

Kata pods require at least **2Gi memory** due to QEMU overhead:

```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

### Body Forwarding in ext_authz

The `includeRequestBodyInCheck` is essential for OPA to inspect tool arguments.

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues.

### Quick Checks

```bash
# Check all components are running
oc get pods -n istio-system
oc get pods -n kuadrant-system
oc get pods -n mcp-system
oc get pods -n gateway-system

# Check AuthPolicy is enforced
oc get authpolicy -A -o wide

# Check Authorino logs
oc logs -n kuadrant-system -l authorino-resource=authorino -f

# Check MCP Gateway logs
oc logs -n gateway-system -l app=mcp-gateway -f
```

## Project Structure

```
.
├── manifests/
│   ├── istio/                    # Istio ext_authz configuration
│   ├── osc/                      # OpenShift Sandboxed Containers
│   ├── policies/                 # OPA/AuthPolicy definitions
│   └── mcp-servers/              # MCP Server registrations
├── scripts/
│   ├── setup-namespaces.sh       # Namespace configuration
│   └── test-policy.sh            # Policy verification
├── docs/
│   └── troubleshooting.md        # Common issues
└── README.md
```

## References

- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway and agent platform
- [Kagenti OCP Install Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md)
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://www.anthropic.com/news/sandbox-runtime) - Reference architecture

## License

Apache 2.0
