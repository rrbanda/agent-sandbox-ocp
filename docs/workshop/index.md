# AI Agent Sandbox on OpenShift

A hands-on workshop for securing AI agents with VM isolation, network control, and policy enforcement.

**Duration**: ~2.5 hours  
**Level**: Intermediate

## What You'll Build

A **Currency Conversion Agent** that:

- ✅ Converts between fiat currencies (USD, EUR, GBP, JPY)
- ❌ Is blocked from cryptocurrency conversions (BTC, ETH, DOGE)
- 🔒 Runs in an isolated VM (Kata Containers)
- 🌐 Can only reach approved external APIs

## The Three Layers of Protection

```mermaid
flowchart LR
    subgraph L1["Layer 1: VM Isolation"]
        A["Kata Containers"]
    end
    subgraph L2["Layer 2: Network"]
        B["Istio Egress"]
    end
    subgraph L3["Layer 3: Policy"]
        C["OPA Rules"]
    end
    
    L1 --> L2 --> L3
```

| Layer | Technology | What It Protects Against |
|-------|------------|--------------------------|
| **1. VM Isolation** | OpenShift Sandboxed Containers | Container escapes, kernel exploits |
| **2. Network Egress** | Istio ServiceEntry | Data exfiltration, unauthorized APIs |
| **3. Tool Policy** | Kuadrant + OPA | Unauthorized tool usage, crypto conversion |

---

## Workshop Flow

```mermaid
flowchart LR
    A["00<br/>Prerequisites"] --> B["01<br/>Introduction"]
    B --> C["02<br/>Platform Setup"]
    C --> D["03<br/>Agent Dev"]
    D --> E["04<br/>Deploy & Test"]
    E --> F["05<br/>Appendix"]
```

---

## Modules

### [Module 00: Prerequisites](00-prerequisites/index.md)
**👷 Platform Admin** • 45-60 minutes (one-time)

Install the required platform components:

- OpenShift Sandboxed Containers Operator
- Istio Service Mesh
- Kuadrant Operator
- Kagenti Platform (via Helm)

> ⏭️ **Skip if already installed** - Run the verification script to check.

---

### [Module 01: Introduction](01-introduction/index.md)
**👥 Everyone** • 15 minutes

Understand the security challenges with AI agents and the three-layer defense model.

- Why AI agents need special security
- The Currency Agent demo scenario
- Workshop overview

---

### [Module 02: Platform Setup](02-platform-setup/index.md)
**👷 Platform Admin performs** • 30 minutes  
**👩‍💻 Developer reads** (to understand the security context)

Configure the agent namespace:

- Apply KataConfig to enable VM runtime
- Create secure namespace with Istio labels
- Configure egress controls (ServiceEntry)
- Deploy OPA policies (AuthPolicy)

> 💡 **Developers**: Read through to understand what policies protect your agent.

---

### [Module 03: Agent Development](03-agent-developer/index.md)
**👩‍💻 Developer performs** • 30 minutes  
**👷 Platform Admin reads** (to understand developer needs)

Build and test the Currency Agent locally:

- Understand the agent code (Google ADK)
- Run locally with `adk web`
- Test in the ADK Web UI
- Prepare for containerization

> 💡 **Platform Admins**: Understanding how developers build agents helps you configure better policies.

---

### [Module 04: Deploy & Test](04-deploy-and-test/index.md)
**👥 Both personas** • 30 minutes

Deploy the agent to OpenShift and verify all security layers:

- Deploy the Agent CR
- Verify VM isolation (Kata)
- Test allowed requests (USD → EUR)
- Test blocked requests (USD → BTC)
- Observe traces and logs

---

### [Module 05: Appendix](05-appendix/index.md)
**📚 Reference**

- Troubleshooting common issues
- Cleanup instructions
- Next steps and resources

---

## Who Should Do What?

| Your Role | Mod 00 | Mod 01 | Mod 02 | Mod 03 | Mod 04 | Mod 05 |
|-----------|--------|--------|--------|--------|--------|--------|
| **Solo Learner** | ✅ Do | ✅ Do | ✅ Do | ✅ Do | ✅ Do | Ref |
| **Platform Admin** | ✅ Do | ✅ Do | ✅ Do | 📖 Read | ✅ Do | Ref |
| **Agent Developer** | ⏭️ Skip | ✅ Do | 📖 Read | ✅ Do | ✅ Do | Ref |

---

## Let's Get Started

👉 [Start with Module 00: Prerequisites](00-prerequisites/index.md)

Or if prerequisites are already installed:

👉 [Start with Module 01: Introduction](01-introduction/index.md)
