# Module 00: Prerequisites

**Duration**: 45-60 minutes (one-time setup)  
**Persona**: 👷 Platform Admin

## Overview

This module covers the **one-time cluster setup** required before running the workshop. These are infrastructure components that need to be installed once per cluster.

If these components are already installed, run the [verification check](#quick-check) and skip to [Module 01: Introduction](../01-introduction/index.md).

---

## What You'll Install

| Component | Purpose | What It Provides |
|-----------|---------|------------------|
| **OSC Operator** | VM isolation | `KataConfig` CRD for Kata runtime |
| **Kagenti** | AI Agent platform | Agent, AgentBuild, Tool CRDs + Pipeline infrastructure |
| **Istio** | Service mesh | Egress control for agents |
| **Kuadrant** | API policies | Authorization enforcement |

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Prerequisites (One-Time Setup)                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌──────────────────────────────────────────────────────────────────┐  │
│  │                      OpenShift Cluster                            │  │
│  │                                                                   │  │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐              │  │
│  │  │ OSC         │  │ Kagenti     │  │ Istio +     │              │  │
│  │  │ Operator    │  │ Platform    │  │ Kuadrant    │              │  │
│  │  │             │  │             │  │             │              │  │
│  │  │ Provides:   │  │ Provides:   │  │ Provides:   │              │  │
│  │  │ • KataConfig│  │ • Agent CRD │  │ • Egress    │              │  │
│  │  │   CRD       │  │ • AgentBuild│  │ • AuthPolicy│              │  │
│  │  │             │  │ • Pipelines │  │             │              │  │
│  │  └─────────────┘  └─────────────┘  └─────────────┘              │  │
│  │                                                                   │  │
│  └──────────────────────────────────────────────────────────────────┘  │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] OpenShift 4.14+ cluster with admin access
- [ ] `oc` CLI installed ([Download](https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/))
- [ ] `helm` CLI installed ([Install Helm](https://helm.sh/docs/intro/install/))
- [ ] Cluster admin credentials (`oc whoami` shows admin user)
- [ ] Access to OperatorHub (Red Hat registry connected)

---

## Steps

| Step | Description | Time |
|------|-------------|------|
| [01 - Install OSC](01-install-osc.md) | OpenShift Sandboxed Containers Operator | 10 min |
| [02 - Install Istio](02-install-istio.md) | Istio Service Mesh (via Kagenti deps) | 10 min |
| [03 - Install Kuadrant](03-install-kuadrant.md) | Kuadrant Operator (via Kagenti deps) | 10 min |
| [04 - Deploy Kagenti](04-deploy-kagenti.md) | Kagenti Platform via Helm | 20 min |
| [05 - Verify Setup](05-verify-setup.md) | Confirm all components are running | 5 min |

!!! note "Istio and Kuadrant via Kagenti"
    Steps 02-03 can be installed together using `helm install kagenti-deps`. See [Step 04](04-deploy-kagenti.md) for details.

---

## Quick Check

Run this command to check if prerequisites are already installed:

```bash
echo "=== Prerequisites Check ===" && \
echo "" && \
echo "1. OSC Operator:" && \
oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -E "sandboxed.*Succeeded" || echo "   Not installed" && \
echo "" && \
echo "2. Kagenti CRDs:" && \
oc get crd agents.agent.kagenti.dev 2>/dev/null && echo "   Agent CRD: ✓" || echo "   Agent CRD: Not found" && \
oc get crd agentbuilds.agent.kagenti.dev 2>/dev/null && echo "   AgentBuild CRD: ✓" || echo "   AgentBuild CRD: Not found" && \
echo "" && \
echo "3. Kagenti Controller:" && \
oc get pods -n kagenti-system 2>/dev/null | grep -E "kagenti-controller.*Running" || echo "   Not running" && \
echo "" && \
echo "4. Pipeline Steps:" && \
STEPS=$(oc get configmaps -n kagenti-system -l kagenti.operator.dev/tekton=step 2>/dev/null | grep -c step) && \
echo "   $STEPS step ConfigMaps found"
```

If all components show as installed, skip to [Module 01: Introduction](../01-introduction/index.md).

---

## What's the Difference?

| Module | Scope | Who Does It |
|--------|-------|-------------|
| **Module 00 (Prerequisites)** | Cluster-wide operators and platforms | Platform Admin (once) |
| **Module 02 (Platform Setup)** | Per-environment configuration (KataConfig, namespaces) | Platform Admin (per deployment) |
| **Module 03 (Develop Agent)** | Agent code and MCP servers | Developer |
| **Module 04 (Deploy & Test)** | AgentBuild and Agent CRs | Developer |

---

## Let's Begin

👉 [Step 01: Install OpenShift Sandboxed Containers](01-install-osc.md)
