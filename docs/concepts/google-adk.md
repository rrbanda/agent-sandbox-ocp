# What to Know About Google ADK

---

## 1. What ADK Is

**Google Agent Development Kit (ADK)** is an open-source framework for building AI agents. It provides:

- **Agent definition** - Declarative agent configuration
- **Tool integration** - Connect to MCP servers and other tools
- **Local development** - Built-in web UI for testing
- **Deployment flexibility** - Run locally, in containers, or on Kubernetes

**Key idea**

> ADK is a Python framework that makes building AI agents feel like building web apps.

---

## 2. Why ADK for This Workshop

We chose ADK because:

1. **MCP-native** - First-class support for Model Context Protocol
2. **Simple structure** - Easy to understand agent code
3. **Built-in UI** - `adk web` provides instant testing interface
4. **Production-ready** - Same code runs locally and in containers

---

## 3. ADK Project Structure

A minimal ADK agent:

```
currency_agent/
├── __init__.py          # Package marker
├── agent.py             # Agent definition
└── .env                 # API keys (local dev only)
```

### agent.py

```python
from google.adk import Agent
from google.adk.tools import mcp

# Create the agent
agent = Agent(
    name="currency_agent",
    model="gemini-2.0-flash",
    description="Converts currencies using real-time exchange rates",
    instruction="You help users convert between currencies...",
    tools=[
        mcp.MCPToolset(
            server="http://localhost:8080",
            tools=["get_exchange_rate"]
        )
    ]
)
```

---

## 4. Key ADK Concepts

### Agent

The core entity that:

- Has a name and description
- Uses an LLM model (e.g., Gemini)
- Has instructions (system prompt)
- Has access to tools

### Tools

External capabilities the agent can use:

- **MCP Tools** - Via MCP servers
- **Function Tools** - Python functions
- **Built-in Tools** - Code execution, etc.

### Sessions

Conversation state management:

- Tracks message history
- Maintains context across turns
- Handles multi-turn interactions

---

## 5. Running ADK Locally

### Setup

```bash
# Install ADK
pip install google-adk

# Set API key
export GOOGLE_API_KEY="your-gemini-key"
```

### Development UI

```bash
cd currency_agent
adk web
# Opens http://localhost:8000/dev-ui/
```

The web UI provides:

- Agent selection
- Chat interface
- Execution traces
- Tool call inspection

### CLI Testing

```bash
adk run currency_agent "What is 100 USD in EUR?"
```

---

## 6. ADK with MCP

ADK integrates with MCP servers via `MCPToolset`:

```python
from google.adk.tools import mcp

tools = [
    mcp.MCPToolset(
        server="http://currency-mcp-server:8080",
        tools=["get_exchange_rate"]
    )
]
```

The flow:

```
User Query → ADK Agent → LLM → Tool Decision
                              ↓
                         MCPToolset
                              ↓
                        MCP Server
                              ↓
                         Tool Result
                              ↓
                      LLM → Response
```

---

## 7. Containerizing ADK Agents

### Simple Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY currency_agent/ ./currency_agent/

CMD ["adk", "api_server", "--host", "0.0.0.0", "--port", "8000"]
```

### requirements.txt

```
google-adk>=0.1.0
```

---

## 8. ADK vs Other Frameworks

| Aspect | ADK | LangChain | LangGraph | Custom |
|--------|-----|-----------|-----------|--------|
| MCP support | Native | Via adapter | Via adapter | DIY |
| Learning curve | Low | Medium | High | Varies |
| Flexibility | Medium | High | Very High | Maximum |
| Built-in UI | Yes | No | LangSmith | No |
| Opinionated | Yes | Somewhat | Less | No |

Choose ADK when you want **simplicity with MCP**.

---

## 9. ADK Deployment Options

### Local Development

```bash
adk web  # Full UI
adk run  # CLI only
```

### Container (API Server)

```bash
adk api_server --host 0.0.0.0 --port 8000
```

### Kubernetes (via Kagenti)

```yaml
apiVersion: kagenti.io/v1alpha1
kind: Agent
spec:
  image: your-registry/currency-agent:latest
  # Kagenti handles the rest
```

---

## 10. Environment Variables

| Variable | Purpose |
|----------|---------|
| `GOOGLE_API_KEY` | Gemini API authentication |
| `MCP_SERVER_URL` | Default MCP server endpoint |
| `ADK_LOG_LEVEL` | Logging verbosity |

In Kubernetes, use Secrets:

```yaml
env:
  - name: GOOGLE_API_KEY
    valueFrom:
      secretKeyRef:
        name: gemini-api-key
        key: GOOGLE_API_KEY
```

---

## 11. Testing Agents

### Unit Testing

```python
from currency_agent.agent import agent

def test_agent_has_tools():
    assert len(agent.tools) > 0
    
def test_agent_description():
    assert "currency" in agent.description.lower()
```

### Integration Testing

```bash
# Start MCP server
python -m currency_mcp_server &

# Test agent
adk run currency_agent "What is 50 EUR in USD?"
```

---

## 12. ADK Web UI Features

The built-in UI (`adk web`) provides:

| Feature | Purpose |
|---------|---------|
| Agent selector | Choose which agent to test |
| Chat interface | Send prompts, see responses |
| Trace viewer | Inspect LLM calls and tool invocations |
| Event log | Real-time execution events |
| Settings | Model parameters, etc. |

This is invaluable for **debugging** before deployment.

---

## 13. Relevance to This Workshop

In the Currency Agent demo:

1. **agent.py** defines the agent with MCP toolset
2. **`adk web`** is used for local testing (inner loop)
3. **`adk api_server`** runs in the container (outer loop)
4. **Kagenti Agent CR** deploys the containerized agent

The same ADK code works locally and in production.

---

## 14. A Defensible Technical Statement

> Google ADK provides a Python framework for building AI agents with native MCP support. Its built-in web UI accelerates development, while its simple structure makes containerization straightforward. ADK agents can run unchanged from local development to Kubernetes production.

---

## 15. Key Takeaway

> **ADK is the bridge between your laptop and the cluster - same code, different environments.**

---

## References

* [Google ADK GitHub](https://github.com/google/adk-python)
* [ADK Documentation](https://google.github.io/adk-python/)
* [Model Context Protocol](https://modelcontextprotocol.io/)
* [Gemini API](https://ai.google.dev/)

