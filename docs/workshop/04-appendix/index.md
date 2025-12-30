# Module 04: Appendix

Reference materials for troubleshooting, cleanup, and next steps.

## Contents

| Document | Description |
|----------|-------------|
| [Troubleshooting](troubleshooting.md) | Common issues and solutions |
| [Cleanup](cleanup.md) | Remove demo resources |
| [Next Steps](next-steps.md) | Where to go from here |

## Quick Reference

### Useful Commands

```bash
# Check agent status
oc get pods -n agent-sandbox -l app=currency-agent

# View agent logs
oc logs -n agent-sandbox -l app=currency-agent -f

# Check policy
oc get authpolicy -n mcp-test

# Verify Kata runtime
oc get pod -n agent-sandbox -l app=currency-agent -o jsonpath='{.items[0].spec.runtimeClassName}'

# Check egress rules
oc get serviceentry -n agent-sandbox
```

### Key Resources

| Resource | Namespace | Purpose |
|----------|-----------|---------|
| `Agent/currency-agent` | agent-sandbox | The AI agent |
| `AuthPolicy` | mcp-test | OPA policy blocking crypto |
| `ServiceEntry` | agent-sandbox | Egress allowlist |
| `KataConfig` | (cluster-scoped) | VM runtime config |

### Links

- [Kagenti Documentation](https://github.com/kagenti/kagenti)
- [Google ADK Documentation](https://github.com/google/adk-python)
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant](https://kuadrant.io/)

