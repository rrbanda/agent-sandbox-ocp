# Concepts

This section explains the key technologies and concepts used in this workshop. Read these to understand **why** each component exists and **how** they work together.

---

## 1. The Problem & Solution

Start here to understand the security challenges and approach.

| Concept | Description |
|---------|-------------|
| [Threat Model](threat-model.md) | Why AI agents need special security considerations |
| [Defense in Depth](defense-in-depth.md) | The three-layer protection model |

---

## 2. Building Agents

Understand the development framework and workflow.

| Concept | Description |
|---------|-------------|
| [Google ADK](google-adk.md) | Agent Development Kit - the framework for building AI agents |
| [Inner & Outer Loop](inner-outer-loop.md) | Developer experience from local development to production |

---

## 3. Deploying Agents

Understand the platform that runs your agents.

| Concept | Description |
|---------|-------------|
| [Kagenti Platform](kagenti-platform.md) | The MCP Gateway for deploying and managing AI agents on Kubernetes |

---

## 4. Security Layers (Deep Dive)

Detailed explanations of each security layer.

| Layer | Concept | Description |
|-------|---------|-------------|
| **1** | [OSC & Kata Containers](osc-explained.md) | VM-based isolation - agents run in lightweight VMs |
| **2** | [Istio Egress Control](istio-egress.md) | Network control - restrict external API access |
| **3** | [Kuadrant & OPA](kuadrant-opa.md) | Policy enforcement - validate tool calls |

---

## Recommended Reading Order

For workshop participants, read in this order:

| # | Document | Why |
|---|----------|-----|
| 1 | [Threat Model](threat-model.md) | Understand the problem |
| 2 | [Defense in Depth](defense-in-depth.md) | Understand the solution approach |
| 3 | [Google ADK](google-adk.md) | Know what you're building |
| 4 | [Inner & Outer Loop](inner-outer-loop.md) | Understand the dev workflow |
| 5 | [Kagenti Platform](kagenti-platform.md) | Know the deployment platform |
| 6 | [OSC & Kata](osc-explained.md) | Layer 1 deep dive |
| 7 | [Istio Egress](istio-egress.md) | Layer 2 deep dive |
| 8 | [Kuadrant & OPA](kuadrant-opa.md) | Layer 3 deep dive |

---

## Quick Reference

| If you want to know... | Read |
|------------------------|------|
| Why AI agents are risky | [Threat Model](threat-model.md) |
| What the three layers are | [Defense in Depth](defense-in-depth.md) |
| How to build an agent | [Google ADK](google-adk.md) |
| How local vs production differs | [Inner & Outer Loop](inner-outer-loop.md) |
| What Kagenti does | [Kagenti Platform](kagenti-platform.md) |
| How VM isolation works | [OSC & Kata](osc-explained.md) |
| How network egress is controlled | [Istio Egress](istio-egress.md) |
| How tool policies work | [Kuadrant & OPA](kuadrant-opa.md) |
