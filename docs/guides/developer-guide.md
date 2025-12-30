# Developer Guide: Building and Deploying Agents

This guide is for **Agent Developers** who want to build and deploy AI agents on OpenShift.

## Prerequisites

- Python 3.11+
- [Google ADK](https://github.com/google/adk-python) installed (`pip install google-adk`)
- Access to an OpenShift cluster with Kagenti installed
- Container registry access (Quay.io, GHCR, etc.)

---

## Step 1: Develop Locally (Inner Loop)

### 1.1 Create Your Agent

The Currency Agent structure:

```
currency_agent/
├── __init__.py
├── agent.py          # Agent definition
└── requirements.txt  # Dependencies
```

### 1.2 Run Locally

```bash
cd currency_agent
adk web
```

### 1.3 Test in ADK Web UI

1. Open http://localhost:8000/dev-ui/
2. Select `currency_agent` from dropdown
3. Test prompts:
   - "What is 100 USD in EUR?"
   - "Convert 50 GBP to JPY"
4. Use the Trace tab to debug tool calls

### 1.4 Iterate

- Modify prompts in `agent.py`
- Restart `adk web`
- Test again
- Repeat until your agent works correctly

---

## Step 2: Containerize

### 2.1 Create Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy agent code
COPY . .

# Run ADK API server
CMD ["adk", "api_server", "--host=0.0.0.0", "--port=8000"]
```

### 2.2 Build and Test Locally

```bash
# Build
docker build -t currency-agent:local .

# Test locally
docker run -p 8000:8000 -e GOOGLE_API_KEY=$GOOGLE_API_KEY currency-agent:local

# Verify it works
curl http://localhost:8000/health
```

### 2.3 Push to Registry

```bash
# Tag for your registry
docker tag currency-agent:local quay.io/myorg/currency-agent:v1

# Push
docker push quay.io/myorg/currency-agent:v1
```

---

## Step 3: Deploy to OpenShift (Outer Loop)

### 3.1 Create Agent CR

Create `currency-agent.yaml`:

```yaml
apiVersion: kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
  namespace: agent-sandbox    # Use the pre-configured secure namespace
spec:
  imageSource:
    image: quay.io/myorg/currency-agent:v1
  replicas: 1
  servicePorts:
    - name: http
      port: 8000
      protocol: TCP
  podTemplateSpec:
    spec:
      containers:
        - name: agent
          env:
            - name: GOOGLE_API_KEY
              valueFrom:
                secretKeyRef:
                  name: gemini-api-key
                  key: GOOGLE_API_KEY
          resources:
            requests:
              memory: "256Mi"
              cpu: "100m"
            limits:
              memory: "512Mi"
              cpu: "500m"
```

### 3.2 Deploy

```bash
# Ensure you're logged into OpenShift
oc login <cluster-url>

# Deploy to the secured namespace
oc apply -f currency-agent.yaml

# Wait for pod to be ready
oc get pods -n agent-sandbox -w
```

### 3.3 Verify Deployment

```bash
# Check pod is running
oc get pod -n agent-sandbox -l app=currency-agent

# Check it's using Kata (VM isolation)
oc get pod -n agent-sandbox -l app=currency-agent -o yaml | grep runtimeClassName

# Check logs
oc logs -n agent-sandbox -l app=currency-agent
```

---

## Step 4: Test in Cluster

### Option A: ADK Web UI

If ADK Web UI is deployed:

```bash
# Get the URL
echo "https://$(oc get route adk-server -n adk-web -o jsonpath='{.spec.host}')/dev-ui/"
```

1. Open the URL
2. Select `currency_agent`
3. Test: "What is 100 USD in EUR?" → Should work
4. Test: "What is 100 USD in BTC?" → Should be blocked by OPA

### Option B: Direct API Call

```bash
# Port-forward to the agent
oc port-forward -n agent-sandbox svc/currency-agent 8000:8000

# Test
curl http://localhost:8000/health
```

---

## What You Don't Need to Do

The platform handles these automatically:

- ❌ Configure OPA policies (pre-configured by platform admin)
- ❌ Set up Istio egress rules (pre-configured)
- ❌ Configure Kata isolation (enabled at namespace level)
- ❌ Set up SPIFFE identity (automatic via SPIRE)
- ❌ Configure mTLS (automatic via Istio)
- ❌ Set up tracing (automatic via Phoenix)

You just deploy your Agent CR. Security is automatic.

---

## Troubleshooting

### Pod not starting

```bash
oc describe pod -n agent-sandbox -l app=currency-agent
oc logs -n agent-sandbox -l app=currency-agent
```

### Tool calls blocked

If legitimate tool calls are being blocked, check with your platform admin. The OPA AuthPolicy might be too restrictive.

### Can't reach external API

The agent can only reach APIs in the ServiceEntry allowlist. Ask your platform admin to add the required API.

---

## Next Steps

- Read [Threat Model](../concepts/threat-model.md) to understand why these security layers exist
- Read [Defense in Depth](../concepts/defense-in-depth.md) for details on each layer
- See [Demo Walkthrough](demo-walkthrough.md) for a complete demo script

