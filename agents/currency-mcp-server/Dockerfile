# Currency MCP Server Dockerfile
# Provides the get_exchange_rate tool for currency conversion

# Use the official Python lightweight image
FROM python:3.13-slim

# Install uv for fast dependency management
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

