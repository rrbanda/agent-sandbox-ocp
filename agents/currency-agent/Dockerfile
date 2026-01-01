# Currency Agent Dockerfile
# Google ADK agent with MCP Gateway support for OPA policy enforcement
#
# NOTE: Kagenti pipeline replaces base image with UBI9

FROM python:3.11-slim

# For UBI compatibility - use the app-root structure
WORKDIR /opt/app-root/src

# Copy all project files (including README.md for pyproject.toml)
COPY . .

# Install dependencies using pip (more compatible with UBI)
RUN pip install --no-cache-dir .

# Expose A2A port
EXPOSE 10000

# Run the agent
CMD ["python", "-m", "currency_agent"]
