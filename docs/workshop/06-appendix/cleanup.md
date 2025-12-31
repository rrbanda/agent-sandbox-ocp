# Cleanup

Remove all demo resources from your cluster.

## Quick Cleanup

Remove everything at once:

```bash
# Delete agent and demo resources
oc delete -f manifests/currency-demo/05-currency-agent.yaml
oc delete -f manifests/currency-demo/04-authpolicy.yaml
oc delete -f manifests/currency-demo/03-currency-httproute.yaml
oc delete -f manifests/currency-demo/02-currency-mcp-server.yaml
oc delete -f manifests/currency-demo/06-service-entry.yaml
oc delete -f manifests/currency-demo/01-namespaces.yaml

# Delete ADK Web UI (if deployed)
oc delete -f manifests/adk-web/01-adk-server.yaml
oc delete -f manifests/adk-web/00-namespace.yaml

# Delete secrets
oc delete secret gemini-api-key -n agent-sandbox --ignore-not-found
oc delete secret gemini-api-key -n adk-web --ignore-not-found
```

## Step-by-Step Cleanup

### 1. Delete the Agent

```bash
oc delete agent currency-agent -n agent-sandbox
# or
oc delete -f manifests/currency-demo/05-currency-agent.yaml
```

### 2. Delete Policy Resources

```bash
oc delete -f manifests/currency-demo/04-authpolicy.yaml
oc delete -f manifests/currency-demo/03-currency-httproute.yaml
```

### 3. Delete MCP Server

```bash
oc delete -f manifests/currency-demo/02-currency-mcp-server.yaml
```

### 4. Delete Egress Rules

```bash
oc delete -f manifests/currency-demo/06-service-entry.yaml
```

### 5. Delete Namespaces

```bash
oc delete -f manifests/currency-demo/01-namespaces.yaml
# This deletes: agent-sandbox, mcp-test
```

### 6. Delete ADK Web UI

```bash
oc delete -f manifests/adk-web/01-adk-server.yaml
oc delete -f manifests/adk-web/00-namespace.yaml
```

## Keep KataConfig?

The KataConfig is cluster-scoped and affects all nodes. You may want to keep it for future use.

**To remove** (will trigger node reboots):

```bash
oc delete -f manifests/currency-demo/00-kataconfig.yaml
```

**To keep**: Just leave it. It doesn't affect workloads that don't use `runtimeClassName: kata`.

## Verify Cleanup

```bash
# Check namespaces are gone
oc get ns | grep -E "agent-sandbox|mcp-test|adk-web"

# Check no orphaned resources
oc get agents --all-namespaces
oc get authpolicy --all-namespaces
oc get serviceentry --all-namespaces
```

## Cleanup Script

For convenience, here's a complete cleanup script:

```bash
#!/bin/bash
# cleanup.sh

echo "Cleaning up AI Agent Sandbox demo..."

# Currency demo
oc delete -f manifests/currency-demo/05-currency-agent.yaml --ignore-not-found
oc delete -f manifests/currency-demo/04-authpolicy.yaml --ignore-not-found
oc delete -f manifests/currency-demo/03-currency-httproute.yaml --ignore-not-found
oc delete -f manifests/currency-demo/02-currency-mcp-server.yaml --ignore-not-found
oc delete -f manifests/currency-demo/06-service-entry.yaml --ignore-not-found
oc delete -f manifests/currency-demo/01-namespaces.yaml --ignore-not-found

# ADK Web UI
oc delete -f manifests/adk-web/01-adk-server.yaml --ignore-not-found
oc delete -f manifests/adk-web/00-namespace.yaml --ignore-not-found

# Secrets
oc delete secret gemini-api-key -n agent-sandbox --ignore-not-found 2>/dev/null
oc delete secret gemini-api-key -n adk-web --ignore-not-found 2>/dev/null

echo "Cleanup complete!"
echo ""
echo "Note: KataConfig was NOT removed. Run this to remove it:"
echo "  oc delete -f manifests/currency-demo/00-kataconfig.yaml"
```

Save as `scripts/cleanup.sh` and run with:

```bash
chmod +x scripts/cleanup.sh
./scripts/cleanup.sh
```

