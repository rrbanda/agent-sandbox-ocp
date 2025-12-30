# Architecture

## Overview

The demo uses Kagenti's Agent CRD to deploy a Google ADK agent that runs inside a Kata micro-VM. The agent has built-in HTTP fetch capabilities that are subject to OPA policy enforcement.

```mermaid
flowchart TB
    subgraph User["User/DevOps"]
        Apply["oc apply -f agent.yaml"]
    end

    subgraph Kagenti["Kagenti Platform"]
        AgentCRD["Agent CR<br/>(spec.runtimeClassName: kata)"]
        Operator["Kagenti Operator"]
        MCPGateway["MCP Gateway"]
        Broker["MCP Broker"]
    end

    subgraph KataVM["Kata VM (Isolated Execution)"]
        AgentPod["Agent Pod<br/>(Google ADK with fetch_url tool)"]
        IstioSidecar["Istio Sidecar"]
    end

    subgraph Policy["Policy Enforcement"]
        Authorino["Authorino"]
        OPA["OPA Policy"]
    end

    subgraph External["External APIs"]
        Approved["✅ httpbin.org<br/>✅ api.weather.gov"]
        Blocked["❌ malicious.com"]
    end

    %% Deployment flow
    Apply -->|"1. apply"| AgentCRD
    AgentCRD -->|"2. reconcile"| Operator
    Operator -->|"3. create pod<br/>(runtimeClassName: kata)"| AgentPod

    %% Tool call flow
    AgentPod -->|"4. tools/call(fetch_url)"| MCPGateway
    MCPGateway -->|"5. authorize"| Authorino
    Authorino --> OPA
    OPA -->|"allow/deny"| Authorino
    Authorino -->|"6. decision"| MCPGateway
    MCPGateway -->|"7. if allowed"| Broker
    Broker -->|"8. execute"| AgentPod
    AgentPod -->|"9. fetch"| Approved

    %% Blocked paths
    AgentPod -.->|"blocked by OPA"| Blocked
    IstioSidecar -.->|"REGISTRY_ONLY blocks"| Blocked

    style KataVM fill:#e3f2fd,stroke:#1976d2,stroke-width:2px
    style Kagenti fill:#fff3e0,stroke:#ff9800
    style Policy fill:#fce4ec,stroke:#e91e63
    style Blocked fill:#ffebee,stroke:#f44336
    style Approved fill:#e8f5e9,stroke:#4caf50
```

## Request Flow

```mermaid
sequenceDiagram
    participant User
    participant CRD as Agent CR
    participant Operator as Kagenti Operator
    participant Kata as Kata Runtime
    participant Agent as Agent (Kata VM)
    participant Gateway as MCP Gateway
    participant Authorino
    participant OPA

    Note over User,OPA: 1. Agent Deployment via Kagenti CRD
    User->>CRD: oc apply -f agent.yaml
    CRD->>Operator: Watch/Reconcile
    Operator->>Kata: Create Pod with<br/>runtimeClassName: kata
    Kata->>Agent: Start agent in micro-VM

    Note over User,OPA: 2. Tool Call - BLOCKED by OPA
    Agent->>Gateway: tools/call("fetch_url",<br/>{"url": "https://malicious.com"})
    Gateway->>Authorino: Check authorization
    Authorino->>OPA: Evaluate Rego policy
    OPA->>OPA: url not in approved_url()
    OPA-->>Authorino: DENY
    Authorino-->>Gateway: 403 Forbidden
    Gateway-->>Agent: HTTP 403

    Note over User,OPA: 3. Tool Call - ALLOWED
    Agent->>Gateway: tools/call("fetch_url",<br/>{"url": "https://httpbin.org/get"})
    Gateway->>Authorino: Check authorization
    Authorino->>OPA: Evaluate Rego policy
    OPA-->>Authorino: ALLOW
    Authorino-->>Gateway: 200 OK
    Gateway-->>Agent: HTTP 200 (proceed to execute)
    Agent->>Agent: Execute fetch to httpbin.org
```

## What Each Layer Provides

```mermaid
flowchart LR
    subgraph Layer1["Layer 1: Kagenti + OPA"]
        direction TB
        L1A["Tool-level policy"]
        L1B["Argument inspection"]
        L1C["URL pattern matching"]
        L1D["IMDS protection"]
    end

    subgraph Layer2["Layer 2: Istio"]
        direction TB
        L2A["Network egress control"]
        L2B["REGISTRY_ONLY mode"]
        L2C["mTLS between pods"]
        L2D["ServiceEntry allowlist"]
    end

    subgraph Layer3["Layer 3: Kata"]
        direction TB
        L3A["VM isolation"]
        L3B["Separate kernel"]
        L3C["Host not visible"]
        L3D["Unix sockets isolated"]
    end

    Layer1 --> Layer2 --> Layer3

    style Layer1 fill:#fff3e0
    style Layer2 fill:#e3f2fd
    style Layer3 fill:#e8f5e9
```

## Kagenti Agent CRD with Kata

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: adk-kata-agent
  namespace: agent-sandbox
spec:
  server:
    name: simple-adk-agent
    endpoint: /mcp
  image: quay.io/rbrhssa/simple-adk-agent:latest
  podTemplateSpec:
    spec:
      runtimeClassName: kata    # ← VM isolation
      containers:
        - name: agent
          resources:
            limits:
              memory: "2Gi"     # ← Required for QEMU
              cpu: "1"
```

The `runtimeClassName: kata` in `podTemplateSpec.spec` tells Kubernetes to run this pod using the Kata runtime, which creates a micro-VM for the container.
