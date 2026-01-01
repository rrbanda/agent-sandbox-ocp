# Currency Agent Dockerfile
# Google ADK agent with MCP Gateway support for OPA policy enforcement
#
# NOTE: Kagenti pipeline replaces base image with UBI9
# The UBI9 python-311 image has Python 3.11 in /opt/app-root/bin/

FROM python:3.11-slim

# For UBI compatibility - use the app-root structure
WORKDIR /opt/app-root/src

# Copy project files first
COPY pyproject.toml .
COPY currency_agent/ ./currency_agent/

# Install dependencies using pip (more compatible with UBI)
# The --no-cache-dir reduces image size
RUN pip install --no-cache-dir .

# Expose A2A port
EXPOSE 10000

# Run the agent
CMD ["python", "-m", "currency_agent"]
