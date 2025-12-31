# Part 4: Reference

This section provides reference documentation for the workshop.

## Contents

| Document | Description |
|----------|-------------|
| [Manifest Reference](manifest-reference.md) | Complete guide to all YAML files |
| [Troubleshooting](troubleshooting.md) | Common issues and solutions |
| [Cleanup](cleanup.md) | Remove workshop resources |

## Quick Links

### Manifests by Phase

| Phase | Files |
|-------|-------|
| **Platform Setup** | `platform/00-namespace.yaml`, `00b-rbac-scc.yaml`, `01-pipeline-template.yaml` |
| **Build** | `agent/02-mcp-server-build.yaml`, `03-currency-agent-build.yaml` |
| **Deploy** | `agent/04-*.yaml`, `05-currency-agent.yaml`, `06-route.yaml` |
| **Security** | `security/01-service-entry.yaml`, `02-authpolicy.yaml` |

### Commands Cheat Sheet

```bash
# Check agent status
oc get agent -n currency-kagenti

# Check build status
oc get agentbuild -n currency-kagenti
oc get pipelineruns -n currency-kagenti

# View agent logs
oc logs -n currency-kagenti deployment/currency-agent

# Get agent URL
oc get route currency-agent -n currency-kagenti

# Test agent
curl -X POST "https://$(oc get route currency-agent -n currency-kagenti -o jsonpath='{.spec.host}')" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"message/send","id":"1","params":{"message":{"role":"user","parts":[{"text":"100 USD to EUR"}]}}}'
```

