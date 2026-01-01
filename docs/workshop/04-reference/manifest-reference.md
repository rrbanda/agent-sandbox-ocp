# Manifest Reference

Complete guide to all YAML manifests used in this workshop.

## Directory Structure

```
manifests/currency-kagenti/
├── platform/                   # 👷 Platform Admin (one-time)
│   ├── 00-namespace.yaml       # Create namespace
│   ├── 00b-rbac-scc.yaml       # Pipeline permissions
│   └── 01-pipeline-template.yaml # Build pipeline config
│
├── agent/                      # 👩‍💻 Developer (per deployment)
│   ├── 02-mcp-server-build.yaml    # AgentBuild: MCP server
│   ├── 03-currency-agent-build.yaml # AgentBuild: Agent
│   ├── 04-mcp-server-deploy.yaml   # Deploy MCP server
│   ├── 04b-mcp-httproute.yaml      # MCP Gateway routing
│   ├── 04c-mcpserver.yaml          # MCPServer CR
│   ├── 05a-agent-code-configmap.yaml # Agent code with Host header
│   ├── 05-currency-agent.yaml      # Agent CR (Kata)
│   └── 06-route.yaml               # External access
│
└── security/                   # 👷 Platform Admin (after testing)
    ├── 01-service-entry.yaml   # Istio egress control
    └── 02-authpolicy.yaml      # OPA tool policy
```


## Platform Manifests

### 00-namespace.yaml

**Purpose**: Create isolated namespace for agent workloads

**Apply**:
```bash
oc apply -f platform/00-namespace.yaml
```

**Contents**:
```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: currency-kagenti
  labels:
    app.kubernetes.io/name: currency-kagenti
```


### 00b-rbac-scc.yaml

**Purpose**: Grant pipeline build permissions

**Apply**:
```bash
oc apply -f platform/00b-rbac-scc.yaml

# Additional SCCs (requires cluster-admin)
oc adm policy add-scc-to-user pipelines-scc \
  system:serviceaccount:currency-kagenti:pipeline
```


### 01-pipeline-template.yaml

**Purpose**: Define build pipeline steps (git clone, buildah/buildpacks)

**Apply**:
```bash
oc apply -f platform/01-pipeline-template.yaml
```

**Build Strategy**:
- If source has Dockerfile → Buildah
- If no Dockerfile → Buildpacks (auto-detect)


## Agent Manifests

### 02-mcp-server-build.yaml

**Purpose**: Build MCP Server image from Git source

**Apply**:
```bash
oc apply -f agent/02-mcp-server-build.yaml
```

**Key Fields**:
```yaml
spec:
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent/mcp-server"
  buildOutput:
    image: "currency-mcp-server"
    imageRegistry: "quay.io/rbrhssa"
```


### 03-currency-agent-build.yaml

**Purpose**: Build Currency Agent image from Git source

**Apply**:
```bash
oc apply -f agent/03-currency-agent-build.yaml
```

**Key Fields**:
```yaml
spec:
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent"
  buildOutput:
    image: "currency-agent"
    imageRegistry: "quay.io/rbrhssa"
```


### 04-mcp-server-deploy.yaml

**Purpose**: Deploy MCP Server (Deployment + Service)

**Apply**:
```bash
oc apply -f agent/04-mcp-server-deploy.yaml
```

**Creates**:
- Deployment: `currency-mcp-server`
- Service: `currency-mcp-server` (port 8080)


### 04b-mcp-httproute.yaml

**Purpose**: Route traffic to MCP Server via MCP Gateway

**Apply**:
```bash
oc apply -f agent/04b-mcp-httproute.yaml
```

**Key Fields**:
```yaml
spec:
  parentRefs:
    - name: mcp-gateway
      namespace: kagenti-system
  hostnames:
    - currency-mcp.mcp.local
```


### 05a-agent-code-configmap.yaml

**Purpose**: Agent code with MCP Gateway Host header support (enables OPA policy enforcement)

**Apply**:
```bash
oc apply -f agent/05a-agent-code-configmap.yaml
```

