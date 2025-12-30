# Architecture

## Overview

The demo uses Kagenti's Agent CRD to deploy a Currency Agent that runs inside a Kata micro-VM. The agent uses an MCP server to get exchange rates, with OPA policy enforcement blocking cryptocurrency conversions.

```mermaid
flowchart TB
    subgraph User["User/DevOps"]
        Apply["oc apply -f 05-currency-agent.yaml"]
    end

    subgraph Kagenti["Kagenti Platform"]
        AgentCRD["Agent CR<br/>(spec.runtimeClassName: kata)"]
        Operator["Kagenti Operator"]
        MCPGateway["MCP Gateway"]
    end

    subgraph KataVM["Kata VM (Isolated Execution)"]
        AgentPod["Currency Agent<br/>(Google ADK)"]
        IstioSidecar["Istio Sidecar"]
    end

    subgraph MCPServer["MCP Server"]
        CurrencyMCP["currency-mcp-server<br/>(get_exchange_rate tool)"]
    end

    subgraph Policy["Policy Enforcement"]
        Authorino["Authorino"]
        OPA["OPA Policy"]
    end

    subgraph External["External APIs"]
        Approved["✅ api.frankfurter.app<br/>✅ USD, EUR, GBP, JPY"]
        Blocked["❌ BTC, ETH, DOGE"]
    end

    %% Deployment flow
    Apply -->|"1. apply"| AgentCRD
    AgentCRD -->|"2. reconcile"| Operator
    Operator -->|"3. create pod<br/>(runtimeClassName: kata)"| AgentPod

    %% Tool call flow
    AgentPod -->|"4. tools/call(get_exchange_rate)"| MCPGateway
    MCPGateway -->|"5. authorize"| Authorino
    Authorino --> OPA
    OPA -->|"allow/deny"| Authorino
    Authorino -->|"6. decision"| MCPGateway
    MCPGateway -->|"7. if allowed"| CurrencyMCP
    CurrencyMCP -->|"8. get rate"| Approved

    %% Blocked paths
    MCPGateway -.->|"blocked by OPA"| Blocked
    IstioSidecar -.->|"REGISTRY_ONLY blocks"| Blocked

    style KataVM fill:#CC0000,color:#FFFFFF,stroke:#820000,stroke-width:2px
    style Kagenti fill:#A30000,color:#FFFFFF,stroke:#820000
    style Policy fill:#820000,color:#FFFFFF,stroke:#6A0000
    style Blocked fill:#4A4A4A,color:#FFFFFF,stroke:#2A2A2A
    style Approved fill:#6A6A6A,color:#FFFFFF,stroke:#4A4A4A
```

## Request Flow

```mermaid
sequenceDiagram
    participant User
    participant CRD as Agent CR
    participant Operator as Kagenti Operator
    participant Kata as Kata Runtime
    participant Agent as Currency Agent (Kata VM)
    participant Gateway as MCP Gateway
    participant Authorino
    participant OPA
    participant MCP as Currency MCP Server

    Note over User,MCP: 1. Agent Deployment via Kagenti CRD
    User->>CRD: oc apply -f 05-currency-agent.yaml
    CRD->>Operator: Watch/Reconcile
    Operator->>Kata: Create Pod with<br/>runtimeClassName: kata
    Kata->>Agent: Start agent in micro-VM

    Note over User,MCP: 2. Tool Call - BLOCKED by OPA (Crypto)
    Agent->>Gateway: tools/call("get_exchange_rate",<br/>{"currency_from": "USD", "currency_to": "BTC"})
    Gateway->>Authorino: Check authorization
    Authorino->>OPA: Evaluate Rego policy
    OPA->>OPA: BTC not in approved currencies
    OPA-->>Authorino: DENY
    Authorino-->>Gateway: 403 Forbidden
    Gateway-->>Agent: HTTP 403

    Note over User,MCP: 3. Tool Call - ALLOWED (Fiat)
    Agent->>Gateway: tools/call("get_exchange_rate",<br/>{"currency_from": "USD", "currency_to": "EUR"})
    Gateway->>Authorino: Check authorization
    Authorino->>OPA: Evaluate Rego policy
    OPA-->>Authorino: ALLOW
    Authorino-->>Gateway: 200 OK
    Gateway->>MCP: Forward to currency-mcp-server
    MCP-->>Gateway: Exchange rate: 0.92
    Gateway-->>Agent: HTTP 200 + result
```

## What Each Layer Provides

```mermaid
flowchart LR
    subgraph Layer1["Layer 1: Kata (Foundation)"]
        direction TB
        L1A["VM isolation"]
        L1B["Separate kernel"]
        L1C["Host not visible"]
        L1D["Unix sockets isolated"]
    end

    subgraph Layer2["Layer 2: Istio (Network)"]
        direction TB
        L2A["Network egress control"]
        L2B["REGISTRY_ONLY mode"]
        L2C["mTLS between pods"]
        L2D["ServiceEntry allowlist"]
    end

    subgraph Layer3["Layer 3: OPA (Application)"]
        direction TB
        L3A["Tool-level policy"]
        L3B["Argument inspection"]
        L3C["Currency blocking"]
        L3D["Audit logging"]
    end

    Layer1 --> Layer2 --> Layer3

    style Layer1 fill:#CC0000,color:#FFFFFF
    style Layer2 fill:#A30000,color:#FFFFFF
    style Layer3 fill:#820000,color:#FFFFFF
```

## Kagenti Agent CRD with Kata

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
  namespace: agent-sandbox
spec:
  imageSource:
    image: quay.io/rbrhssa/currency-agent:latest
  podTemplateSpec:
    spec:
      runtimeClassName: kata    # ← VM isolation
      containers:
        - name: agent
          env:
            - name: GOOGLE_API_KEY
              valueFrom:
                secretKeyRef:
                  name: gemini-api-key
                  key: GOOGLE_API_KEY
            - name: MCP_SERVER_URL
              value: "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
          resources:
            limits:
              memory: "2Gi"     # ← Required for QEMU
              cpu: "1"
```

The `runtimeClassName: kata` tells Kubernetes to run this pod using the Kata runtime, which creates a micro-VM for the container.

## OPA Policy Example

```rego
# Block cryptocurrency conversions
deny {
  body := json.unmarshal(input.context.request.http.body)
  body.method == "tools/call"
  body.params.name == "get_exchange_rate"
  currency := body.params.arguments.currency_to
  currency == "BTC"
}

deny {
  body := json.unmarshal(input.context.request.http.body)
  body.method == "tools/call"
  body.params.name == "get_exchange_rate"
  currency := body.params.arguments.currency_to
  currency == "ETH"
}

allow { not deny }
```
