# What to Know About Kuadrant and OPA Policy

---

## 1. What Kuadrant Is

**Kuadrant** is a Kubernetes-native API management solution that provides:

- **Authentication** (AuthN)
- **Authorization** (AuthZ)
- **Rate limiting**
- **DNS management**

In this workshop, we use Kuadrant's **AuthPolicy** with **OPA (Open Policy Agent)** to enforce tool-level policies.

**Key idea**

> Kuadrant + OPA validates every tool call before it reaches the MCP server.

---

## 2. What OPA Is

**OPA (Open Policy Agent)** is a general-purpose policy engine that:

- Evaluates policies written in **Rego** (a declarative language)
- Returns allow/deny decisions
- Is CNCF-graduated and widely adopted

OPA answers the question: **"Is this action allowed?"**

---

## 3. Why Policy Enforcement Matters for AI Agents

AI agents make decisions at runtime. These decisions are:

- **Non-deterministic** - LLMs don't always produce the same output
- **Influenced by prompts** - Including potentially malicious ones
- **Capable of calling tools** - With real-world consequences

Policy enforcement provides a **deterministic checkpoint**:

```
User Prompt → LLM Decision → Tool Call → [Policy Check] → Execution
```

Even if the LLM is tricked, the policy engine can block the action.

---

## 4. How Kuadrant AuthPolicy Works

### Architecture

```
Agent Pod → MCP Gateway → Authorino → OPA → MCP Server
                ↑
           AuthPolicy CR
```

1. **AuthPolicy** defines rules as a Kubernetes Custom Resource
2. **Authorino** (Kuadrant's auth engine) evaluates requests
3. **OPA** can be used for complex policy logic
4. Requests are allowed or denied before reaching the backend

### Basic AuthPolicy Structure

```yaml
apiVersion: kuadrant.io/v1
kind: AuthPolicy
metadata:
  name: currency-mcp-policy
  namespace: agent-sandbox
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: currency-mcp-route
  
  rules:
    authorization:
      opa-policy:
        rego: |
          # Policy logic here
          allow = true { ... }
```

---

## 5. Writing Rego Policies

Rego is a declarative policy language. Here's a simple example:

### Allow Only Fiat Currencies

```rego
package currency

default allow = false

# List of allowed currencies (fiat only)
allowed_currencies = {"USD", "EUR", "GBP", "JPY", "CAD", "AUD", "CHF"}

# Allow if both currencies are in the allowed list
allow {
    input.from_currency in allowed_currencies
    input.to_currency in allowed_currencies
}
```

### Deny Cryptocurrency

```rego
# Explicitly deny crypto
blocked_currencies = {"BTC", "ETH", "DOGE", "XRP", "SOL"}

deny {
    input.from_currency in blocked_currencies
}

deny {
    input.to_currency in blocked_currencies
}
```

---

## 6. What Gets Validated

In the Currency Agent example, the policy validates the **tool call arguments**:

| Request | Validation | Result |
|---------|------------|--------|
| `get_exchange_rate(USD, EUR)` | Both in allowed list | ✅ Allow |
| `get_exchange_rate(USD, BTC)` | BTC is blocked | ❌ Deny |
| `get_exchange_rate(ETH, USD)` | ETH is blocked | ❌ Deny |

The policy runs **before** the MCP server executes the tool.

---

## 7. Where Policy Lives

### Option 1: Inline in AuthPolicy

```yaml
spec:
  rules:
    authorization:
      opa-policy:
        rego: |
          package currency
          default allow = false
          # ... policy logic ...
```

### Option 2: External OPA Server

```yaml
spec:
  rules:
    authorization:
      external-opa:
        url: http://opa-server:8181/v1/data/currency/allow
```

### Option 3: ConfigMap Reference

```yaml
spec:
  rules:
    authorization:
      opa-policy:
        externalPolicy:
          configMapRef:
            name: currency-policy
            key: policy.rego
```

---

## 8. Policy Scope and Targeting

AuthPolicy uses `targetRef` to specify what it protects:

```yaml
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute           # or Gateway
    name: currency-mcp-route
```

This means:

- The policy only applies to requests matching this HTTPRoute
- Other routes are unaffected
- You can have different policies for different tools

---

## 9. Kuadrant vs Other Solutions

| Aspect | Kuadrant AuthPolicy | Kubernetes RBAC | Custom Middleware |
|--------|---------------------|-----------------|-------------------|
| Scope | API/route level | Resource level | Application level |
| Granularity | Request content | Verb + resource | Custom |
| Kubernetes-native | Yes (CRD) | Yes | No |
| Policy language | Rego/OPA | None | Custom |
| Hot-reload | Yes | Yes | Depends |

---

## 10. Relevance to AI Agents

Policy enforcement is the **innermost defense layer**:

| Layer | What It Stops |
|-------|---------------|
| Kata (VM) | Container escapes |
| Istio (Network) | Data exfiltration |
| **OPA (Policy)** | Invalid tool arguments |

Even if an agent can reach the MCP server, it cannot:

- Call tools with blocked parameters
- Bypass business logic rules
- Execute unauthorized operations

---

## 11. A Defensible Technical Statement

> Kuadrant AuthPolicy with OPA provides fine-grained, declarative policy enforcement for AI agent tool calls. By validating request content against Rego policies before execution, we prevent unauthorized operations even when the LLM makes unexpected decisions.

---

## 12. Key Takeaway

> **OPA doesn't trust the LLM's decision - it validates every tool call against explicit rules.**

---

## References

* [Kuadrant Documentation](https://docs.kuadrant.io/)
* [OPA Documentation](https://www.openpolicyagent.org/docs/latest/)
* [Rego Language Reference](https://www.openpolicyagent.org/docs/latest/policy-language/)
* [Authorino (Kuadrant Auth Engine)](https://github.com/Kuadrant/authorino)

