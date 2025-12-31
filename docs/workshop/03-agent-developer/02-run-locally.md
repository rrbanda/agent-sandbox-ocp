# Step 02: Run Locally

**Time**: 10 minutes

## What You'll Do

Clone the official Google ADK samples, configure your environment, and start the Currency Agent locally.

---

## Prerequisites

Ensure you have:

- Python 3.10+
- Git installed
- A Gemini API key ([Get one here](https://aistudio.google.com/app/apikey))

---

## Step 1: Clone the Repository

```bash
git clone https://github.com/google/adk-samples.git
cd adk-samples/python/agents/currency-agent
```

---

## Step 2: Install uv

The project uses [uv](https://docs.astral.sh/uv/) for dependency management:

```bash
# macOS and Linux
curl -LsSf https://astral.sh/uv/install.sh | sh

# Windows (PowerShell)
# powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
```

!!! note
    You may need to restart your terminal after installing `uv`.

---

## Step 3: Configure Environment

Create a `.env` file with your Gemini API key:

```bash
# Using Gemini API Key (recommended for getting started)
echo "GOOGLE_API_KEY=your-api-key-here" >> .env
echo "GOOGLE_GENAI_USE_VERTEXAI=FALSE" >> .env
```

Replace `your-api-key-here` with your actual API key from [Google AI Studio](https://aistudio.google.com/app/apikey).

---

## Step 4: Start the MCP Server

In a terminal, start the MCP Server (runs on port 8080):

```bash
uv run mcp-server/server.py
```

You should see:

```
[INFO]: 🚀 MCP server started on port 8080
```

Keep this terminal running.

---

## Step 5: Start the A2A Server

In a **separate terminal** (same directory), start the A2A Server (runs on port 10000):

```bash
uv run uvicorn currency_agent.agent:a2a_app --host localhost --port 10000
```

You should see:

```
[INFO]: --- 🔧 Loading MCP tools from MCP Server... ---
[INFO]: --- 🤖 Creating ADK Currency Agent... ---
INFO:     Uvicorn running on http://localhost:10000
```

Keep this terminal running.

---

## Understanding What's Running

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    Local Development Setup                               │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Terminal 1: MCP Server                                                 │
│  ─────────────────────                                                  │
│  uv run mcp-server/server.py                                            │
│  http://localhost:8080/mcp                                              │
│  Exposes: get_exchange_rate tool                                        │
│                                                                         │
│  Terminal 2: A2A Server                                                 │
│  ─────────────────────                                                  │
│  uv run uvicorn currency_agent.agent:a2a_app ...                        │
│  http://localhost:10000                                                 │
│  Exposes: ADK agent via A2A protocol                                    │
│                                                                         │
│  Terminal 3: Test Client (next step)                                    │
│  ─────────────────────                                                  │
│  uv run currency_agent/test_client.py                                   │
│  Sends test queries to the A2A server                                   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Verify Everything Is Running

Check the services are accessible:

```bash
# Check MCP Server (should return server info)
curl http://localhost:8080/mcp -H "Accept: application/json" -d '{"jsonrpc":"2.0","method":"initialize","id":"1","params":{}}' -H "Content-Type: application/json"

# Check A2A Server (should return agent card)
curl http://localhost:10000/.well-known/agent.json
```

---

## Troubleshooting

### "GOOGLE_API_KEY not set"

Ensure the `.env` file exists and contains your API key:

```bash
cat .env
# Should show: GOOGLE_API_KEY=your-key-here
```

### MCP Server Won't Start

Check if port 8080 is available:

```bash
lsof -i :8080

# Use a different port if needed
PORT=9090 uv run mcp-server/server.py
```

### A2A Server Can't Connect to MCP

Ensure MCP server is running first, then set the URL:

```bash
MCP_SERVER_URL=http://localhost:8080/mcp uv run uvicorn currency_agent.agent:a2a_app --host localhost --port 10000
```

### uv Not Found

Restart your terminal or manually add uv to your PATH:

```bash
export PATH="$HOME/.cargo/bin:$PATH"
```

---

## Next Step

Now let's test the agent with the A2A test client.

👉 [Step 03: Test the Agent](03-test-in-adk-ui.md)
