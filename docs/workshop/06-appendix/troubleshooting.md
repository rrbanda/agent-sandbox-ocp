# Troubleshooting

Common issues and their solutions.

## Agent Issues

### Pod Stuck in Pending

**Symptom**: Agent pod stays in `Pending` state.

**Check**:
```bash
oc describe pod -n agent-sandbox -l app=currency-agent
```

**Common Causes**:

1. **Kata runtime not available**
   ```bash
   oc get runtimeclass kata
   # If missing, KataConfig hasn't completed
   oc get kataconfig
   ```

2. **Insufficient resources**
   ```bash
   oc describe pod -n agent-sandbox -l app=currency-agent | grep -A 5 Events
   ```

3. **Node selector mismatch**
   - Kata may only be installed on specific nodes

**Solution**: Wait for KataConfig to complete or check node availability.

---

### Pod CrashLoopBackOff

**Symptom**: Agent pod repeatedly crashes.

**Check logs**:
```bash
oc logs -n agent-sandbox -l app=currency-agent --previous
```

**Common Causes**:

1. **Missing API key**
   ```bash
   oc get secret gemini-api-key -n agent-sandbox
   # If missing:
   oc create secret generic gemini-api-key \
     --from-literal=GOOGLE_API_KEY="your-key" \
     -n agent-sandbox
   ```

2. **Invalid API key**
   - Verify your Gemini API key is correct
   - Check for quota limits

3. **Package installation failure**
   - Network issues downloading pip packages
   - Try recreating the pod

---

### Agent Not Responding

**Symptom**: Pod is running but requests fail.

**Check**:
```bash
# Port forward and test
oc port-forward svc/currency-agent 8000:8000 -n agent-sandbox
curl http://localhost:8000/health
```

**Common Causes**:

1. **Agent still starting**
   - Package installation takes time on first start
   - Check logs for "Uvicorn running"

2. **Service misconfigured**
   ```bash
   oc get svc currency-agent -n agent-sandbox -o yaml
   oc get endpoints currency-agent -n agent-sandbox
   ```

---

## Policy Issues

### Allowed Request Being Blocked

**Symptom**: Valid currency conversion (e.g., USD to EUR) is blocked.

**Check**:
```bash
oc get authpolicy -n mcp-test -o yaml
```

**Common Causes**:

1. **Policy misconfigured**
   - Check the Rego rules
   - Verify blocked currency list

2. **HTTPRoute not matching**
   ```bash
   oc get httproute -n mcp-test
   ```

---

### Blocked Request Succeeding

**Symptom**: Crypto conversion (BTC, ETH) is allowed.

**Check**:
```bash
oc get authpolicy -n mcp-test
oc describe authpolicy -n mcp-test
```

**Common Causes**:

1. **AuthPolicy not applied**
   ```bash
   oc apply -f manifests/currency-demo/04-authpolicy.yaml
   ```

2. **Authorino not running**
   ```bash
   oc get pods -n kuadrant-system -l app=authorino
   ```

---

## Egress Issues

### Agent Can't Reach External API

**Symptom**: Currency conversion fails with connection timeout.

**Check**:
```bash
# Test from a pod in the namespace
oc run test-egress -n agent-sandbox --rm -it --restart=Never \
  --image=curlimages/curl -- curl -I https://api.frankfurter.app/latest
```

**Common Causes**:

1. **ServiceEntry missing**
   ```bash
   oc get serviceentry -n agent-sandbox
   # If missing:
   oc apply -f manifests/currency-demo/06-service-entry.yaml
   ```

2. **Istio not enrolled**
   ```bash
   oc get namespace agent-sandbox -o yaml | grep istio
   # Should have: istio.io/dataplane-mode: ambient
   ```

---

## AgentBuild Issues

### Build Fails with Permission Denied

**Symptom**: Buildah step fails with `permission denied` or `operation not permitted`.

**Check**:
```bash
oc logs -n agent-sandbox -l tekton.dev/taskRun -c step-build-image --tail=30
```

**Solution**:
```bash
# Add pipeline SA to privileged SCC (requires cluster-admin)
oc adm policy add-scc-to-user privileged \
  system:serviceaccount:agent-sandbox:pipeline

# Also ensure pipelines-scc has required capabilities
oc adm policy add-scc-to-user pipelines-scc \
  system:serviceaccount:agent-sandbox:pipeline
```

---

### Docker Hub Rate Limit

**Symptom**: Build fails with `toomanyrequests: You have reached your unauthenticated pull rate limit`.

