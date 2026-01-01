# Currency MCP Server Dockerfile
# Provides the get_exchange_rate tool for currency conversion
#
# NOTE: Kagenti pipeline replaces base image with UBI9
# Using pip instead of uv for better UBI compatibility

FROM python:3.11-slim

# For UBI compatibility - use the app-root structure
WORKDIR /opt/app-root/src

# Allow statements and log messages to immediately appear in the logs
ENV PYTHONUNBUFFERED=1

# Copy project files
COPY pyproject.toml .
COPY server.py .

# Install dependencies using pip (more compatible with UBI)
RUN pip install --no-cache-dir fastmcp httpx

EXPOSE 8080

# Run the FastMCP server
CMD ["python", "server.py"]
