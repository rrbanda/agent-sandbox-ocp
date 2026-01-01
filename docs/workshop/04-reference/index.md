# Part 4: Reference

## Everything You Need, When You Need It

Stuck? Need details? This section has you covered.

---

## Quick Links

| Need | Go To |
|------|-------|
| Complete system diagrams | [Reference Architecture](../../architecture.md) |
| All YAML manifests explained | [Manifest Reference](manifest-reference.md) |
| Something not working? | [Troubleshooting](troubleshooting.md) |
| Done and cleaning up? | [Cleanup](cleanup.md) |

---

## Contents

| Document | Description |
|----------|-------------|
| [Reference Architecture](../../architecture.md) | Complete architecture diagrams and request flows—all in one place |
| [Manifest Reference](manifest-reference.md) | Complete guide to all YAML files—what they do, when to apply, in what order |
| [Troubleshooting](troubleshooting.md) | Common issues and how to fix them |
| [Cleanup](cleanup.md) | Remove all workshop resources from your cluster |

---

## Commands Cheat Sheet

### Check Status

```bash
# Agent status
oc get agent -n currency-kagenti

# Build status
oc get agentbuild -n currency-kagenti
oc get pipelineruns -n currency-kagenti

# Pod status
oc get pods -n currency-kagenti

# View logs
oc logs -n currency-kagenti deployment/currency-agent
```

### Get URLs

```bash
# Agent A2A URL
echo "https://$(oc get route currency-agent-a2a -n currency-kagenti -o jsonpath='{.spec.host}')"

# ADK Web UI URL
echo "https://$(oc get route adk-server -n adk-web -o jsonpath='{.spec.host}')/dev-ui/"
```

### Test the Agent

```bash
# Quick test (USD to EUR - should work)
curl -X POST "https://$(oc get route currency-agent-a2a -n currency-kagenti -o jsonpath='{.spec.host}')/" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"message/send","id":"1","params":{"message":{"messageId":"test-1","role":"user","parts":[{"text":"What is 100 USD in EUR?"}]}}}'

# Test blocked (USD to BTC - should return 403)
curl -X POST "https://$(oc get route currency-agent-a2a -n currency-kagenti -o jsonpath='{.spec.host}')/" \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"message/send","id":"2","params":{"message":{"messageId":"test-2","role":"user","parts":[{"text":"What is 100 USD in BTC?"}]}}}'
```

### Verify Security

```bash
# Check Kata runtime
oc get pod -n currency-kagenti -l app.kubernetes.io/name=currency-agent \
  -o jsonpath='{.items[0].spec.runtimeClassName}'
# Should output: kata

# Check egress policy
oc get serviceentry -n currency-kagenti

# Check OPA policy
oc get authpolicy -n currency-kagenti
```

---

## Manifests by Phase

| Phase | Files | Applied By |
|-------|-------|------------|
| **Platform Setup** | `platform/00-namespace.yaml`<br>`platform/00b-rbac-scc.yaml`<br>`platform/01-pipeline-template.yaml` | 👷 Admin |
| **Build** | `agent/02-mcp-server-build.yaml`<br>`agent/03-currency-agent-build.yaml` | 👩‍💻 Developer |
| **Deploy** | `agent/04-*.yaml`<br>`agent/05-currency-agent.yaml`<br>`agent/06-route.yaml` | 👩‍💻 Developer |
| **Security** | `security/01-service-entry.yaml`<br>`security/02-authpolicy.yaml` | 👷 Admin |

---

## Need Help?

- **Workshop Issues**: Check [Troubleshooting](troubleshooting.md)
- **Kagenti Documentation**: [github.com/kagenti/kagenti](https://github.com/kagenti/kagenti)
- **Google ADK Documentation**: [google.github.io/adk-docs](https://google.github.io/adk-docs)
