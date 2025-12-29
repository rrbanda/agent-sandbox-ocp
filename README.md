# Agent Sandbox on OpenShift

> **Enterprise-grade AI agent isolation using OpenShift Sandboxed Containers (OSC) and Kagenti MCP Gateway with OPA policy enforcement**

This repository demonstrates how to achieve [Anthropic SRT (Sandbox Runtime)](https://www.anthropic.com/news/sandbox-runtime) equivalent capabilities on OpenShift using:

- **OpenShift Sandboxed Containers (OSC)** - VM-level isolation via Kata Containers
- **Kagenti MCP Gateway** - Centralized tool call routing and policy enforcement
- **Authorino + OPA** - Fine-grained tool argument inspection and URL blocking

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
| `fetch_url` | `https://example.com/page` | ✅ **ALLOWED** (200) |

### Sandboxed Agent (Kata Runtime)

```
Pod: weather-time-agent-5776df7cb6-bfstw
RuntimeClass: kata
Node: worker-cluster-nngf2-4
Status: Running
✅ Agent is running with Kata VM-level isolation!
```

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

## Prerequisites

- OpenShift 4.14+ cluster
- OpenShift Sandboxed Containers operator installed
- [Kagenti](https://github.com/kagenti/kagenti) installed
- Kuadrant operator installed

## Quick Start

### 1. Install Kagenti

Follow the [Kagenti Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md)

### 2. Configure Istio for OPA Body Forwarding

```bash
# Switch from ambient to sidecar mode (required for ext_authz)
oc patch istio default -n istio-system --type=json -p='[
  {"op": "remove", "path": "/spec/values/profile"}
]'

# Create istio-cni namespace if missing
oc create namespace istio-cni

# Enable request body forwarding for OPA inspection
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

### 3. Enable Sidecar Injection

```bash
./scripts/setup-namespaces.sh
```

### 4. Apply OPA Policy

```bash
kubectl apply -f manifests/policies/url-blocking-policy.yaml
```

### 5. Deploy Sandboxed Agent

```bash
kubectl apply -f manifests/osc/sandboxed-agent.yaml
```

### 6. Run Demo Test

```bash
./scripts/test-policy.sh
```

## OPA Policy Example

The policy blocks `fetch_url` calls to non-approved URLs:

```rego
package authorino.authz

allow { count(deny) == 0 }

deny[msg] {
  input.context.request.http.body
  body := json.unmarshal(input.context.request.http.body)
  body.method == "tools/call"
  body.params.name == "fetch_url"
  url := body.params.arguments.url
  not approved_url(url)
  msg := sprintf("BLOCKED: URL '%s' not in approved list", [url])
}

approved_url(url) { startswith(url, "https://api.weather.gov") }
approved_url(url) { startswith(url, "https://httpbin.org") }
approved_url(url) { startswith(url, "https://example.com") }
```

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
- [MCP Gateway](https://github.com/kagenti/mcp-gateway) - Model Context Protocol gateway
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://www.anthropic.com/news/sandbox-runtime) - Reference architecture

## License

Apache 2.0
