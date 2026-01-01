# Currency Agent Dockerfile
# Google ADK agent with MCP Gateway support for OPA policy enforcement

FROM python:3.11-slim

WORKDIR /app

# Install uv for fast package management
RUN pip install uv

# Copy project files
COPY pyproject.toml .
COPY currency_agent/ ./currency_agent/

# Install dependencies
RUN uv pip install --system .

# Expose A2A port
EXPOSE 10000

# Run the agent
CMD ["python", "-m", "currency_agent"]