**Why It's Needed**:
The default agent image doesn't include the `Host` header needed for MCP Gateway routing. This ConfigMap provides updated agent code that:

1. Sets `headers={"Host": MCP_HOST_HEADER}` in `StreamableHTTPConnectionParams`
2. Enables routing through MCP Gateway to the correct MCP Server
3. Triggers OPA policy evaluation for every tool call

**Key Code**:
```python
MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=MCP_SERVER_URL,
        headers={"Host": MCP_HOST_HEADER},  # ← Critical for policy enforcement!
    )
)
```

!!! warning "Without This ConfigMap"
    Tool calls bypass the MCP Gateway's policy enforcement. BTC conversions would succeed.


### 05-currency-agent.yaml

**Purpose**: Deploy Currency Agent with Kata VM isolation

**Apply**:
```bash
# First apply the ConfigMap, then the Agent
oc apply -f agent/05a-agent-code-configmap.yaml
oc apply -f agent/05-currency-agent.yaml
```

**Key Fields**:
```yaml
spec:
  imageSource:
    buildRef:
      name: currency-agent-build    # Reference to AgentBuild
  podTemplateSpec:
    spec:
      runtimeClassName: kata        # Kata VM isolation
      containers:
      - name: agent
        env:
        - name: MCP_SERVER_URL
          value: "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
        - name: MCP_HOST_HEADER
          value: "currency-mcp.mcp.local"
        volumeMounts:
        - mountPath: /app/currency_agent/agent.py
          name: agent-code
          subPath: agent.py
      volumes:
      - name: agent-code
        configMap:
          name: currency-agent-code
```

**Security**:
- Layer 1 (Kata) is enabled here via `runtimeClassName: kata`
- Layer 3 (OPA) is enabled via MCP Gateway routing with Host header


### 06-route.yaml

**Purpose**: Expose agent externally via OpenShift Route

**Apply**:
```bash
oc apply -f agent/06-route.yaml
```


## Security Manifests

### 01-service-entry.yaml

**Purpose**: Define allowed external APIs (Istio egress control)

**Apply**:
```bash
oc apply -f security/01-service-entry.yaml
```

**Allowed Hosts**:
```yaml
spec:
  hosts:
    - api.frankfurter.app           # Currency rates
    - generativelanguage.googleapis.com  # Gemini API
```

**Security**: Layer 2 (Network Egress)


### 02-authpolicy.yaml

**Purpose**: Block cryptocurrency conversions via OPA policy

**Apply**:
```bash
oc apply -f security/02-authpolicy.yaml
```

**Blocked Currencies**:
- BTC, ETH, DOGE, XRP, SOL, ADA, DOT, MATIC, SHIB, AVAX

**Security**: Layer 3 (Tool Policy)


## Deployment Order Summary

| Step | File | Who | When |
|------|------|-----|------|
| 1 | `platform/00-namespace.yaml` | 👷 Admin | First |
| 2 | `platform/00b-rbac-scc.yaml` | 👷 Admin | First |
| 3 | `platform/01-pipeline-template.yaml` | 👷 Admin | First |
| 4 | `agent/02-mcp-server-build.yaml` | 👩‍💻 Dev | After platform |
| 5 | `agent/03-currency-agent-build.yaml` | 👩‍💻 Dev | After platform |
| 6 | `agent/04-mcp-server-deploy.yaml` | 👩‍💻 Dev | After builds |
| 7 | `agent/04b-mcp-httproute.yaml` | 👩‍💻 Dev | After MCP deploy |
| 8 | `agent/05-currency-agent.yaml` | 👩‍💻 Dev | After agent build |
| 9 | `agent/06-route.yaml` | 👩‍💻 Dev | After agent deploy |
| 10 | `security/01-service-entry.yaml` | 👷 Admin | After testing |
| 11 | `security/02-authpolicy.yaml` | 👷 Admin | After testing |


## Quick Apply All

### Platform Only

```bash
oc apply -f platform/
```

### Agent Only

```bash
oc apply -f agent/
```

### Security Only (After Testing)

```bash
oc apply -f security/
```

