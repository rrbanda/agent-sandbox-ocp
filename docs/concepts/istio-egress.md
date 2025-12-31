# What to Know About Istio Egress Control

---

## 1. What Istio Is (and What It Is Not)

**Istio** is an open-source **service mesh** that provides traffic management, security, and observability for Kubernetes workloads.

In this workshop, we use a specific Istio capability: **egress control**.

**Key idea**

> Istio egress control determines what external APIs your workloads can reach.

---

## 2. Why Egress Control Matters for AI Agents

AI agents often need to call external APIs:

- Currency exchange rates
- Weather services
- Search APIs
- Tool backends

Without egress control, a compromised or prompt-injected agent could:

- **Exfiltrate data** to attacker-controlled servers
- **Call unauthorized APIs** to perform unintended actions
- **Establish reverse shells** to external hosts

Egress control is your **network-level defense**.

---

## 3. How Istio Egress Works

### Default Behavior: ALLOW_ANY

By default, Istio allows all outbound traffic. Pods can reach any external host.

### Locked-Down Mode: REGISTRY_ONLY

When set to `REGISTRY_ONLY`, Istio **blocks all external traffic** except what you explicitly allow via `ServiceEntry` resources.

```yaml
# In Istio ConfigMap
outboundTrafficPolicy:
  mode: REGISTRY_ONLY
```

### ServiceEntry: The Allowlist

A `ServiceEntry` tells Istio "this external host is allowed":

```yaml
apiVersion: networking.istio.io/v1beta1
kind: ServiceEntry
metadata:
  name: allow-frankfurter-api
  namespace: agent-sandbox
spec:
  hosts:
    - api.frankfurter.app
  ports:
    - number: 443
      name: https
      protocol: HTTPS
  resolution: DNS
  location: MESH_EXTERNAL
```

---

## 4. What ServiceEntry Controls

| Field | Purpose |
|-------|---------|
| `hosts` | External hostnames allowed (e.g., `api.frankfurter.app`) |
| `ports` | Allowed ports and protocols |
| `resolution` | How to resolve the host (`DNS`, `STATIC`, `NONE`) |
| `location` | `MESH_EXTERNAL` for external services |

### Multiple Hosts

You can allow multiple hosts in one ServiceEntry:

```yaml
spec:
  hosts:
    - api.frankfurter.app
    - api.exchangerate.host
```

Or create separate ServiceEntries for different services.

---

## 5. Namespace Scoping

ServiceEntry resources are **namespace-scoped** by default in OpenShift Service Mesh.

This means:

- A ServiceEntry in `agent-sandbox` only affects pods in that namespace
- Other namespaces remain unaffected
- Each team can have different egress policies

This is critical for **multi-tenant** environments.

---

## 6. What Happens When Traffic Is Blocked

When a pod tries to reach a host not in a ServiceEntry:

1. The Istio sidecar intercepts the request
2. No matching ServiceEntry is found
3. The request is **dropped** (connection refused or timeout)
4. Istio logs the blocked attempt

```bash
# Check sidecar logs for blocked traffic
oc logs -n agent-sandbox <pod-name> -c istio-proxy
```

---

## 7. Relevance to AI Agents

In the Currency Agent example:

| Action | Result |
|--------|--------|
| Agent calls `api.frankfurter.app` |  Allowed by ServiceEntry |
| Prompt injection tries `evil.com/exfiltrate` |  Blocked - no ServiceEntry |
| Agent tries `crypto-api.com` for BTC rates |  Blocked - not in allowlist |

Even if OPA policy fails, the network layer provides defense in depth.

---

## 8. Istio vs NetworkPolicy

| Aspect | Istio ServiceEntry | Kubernetes NetworkPolicy |
|--------|-------------------|-------------------------|
| Scope | External (egress to internet) | Internal (pod-to-pod) |
| Granularity | Hostname-based | IP/CIDR-based |
| Protocol awareness | Full L7 (HTTP, gRPC) | L3/L4 only |
| Requires sidecar | Yes | No |

**Use both**: NetworkPolicy for internal traffic, Istio for external.

---

## 9. Common Patterns

### Pattern 1: Deny All, Allow Specific

```yaml
# Default: REGISTRY_ONLY blocks everything
# Then add ServiceEntries for each allowed API
```

### Pattern 2: Allow by Namespace

```yaml
# Create ServiceEntries per namespace
# Each namespace has its own allowlist
```

### Pattern 3: Shared Services

```yaml
# Export ServiceEntries to other namespaces
spec:
  exportTo:
    - "."          # This namespace only
    - "*"          # All namespaces
    - "other-ns"   # Specific namespace
```

---

## 10. A Defensible Technical Statement

> Istio egress control with ServiceEntry resources provides network-level defense by restricting AI agents to explicitly allowed external APIs. Combined with REGISTRY_ONLY mode, this prevents data exfiltration and unauthorized API access even if application-level controls fail.

---

## 11. Key Takeaway

> **If the agent doesn't have network access to an external host, it cannot exfiltrate data there.**

---

## References

* [Istio ServiceEntry Documentation](https://istio.io/latest/docs/reference/config/networking/service-entry/)
* [Istio Egress Traffic Control](https://istio.io/latest/docs/tasks/traffic-management/egress/)
* [OpenShift Service Mesh](https://docs.openshift.com/container-platform/latest/service_mesh/v2x/ossm-about.html)

