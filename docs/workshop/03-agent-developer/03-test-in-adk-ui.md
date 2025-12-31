# Step 03: Test the Agent

**Time**: 5 minutes

## What You'll Do

Test the Currency Agent using the A2A test client to verify it's working correctly.

---

## Prerequisites

Ensure both services are running (from Step 02):

- **Terminal 1**: MCP Server (`uv run mcp-server/server.py`)
- **Terminal 2**: A2A Server (`uv run uvicorn currency_agent.agent:a2a_app ...`)

---

## Run the Test Client

In a **third terminal**, run the test client:

```bash
cd adk-samples/python/agents/currency-agent
uv run currency_agent/test_client.py
```

---

## Expected Output

You should see output like this:

```
--- 🔄 Connecting to agent at http://localhost:10000... ---
--- ✅ Connection successful. ---
--- ✉️  Single Turn Request ---
--- 📥 Single Turn Request Response ---
{"result":{"id":"task-abc123","status":{"state":"completed"},"artifacts":[{"parts":[{"kind":"text","text":"100 USD is approximately 141.50 CAD based on the current exchange rate."}]}]}}

--- ❔ Query Task ---
--- 📥 Query Task Response ---
{"result":{"id":"task-abc123","status":{"state":"completed"},"artifacts":[...]}}

--- 📝 Multi-Turn Request ---
--- 📥 Multi-Turn: First Turn Response ---
{"result":{"id":"task-def456","status":{"state":"input_required"},...}}

--- 📝 Multi-Turn: Second Turn (Input Required) ---
--- Multi-Turn: Second Turn Response ---
{"result":{"id":"task-def456","status":{"state":"completed"},"artifacts":[{"parts":[{"kind":"text","text":"100 USD is approximately 78.50 GBP."}]}]}}
```

---

## Understanding the Test Client

The test client (`currency_agent/test_client.py`) demonstrates two test scenarios:

### 1. Single-Turn Test

```python
async def run_single_turn_test(client: A2AClient) -> None:
    """Runs a single-turn non-streaming test."""
    
    send_message_payload = create_send_message_payload(
        text="how much is 100 USD in CAD?"
    )
    response = await client.send_message(request)
    # Returns: "100 USD is approximately 141.50 CAD"
```

A complete question that the agent can answer in one response.

### 2. Multi-Turn Test

```python
async def run_multi_turn_test(client: A2AClient) -> None:
    """Runs a multi-turn non-streaming test."""
    
    # First turn: incomplete question
    first_turn_payload = create_send_message_payload(
        text="how much is 100 USD?"
    )
    # Agent responds: "What currency do you want to convert to?"
    
    # Second turn: provide the missing info
    second_turn_payload = create_send_message_payload(
        "in GBP", task.id, context_id
    )
    # Agent responds: "100 USD is approximately 78.50 GBP"
```

Demonstrates conversation context - the agent remembers the first message.

---

## A2A Message Structure

The A2A protocol uses JSON-RPC messages:

```json
{
  "jsonrpc": "2.0",
  "method": "message/send",
  "id": "unique-request-id",
  "params": {
    "message": {
      "role": "user",
      "parts": [{"kind": "text", "text": "100 USD to EUR?"}],
      "messageId": "unique-message-id"
    }
  }
}
```

Response:

```json
{
  "jsonrpc": "2.0",
  "id": "unique-request-id",
  "result": {
    "id": "task-id",
    "status": {"state": "completed"},
    "artifacts": [{
      "parts": [{"kind": "text", "text": "100 USD is 92.45 EUR"}]
    }]
  }
}
```

---

## Manual Testing with curl

You can also test manually:

```bash
curl -X POST http://localhost:10000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "What is 50 EUR in JPY?"}],
        "messageId": "test-123"
      }
    }
  }'
```

---

## Check the Logs

### MCP Server Logs (Terminal 1)

You should see tool calls:

```
[INFO]: --- 🛠️ Tool: get_exchange_rate called for converting USD to CAD ---
[INFO]: ✅ API response: {"amount": 1, "base": "USD", "date": "2024-12-30", "rates": {"CAD": 1.415}}
```

### A2A Server Logs (Terminal 2)

You should see agent processing:

```
[INFO]: --- 🔧 Loading MCP tools from MCP Server... ---
[INFO]: --- 🤖 Creating ADK Currency Agent... ---
INFO:     127.0.0.1:54321 - "POST / HTTP/1.1" 200 OK
```

---

## Test Different Currencies

Try various conversion requests:

| Request | Expected Response |
|---------|-------------------|
| "100 USD to EUR" | ~92 EUR |
| "50 GBP to JPY" | ~9,500 JPY |
| "1000 EUR to USD" | ~1,080 USD |
| "What's the exchange rate between CAD and AUD?" | Current rate |

---

## Test Error Handling

Try requests the agent can't handle:

```bash
curl -X POST http://localhost:10000 \
  -H "Content-Type: application/json" \
  -d '{
    "jsonrpc": "2.0",
    "method": "message/send",
    "id": "1",
    "params": {
      "message": {
        "role": "user",
        "parts": [{"kind": "text", "text": "What is the weather today?"}],
        "messageId": "test-456"
      }
    }
  }'
```

Expected: The agent should politely decline and say it can only help with currency conversions.

---

## Verification Checklist

Before moving on, confirm:

- [ ] Test client connects successfully
- [ ] Single-turn query returns conversion result
- [ ] Multi-turn conversation works
- [ ] MCP server logs show tool calls
- [ ] Non-currency questions are politely declined

---

## Next Step

Now let's understand how the agent is containerized for deployment.

👉 [Step 04: Understand Containerization](04-containerize.md)
