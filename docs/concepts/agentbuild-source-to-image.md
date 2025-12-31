# AgentBuild: Source-to-Image for AI Agents

---

## 1. What AgentBuild Is

**AgentBuild** is a Kagenti Custom Resource (CR) that automates building container images from source code. Instead of manually building and pushing images, you define where your code lives and Kagenti handles the rest.

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: AgentBuild
metadata:
  name: currency-agent-build
spec:
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent"
  buildOutput:
    image: "currency-agent"
    imageTag: "v1.0.0"
    imageRegistry: "quay.io/your-org"
```

**Key idea**

> AgentBuild brings GitOps-style source-to-image builds to AI agent development.

---

## 2. Why AgentBuild Matters

Without AgentBuild, deploying an agent requires:

1. Clone repository locally
2. Build Docker image
3. Push to registry
4. Update Agent CR with new image
5. Repeat for every change

With AgentBuild:

1. Apply AgentBuild CR pointing to Git repo
2. Kagenti builds and pushes automatically
3. Agent CR references build via `buildRef`
4. Updates trigger automatic rebuilds

---

## 3. How It Works

```
┌─────────────────────────────────────────────────────────────────┐
│                    AgentBuild Pipeline                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│   1. AgentBuild CR      2. Tekton Pipeline    3. Built Image   │
│   ┌──────────────┐      ┌──────────────────┐  ┌─────────────┐  │
│   │ source:      │      │ git-clone        │  │ quay.io/    │  │
│   │   repo: ...  │─────▶│ dockerfile-check │─▶│ org/agent   │  │
│   │   subfolder  │      │ buildah/buildpack│  │ :v1.0.0     │  │
│   └──────────────┘      └──────────────────┘  └─────────────┘  │
│                                │                     │         │
│                                ▼                     │         │
│                         ┌──────────────┐             │         │
│   4. Agent CR           │ push to      │             │         │
│   ┌──────────────┐      │ registry     │             │         │
│   │ imageSource: │◀─────┴──────────────┘─────────────┘         │
│   │   buildRef:  │                                             │
│   │     name: .. │                                             │
│   └──────────────┘                                             │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## 4. AgentBuild CR Structure

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: AgentBuild
metadata:
  name: my-agent-build
  namespace: my-namespace
  labels:
    kagenti.io/framework: google-adk    # Framework label
    kagenti.io/protocol: a2a            # Protocol (a2a or mcp)
    kagenti.io/type: agent              # Type (agent or tool)
spec:
  mode: dev                             # Build mode (dev/prod)
  
  source:
    sourceRepository: "github.com/org/repo.git"
    sourceRevision: "main"              # Branch or tag
    sourceSubfolder: "path/to/agent"    # Subfolder in repo
    sourceCredentials:
      name: github-token-secret         # Secret for private repos
  
  pipeline:
    namespace: kagenti-system           # Where pipeline runs
    parameters:
      - name: SOURCE_REPO_SECRET
        value: github-token-secret
  
  buildOutput:
    image: "my-agent"
    imageTag: "v1.0.0"
    imageRegistry: "quay.io/my-org"
```

---

## 5. Build Modes: Dockerfile vs Buildpacks

AgentBuild automatically detects how to build your code:

| Condition | Build Method | Use Case |
|-----------|--------------|----------|
| `Dockerfile` exists | **Buildah** | Full control over image |
| No `Dockerfile` | **Buildpacks** | Auto-detect Python, Node, etc. |

### Dockerfile Build (Buildah)

```dockerfile
FROM python:3.12-slim
COPY . /app
RUN pip install -r requirements.txt
CMD ["python", "main.py"]
```

### Buildpacks Build (No Dockerfile)

Just have `requirements.txt` or `pyproject.toml`:

```
google-adk>=1.0.0
uvicorn>=0.30.0
```

Buildpacks automatically creates an optimized image.

---

## 6. Linking Agent to AgentBuild

The Agent CR references the build using `buildRef`:

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
spec:
  # Reference the AgentBuild instead of direct image
  imageSource:
    buildRef:
      name: currency-agent-build    # Name of AgentBuild CR
  
  # Alternative: Direct image (not recommended)
  # imageSource:
  #   image: quay.io/org/currency-agent:v1.0.0
```

When you use `buildRef`:

