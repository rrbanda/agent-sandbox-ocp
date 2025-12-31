# Next Steps

Congratulations on completing the workshop! Here's where to go from here.

## Extend the Demo

### Add More Currencies to Block List

Modify the OPA policy to block additional currencies:

```bash
oc edit authpolicy currency-tool-policy -n mcp-test
```

Add currencies to the blocked list:
```rego
deny if {
  input.context.request.http.body.params.arguments.currency_to in [
    "BTC", "ETH", "DOGE", "XRP", "SOL",
    "USDT", "USDC"  # Add stablecoins
  ]
}
```

### Add More Tools

Extend the Currency Agent with additional tools:

```python
def get_historical_rate(currency_from: str, currency_to: str, date: str) -> dict:
    """Get historical exchange rate for a specific date."""
    url = f"https://api.frankfurter.app/{date}?from={currency_from}&to={currency_to}"
    # ...
```

### Create a New Agent

Build a different agent using the same security patterns:

1. Create agent code following ADK patterns
2. Deploy with `runtimeClassName: kata`
3. Configure egress for your APIs
4. Define tool policies

---

## Production Considerations

### High Availability

```yaml
spec:
  replicas: 3  # Multiple replicas
  podTemplateSpec:
    spec:
      affinity:
        podAntiAffinity:  # Spread across nodes
```

### Resource Limits

```yaml
containers:
  - name: agent
    resources:
      requests:
        memory: "256Mi"
        cpu: "100m"
      limits:
        memory: "1Gi"
        cpu: "500m"
```

### Monitoring

- Enable Phoenix for LLM observability
- Configure Prometheus metrics
- Set up alerts for policy violations

### Secrets Management

- Use external secrets operator
- Rotate API keys regularly
- Audit secret access

---

## Learn More

### Kagenti Platform

- [Kagenti GitHub](https://github.com/kagenti/kagenti)
- [Kagenti Operator](https://github.com/kagenti/kagenti-operator)
- [Personas and Roles](https://github.com/kagenti/kagenti/blob/main/PERSONAS_AND_ROLES.md)

### Google ADK

- [ADK Python](https://github.com/google/adk-python)
- [ADK Documentation](https://google.github.io/adk-docs/)
- [ADK Web UI](https://github.com/google/adk-web)

### OpenShift Security

- [OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/index.html)
- [Kata Containers](https://katacontainers.io/)
- [Kuadrant](https://kuadrant.io/)

### AI Agent Security

- [OWASP LLM Top 10](https://owasp.org/www-project-top-10-for-large-language-model-applications/)
- [Agent Security Best Practices](https://cloud.google.com/blog/topics/developers-practitioners/securing-ai-agents)

---

## Community

### Get Involved

- ⭐ Star the repo: [agent-sandbox-ocp](https://github.com/rrbanda/agent-sandbox-ocp)
- 🐛 Report issues: [GitHub Issues](https://github.com/rrbanda/agent-sandbox-ocp/issues)
- 💬 Join discussions: [Kagenti Discussions](https://github.com/kagenti/kagenti/discussions)

### Contribute

We welcome contributions:

- Additional agent examples
- More security policies
- Documentation improvements
- Bug fixes

---

## Feedback

We'd love to hear how the workshop went!

- What worked well?
- What was confusing?
- What would you add?

Open an issue or discussion on GitHub with your feedback.

---

## Thank You! 🙏

Thank you for completing the **AI Agent Sandbox on OpenShift** workshop.

You now have the knowledge to:

 Build AI agents with Google ADK  
 Deploy agents securely on OpenShift  
 Implement defense-in-depth with VM isolation, network control, and policies  
 Test and verify security controls  

Go build something amazing! 🚀

