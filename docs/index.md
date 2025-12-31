# Securing Code First Agents on OpenShift

## The Challenge

You've built an AI agent. It's powerful, capable, and ready to transform how your organization works.

But here's the uncomfortable truth: **that same power makes it a security risk**.

Agents don't just answer questions—they take actions. They call APIs. They execute code. They make decisions. And without proper guardrails, they can be manipulated to do things you never intended.

---

## The Solution

This workshop teaches you how to deploy AI agents securely using **defense in depth**—three independent protection layers that work even if one fails:

| Layer | Technology | Protection |
|-------|------------|------------|
| **1. VM Isolation** | Kata Containers | Even if compromised, agent can't escape its VM |
| **2. Network Egress** | Istio ServiceEntry | Agent can only reach APIs you approve |
| **3. Tool Policy** | Kuadrant + OPA | Every action is validated before execution |

---

## The Workshop

A structured, hands-on experience that takes you from "I hope it's secure" to "I can prove it."

| Part | What You'll Do | Time |
|------|----------------|------|
| [**Part 1: Foundations**](workshop/01-foundations/index.md) | Understand why agents need special security | 30 min |
| [**Part 2: Inner Loop**](workshop/02-inner-loop/index.md) | Build and test your Currency Agent | 30 min |
| [**Part 3: Outer Loop**](workshop/03-outer-loop/index.md) | Deploy with all three security layers | 60 min |
| [**Part 4: Reference**](workshop/04-reference/index.md) | Manifests, troubleshooting, cleanup | As needed |

**Total Duration:** ~2 hours

---

## Who This Is For

| Role | What You'll Learn |
|------|-------------------|
| **Agent Developer** | Build agents with Google ADK, deploy with security built-in |
| **Platform Admin** | Configure secure namespaces, apply defense-in-depth policies |

---

## What You'll Build

A **Currency Conversion Agent** that demonstrates all three security layers:

| Allowed | Blocked |
|---------|---------|
|  Convert USD → EUR |  Convert USD → BTC |
|  Call api.frankfurter.app |  Call any other API |
|  Run normally |  Escape its VM |

You'll see security working—not just configured, but actually stopping unauthorized actions.

---

## Prerequisites

- OpenShift 4.14+ cluster
- Kagenti, Kuadrant, and OSC operators installed
- ADK Web UI deployed on cluster
- Gemini API key

---

## Ready?

👉 **[Start the Workshop](workshop/index.md)**