**Solution**: The pipeline automatically replaces Docker Hub images with UBI equivalents:

| Docker Hub | UBI Replacement |
|------------|-----------------|
| `python:3.13-slim` | `registry.access.redhat.com/ubi9/python-312` |
| `python:3.12-slim` | `registry.access.redhat.com/ubi9/python-312` |
| `python:3.11-slim` | `registry.access.redhat.com/ubi9/python-311` |

If this isn't working, check the `buildah-build-step` ConfigMap in `kagenti-system`:

```bash
oc get configmap buildah-build-step -n kagenti-system -o yaml
```

---

### Build Stuck in Pending

**Symptom**: TaskRun shows `Pending` and pod never starts.

**Check**:
```bash
oc describe taskrun <taskrun-name> -n agent-sandbox
oc get pvc -n agent-sandbox
```

**Common Causes**:

1. **PVC not available**
   ```bash
   oc get pvc -n agent-sandbox
   # If stuck in Pending, check storage class
   ```

2. **Previous PVC being deleted**
   - Wait for cleanup and retry
   ```bash
   oc delete agentbuild <name> -n agent-sandbox
   sleep 30
   oc apply -f <agentbuild.yaml>
   ```

---

### Secret Not Found

**Symptom**: Build fails with `secret "ghcr-secret" not found` or similar.

**Solution**: Create required secrets:

```bash
# For registry push
oc create secret docker-registry ghcr-secret \
  --docker-server=quay.io \
  --docker-username=your-user \
  --docker-password=your-password \
  -n agent-sandbox

# For buildpacks
oc create secret docker-registry ghcr-token \
  --docker-server=quay.io \
  --docker-username=your-user \
  --docker-password=your-password \
  -n agent-sandbox
```

---

### UBI Image Permission Errors

**Symptom**: Build fails with `Permission denied` when creating `.venv` or cache directories.

**Cause**: UBI Python images run as non-root by default.

**Solution**: The pipeline automatically adds `USER root` and `chmod` commands. If not working, check the `buildah-build-step` ConfigMap includes these fixes:

```bash
oc get configmap buildah-build-step -n kagenti-system -o jsonpath='{.data.task-spec\.yaml}' | grep -A5 "replace-base-image"
```

---

### EXPOSE $PORT Error

**Symptom**: Build fails with `EXPOSE requires at least one argument`.

**Cause**: The Dockerfile uses `EXPOSE $PORT` but the variable isn't set at build time.

**Solution**: The pipeline automatically replaces `EXPOSE $PORT` with `EXPOSE 8080`. If not working, check the `buildah-build-step` ConfigMap.

---

## Kata Issues

### RuntimeClass Not Found

**Symptom**: `runtimeclass "kata" not found`

**Check**:
```bash
oc get runtimeclass
oc get kataconfig
```

**Common Causes**:

1. **KataConfig not applied**
   ```bash
   oc apply -f manifests/currency-demo/00-kataconfig.yaml
   ```

2. **KataConfig still installing**
   ```bash
   oc get kataconfig example-kataconfig -o yaml | grep -A 10 status
   ```

3. **OSC Operator not installed**
   - Check OperatorHub for "OpenShift sandboxed containers"

---

## ADK Web UI Issues

### UI Shows "Failed to load agents"

**Check**:
```bash
oc logs -n adk-web -l app=adk-server
```

**Common Causes**:

1. **API key not configured**
   ```bash
   oc get secret gemini-api-key -n adk-web
   ```

2. **CORS issues**
   - Check browser console for CORS errors

---

### Can't Access UI Route

**Check**:
```bash
oc get route adk-server -n adk-web
```

**Common Causes**:

1. **Route not created**
   ```bash
   oc apply -f manifests/adk-web/01-adk-server.yaml
   ```

2. **TLS certificate issues**
   - Try accessing via HTTP instead of HTTPS

---

## Getting Help

If you're still stuck:

1. **Check all pod logs**:
   ```bash
   oc logs -n agent-sandbox --all-containers -l app=currency-agent
   ```

2. **Describe resources**:
   ```bash
   oc describe pod -n agent-sandbox -l app=currency-agent
   oc describe authpolicy -n mcp-test
   ```

3. **Check events**:
   ```bash
   oc get events -n agent-sandbox --sort-by='.lastTimestamp'
   ```

4. **Open an issue**: [GitHub Issues](https://github.com/rrbanda/agent-sandbox-ocp/issues)

