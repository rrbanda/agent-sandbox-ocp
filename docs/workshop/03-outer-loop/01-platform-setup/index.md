# Section 1: Platform Setup

**Duration**: 15 minutes | **Persona**: 👷 Platform Admin

As a Platform Admin, you'll configure the foundation for agent deployments: create a dedicated namespace, configure pipeline permissions, and set up secrets for builds.

## What You'll Apply

| File | Purpose |
|------|---------|
| `platform/00-namespace.yaml` | Create `currency-kagenti` namespace |
| `platform/00b-rbac-scc.yaml` | Grant pipeline build permissions |
| `platform/01-pipeline-template.yaml` | Define build pipeline steps |

## Step 1: Create Namespace

```bash
# Navigate to manifests directory
cd manifests/currency-kagenti

# Create the namespace
oc apply -f platform/00-namespace.yaml
```

Verify:
```bash
oc get namespace currency-kagenti
```

## Step 2: Configure Pipeline Permissions

AgentBuild uses Tekton pipelines that need special permissions to build container images:

```bash
# Apply RBAC and SCC bindings
oc apply -f platform/00b-rbac-scc.yaml

# Grant additional SCCs (requires cluster-admin)
oc adm policy add-scc-to-user pipelines-scc \
  system:serviceaccount:currency-kagenti:pipeline

oc adm policy add-scc-to-user container-build \
  system:serviceaccount:currency-kagenti:pipeline
```

## Step 3: Apply Pipeline Template

The pipeline template defines how AgentBuild constructs images:

```bash
oc apply -f platform/01-pipeline-template.yaml
```

This template supports:
- **Dockerfile builds** (using Buildah) - when Dockerfile exists
- **Buildpacks** - when no Dockerfile exists (auto-detect)

## Step 4: Create Required Secrets

### GitHub Token (for cloning repositories)

```bash
# Create GitHub token secret
oc create secret generic github-token-secret \
  --from-literal=token='ghp_your_github_token' \
  -n currency-kagenti
```

!!! tip "Getting a GitHub Token"
    1. Go to GitHub → Settings → Developer settings → Personal access tokens
    2. Create a token with `repo` scope
    3. Use that token in the command above

### Gemini API Key (for LLM access)

```bash
# Create Gemini API key secret
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY='your_gemini_api_key' \
  -n currency-kagenti
```

!!! tip "Getting a Gemini API Key"
    1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
    2. Create an API key
    3. Use that key in the command above

### Registry Credentials (for pushing images)

```bash
# Create registry credentials for Quay.io
oc create secret docker-registry quay-registry-secret \
  --docker-server=quay.io \
  --docker-username=your-quay-username \
  --docker-password=your-quay-password \
  -n currency-kagenti

# Link to pipeline service account
oc secrets link pipeline quay-registry-secret \
  --for=pull,mount -n currency-kagenti
```

## Verify Setup

```bash
# Check namespace
oc get namespace currency-kagenti

# Check secrets
oc get secrets -n currency-kagenti

# Check pipeline template
oc get configmap pipeline-template-dev -n currency-kagenti

# Check service account permissions
oc get rolebindings -n currency-kagenti | grep pipeline
```

Expected output:
```
NAME                        READY
currency-kagenti            Active

NAME                        TYPE
gemini-api-key              Opaque
github-token-secret         Opaque
quay-registry-secret        kubernetes.io/dockerconfigjson

NAME                        DATA
pipeline-template-dev       1
```

## What's Configured

| Component | Status | Purpose |
|-----------|--------|---------|
| Namespace |  Created | Isolated environment for agent workloads |
| Pipeline RBAC |  Configured | Allows Tekton to build images |
| Pipeline Template |  Applied | Defines build steps (git clone, buildah/buildpacks) |
| GitHub Secret |  Created | Authentication for git clone |
| Gemini Secret |  Created | API key for LLM access |
| Registry Secret |  Created | Push access to container registry |

## Platform Ready!

The platform is now ready for developers to deploy agents. As a developer, you can now create `AgentBuild` CRs to build images from Git, deploy `Agent` CRs with Kata isolation, and access deployed agents via Routes.

👉 [Section 2: Build with AgentBuild](../02-build-with-agentbuild/index.md)

