# Section 3: Deploy Agent

**Duration**: 15 minutes  
**Persona**: 👩‍💻 Developer

## Overview

Now that images are built, you'll deploy the Currency Agent and MCP Server to the cluster with **Kata VM isolation**.


## What You'll Deploy

| Component | Type | Purpose |
|-----------|------|---------|
| MCP Server | Deployment + Service | Provides `get_exchange_rate` tool |
| HTTPRoute | Gateway routing | Routes to MCP Server via MCP Gateway |
| Currency Agent | Agent CR | The ADK agent running in Kata VM |
| Route | External access | Exposes agent for testing |


## Step 1: Deploy MCP Server

The MCP Server provides the tools that the agent uses.

```bash
cd manifests/currency-kagenti

# Deploy MCP Server
oc apply -f agent/04-mcp-server-deploy.yaml

# Configure HTTPRoute for MCP Gateway
oc apply -f agent/04b-mcp-httproute.yaml

# Wait for pod to be ready
oc get pods -n currency-kagenti -l app=currency-mcp-server -w
```

### Verify MCP Server

```bash
# Check pod is running
oc get pods -n currency-kagenti -l app=currency-mcp-server

# Check service exists
oc get svc currency-mcp-server -n currency-kagenti
```


## Step 2: Deploy Agent Code ConfigMap

The agent needs updated code that routes through the MCP Gateway with the proper `Host` header. This enables OPA policy enforcement.

```bash
# Apply agent code ConfigMap
oc apply -f agent/05a-agent-code-configmap.yaml
```

### Why This Is Critical

Without the `Host` header, tool calls bypass the MCP Gateway's policy enforcement:

| Configuration | What Happens |
|---------------|--------------|
| Direct to MCP Server | ❌ No policy check, BTC works |
| Via MCP Gateway + Host header | ✅ OPA policy enforced, BTC blocked |

The ConfigMap contains agent code that uses:

```python
MCPToolset(
    connection_params=StreamableHTTPConnectionParams(
        url=MCP_SERVER_URL,
        headers={"Host": MCP_HOST_HEADER},  # ← Enables gateway routing!
    )
)
```


## Step 3: Deploy Currency Agent

Now deploy the agent with Kata VM isolation:

```bash
# Deploy Agent CR
oc apply -f agent/05-currency-agent.yaml

# Watch the pod start
oc get pods -n currency-kagenti -l app=currency-agent -w
```

### What the Agent CR Does

```yaml
# agent/05-currency-agent.yaml (key parts)
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
spec:
  imageSource:
    buildRef:
      name: currency-agent-build    # ← References AgentBuild
  
  podTemplateSpec:
    spec:
      runtimeClassName: kata        # ← Kata VM isolation (Layer 1)
      
      containers:
      - name: agent
        env:
        - name: GOOGLE_API_KEY
          valueFrom:
            secretKeyRef:
              name: gemini-api-key
              key: GOOGLE_API_KEY
        # MCP Gateway configuration (Layer 3)
        - name: MCP_SERVER_URL
          value: "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
        - name: MCP_HOST_HEADER
          value: "currency-mcp.mcp.local"
        
        volumeMounts:
        - mountPath: /app/currency_agent/agent.py
          name: agent-code
          subPath: agent.py
      
      volumes:
      - name: agent-code
        configMap:
          name: currency-agent-code    # ← ConfigMap with Host header support
```

| Field | Purpose |
|-------|---------|
| `buildRef` | Uses image from AgentBuild (not hardcoded image) |
| `runtimeClassName: kata` | Runs in Kata VM (Layer 1 security) |
| `GOOGLE_API_KEY` | From secret for LLM access |
| `MCP_SERVER_URL` | Points to MCP Gateway (not direct to MCP Server!) |
| `MCP_HOST_HEADER` | Routes to correct backend and triggers OPA policy |
| `volumeMounts` + `configMap` | Overrides agent code with Host header support |


## Step 4: Verify Kata Isolation

Confirm the agent is running in a Kata VM:

```bash
# Check runtimeClassName
oc get pod -n currency-kagenti -l app=currency-agent \
  -o jsonpath='{.items[0].spec.runtimeClassName}'
```

Expected output:
```
kata
```

### Additional Verification

```bash
# Check pod is using kata runtime
oc describe pod -n currency-kagenti -l app=currency-agent | grep -i runtime

# Check kata is actually being used (from node)
oc debug node/<node-name> -- chroot /host crictl ps | grep currency-agent
```


## Step 5: Expose Agent Externally

Create a Route to access the agent for testing:

```bash
# Apply Route
oc apply -f agent/06-route.yaml

# Get the URL
AGENT_URL=$(oc get route currency-agent -n currency-kagenti \
  -o jsonpath='https://{.spec.host}')
echo "Agent URL: $AGENT_URL"
```


## Step 6: Test the Agent

Now test that the agent works:

### Test via curl

```bash
# Test the A2A endpoint
curl -X POST "$AGENT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to EUR"}],
        "messageId": "test-1"
      }
    }
  }'
```

### Expected Response

```json
{
  "jsonrpc": "2.0",
  "id": "1",
  "result": {
    "message": {
      "role": "assistant",
      "parts": [
        {"text": "Based on today's exchange rate, 100 USD is approximately 92.45 EUR..."}
      ]
    }
  }
}
```


## Step 7: Test Cryptocurrency (No Policy Yet)

At this point, crypto conversions **still work** because we haven't applied security policies yet:

```bash
# This should WORK (no policy yet)
curl -X POST "$AGENT_URL" \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "2",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"text": "Convert 100 USD to BTC"}],
        "messageId": "test-2"
      }
    }
  }'
```

!!! warning "BTC Works Now"
    The agent can currently convert to cryptocurrency. After security hardening, this will be blocked.


## Troubleshooting

### Pod Not Starting

```bash
# Check pod status
oc describe pod -n currency-kagenti -l app=currency-agent

# Check logs
oc logs -n currency-kagenti -l app=currency-agent

# Check events
oc get events -n currency-kagenti --sort-by='.lastTimestamp'
```

### Agent Can't Connect to MCP Server

```bash
# Check MCP Server is running
oc get pods -n currency-kagenti -l app=currency-mcp-server

# Test connectivity from agent pod
oc exec -n currency-kagenti deployment/currency-agent -- \
  curl -s http://currency-mcp-server:8080/health
```

### Kata Pod Stuck in Pending

```bash
# Check RuntimeClass exists
oc get runtimeclass kata

# Check which nodes have Kata
oc get nodes -l node-role.kubernetes.io/kata-oc

# If no nodes labeled, kata is not configured
```


## Summary

You've now:

-  Deployed MCP Server
-  Deployed Currency Agent in Kata VM
-  Verified Kata isolation
-  Tested agent functionality
- ⚠️ Noted that crypto still works (no policy yet)


## Next

Apply security hardening to block cryptocurrency:

👉 [Section 4: Security Hardening](../04-security-hardening/index.md)

