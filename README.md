# Secure AI Agents on OpenShift

A hands-on workshop for deploying AI agents with enterprise-grade security on OpenShift.

## The Challenge

As AI agents become more capable—executing code, calling APIs, making decisions—they introduce new security risks:

- **Untrusted code execution**: LLMs can generate malicious code
- **Data exfiltration**: Agents might leak secrets to external services  
- **Unauthorized actions**: Prompt injection can cause unintended behavior

## The Solution: Defense in Depth

This workshop demonstrates how to protect AI agents with **three independent security layers**:

```
┌─────────────────────────────────────────────────────────────┐
│  Layer 1: VM Isolation (Kata Containers)                    │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Layer 2: Network Egress (Istio Service Mesh)         │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  Layer 3: Tool Policy (Kuadrant + OPA)          │  │  │
│  │  │  ┌───────────────────────────────────────────┐  │  │  │
│  │  │  │           Agent Execution                 │  │  │  │
│  │  │  └───────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

| Layer | Technology | Protection |
|-------|------------|------------|
| **1. VM Isolation** | OpenShift Sandboxed Containers | Agent runs in hardware-isolated VM |
| **2. Network Egress** | Istio Service Mesh | Controls what external APIs agents can reach |
| **3. Tool Policy** | Kuadrant + OPA *(optional)* | Validates tool calls before execution |

## 📚 Workshop

**[Start the Workshop →](https://rrbanda.github.io/agent-sandbox-ocp/)**

The workshop is structured in four parts:

| Part | Title | Description |
|------|-------|-------------|
| **Part 0** | [Prerequisites](docs/workshop/00-prerequisites/) | Install OSC, Kagenti, and verify setup |
| **Part 1** | [Foundations](docs/workshop/01-foundations/) | Security concepts and technology stack |
| **Part 2** | [Inner Loop](docs/workshop/02-inner-loop/) | Develop and test agents locally with ADK |
| **Part 3** | [Outer Loop](docs/workshop/03-outer-loop/) | Deploy to OpenShift with full security |

## Quick Start

### Prerequisites

- OpenShift 4.14+ with cluster admin access
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html) operator
- [Kagenti Platform](https://github.com/kagenti/kagenti)
- [Kuadrant Operator](https://kuadrant.io/) *(optional - for OPA policy layer)*
- [Gemini API Key](https://aistudio.google.com/app/apikey)

### Install Kagenti

We provide automated scripts for installing Kagenti:

```bash
# 1. Copy and fill in your credentials
cp scripts/.secrets_template.yaml .secrets.yaml
# Edit .secrets.yaml with your API keys

# 2. Run the installation script
./scripts/install-kagenti.sh
```

See [Installation Guide](docs/kagenti-installation-guide.md) for detailed instructions.

### Deploy the Demo Agent

```bash
# Deploy the currency agent with security layers
oc apply -f manifests/currency-kagenti/

# Test the agent
curl -X POST "https://$(oc get route currency-agent -n currency-kagenti -o jsonpath='{.spec.host}')/run" \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Convert 100 USD to EUR"}'
```

## Project Structure

```
agent-sandbox-ocp/
├── agents/                          # Agent source code
│   ├── currency-agent/              # ADK-based currency agent
│   │   ├── currency_agent/
│   │   │   └── agent.py             # Agent logic with MCP toolset
│   │   ├── Dockerfile
│   │   └── pyproject.toml
│   └── currency-mcp-server/         # MCP server for exchange rates
│       ├── server.py
│       ├── Dockerfile
│       └── pyproject.toml
├── docs/
│   ├── workshop/                    # Workshop content
│   │   ├── 00-prerequisites/        # Setup & installation
│   │   ├── 01-foundations/          # Security concepts
│   │   ├── 02-inner-loop/           # Local development
│   │   ├── 03-outer-loop/           # Production deployment
│   │   └── 04-reference/            # Troubleshooting & cleanup
│   ├── concepts/                    # Technology explainers
│   │   ├── osc-explained.md         # OpenShift Sandboxed Containers
│   │   ├── istio-egress.md          # Istio & egress control
│   │   ├── kuadrant-opa.md          # Kuadrant & OPA policies
│   │   ├── kagenti-platform.md      # Kagenti platform
│   │   └── google-adk.md            # Google ADK
│   ├── kagenti-installation-guide.md
│   └── architecture.md
├── manifests/
│   └── currency-kagenti/            # Production manifests
│       ├── platform/                # Namespace, RBAC, pipelines
│       ├── agent/                   # Agent & MCP server resources
│       └── security/                # AuthPolicy, ServiceEntry
├── scripts/
│   ├── install-kagenti.sh           # Automated Kagenti installation
│   ├── uninstall-kagenti.sh         # Clean uninstall script
│   └── .secrets_template.yaml       # Credentials template
└── mkdocs.yml                       # Documentation site config
```

## Key Concepts

| Concept | Description |
|---------|-------------|
| [OpenShift Sandboxed Containers](docs/concepts/osc-explained.md) | VM-level isolation using Kata Containers |
| [Istio Egress Control](docs/concepts/istio-egress.md) | Network policies for external API access |
| [Kuadrant & OPA](docs/concepts/kuadrant-opa.md) | Policy enforcement for tool calls |
| [Kagenti Platform](docs/concepts/kagenti-platform.md) | Kubernetes-native agent management |
| [Google ADK](docs/concepts/google-adk.md) | Agent development framework |

## Architecture

The currency agent demonstrates the complete security flow:

```
User Request
    │
    ▼
┌─────────────────┐
│  Currency Agent │  (Runs in Kata VM)
│  (Google ADK)   │
└────────┬────────┘
         │ MCP tool call
         ▼
┌─────────────────┐
│   MCP Gateway   │  (Envoy + Broker)
│   + AuthPolicy  │  ← OPA blocks crypto
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│   MCP Server    │  (Runs in Kata VM)
│  (Frankfurter)  │
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  ServiceEntry   │  ← Istio allows only
│  (Egress)       │     frankfurter.dev
└─────────────────┘
```

## License

Apache 2.0
