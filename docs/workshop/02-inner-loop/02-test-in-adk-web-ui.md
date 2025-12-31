# Test in ADK Web UI

**Duration**: 15 minutes

## Overview

The ADK Web UI is **already deployed on the cluster**. You'll use it to test the Currency Agent interactively and view execution traces.

---

## Access the ADK Web UI

### Get the URL

```bash
# Get the ADK Web UI URL
ADK_URL=$(oc get route adk-server -n adk-web -o jsonpath='https://{.spec.host}')
echo "Open: $ADK_URL/dev-ui/"
```

### Open in Browser

Navigate to:
```
https://adk.apps.<your-cluster-domain>/dev-ui/
```

You should see the Google ADK Web interface:

![ADK Web UI Initial](../../images/adk-web-ui-initial.png)

---

## Test the Currency Agent

### Step 1: Select the Agent

From the agent dropdown, select **`currency_agent`**.

### Step 2: Send Test Prompts

Try these prompts to test different capabilities:

| Prompt | Expected Behavior |
|--------|-------------------|
| "What is 100 USD in EUR?" | Calls `get_exchange_rate(USD, EUR)`, returns rate |
| "Convert 50 GBP to JPY" | Calls tool, calculates 50 * rate |
| "How much is 1000 CHF in USD?" | Another currency pair test |
| "Hello!" | Friendly greeting without tool call |
| "What currencies do you support?" | Answers from instruction, no tool call |

### Step 3: View the Response

The agent should respond with the current exchange rate:

```
User: What is 100 USD in EUR?

Agent: I'll check the current exchange rate for you.

Based on today's rates, 100 USD is approximately 92.45 EUR.

The exchange rate is 1 USD = 0.9245 EUR (as of 2024-12-31).

Would you like me to help with any other currency conversions?
```

---

## View Execution Traces

### Why Traces Matter

Traces show you exactly what happened during agent execution:
- Which tools were called
- What arguments were passed
- How long each step took
- LLM reasoning process

### View the Trace

1. Click on the **Trace** tab in the ADK Web UI
2. Expand the trace to see each step:

```
┌─────────────────────────────────────────────────────────────────────────┐
│  Trace: "What is 100 USD in EUR?"                                        │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ▼ Agent Execution (1.2s total)                                         │
│    │                                                                    │
│    ├─ LLM Decision (0.3s)                                               │
│    │   Model: gemini-2.0-flash-exp                                      │
│    │   Decision: Call get_exchange_rate                                 │
│    │                                                                    │
│    ├─ Tool Call: get_exchange_rate (0.5s)                               │
│    │   Arguments: {currency_from: "USD", currency_to: "EUR"}            │
│    │   Result: {rate: 0.9245, date: "2024-12-31"}                       │
│    │                                                                    │
│    └─ LLM Response (0.4s)                                               │
│        Generated: "Based on today's rates, 100 USD is..."               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

![ADK Web UI Trace](../../images/adk-web-ui-trace.png)

---

## Test Edge Cases

Try these prompts to understand agent behavior:

### Test 1: Invalid Currency

```
Prompt: "Convert 100 USD to XYZ"

Expected: Agent handles error gracefully
```

### Test 2: No Tool Needed

```
Prompt: "Hello, how are you?"

Expected: Friendly response, no tool call in trace
```

### Test 3: Cryptocurrency (No Policy Yet)

```
Prompt: "What is 100 USD in BTC?"

Expected: Currently WORKS (no policy applied yet)
         After security hardening: Will be BLOCKED
```

!!! warning "BTC Works Now"
    At this stage, cryptocurrency conversions work because we haven't applied the OPA policy yet. After the outer loop security hardening, this will be blocked.

---

## Debugging with Traces

If something doesn't work as expected, use traces to debug:

| Symptom | What to Check in Trace |
|---------|------------------------|
| Wrong tool called | LLM Decision step - is the docstring clear? |
| Tool error | Tool Call result - what error returned? |
| Slow response | Time for each step - is tool call slow? |
| Wrong answer | LLM Response - did it use the tool result correctly? |

---

## Modify and Test Again (Optional)

If you want to modify the agent code:

### Option A: Edit ConfigMap (Quick)

```bash
# Edit the agent code ConfigMap
oc edit configmap currency-agent-code -n adk-web

# Restart ADK server to pick up changes
oc rollout restart deployment/adk-server -n adk-web

# Wait for restart
oc rollout status deployment/adk-server -n adk-web
```

### Option B: Push to Git (Production-like)

For production workflows, you would:

1. Modify code in your Git repository
2. Push changes
3. Trigger AgentBuild (covered in Outer Loop)
4. Deploy new version

---

## Summary

You've now:

- ✅ Accessed the ADK Web UI on the cluster
- ✅ Tested the Currency Agent with various prompts
- ✅ Viewed execution traces
- ✅ Tested edge cases

The agent is working correctly in the inner loop. Time to deploy it properly with security!

---

## Next

👉 [Step 3: Iterate and Refine](03-iterate-and-refine.md)

Or if you're ready to deploy:

👉 [Part 3: Outer Loop](../03-outer-loop/index.md)

