# Step 04: Understand Containerization

**Time**: 5 minutes

## What You'll Do

Understand how the Currency Agent and MCP server are containerized for deployment to Kubernetes.

---

## Container Strategy

The Currency Agent has two components that need containerization:

| Component | Has Dockerfile | Build Method |
|-----------|----------------|--------------|
| MCP Server | ✅ Yes | Dockerfile (buildah) |
| ADK Agent | ❌ No | Buildpacks |

---

## MCP Server Dockerfile

The MCP server includes a Dockerfile (`mcp-server/Dockerfile`):

```dockerfile
# Use the official Python lightweight image
FROM python:3.13-slim

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install the project into /app
COPY . /app
WORKDIR /app

# Allow statements and log messages to immediately appear in the logs
ENV PYTHONUNBUFFERED=1

# Install dependencies
RUN uv sync --locked

EXPOSE $PORT

# Run the FastMCP server
CMD ["uv", "run", "server.py"]
```

### Key Points

| Line | Purpose |
|------|---------|
| `FROM python:3.13-slim` | Lightweight Python base image |
| `COPY --from=...uv:latest` | Multi-stage copy of `uv` package manager |
| `uv sync --locked` | Install exact versions from `uv.lock` |
| `CMD ["uv", "run", "server.py"]` | Start the MCP server |

---

## Agent Container (No Dockerfile)

The agent directory doesn't have a Dockerfile. This is intentional - Kagenti's AgentBuild uses **Buildpacks** to automatically create a container.

When AgentBuild detects no Dockerfile:

1. Analyzes `pyproject.toml` for dependencies
2. Detects it's a Python project
3. Uses Cloud Native Buildpacks to build
4. Creates an optimized container image

---

## How AgentBuild Works

```
┌─────────────────────────────────────────────────────────────────────────┐
│                    AgentBuild Pipeline                                   │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  1. git-clone                                                           │
│     Clone source from GitHub                                            │
│              ↓                                                          │
│  2. check-dockerfile                                                    │
│     Does Dockerfile exist?                                              │
│              ↓                                                          │
│     ┌───────┴───────┐                                                  │
│     │               │                                                   │
│     ↓               ↓                                                   │
│  YES: buildah    NO: buildpacks                                         │
│  Build with      Auto-detect and                                        │
│  Dockerfile      build                                                  │
│              ↓                                                          │
│  3. Push to registry                                                    │
│     image-registry.openshift-image-registry.svc:5000/...               │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## UBI Images for Production

For production deployments on OpenShift, we modify the Dockerfile to use UBI (Universal Base Image) instead of Docker Hub images:

```dockerfile
# Production: Use Red Hat UBI
FROM registry.access.redhat.com/ubi9/python-312:latest

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /uvx /bin/

# Install the project into /app
COPY . /app
WORKDIR /app

# Fix permissions for OpenShift
RUN chmod -R 777 /app || true

ENV PYTHONUNBUFFERED=1

# Install as root (UBI requirement)
USER root
RUN uv sync --locked

EXPOSE 8080

CMD ["uv", "run", "server.py"]
```

### Why UBI?

| Concern | Docker Hub | UBI |
|---------|------------|-----|
| Rate limits | ❌ 100 pulls/6h | ✅ Unlimited |
| OpenShift certified | ❌ No | ✅ Yes |
| Security updates | ⚠️ Varies | ✅ Red Hat supported |
| Enterprise support | ❌ No | ✅ Yes |

---

## Container Startup Commands

### MCP Server

```bash
# Dockerfile CMD
uv run server.py

# Equivalent to:
python -m mcp_server.server
# Starts FastMCP on port 8080
```

### ADK Agent

```bash
# Buildpack default or explicit
uv run uvicorn currency_agent.agent:a2a_app --host 0.0.0.0 --port 10000

# Exposes A2A server on port 10000
```

---

## Environment Variables

Both containers need environment configuration:

### MCP Server

```yaml
env:
  - name: PORT
    value: "8080"
  - name: HOST
    value: "0.0.0.0"
```

### ADK Agent

```yaml
env:
  - name: GOOGLE_API_KEY
    valueFrom:
      secretKeyRef:
        name: gemini-api-key
        key: GOOGLE_API_KEY
  - name: MCP_SERVER_URL
    value: "http://currency-mcp-server:8080/mcp"
  - name: PORT
    value: "10000"
  - name: HOST
    value: "0.0.0.0"
```

---

## Building Locally (Optional)

If you want to build containers locally:

```bash
# Build MCP Server
cd mcp-server
docker build -t currency-mcp-server:latest .

# Run locally
docker run -p 8080:8080 currency-mcp-server:latest
```

For the agent (using buildpacks):

```bash
# Install pack CLI
# https://buildpacks.io/docs/tools/pack/

# Build with buildpacks
pack build currency-agent:latest --builder paketobuildpacks/builder:base
```

---

## What Happens in Kagenti

When you create an `AgentBuild` CR, Kagenti:

1. Creates a `PipelineRun` in Tekton
2. Clones the source from Git
3. Detects build method (Dockerfile or Buildpacks)
4. Builds the container image
5. Pushes to the specified registry
6. Updates the `AgentBuild` status with the image reference

You can then create an `Agent` CR that references the build.

---

## Summary

| Component | Build Method | Base Image | Port |
|-----------|--------------|------------|------|
| MCP Server | Dockerfile + buildah | UBI Python 3.12 | 8080 |
| ADK Agent | Buildpacks | Auto-detected | 10000 |

---

## Module Complete! 🎉

You now understand:

- ✅ How the Currency Agent works (ADK + MCP + A2A)
- ✅ How to run it locally
- ✅ How to test with the A2A client
- ✅ How it's containerized for deployment

---

## Next Step

Deploy the agent to OpenShift using Kagenti.

👉 [Module 04: Deploy & Test](../04-deploy-and-test/index.md)
