# Step 06: Configure Pipelines for AgentBuild

**Time**: 5 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Configure the namespace for Tekton pipeline builds, enabling the AgentBuild source-to-image workflow.

This step is **required** for developers to use AgentBuild CRs.

---

## What You'll Configure

| Component | Purpose |
|-----------|---------|
| Pipeline Template | Defines build steps for AgentBuild |
| GitHub Secret | Credentials for cloning repositories |
| Registry Secret | Credentials for pushing images |
| RBAC | Permissions for pipeline ServiceAccount |

---

## Step 1: Create Pipeline Template

The pipeline template tells Kagenti how to build container images:

```bash
cat <<'EOF' | oc apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: pipeline-template-dev
  namespace: agent-sandbox
  labels:
    app.kubernetes.io/name: kagenti-operator
    app.kubernetes.io/component: pipeline-template
    component.kagenti.ai/mode: dev
data:
  template.json: |
    {
      "name": "Development Pipeline",
      "namespace": "agent-sandbox",
      "description": "Pipeline for development builds",
      "requiredParameters": [
        "repo-url",
        "revision",
        "subfolder-path",
        "image"
      ],
      "steps": [
        {
          "name": "github-clone",
          "configMap": "github-clone-step",
          "enabled": true,
          "requiredParameters": ["repo-url"]
        },
        {
          "name": "folder-verification",
          "configMap": "check-subfolder-step",
          "enabled": true,
          "requiredParameters": ["subfolder-path"]
        },
        {
          "name": "dockerfile-check",
          "configMap": "check-dockerfile-step",
          "enabled": true,
          "requiredParameters": ["subfolder-path"]
        },
        {
          "name": "buildah-build",
          "configMap": "buildah-build-step",
          "enabled": true,
          "requiredParameters": ["image"],
          "whenExpressions": [
            {
              "input": "$(tasks.dockerfile-check.results.has-dockerfile)",
              "operator": "in",
              "values": ["true"]
            }
          ]
        },
        {
          "name": "buildpack-step",
          "configMap": "buildpack-step",
          "enabled": true,
          "requiredParameters": ["image"],
          "whenExpressions": [
            {
              "input": "$(tasks.dockerfile-check.results.has-dockerfile)",
              "operator": "in",
              "values": ["false"]
            }
          ]
        }
      ],
      "globalParameters": [
        {
          "name": "pipeline-timeout",
          "value": "20m"
        }
      ]
    }
EOF
```

---

## Step 2: Create GitHub Token Secret

For accessing Git repositories (even public repos may need this for rate limits):

```bash
oc create secret generic github-token-secret \
  --from-literal=token='ghp_your_github_token_here' \
  -n agent-sandbox
```

!!! tip "GitHub Token"
    Create a token at [GitHub Settings > Developer settings > Personal access tokens](https://github.com/settings/tokens).
    For public repos, only `public_repo` scope is needed.

---

## Step 3: Create Registry Secrets

For pushing built images to your registry:

=== "Quay.io"

    ```bash
    oc create secret docker-registry quay-registry-secret \
      --docker-server=quay.io \
      --docker-username=your-username \
      --docker-password=your-password \
      -n agent-sandbox
    ```

=== "GitHub Container Registry"

    ```bash
    oc create secret docker-registry ghcr-secret \
      --docker-server=ghcr.io \
      --docker-username=your-github-username \
      --docker-password=ghp_your_token \
      -n agent-sandbox
    ```

The pipeline also needs a `ghcr-token` secret for buildpack builds:

```bash
oc create secret docker-registry ghcr-token \
  --docker-server=quay.io \
  --docker-username=your-username \
  --docker-password=your-password \
  -n agent-sandbox
```

---

## Step 4: Configure Pipeline RBAC

Grant the pipeline ServiceAccount necessary permissions:

```bash
cat <<'EOF' | oc apply -f -
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: pipelines-scc-rolebinding
  namespace: agent-sandbox
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: pipelines-scc-clusterrole
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: agent-sandbox
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: openshift-pipelines-edit
  namespace: agent-sandbox
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: edit
subjects:
- kind: ServiceAccount
  name: pipeline
  namespace: agent-sandbox
EOF
```

---

## Step 5: Configure SCC for Builds

Building container images requires elevated privileges. A cluster admin must run:

```bash
# Add pipeline SA to pipelines-scc
oc adm policy add-scc-to-user pipelines-scc \
  system:serviceaccount:agent-sandbox:pipeline

# For buildah privileged builds (required)
oc adm policy add-scc-to-user privileged \
  system:serviceaccount:agent-sandbox:pipeline
```

!!! warning "Cluster Admin Required"
    These commands require `cluster-admin` privileges.

---

## Verification

Verify the setup:

```bash
# Check pipeline ServiceAccount exists
oc get sa pipeline -n agent-sandbox

# Check secrets exist
oc get secrets -n agent-sandbox | grep -E "github|registry|ghcr|quay"

# Check pipeline template
oc get configmap pipeline-template-dev -n agent-sandbox

# Check SCC assignment
oc adm policy who-can use scc pipelines-scc | grep agent-sandbox
```

---

## What's Next?

With pipelines configured, you're ready to:

1. Create AgentBuild CRs to build from source
2. Deploy agents using the built images
3. Watch automated builds in action

Continue to [Deploy Agent with AgentBuild](../04-deploy-and-test/01-deploy-agent.md).

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `permission denied` in builds | Add pipeline SA to `privileged` SCC |
| `secret not found` | Create the required secrets |
| Build stuck in `Pending` | Check PVC availability and node resources |
| Docker Hub rate limit | Pipeline auto-replaces with UBI images |

---

## Next Step

👉 [Module 03: Develop Agent](../03-develop-agent/index.md) (Developer workflow begins)

