# Agent Sandbox on OpenShift

> **Enterprise-grade AI agent isolation using OpenShift Sandboxed Containers (OSC) and Kagenti MCP Gateway with OPA policy enforcement**

This repository demonstrates how to achieve [Anthropic SRT (Sandbox Runtime)](https://www.anthropic.com/news/sandbox-runtime) equivalent capabilities on OpenShift using:

- **OpenShift Sandboxed Containers (OSC)** - VM-level isolation via Kata Containers
- **Kagenti MCP Gateway** - Centralized tool call routing and policy enforcement
- **Authorino + OPA** - Fine-grained tool argument inspection and blocking

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

### 1. Install Kagenti (if not already installed)

Follow the [Kagenti Installation Guide](https://github.com/kagenti/kagenti/blob/main/docs/ocp/openshift-install.md)

### 2. Configure Istio for OPA Body Forwarding

```bash
# Switch from ambient to sidecar mode (if needed)
oc patch istio default -n istio-system --type=json -p='[
  {"op": "remove", "path": "/spec/values/profile"}
]'

# Enable request body forwarding for ext_authz
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

### 3. Enable Sidecar Injection for Required Namespaces

```bash
oc label namespace kuadrant-system istio-discovery=enabled istio-injection=enabled --overwrite
oc label namespace mcp-system istio-discovery=enabled istio-injection=enabled --overwrite
oc rollout restart deployment/authorino -n kuadrant-system
oc delete pods -n mcp-system --all
```

### 4. Apply OPA Policy for URL Blocking

```bash
kubectl apply -f manifests/policies/url-blocking-policy.yaml
```

### 5. Deploy Agent with Sandboxed Runtime

```bash
kubectl apply -f manifests/osc/sandboxed-agent.yaml
```

### 6. Test the Policy

```bash
./scripts/test-policy.sh
```

## Demo: Blocking Malicious URLs

The OPA policy in `manifests/policies/url-blocking-policy.yaml` demonstrates:

- **Blocking** `fetch_url` calls to non-approved URLs
- **Allowing** approved URLs (e.g., `api.weather.gov`, `httpbin.org`)
- **Blocking** specific tool arguments (e.g., weather queries for restricted cities)

### Example Test Results

```
✓ tools/list (not a tools/call) - HTTP 200
✓ fetch_url → https://malicious.com - BLOCKED (HTTP 403)
✓ fetch_url → https://api.weather.gov - ALLOWED (HTTP 200)
✓ weather → Moscow (restricted) - BLOCKED (HTTP 403)
✓ weather → New York (allowed) - ALLOWED (HTTP 200)
```

## Project Structure

```
.
├── manifests/
│   ├── osc/                    # OpenShift Sandboxed Containers configs
│   │   ├── kataconfig.yaml     # KataConfig for OSC
│   │   └── sandboxed-agent.yaml # Agent deployment with kata runtime
│   ├── policies/               # OPA/AuthPolicy definitions
│   │   └── url-blocking-policy.yaml
│   └── mcp-servers/            # MCP Server registrations
│       └── fetch-server.yaml
├── scripts/
│   └── test-policy.sh          # Policy verification script
├── docs/
│   └── troubleshooting.md      # Common issues and solutions
└── README.md
```

## Key Configuration Details

### Istio Mode: Sidecar (Not Ambient)

For OPA body inspection to work, Istio must be in **sidecar mode**, not ambient mode. This is because ambient mode has limited support for CUSTOM AuthorizationPolicy with ext_authz.

### Memory for Kata Pods

Kata pods require at least **2Gi memory** due to the QEMU overhead for micro-VMs:

```yaml
resources:
  limits:
    memory: "2Gi"
  requests:
    memory: "2Gi"
```

### Body Forwarding in ext_authz

The `includeRequestBodyInCheck` configuration is essential for OPA to inspect tool call arguments:

```yaml
includeRequestBodyInCheck:
  maxRequestBytes: 8192
  allowPartialMessage: true
```

## References

- [Kagenti](https://github.com/kagenti/kagenti) - MCP Gateway and agent platform
- [MCP Gateway](https://github.com/kagenti/mcp-gateway) - Model Context Protocol gateway
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant/Authorino](https://github.com/Kuadrant/authorino) - Policy engine
- [Anthropic SRT](https://www.anthropic.com/news/sandbox-runtime) - Reference architecture

## License

Apache 2.0
