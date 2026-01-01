# Currency Agent

A Google ADK-based AI agent for currency conversions with MCP Gateway support.

## Overview

This agent:
- Uses **Gemini 2.5 Flash** as the LLM
- Connects to an MCP server for the `get_exchange_rate` tool
- Supports **MCP Gateway routing** via Host header for OPA policy enforcement
- Exposes **A2A protocol** on port 10000

## MCP Gateway Integration

When deployed to OpenShift with Kagenti, the agent connects through the MCP Gateway (Envoy) which:
1. Routes requests based on the `Host` header
2. Applies OPA policies to validate tool calls
3. Only allows approved currency conversions (blocks crypto)

```
Agent → MCP Gateway (Envoy) → MCP Server
              ↓
       AuthPolicy (OPA)
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MCP_SERVER_URL` | `http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp` | MCP Gateway endpoint |
| `MCP_HOST_HEADER` | `currency-mcp.mcp.local` | Host header for gateway routing |
| `GOOGLE_API_KEY` | - | Gemini API key (required) |

## Local Development

```bash
# Set up environment
export GOOGLE_API_KEY=your-key
export MCP_SERVER_URL=http://localhost:8080/mcp
export MCP_HOST_HEADER=  # Leave empty for local

# Install dependencies
uv pip install .

# Run the agent
python -m currency_agent
```

## Container Build

```bash
# Build the image
podman build -t currency-agent .

# Run the container
podman run -p 10000:10000 \
  -e GOOGLE_API_KEY=your-key \
  -e MCP_SERVER_URL=http://mcp-server:8080/mcp \
  currency-agent
```

## License

Apache 2.0

