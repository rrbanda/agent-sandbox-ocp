# Agent Sandbox on OpenShift

A demo showing three-layer security for AI agents using the **Currency Agent** example:

| Layer | Technology | What It Blocks |
|-------|------------|----------------|
| **1. Tool Policy** | MCP Gateway + Authorino/OPA | Unauthorized tool arguments (e.g., crypto) |
| **2. Network Egress** | Istio REGISTRY_ONLY | Direct internet access from pods |
| **3. Execution Isolation** | OpenShift Sandboxed Containers (Kata) | Host access if agent is compromised |

Inspired by [Anthropic's SRT](https://github.com/anthropic-experimental/sandbox-runtime), adapted for Kubernetes/OpenShift.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│              LAYER 3: Kata VM Isolation                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │             Currency Agent (Kata Pod)                 │  │
│  │  "Convert USD to EUR" ──► MCP Gateway                 │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              LAYER 1: MCP Gateway + OPA                     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │     Host: currency-mcp.mcp.local                      │  │
│  │              │                                        │  │
│  │       ┌──────▼──────┐                                 │  │
│  │       │  Authorino  │   ✅ USD → EUR (allowed)        │  │
│  │       │   (OPA)     │   ❌ USD → BTC (blocked)        │  │
│  │       └──────┬──────┘                                 │  │
│  │              │                                        │  │
│  │       Currency MCP Server                             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              LAYER 2: Istio Egress Control                  │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  ServiceEntry (Allowed):                              │  │
│  │    ✅ api.frankfurter.app                              │  │
│  │    ✅ generativelanguage.googleapis.com                │  │
│  │    ❌ All other external hosts                         │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Tools

| Tool | Version | Purpose |
|------|---------|---------|
| `oc` | ≥4.16 | OpenShift CLI |
| `helm` | ≥3.18 | Kubernetes package manager |
| `git` | Latest | Clone repositories |

### Step 1: Install OpenShift Sandboxed Containers Operator

From OperatorHub, install **"OpenShift sandboxed containers Operator"**.

After installation, label worker nodes for Kata:
```bash
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""
```

### Step 2: Install Kuadrant Operator

From OperatorHub, install **"Kuadrant Operator"** in `kuadrant-system` namespace.

Create Kuadrant instance:
```bash
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF
```

### Step 3: Install Kagenti

See the [Kagenti OpenShift Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/install.md#openshift-installation) for full details.

#### Option A: Ansible-Based Installer (Recommended)

```bash
# Clone repository
git clone https://github.com/kagenti/kagenti.git
cd kagenti

# Configure secrets
cp deployments/envs/secret_values.yaml.example deployments/envs/.secret_values.yaml
# Edit .secret_values.yaml with your values (quay credentials, API keys)

# Run installer for OpenShift
deployments/ansible/run-install.sh --env ocp
```

#### Option B: Helm Install from OCI Charts

```bash
# Get domain
export DOMAIN=apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')

# Get latest version
LATEST_TAG=$(git ls-remote --tags --sort="v:refname" https://github.com/kagenti/kagenti.git | tail -n1 | sed 's|.*refs/tags/v||; s/\^{}//')

# Install dependencies
helm install kagenti-deps oci://ghcr.io/kagenti/kagenti/kagenti-deps \
  -n kagenti-system --create-namespace \
  --version $LATEST_TAG \
  --set spire.trustDomain=${DOMAIN}

# Install MCP Gateway
LATEST_GATEWAY_TAG=$(skopeo list-tags docker://ghcr.io/kagenti/charts/mcp-gateway | jq -r '.Tags[-1]')
helm install mcp-gateway oci://ghcr.io/kagenti/charts/mcp-gateway \
  -n mcp-system --create-namespace \
  --version $LATEST_GATEWAY_TAG

# Prepare secrets file (.secrets.yaml) then install Kagenti
helm install kagenti oci://ghcr.io/kagenti/kagenti/kagenti \
  -n kagenti-system \
  -f .secrets.yaml \
  --version $LATEST_TAG \
  --set agentOAuthSecret.spiffePrefix=spiffe://${DOMAIN}/sa \
  --set uiOAuthSecret.useServiceAccountCA=false \
  --set agentOAuthSecret.useServiceAccountCA=false
```

> **Note:** If your cluster already has Istio, cert-manager, Tekton, or Keycloak, disable them:
> ```bash
> helm install kagenti-deps oci://ghcr.io/kagenti/kagenti/kagenti-deps \
>   -n kagenti-system --create-namespace \
>   --set components.istio.enabled=false \
>   --set components.certManager.enabled=false \
>   --set components.tekton.enabled=false \
>   --set components.keycloak.enabled=false \
>   --set components.spire.enabled=false
> ```

### Step 4: Post-Install Fixes

#### Fix 1: Remove Ambient Mode from kagenti-system

The Kagenti controller needs direct Kubernetes API access. If ambient mode is enabled, remove it:

```bash
# Check if ambient label exists
oc get namespace kagenti-system -o jsonpath='{.metadata.labels.istio\.io/dataplane-mode}'

# If it shows "ambient", remove it:
oc label namespace kagenti-system istio.io/dataplane-mode-

# Restart controller
oc delete pod -n kagenti-system -l control-plane=controller-manager
```

#### Fix 2: Add `*.mcp.local` Listener to MCP Gateway

The default MCP Gateway only listens on `mcp.127-0-0-1.sslip.io`. Add a listener for custom hostnames:

```bash
oc patch gateway mcp-gateway -n gateway-system --type=json -p='[
  {
    "op": "add",
    "path": "/spec/listeners/-",
    "value": {
      "name": "mcps",
      "hostname": "*.mcp.local",
      "port": 8080,
      "protocol": "HTTP",
      "allowedRoutes": {
        "namespaces": {
          "from": "All"
        }
      }
    }
  }
]'
```

#### Fix 3: Configure Istio for OPA Body Forwarding

**Required** for OPA to inspect tool call arguments:

```bash
oc patch istio default -n istio-system --type=merge -p '
{
  "spec": {
    "values": {
      "meshConfig": {
        "extensionProviders": [
          {
            "name": "kuadrant-authorization",
            "envoyExtAuthzGrpc": {
              "service": "authorino-authorino-authorization.kuadrant-system.svc.cluster.local",
              "port": 50051,
              "timeout": "5s",
              "includeRequestBodyInCheck": {
                "maxRequestBytes": 8192,
                "allowPartialMessage": true
              }
            }
          }
        ],
        "outboundTrafficPolicy": {
          "mode": "REGISTRY_ONLY"
        }
      }
    }
  }
}'
```

### Step 5: Verify Installation

```bash
# Kagenti controller
oc get pods -n kagenti-system | grep kagenti-controller

# MCP Gateway
oc get pods -n gateway-system | grep mcp-gateway

# Kuadrant/Authorino
oc get pods -n kuadrant-system | grep authorino

# Kata RuntimeClass
oc get runtimeclass kata
```

Expected:
```
kagenti-controller-manager-xxx   1/1   Running
mcp-gateway-istio-xxx            1/1   Running
authorino-xxx                    1/1   Running
kata                             kata
```

---

## Files

| File | What | Why |
|------|------|-----|
| `00-kataconfig.yaml` | Kata runtime config | Enables VM isolation on nodes |
| `01-namespaces.yaml` | Create namespaces | `mcp-test`, `agent-sandbox` |
| `02-currency-mcp-server.yaml` | Currency MCP Server | Provides `get_exchange_rate` tool |
| `03-currency-httproute.yaml` | HTTPRoute | Routes to MCP server via gateway |
| `04-authpolicy.yaml` | OPA policy | Blocks BTC/ETH, allows fiat currencies |
| `05-currency-agent.yaml` | Kagenti Agent | Runs in Kata VM |
| `06-service-entry.yaml` | Istio egress rules | Allows `api.frankfurter.app` |

---

## Quick Start

```bash
# 0. Enable Kata runtime (PREREQUISITE - wait 10-15 min)
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""
oc apply -f 00-kataconfig.yaml
watch oc get runtimeclass kata  # Wait for this to appear

# 1. Create namespaces
oc apply -f 01-namespaces.yaml

# 2. Create secrets
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='your-key' -n agent-sandbox

oc create secret docker-registry quay-pull-secret \
  --docker-server=quay.io \
  --docker-username=<user> \
  --docker-password=<token> \
  -n mcp-test

oc create secret docker-registry quay-pull-secret \
  --docker-server=quay.io \
  --docker-username=<user> \
  --docker-password=<token> \
  -n agent-sandbox

# 3. Deploy MCP Server
oc apply -f 02-currency-mcp-server.yaml

# 4. Create HTTPRoute
oc apply -f 03-currency-httproute.yaml

# 5. Apply OPA AuthPolicy
oc apply -f 04-authpolicy.yaml

# 6. Configure Istio egress
oc apply -f 06-service-entry.yaml

# 7. Deploy Agent in Kata VM
oc apply -f 05-currency-agent.yaml

# 8. Run tests
./scripts/demo-complete.sh
```

---

## Test OPA Policy

```bash
# Create test pod (without Istio sidecar)
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-curl
  namespace: mcp-test
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "3600"]
EOF

oc wait --for=condition=Ready pod/test-curl -n mcp-test --timeout=60s

# Initialize session
SESSION=$(oc exec -n mcp-test test-curl -- curl -s \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  -D - 2>/dev/null | grep -i "mcp-session-id:" | awk -F': ' '{print $2}' | tr -d '\r')

# ALLOWED: USD → EUR (HTTP 200)
oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"EUR"}}}'

# BLOCKED: USD → BTC (HTTP 403)
oc exec -n mcp-test test-curl -- curl -sw '%{http_code}' -o /dev/null \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"BTC"}}}'
```

---

## Expected Results

| Test | Currency | Expected |
|------|----------|----------|
| ✅ Allowed | USD → EUR | HTTP 200 OK |
| ✅ Allowed | GBP → JPY | HTTP 200 OK |
| ❌ Blocked | USD → BTC | HTTP 403 Forbidden |
| ❌ Blocked | ETH → EUR | HTTP 403 Forbidden |

---

## Verify Kata VM Isolation

```bash
# Check agent is using Kata runtime
oc get pod -n agent-sandbox -l app=currency-agent \
  -o jsonpath='{.items[0].spec.runtimeClassName}'
# Expected: kata

# Check agent status
oc get agent -n agent-sandbox
# Expected: currency-agent  True
```

---

## Project Structure

```
.
├── 00-kataconfig.yaml       # Kata runtime (prerequisite)
├── 01-namespaces.yaml       # mcp-test, agent-sandbox
├── 02-currency-mcp-server.yaml  # MCP server deployment
├── 03-currency-httproute.yaml   # Gateway routing
├── 04-authpolicy.yaml       # OPA policy (blocks BTC/ETH)
├── 05-currency-agent.yaml   # Kagenti Agent in Kata VM
├── 06-service-entry.yaml    # Istio egress allowlist
├── scripts/
│   └── demo-complete.sh     # Test all security layers
├── docs/
│   ├── architecture.md      # Detailed diagrams
│   └── troubleshooting.md   # Common issues
└── README.md
```

---

## Key Technical Details

### 1. MCP Server Must Have Istio Sidecar Disabled

```yaml
metadata:
  annotations:
    sidecar.istio.io/inject: "false"
```

### 2. Kata Pods Require 2Gi Memory

```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

### 3. Test Pods Need Sidecar Disabled

Otherwise you get 502 Bad Gateway errors.

### 4. Host Header Required for Gateway Routing

```bash
curl -H "Host: currency-mcp.mcp.local" http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp
```

---

## How the Layers Work Together

| Attack | Layer 1 (OPA) | Layer 2 (Istio) | Layer 3 (Kata) |
|--------|---------------|-----------------|----------------|
| `get_exchange_rate("USD", "BTC")` | ✅ BLOCKED | - | - |
| `requests.get("https://evil.com")` | Bypassed | ✅ BLOCKED | - |
| Kernel exploit → host escape | Bypassed | Bypassed | ✅ CONTAINED |
| Read `/etc/shadow` on host | Bypassed | Bypassed | ✅ ISOLATED |

**Defense in depth:** If one layer is bypassed, the next layer catches the attack.

---

## References

- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway platform
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://github.com/anthropic-experimental/sandbox-runtime) - Inspiration
- [Frankfurter API](https://www.frankfurter.app/) - Currency exchange rates

## License

Apache 2.0
