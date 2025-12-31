# Module 06: Appendix

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
oc get pods -n currency-kagenti -l app.kubernetes.io/name=currency-agent

# View agent logs
oc logs -n currency-kagenti deployment/currency-agent -f

# Check AgentBuild status
oc get agentbuild -n currency-kagenti

# Check PipelineRuns
oc get pipelineruns -n currency-kagenti

# Verify Kata runtime
oc get pod -n currency-kagenti -l app.kubernetes.io/name=currency-agent \
  -o jsonpath='{.items[0].spec.runtimeClassName}'

# Check egress rules
oc get serviceentry -n currency-kagenti

# Check policy
oc get authpolicy -n currency-kagenti
```

### Key Resources

| Resource | Namespace | Purpose |
|----------|-----------|---------|
| `AgentBuild/currency-agent-build` | currency-kagenti | Build agent image |
| `AgentBuild/currency-mcp-server-build` | currency-kagenti | Build MCP server image |
| `Agent/currency-agent` | currency-kagenti | The AI agent |
| `Deployment/currency-mcp-server` | currency-kagenti | Currency tool server |
| `ServiceEntry` | currency-kagenti | Egress allowlist |
| `AuthPolicy` | currency-kagenti | OPA policy blocking crypto |
| `KataConfig` | (cluster-scoped) | VM runtime config |

### Links

- [Kagenti Documentation](https://github.com/kagenti/kagenti)
- [Google ADK Documentation](https://github.com/google/adk-python)
- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kuadrant](https://kuadrant.io/)
- [Model Context Protocol](https://modelcontextprotocol.io/)
- [Agent2Agent Protocol](https://github.com/google/A2A)

---

## Workshop Summary

You've completed a comprehensive workshop covering:

| Module | What You Learned |
|--------|------------------|
| **00: Prerequisites** | Installing OSC, Kagenti, Istio, Kuadrant |
| **01: Introduction** | AI agent security model and threats |
| **02: Platform Setup** | KataConfig, namespaces, pipelines |
| **03: Develop Agent** | Google ADK, agent code, MCP servers |
| **04: Deploy & Test** | AgentBuild, Agent CR, Kata verification |
| **05: Security Hardening** | Egress control, OPA policies |

---

## The Complete Security Model

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Defense in Depth                                      │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Layer 3: Tool Policy (OPA via Kuadrant)                               │
│  ─────────────────────────────────────────────────────────────────      │
│  • Block specific tool operations                                       │
│  • Inspect request parameters                                           │
│  • Audit all decisions                                                  │
│                                                                         │
│  Layer 2: Network Egress (Istio ServiceEntry)                          │
│  ─────────────────────────────────────────────────────────────────      │
│  • Allowlist external APIs                                              │
│  • Block data exfiltration                                              │
│  • Namespace-scoped rules                                               │
│                                                                         │
│  Layer 1: VM Isolation (Kata Containers)                               │
│  ─────────────────────────────────────────────────────────────────      │
│  • Hardware-level isolation                                             │
│  • Separate kernel per pod                                              │
│  • Protected from container escapes                                     │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```
