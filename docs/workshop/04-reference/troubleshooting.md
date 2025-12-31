# Troubleshooting

Common issues and solutions for the workshop.

---

## Build Issues

### AgentBuild Not Starting

**Symptom**: AgentBuild created but no PipelineRun appears

**Check**:
```bash
oc get agentbuild -n currency-kagenti
oc describe agentbuild currency-agent-build -n currency-kagenti
```

**Common Causes**:
- Pipeline template not found
- Missing secrets

**Fix**:
```bash
# Ensure pipeline template exists
oc get configmap pipeline-template-dev -n currency-kagenti

# Check secrets
oc get secrets -n currency-kagenti
```

---

### PipelineRun Fails

**Symptom**: PipelineRun shows `Failed`

**Check**:
```bash
oc describe pipelinerun -n currency-kagenti <name>
oc get taskruns -n currency-kagenti
```

**Common Causes**:

1. **Git clone fails**
   ```bash
   # Check GitHub secret
   oc get secret github-token-secret -n currency-kagenti
   ```

2. **Registry push fails**
   ```bash
   # Check registry secret
   oc get secret quay-registry-secret -n currency-kagenti
   
   # Link to service account
   oc secrets link pipeline quay-registry-secret --for=pull,mount
   ```

3. **Permission denied (buildah)**
   ```bash
   # Add SCC
   oc adm policy add-scc-to-user privileged \
     system:serviceaccount:currency-kagenti:pipeline
   ```

---

## Deployment Issues

### Kata Pod Stuck in Pending

**Symptom**: Pod with `runtimeClassName: kata` never schedules

**Check**:
```bash
oc describe pod -n currency-kagenti <pod-name>
oc get nodes -l node-role.kubernetes.io/kata-oc
```

**Common Causes**:
- Kata not configured on any nodes
- RuntimeClass not created

**Fix**:
```bash
# Check RuntimeClass exists
oc get runtimeclass kata

# If not, apply KataConfig
oc apply -f - <<EOF
apiVersion: kataconfiguration.openshift.io/v1
kind: KataConfig
metadata:
  name: example-kataconfig
spec:
  enablePeerPods: false
EOF

# Wait for nodes to be ready (~10 min)
oc get kataconfig -w
```

---

### Kata Pod OOM Killed

**Symptom**: Pod crashes with OOMKilled

**Fix**: Increase memory limits (Kata VMs need more memory)

```yaml
resources:
  limits:
    memory: "2Gi"    # Minimum for Kata
  requests:
    memory: "1Gi"
```

---

### Agent Can't Connect to MCP Server

**Symptom**: Agent logs show connection errors to MCP Server

**Check**:
```bash
# MCP Server running?
oc get pods -n currency-kagenti -l app=currency-mcp-server

# Service exists?
oc get svc currency-mcp-server -n currency-kagenti

# Test from agent pod
oc exec -n currency-kagenti deployment/currency-agent -- \
  curl -s http://currency-mcp-server:8080/health
```

**Fix**:
```bash
# Redeploy MCP Server
oc rollout restart deployment/currency-mcp-server -n currency-kagenti
```

---

## Security Issues

### OPA Policy Not Blocking Requests

**Symptom**: Crypto conversions still work after applying AuthPolicy

**Check**:
```bash
# AuthPolicy exists?
oc get authpolicy -n currency-kagenti

# Authorino running?
oc get pods -n kuadrant-system -l app=authorino
```

**Common Causes**:
- Request body not forwarded to Authorino
- HTTPRoute not referencing AuthPolicy

**Fix**: Ensure Istio is configured to forward request bodies:
```bash
oc patch istio default -n istio-system --type=merge -p '
{
  "spec": {
    "values": {
      "meshConfig": {
        "extensionProviders": [
          {
            "name": "kuadrant-authorization",
            "envoyExtAuthzGrpc": {
              "includeRequestBodyInCheck": {
                "maxRequestBytes": 8192,
                "allowPartialMessage": true
              }
            }
          }
        ]
      }
    }
  }
}'
```

---

### 502 Bad Gateway

**Symptom**: Gateway returns 502

**Common Cause**: Test pod has Istio sidecar injected

**Fix**:
```bash
# Disable sidecar for test pod
cat <<EOF | oc apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: test-curl
  namespace: currency-kagenti
  annotations:
    sidecar.istio.io/inject: "false"
spec:
  containers:
  - name: curl
    image: curlimages/curl
    command: ["sleep", "3600"]
EOF
```

---

## ADK Web UI Issues

### ADK Web UI Not Loading

**Check**:
```bash
# Pod running?
oc get pods -n adk-web -l app=adk-server

# Logs
oc logs -n adk-web deployment/adk-server

# Route exists?
oc get route adk-server -n adk-web
```

**Common Cause**: Gemini API key not set

**Fix**:
```bash
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='your-key' \
  -n adk-web

oc rollout restart deployment/adk-server -n adk-web
```

---

## Useful Commands

### View All Resources

```bash
# In currency-kagenti namespace
oc get all -n currency-kagenti

# AgentBuilds
oc get agentbuild -n currency-kagenti

# Agents
oc get agent -n currency-kagenti

# PipelineRuns
oc get pipelineruns -n currency-kagenti
```

### View Logs

```bash
# Agent logs
oc logs -n currency-kagenti deployment/currency-agent

# MCP Server logs
oc logs -n currency-kagenti deployment/currency-mcp-server

# ADK Web logs
oc logs -n adk-web deployment/adk-server

# Authorino logs
oc logs -n kuadrant-system -l app=authorino -c authorino
```

### Events

```bash
# Recent events
oc get events -n currency-kagenti --sort-by='.lastTimestamp' | tail -20
```

