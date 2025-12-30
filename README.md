# Agent Sandbox on OpenShift

A step-by-step demo showing how to secure AI agents with three layers of protection:

| Layer | Technology | Protection |
|-------|------------|------------|
| **1. Tool Policy** | OPA via MCP Gateway | Blocks unauthorized tool arguments |
| **2. Network Egress** | Istio | Blocks direct internet access |
| **3. VM Isolation** | Kata Containers | Isolates agent in hardware VM |

**Demo scenario:** A Currency Agent that converts currencies. We'll block cryptocurrency conversions (BTC, ETH) while allowing fiat currencies (USD, EUR).

---

## Quick Start: ADK Web UI Demo

For a visual demo experience, deploy the [Google ADK Web UI](https://github.com/google/adk-web) first:

```bash
# 1. Create namespace
oc apply -f manifests/adk-web/00-namespace.yaml

# 2. Create Gemini API key secret
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='<your-gemini-api-key>' \
  -n adk-web

# 3. Deploy ADK Web server
oc apply -f manifests/adk-web/01-adk-server.yaml

# 4. Wait for pod to be ready (~60 seconds for pip install)
oc get pods -n adk-web -w

# 5. Access the Web UI
echo "https://$(oc get route adk-server -n adk-web -o jsonpath='{.spec.host}')/dev-ui/"
```

**Try it:** Open the URL, select `currency_agent`, and ask: *"What is 100 USD in EUR?"*

### ADK Web UI Screenshots

**Initial View** - Select the `currency_agent` from the dropdown:

![ADK Web UI - Initial View](docs/images/adk-web-ui-initial.png)

**Currency Conversion in Action** - Ask the agent to convert currencies:

![ADK Web UI - Currency Conversion](docs/images/adk-web-ui-conversion.png)

**Trace View** - See the full invocation trace with tool execution:

![ADK Web UI - Trace View](docs/images/adk-web-ui-trace.png)

---

## Prerequisites

Before starting, ensure you have:

- ✅ OpenShift 4.14+ cluster with admin access
- ✅ `oc` CLI configured and logged in
- ✅ **Kagenti installed** ([Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/install.md))
- ✅ **Kuadrant operator installed** (from OperatorHub)
- ✅ **OpenShift Sandboxed Containers operator installed** (from OperatorHub)
- ✅ **Gemini API Key** ([Get one here](https://aistudio.google.com/app/apikey))

### Verify Kagenti is Running

```bash
oc get pods -n kagenti-system | grep kagenti-controller
oc get pods -n gateway-system | grep mcp-gateway
```

Expected: Both should show `Running`.

---

## Demo Flow

```
┌─────────────────────────────────────────────────────────────────────────┐
│  DEMO PHASE 1: Visual Demo with ADK Web UI                              │
│  ─────────────────────────────────────────                              │
│  Show the Currency Agent working in a beautiful web interface           │
│  URL: https://<cluster>/dev-ui/                                         │
│  Try: "Convert 100 USD to EUR" ✅                                       │
└─────────────────────────────────────────────────────────────────────────┘
                                    │
                                    ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  DEMO PHASE 2: Security Layers                                          │
│  ─────────────────────────────────                                       │
│  Show how we protect the agent with 3 layers:                           │
│  • Layer 1: OPA blocks crypto (BTC/ETH) ❌ HTTP 403                     │
│  • Layer 2: Istio blocks unauthorized URLs ❌                           │
│  • Layer 3: Kata VM isolates the agent 🔒                               │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Step 1: Enable Kata VM Isolation

### What
Kata Containers run each pod inside a lightweight VM instead of a regular container. This provides hardware-level isolation.

### Why
If an AI agent is compromised, it cannot escape to the host system because it's trapped inside a VM with its own kernel.

### Do

```bash
# Label a worker node for Kata
oc label node <NODE_NAME> node-role.kubernetes.io/kata-oc=""

# Apply KataConfig
oc apply -f manifests/currency-demo/00-kataconfig.yaml
```

### Test

```bash
# Wait for RuntimeClass to be created (10-15 minutes)
watch oc get runtimeclass kata
```

Expected: `kata` RuntimeClass appears with handler `kata`.

---

## Step 2: Create Namespaces

### What
Create two namespaces:
- `mcp-test` - For MCP servers (tools)
- `agent-sandbox` - For AI agents

### Why
Separating agents from tools allows different security policies for each.

### Do

```bash
oc apply -f manifests/currency-demo/01-namespaces.yaml
```

### Test

```bash
oc get namespace mcp-test agent-sandbox
```

Expected: Both namespaces exist.

---

## Step 3: Create Secrets

### What
Create secrets for:
- Gemini API key (for the LLM)
- Quay pull secret (for private container images)

### Why
The agent needs API access to Gemini, and Kubernetes needs credentials to pull private images.

### Do

```bash
# Gemini API key for the agent
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='<your-gemini-api-key>' \
  -n agent-sandbox

# Quay pull secret for mcp-test namespace
oc create secret docker-registry quay-pull-secret \
  --docker-server=quay.io \
  --docker-username=<your-quay-user> \
  --docker-password=<your-quay-token> \
  -n mcp-test

# Quay pull secret for agent-sandbox namespace
oc create secret docker-registry quay-pull-secret \
  --docker-server=quay.io \
  --docker-username=<your-quay-user> \
  --docker-password=<your-quay-token> \
  -n agent-sandbox
```

### Test

```bash
oc get secret gemini-api-key -n agent-sandbox
oc get secret quay-pull-secret -n mcp-test
oc get secret quay-pull-secret -n agent-sandbox
```

Expected: All three secrets exist.

---

## Step 4: Deploy the Currency MCP Server

### What
Deploy an MCP server that provides a `get_exchange_rate` tool. This tool fetches live exchange rates from the Frankfurter API.

### Why
MCP (Model Context Protocol) servers provide tools that agents can call. The MCP Gateway routes these calls and enforces policies.

### Do

```bash
oc apply -f manifests/currency-demo/02-currency-mcp-server.yaml
```

### Test

```bash
# Check pod is running
oc get pods -n mcp-test -l app=currency-mcp-server

# Check service exists
oc get svc currency-mcp-server -n mcp-test
```

Expected: Pod is `Running`, service exists on port 8080.

---

## Step 5: Create HTTPRoute for Gateway Routing

### What
Create an HTTPRoute that tells the MCP Gateway how to route requests to the currency MCP server based on the `Host` header.

### Why
The MCP Gateway uses host-based routing. Requests with `Host: currency-mcp.mcp.local` will be routed to our currency MCP server.

### Do

```bash
oc apply -f manifests/currency-demo/03-currency-httproute.yaml
```

### Test

```bash
oc get httproute -n mcp-test currency-mcp-route
```

Expected: HTTPRoute exists with hostname `currency-mcp.mcp.local`.

---

## Step 6: Apply OPA Policy (Tool Authorization)

### What
Create an AuthPolicy that uses OPA (Open Policy Agent) to inspect tool call arguments and block unauthorized requests.

### Why
This is **Layer 1** of our security. The policy blocks:
- `get_exchange_rate` calls with `BTC` or `ETH` (cryptocurrencies)
- Allows `USD`, `EUR`, `GBP`, etc. (fiat currencies)

### Do

```bash
oc apply -f manifests/currency-demo/04-authpolicy.yaml
```

### Test

```bash
oc get authpolicy -n gateway-system mcp-tools-auth
```

Expected: AuthPolicy exists and shows `Accepted`.

---

## Step 7: Configure Istio Egress (Network Control)

### What
Create a ServiceEntry that allows the MCP server to call the Frankfurter API. All other external traffic is blocked.

### Why
This is **Layer 2** of our security. Even if an agent or tool tries to call an unauthorized URL directly, Istio blocks it at the network level.

### Do

```bash
oc apply -f manifests/currency-demo/06-service-entry.yaml
```

### Test

```bash
oc get serviceentry -n istio-system approved-external-apis
```

Expected: ServiceEntry exists with hosts including `api.frankfurter.app`.

---

## Step 8: Deploy the Currency Agent

### What
Deploy the Currency Agent using Kagenti's Agent CRD. The agent runs inside a Kata VM and uses Gemini as its LLM.

### Why
This is **Layer 3** of our security. The agent runs in an isolated VM, so even if compromised, it cannot access the host system.

### Do

```bash
oc apply -f manifests/currency-demo/05-currency-agent.yaml
```

### Test

```bash
# Check agent CR
oc get agent -n agent-sandbox currency-agent

# Check pod is running with Kata runtime
oc get pods -n agent-sandbox -l app=currency-agent

# Verify it's using Kata
oc get pod -n agent-sandbox -l app=currency-agent -o jsonpath='{.items[0].spec.runtimeClassName}'
```

Expected: Agent shows `Ready`, pod is `Running`, runtimeClassName is `kata`.

---

## Step 9: Test the Security Layers

### What
Test that our three security layers are working:
1. OPA blocks BTC/ETH conversions
2. Fiat conversions work normally

### Create a Test Pod

```bash
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
```

### Initialize MCP Session

```bash
SESSION=$(oc exec -n mcp-test test-curl -- curl -s \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -d '{"jsonrpc":"2.0","id":"1","method":"initialize","params":{"protocolVersion":"2024-11-05","capabilities":{},"clientInfo":{"name":"test","version":"1.0"}}}' \
  -D - 2>/dev/null | grep -i "mcp-session-id:" | awk -F': ' '{print $2}' | tr -d '\r')

echo "Session: $SESSION"
```

### Test 1: Allowed - USD to EUR

```bash
oc exec -n mcp-test test-curl -- curl -s \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"2","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"EUR"}}}'
```

**Expected:** HTTP 200 with exchange rate result.

### Test 2: Blocked - USD to BTC

```bash
oc exec -n mcp-test test-curl -- curl -sw '\nHTTP Code: %{http_code}\n' \
  http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp \
  -H "Host: currency-mcp.mcp.local" \
  -H "Content-Type: application/json" \
  -H "Accept: application/json, text/event-stream" \
  -H "Mcp-Session-Id: $SESSION" \
  -d '{"jsonrpc":"2.0","id":"3","method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"BTC"}}}'
```

**Expected:** HTTP 403 Forbidden (blocked by OPA policy).

### Run Full Test Script

```bash
./scripts/demo-complete.sh
```

---

## Summary

| Test | What | Expected Result |
|------|------|-----------------|
| USD → EUR | Fiat currency conversion | ✅ HTTP 200 |
| GBP → JPY | Fiat currency conversion | ✅ HTTP 200 |
| USD → BTC | Cryptocurrency (blocked) | ❌ HTTP 403 |
| ETH → EUR | Cryptocurrency (blocked) | ❌ HTTP 403 |
| Agent runtime | Kata VM isolation | `runtimeClassName: kata` |

---

## How the Layers Work Together

```
┌─────────────────────────────────────────────────────────────┐
│  LAYER 3: Kata VM Isolation                                 │
│  Agent runs in isolated micro-VM with separate kernel       │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Currency Agent                                       │  │
│  │  "Convert 100 USD to BTC"                             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 1: OPA Policy at MCP Gateway                         │
│  Inspects tool arguments, blocks BTC/ETH                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  get_exchange_rate(USD, BTC) → ❌ BLOCKED (403)       │  │
│  │  get_exchange_rate(USD, EUR) → ✅ ALLOWED             │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│  LAYER 2: Istio Egress Control                              │
│  Only allows api.frankfurter.app, blocks all other URLs     │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  curl https://api.frankfurter.app → ✅ ALLOWED        │  │
│  │  curl https://evil.com → ❌ BLOCKED                   │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

---

## ADK Web UI (Optional Visual Demo)

The [Google ADK Web UI](https://github.com/google/adk-web) provides a beautiful interface for testing agents before diving into the security layers.

### Deploy ADK Web UI

```bash
# Deploy using the script
./scripts/deploy-adk-web.sh <your-gemini-api-key>

# Or manually:
oc apply -f manifests/adk-web/00-namespace.yaml
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='<key>' -n adk-web
oc apply -f manifests/adk-web/01-adk-server.yaml
```

### Access

```bash
# Get the URL
echo "https://$(oc get route adk-server -n adk-web -o jsonpath='{.spec.host}')/dev-ui/"
```

### Features

| Feature | Description |
|---------|-------------|
| **Chat Interface** | Interactive chat with the Currency Agent |
| **Trace View** | See detailed execution traces |
| **Events** | Real-time event streaming |
| **Sessions** | Manage conversation sessions |

### Clean Up ADK Web UI

```bash
oc delete -f manifests/adk-web/
```

---

## Cleanup

```bash
# Remove ADK Web UI
oc delete -f manifests/adk-web/

# Remove security demo components
oc delete agent currency-agent -n agent-sandbox
oc delete -f manifests/currency-demo/04-authpolicy.yaml
oc delete -f manifests/currency-demo/03-currency-httproute.yaml
oc delete -f manifests/currency-demo/02-currency-mcp-server.yaml
oc delete -f manifests/currency-demo/06-service-entry.yaml
oc delete pod test-curl -n mcp-test
oc delete -f manifests/currency-demo/01-namespaces.yaml
```

---

## Troubleshooting

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues:
- 502 Bad Gateway → Disable sidecar on test pod
- OPA not blocking → Check Istio body forwarding config
- Kata pods pending → Check node labels and RuntimeClass
- ADK Web API key error → Verify secret has correct key

---

## Project Structure

```
agent-sandbox-ocp/
├── manifests/
│   ├── currency-demo/              # Currency conversion security demo
│   │   ├── 00-kataconfig.yaml      # Kata VM runtime config
│   │   ├── 01-namespaces.yaml      # mcp-test & agent-sandbox namespaces
│   │   ├── 02-currency-mcp-server.yaml # MCP server with get_exchange_rate
│   │   ├── 03-currency-httproute.yaml  # Gateway routing
│   │   ├── 04-authpolicy.yaml      # OPA policy blocking crypto
│   │   ├── 05-currency-agent.yaml  # Kagenti Agent CR with Kata
│   │   └── 06-service-entry.yaml   # Istio egress allowlist
│   └── adk-web/                    # ADK Web UI deployment
│       ├── 00-namespace.yaml       # adk-web namespace
│       └── 01-adk-server.yaml      # Combined API + Web UI server
├── scripts/
│   ├── demo-complete.sh            # Full security test script
│   └── deploy-adk-web.sh           # ADK Web UI deployment script
└── docs/
    ├── images/                     # Screenshots for documentation
    │   ├── adk-web-ui-initial.png
    │   ├── adk-web-ui-conversion.png
    │   └── adk-web-ui-trace.png
    ├── architecture.md             # Architecture diagrams
    └── troubleshooting.md          # Common issues & fixes
```

---

## References

- [Google ADK](https://github.com/google/adk-python) - Agent Development Kit
- [ADK Web UI](https://github.com/google/adk-web) - Visual development interface
- [ADK Documentation](https://google.github.io/adk-docs/) - Official docs
- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway platform
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - OPA policy engine
- [Frankfurter API](https://www.frankfurter.app/) - Currency exchange rates

## License

Apache 2.0
