# Platform Admin Guide: Configuring Secure Agent Namespaces

This guide is for **Platform Administrators** who configure OpenShift for secure agent deployment.

## Prerequisites

- OpenShift 4.14+ cluster with admin access
- Installed operators:
  - [Kagenti](https://github.com/kagenti/kagenti)
  - [Kuadrant](https://kuadrant.io/)
  - [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)

---

## Step 1: Install OpenShift Sandboxed Containers

### 1.1 Install the Operator

From OperatorHub, install "OpenShift Sandboxed Containers Operator".

### 1.2 Create KataConfig

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

### 1.3 Wait for Nodes

```bash
# Wait for kata runtime to be installed on nodes
oc get kataconfig example-kataconfig -o yaml | grep -A5 status
```

This takes 10-15 minutes. Nodes will be labeled and rebooted.

---

## Step 2: Create Agent Namespace

### 2.1 Create Namespace with Labels

```bash
oc apply -f - <<EOF
apiVersion: v1
kind: Namespace
metadata:
  name: agent-sandbox
  labels:
    kagenti-enabled: "true"
    istio.io/dataplane-mode: ambient
    shared-gateway-access: "true"
EOF
```

### 2.2 Create Secrets

```bash
# Gemini API key for the Currency Agent
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='your-api-key-here' \
  -n agent-sandbox
```

---

## Step 3: Configure OPA Policy (Layer 3)

Create the AuthPolicy that blocks cryptocurrency conversions:

```bash
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta2
kind: AuthPolicy
metadata:
  name: currency-policy
  namespace: agent-sandbox
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: currency-mcp
  rules:
    authorization:
      crypto-block:
        opa:
          rego: |
            package currency
            
            import future.keywords.if
            import future.keywords.in
            
            default allow := true
            
            # List of blocked cryptocurrencies
            blocked_currencies := ["BTC", "ETH", "DOGE", "XRP", "SOL"]
            
            # Deny if currency_from is crypto
            deny if {
              input.context.request.http.body.params.arguments.currency_from in blocked_currencies
            }
            
            # Deny if currency_to is crypto
            deny if {
              input.context.request.http.body.params.arguments.currency_to in blocked_currencies
            }
            
            allow if not deny
EOF
```

---

## Step 4: Configure Egress Control (Layer 2)

Create the ServiceEntry that allows only the currency API:

```bash
oc apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: currency-api
  namespace: agent-sandbox
spec:
  hosts:
    - api.frankfurter.app
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
EOF
```

With Istio ambient mesh, all other egress is blocked by default.

---

## Step 5: Verify VM Isolation (Layer 1)

### Option A: Require in Agent CR

Developers include `runtimeClassName: kata` in their Agent CR:

```yaml
spec:
  podTemplateSpec:
    spec:
      runtimeClassName: kata
```

### Option B: Enforce via Mutating Webhook (Recommended)

Create a webhook that auto-injects `runtimeClassName: kata` for all pods in the namespace.

```yaml
# Example webhook configuration
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: kata-injector
webhooks:
  - name: kata.agent-sandbox.io
    namespaceSelector:
      matchLabels:
        kagenti-enabled: "true"
    rules:
      - operations: ["CREATE"]
        apiGroups: [""]
        apiVersions: ["v1"]
        resources: ["pods"]
    clientConfig:
      # Your webhook service
```

---

## Step 6: Deploy MCP Server (Optional)

If agents need MCP tools, deploy the Currency MCP Server:

```bash
oc apply -f manifests/currency-demo/02-currency-mcp-server.yaml
oc apply -f manifests/currency-demo/03-currency-httproute.yaml
```

---

## Verification Checklist

### Kata is Working

```bash
# Check nodes have kata runtime
oc get nodes -l node.kubernetes.io/kata-containers-ready=true

# Deploy a test pod
oc run kata-test --image=busybox --restart=Never \
  --overrides='{"spec":{"runtimeClassName":"kata"}}' \
  -n agent-sandbox -- sleep 10

# Check it's running with kata
oc get pod kata-test -n agent-sandbox -o yaml | grep runtimeClassName
```

### OPA Policy is Working

```bash
# Test via MCP Gateway
# Allowed request (USD to EUR)
curl -X POST "http://mcp-gateway.../mcp" \
  -d '{"method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"EUR"}}}'
# Should return 200

# Blocked request (USD to BTC)
curl -X POST "http://mcp-gateway.../mcp" \
  -d '{"method":"tools/call","params":{"name":"get_exchange_rate","arguments":{"currency_from":"USD","currency_to":"BTC"}}}'
# Should return 403
```

### Egress is Working

```bash
# Exec into a pod in the namespace
oc exec -it -n agent-sandbox <pod-name> -- sh

# Allowed
curl https://api.frankfurter.app/latest
# Should work

# Blocked
curl https://api.openai.com
# Should fail (connection refused or timeout)
```

---

## Namespace Security Summary

After configuration, the `agent-sandbox` namespace provides:

| Layer | Configuration | Effect |
|-------|---------------|--------|
| **1. Tool Policy** | AuthPolicy with OPA | Blocks crypto tool arguments |
| **2. Network Egress** | ServiceEntry | Only allows api.frankfurter.app |
| **3. VM Isolation** | KataConfig + runtimeClassName | Pods run in VMs |
| **Identity** | SPIRE (automatic) | SPIFFE identity for each workload |
| **Mesh** | Istio ambient (automatic) | mTLS, observability |

---

## Onboarding New Teams

To create a similar namespace for another team:

1. Create namespace with Kagenti labels
2. Apply team-specific AuthPolicy
3. Apply team-specific ServiceEntry
4. Create required secrets
5. Document the allowed tools and APIs for developers

Each namespace is isolated. Policies in `team-a-sandbox` don't affect `team-b-sandbox`.

---

## Next Steps

- Read [Threat Model](../concepts/threat-model.md) to understand why these layers matter
- Read [Defense in Depth](../concepts/defense-in-depth.md) for technical details
- Use [Demo Walkthrough](demo-walkthrough.md) to demonstrate the security layers

