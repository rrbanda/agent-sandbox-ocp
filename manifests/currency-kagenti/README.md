# Currency Agent - Kagenti Deployment Manifests

Deploy the Currency Agent using Kagenti CRDs with source-to-image builds.

## Directory Structure

```
currency-kagenti/
├── platform/           # Platform admin applies first
│   ├── 00-namespace.yaml
│   ├── 00b-rbac-scc.yaml
│   └── 01-pipeline-template.yaml
├── agent/              # Developer applies to deploy agent
│   ├── 02-mcp-server-build.yaml
│   ├── 03-currency-agent-build.yaml
│   ├── 04-mcp-server-deploy.yaml
│   ├── 04b-mcp-httproute.yaml
│   ├── 04c-mcpserver.yaml
│   ├── 05-currency-agent.yaml
│   └── 06-route.yaml
└── security/           # Platform admin applies after testing
    ├── 01-service-entry.yaml
    └── 02-authpolicy.yaml
```

## Deployment Order

### Step 1: Platform Setup (Platform Admin)

```bash
# Create namespace and configure pipelines
oc apply -f platform/
```

### Step 2: Create Secrets

```bash
# GitHub token for cloning repos
oc create secret generic github-token-secret \
  --from-literal=token='ghp_your_token' \
  -n currency-kagenti

# Gemini API key
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='your_key' \
  -n currency-kagenti

# Registry credentials (if using external registry)
oc create secret docker-registry quay-registry-secret \
  --docker-server=quay.io \
  --docker-username=your-user \
  --docker-password=your-password \
  -n currency-kagenti
```

### Step 3: Build and Deploy Agent (Developer)

```bash
# Apply AgentBuild and Agent CRs
oc apply -f agent/

# Watch builds
oc get pipelineruns -n currency-kagenti -w

# Check pods
oc get pods -n currency-kagenti
```

### Step 4: Test Agent

```bash
# Get route URL
ROUTE=$(oc get route currency-agent -n currency-kagenti -o jsonpath='https://{.spec.host}')

# Test conversion
curl -X POST "$ROUTE" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to EUR"}],
        "messageId": "test-1"
      }
    }
  }'
```

### Step 5: Apply Security Hardening (Platform Admin)

After verifying the agent works:

```bash
# Update HTTPRoute hostname first
# Edit security/00-httproute.yaml with your cluster domain

# Apply security manifests
oc apply -f security/
```

## What Each Manifest Does

### Platform

| File | Purpose |
|------|---------|
| `00-namespace.yaml` | Creates `currency-kagenti` namespace with Istio injection |
| `00b-rbac-scc.yaml` | RBAC and SCC for pipeline builds |
| `01-pipeline-template.yaml` | Pipeline template ConfigMap for AgentBuild |

### Agent

| File | Purpose |
|------|---------|
| `02-mcp-server-build.yaml` | AgentBuild for MCP server (has Dockerfile) |
| `03-currency-agent-build.yaml` | AgentBuild for ADK agent (uses Buildpacks) |
| `04-mcp-server-deploy.yaml` | Deployment + Service for MCP server |
| `04b-mcp-httproute.yaml` | HTTPRoute for MCP Gateway routing |
| `04c-mcpserver.yaml` | MCPServer CR to register with gateway |
| `05-currency-agent.yaml` | Agent CR with Kata runtime |
| `06-route.yaml` | OpenShift Route for external access |

### Security

| File | Purpose |
|------|---------|
| `01-service-entry.yaml` | Istio egress allowlist (frankfurter.app, googleapis.com) |
| `02-authpolicy.yaml` | OPA policy to block cryptocurrency conversions |

!!! note
    The AuthPolicy references `currency-mcp-route` HTTPRoute from the agent folder.

## Source Code

The agent code is from the official Google ADK samples:
- https://github.com/google/adk-samples/tree/main/python/agents/currency-agent

## Troubleshooting

### Build Stuck

```bash
oc get pipelineruns -n currency-kagenti
oc describe pipelinerun <name> -n currency-kagenti
```

### Pod Not Starting

```bash
oc describe pod -n currency-kagenti <pod-name>
oc logs -n currency-kagenti <pod-name>
```

### MCP Server Connection Issues

```bash
oc logs -n currency-kagenti deployment/currency-mcp-server
oc exec -n currency-kagenti deployment/currency-agent -- \
  curl -s http://currency-mcp-server:8080/health
```
