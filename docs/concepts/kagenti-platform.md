# What to Know About Kagenti Platform

---

## 1. What Kagenti Is

**Kagenti** is a cloud-native platform for deploying and managing AI agents on Kubernetes. It provides:

- **Agent CRD** - Deploy agents as Kubernetes resources
- **MCP Gateway** - Centralized tool access and policy enforcement
- **Tool Registry** - Discover and manage MCP tools
- **Observability** - Tracing and monitoring for agent workflows

**Key idea**

> Kagenti brings the Model Context Protocol (MCP) to Kubernetes with enterprise features.

---

## 2. What MCP Is

**Model Context Protocol (MCP)** is an open standard for AI agents to interact with tools:

```
Agent → MCP Client → MCP Gateway → MCP Server → Tool
```

MCP standardizes:

- **Tool discovery** - Agents can list available tools
- **Tool invocation** - Standard request/response format
- **Streaming** - For long-running operations

Think of MCP as **"OpenAPI for AI agents"**.

---

## 3. Why Kagenti Matters for This Workshop

Without Kagenti, you would need to:

1. Manually deploy agent containers
2. Configure tool connections per agent
3. Build custom authentication/authorization
4. Set up observability from scratch

Kagenti provides these as **platform capabilities**.

---

## 4. Core Components

### Agent CRD

Defines an AI agent as a Kubernetes resource:

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
  namespace: agent-sandbox
spec:
  # Option 1: Reference an AgentBuild (recommended)
  imageSource:
    buildRef:
      name: currency-agent-build
  
  # Option 2: Direct image reference
  # imageSource:
  #   image: quay.io/your-org/currency-agent:latest
  
  podTemplateSpec:
    spec:
      runtimeClassName: kata    # VM isolation
```

### AgentBuild CRD

Automates building container images from source:

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: AgentBuild
metadata:
  name: currency-agent-build
  labels:
    kagenti.io/framework: google-adk
    kagenti.io/protocol: a2a
spec:
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent"
  buildOutput:
    image: "currency-agent"
    imageTag: "v1.0.0"
    imageRegistry: "quay.io/your-org"
```

See [AgentBuild: Source-to-Image](agentbuild-source-to-image.md) for details.

### MCP Gateway

The central hub for tool access:

- Routes tool calls to appropriate MCP servers
- Enforces authentication and authorization
- Provides rate limiting and quotas
- Logs all tool invocations

### Tool (MCP Server) CRD

Registers tools with the platform:

```yaml
apiVersion: kagenti.io/v1alpha1
kind: Tool
metadata:
  name: currency-mcp-server
spec:
  type: mcp-server
  endpoint: http://currency-mcp-server:8080
  capabilities:
    - get_exchange_rate
```

---

## 5. Request Flow Through Kagenti

```
1. User sends prompt to Agent
2. Agent decides to call tool
3. Agent sends MCP request to Gateway
4. Gateway authenticates request
5. Gateway checks authorization (AuthPolicy/OPA)
6. Gateway routes to MCP Server
7. MCP Server executes tool
8. Response flows back through Gateway
9. Agent receives tool result
10. Agent formulates response
```

---

## 6. How Kagenti Integrates Security Layers

| Layer | Kagenti Integration |
|-------|---------------------|
| **VM Isolation** | `runtimeClassName` in Agent CR |
| **Network Egress** | ServiceEntry in agent namespace |
| **Tool Policy** | AuthPolicy on HTTPRoute to Gateway |

Kagenti doesn't replace these layers - it **orchestrates** them.

---

## 7. Kagenti UI

Kagenti includes a Streamlit-based dashboard for:

- **Agent Catalog** - Browse and interact with deployed agents
- **Tool Catalog** - Discover available MCP tools
- **Import** - Deploy agents/tools from Git repositories
- **Observability** - Links to traces and metrics

The UI complements but doesn't replace GitOps-based deployments.

---

## 8. Deployment Model

### Helm Installation

```bash
helm repo add kagenti https://kagenti.github.io/charts
helm install kagenti kagenti/kagenti \
  --namespace kagenti-system \
  --create-namespace
```

### What Gets Deployed

- Kagenti Operator (watches Agent/Tool CRs)
- MCP Gateway (routes tool calls)
- Optional: UI, observability components

---

## 9. Multi-Tenancy

Kagenti supports multi-tenant deployments:

```
Namespace: team-a
  └── Agent: team-a-agent
  └── Tool: team-a-tools

Namespace: team-b
  └── Agent: team-b-agent
  └── Tool: team-b-tools
```

Each team:

- Has isolated namespaces
- Can have different security policies
- Shares the central MCP Gateway (with namespace-scoped rules)

---

## 10. Kagenti vs DIY

| Aspect | With Kagenti | DIY |
|--------|--------------|-----|
| Agent deployment | Agent CR → Operator | Write Deployments manually |
| Tool discovery | Automatic via CRDs | Custom implementation |
| Gateway routing | Built-in | Build or integrate |
| Policy integration | AuthPolicy support | Custom middleware |
| Observability | Integrated | Assemble yourself |

---

## 11. What Kagenti Does *Not* Do

Kagenti does **not**:

- Provide the LLM itself (bring your own model)
- Replace your agent framework (ADK, LangGraph, etc.)
- Auto-generate agents or tools
- Manage external API credentials

> Kagenti is infrastructure for agents, not an agent builder.

---

## 12. Relevance to This Workshop

In the Currency Agent demo:

1. **AgentBuild CRs** build both the agent and MCP server from source
2. **Agent CR** deploys the currency agent with:
   - `buildRef` pointing to AgentBuild
   - `runtimeClassName: kata` for VM isolation
3. **MCP Server Deployment** provides the `get_exchange_rate` tool
4. **AuthPolicy** on the Gateway enforces OPA rules

### The Kagenti Deployment Flow

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ AgentBuild CR   │────▶│ Tekton Pipeline │────▶│ Container Image │
│ (source code)   │     │ (build)         │     │ (quay.io)       │
└─────────────────┘     └─────────────────┘     └────────┬────────┘
                                                         │
┌─────────────────┐     ┌─────────────────┐              │
│ Agent CR        │────▶│ Running Pod     │◀─────────────┘
│ (buildRef)      │     │ (Kata VM)       │
└─────────────────┘     └─────────────────┘
```

You apply AgentBuild and Agent CRs, and Kagenti handles:

- Cloning source from Git
- Building container image
- Pushing to registry
- Deploying with Kata isolation

---

## 13. A Defensible Technical Statement

> Kagenti provides Kubernetes-native infrastructure for AI agents using the Model Context Protocol. It handles agent deployment, tool routing, and policy integration, allowing platform teams to offer secure, governed agent execution environments without building custom infrastructure.

---

## 14. Key Takeaway

> **Kagenti is the "Kubernetes for AI agents" - it brings container orchestration patterns to agent workloads.**

---

## References

* [Kagenti GitHub](https://github.com/kagenti/kagenti)
* [Model Context Protocol Specification](https://modelcontextprotocol.io/)
* [MCP Official Documentation](https://modelcontextprotocol.io/docs)

