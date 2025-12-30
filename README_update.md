## Verified Demo Results

Tested on: $(date -u +"%Y-%m-%d %H:%M UTC")

### Layer 1: MCP Gateway + OPA Policy

| Test | Tool Name | URL | Expected | Actual |
|------|-----------|-----|----------|--------|
| Blocked URL | `fetch_url` | `https://malicious.com` | 403 | **HTTP 403 ✅** |
| Allowed URL | `fetch_url` | `https://httpbin.org/get` | 200 | **HTTP 200 ✅** |

**Note:** OPA policy uses exact tool name matching. Configure the policy to match the registered tool name.

### Layer 3: Execution Isolation (Kata)

| Check | Expected | Actual |
|-------|----------|--------|
| Agent pod `runtimeClassName` | `kata` | **`kata` ✅** |
| Pod running on Kata-enabled node | `node-role.kubernetes.io/kata-oc` | **✅ Yes** |
| Agent deployed via Kagenti CRD | `Agent` CR | **✅ Yes** |

**Kagenti Agent with Kata:**
\`\`\`
$ oc get pod adk-kata-agent-57d7bf479-dsvwv -n agent-sandbox -o jsonpath='runtimeClassName: {.spec.runtimeClassName}'
runtimeClassName: kata
\`\`\`
