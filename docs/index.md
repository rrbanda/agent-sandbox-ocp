# AI Agent Sandbox on OpenShift

A hands-on workshop for securing AI agents with VM isolation, network control, and policy enforcement.

## What is This?

This workshop teaches you how to deploy AI agents securely on OpenShift using **defense in depth**:

| Layer | Technology | Protection |
|-------|------------|------------|
| **1. VM Isolation** | Kata Containers | Agent runs in hardware-isolated VM |
| **2. Network Egress** | Istio ServiceEntry | Controls external API access |
| **3. Tool Policy** | Kuadrant + OPA | Validates tool calls before execution |

## Quick Start

### Option 1: Full Workshop

Follow the structured workshop modules:

1. [Introduction](workshop/00-introduction/index.md) - Understand the architecture
2. [Platform Setup](workshop/01-platform-admin/index.md) - Configure OpenShift (Platform Admin)
3. [Agent Development](workshop/02-agent-developer/index.md) - Build with Google ADK (Developer)
4. [Deploy & Test](workshop/03-deploy-and-test/index.md) - Verify security layers

### Option 2: Quick Deploy

```bash
# Clone the repo
git clone https://github.com/rrbanda/agent-sandbox-ocp.git
cd agent-sandbox-ocp

# Apply all manifests
oc apply -f manifests/currency-demo/

# Deploy ADK Web UI
./scripts/deploy-adk-web.sh
```

## The Demo

**Currency Agent**: Converts currencies but blocks cryptocurrency.

- ✅ "What is 100 USD in EUR?" → Works
- ❌ "What is 100 USD in BTC?" → Blocked by policy

## Architecture

```mermaid
flowchart LR
    subgraph L1["Layer 1: VM Isolation"]
        subgraph L2["Layer 2: Network"]
            subgraph L3["Layer 3: Policy"]
                A["Currency Agent"]
            end
        end
    end
```

## Target Audience

| Persona | What You'll Learn |
|---------|-------------------|
| **Platform Admin** | Configure secure agent namespaces |
| **Agent Developer** | Build and deploy agents with Google ADK |

## Prerequisites

- OpenShift 4.14+ cluster
- Kagenti, Kuadrant, and OSC operators installed
- Python 3.11+ (for local development)
- Gemini API key

## Get Started

👉 [Start the Workshop](workshop/index.md)