- Kagenti resolves the built image from AgentBuild status
- Updates to AgentBuild automatically update the Agent
- Clear lineage from source to deployment

---

## 7. Pipeline Templates

AgentBuild uses **Pipeline Templates** defined as ConfigMaps:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-template-dev
  namespace: my-namespace
  labels:
    component.kagenti.ai/mode: dev
data:
  template.json: |
    {
      "name": "Development Pipeline",
      "steps": [
        { "name": "github-clone", "configMap": "github-clone-step" },
        { "name": "dockerfile-check", "configMap": "check-dockerfile-step" },
        { "name": "buildah-build", "configMap": "buildah-build-step" },
        { "name": "buildpack-step", "configMap": "buildpack-step" }
      ]
    }
```

Each step is defined in its own ConfigMap with the task specification.

---

## 8. UBI Base Images

Docker Hub rate limits can block builds. The pipeline automatically replaces Docker Hub images with Red Hat UBI:

| Docker Hub | Red Hat UBI |
|------------|-------------|
| `python:3.13-slim` | `registry.access.redhat.com/ubi9/python-312` |
| `python:3.12-slim` | `registry.access.redhat.com/ubi9/python-312` |
| `python:3.11-slim` | `registry.access.redhat.com/ubi9/python-311` |

This is handled automatically by the `buildah-build-step` ConfigMap.

---

## 9. Required Secrets

### GitHub Token (for private repos)

```bash
oc create secret generic github-token-secret \
  --from-literal=token='ghp_xxxxxxxxxxxx' \
  -n my-namespace
```

### Registry Credentials (for pushing images)

```bash
oc create secret docker-registry quay-registry-secret \
  --docker-server=quay.io \
  --docker-username=myuser \
  --docker-password=mypassword \
  -n my-namespace
```

---

## 10. Security: SCC Configuration

Building container images requires elevated privileges. The `pipeline` ServiceAccount needs:

```bash
# Add pipeline SA to pipelines-scc
oc adm policy add-scc-to-user pipelines-scc \
  system:serviceaccount:my-namespace:pipeline

# For buildah with privileged mode
oc adm policy add-scc-to-user privileged \
  system:serviceaccount:my-namespace:pipeline
```

The `pipelines-scc` needs these capabilities:
- `SETUID` - Required for buildah user mapping
- `SETGID` - Required for buildah group mapping

---

## 11. Build Status

Check build progress:

```bash
# AgentBuild status
oc get agentbuilds -n my-namespace

# Detailed status
oc describe agentbuild my-agent-build -n my-namespace

# Pipeline runs
oc get taskruns -n my-namespace

# Built image
oc get agentbuild my-agent-build -o jsonpath='{.status.builtImage}'
```

---

## 12. Complete Example

### MCP Server Build (has Dockerfile)

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: AgentBuild
metadata:
  name: currency-mcp-server-build
  labels:
    kagenti.io/protocol: mcp
    kagenti.io/type: tool
spec:
  mode: dev
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent/mcp-server"
  buildOutput:
    image: "currency-mcp-server"
    imageTag: "v1.0.0"
    imageRegistry: "quay.io/myorg"
```

### Agent Build (uses Buildpacks)

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: AgentBuild
metadata:
  name: currency-agent-build
  labels:
    kagenti.io/framework: google-adk
    kagenti.io/protocol: a2a
    kagenti.io/type: agent
spec:
  mode: dev
  source:
    sourceRepository: "github.com/google/adk-samples.git"
    sourceSubfolder: "python/agents/currency-agent"
  buildOutput:
    image: "currency-agent"
    imageTag: "v1.0.0"
    imageRegistry: "quay.io/myorg"
```

### Agent Deployment (references build)

```yaml
apiVersion: agent.kagenti.dev/v1alpha1
kind: Agent
metadata:
  name: currency-agent
spec:
  imageSource:
    buildRef:
      name: currency-agent-build
  podTemplateSpec:
    spec:
      runtimeClassName: kata    # Kata VM isolation
```

---

## 13. Key Takeaway

> **AgentBuild automates the path from Git repository to running agent, bringing CI/CD best practices to AI agent deployment.**

---

## References

* [Kagenti GitHub](https://github.com/kagenti/kagenti)
* [Tekton Pipelines](https://tekton.dev/)
* [Buildah](https://buildah.io/)
* [Cloud Native Buildpacks](https://buildpacks.io/)

