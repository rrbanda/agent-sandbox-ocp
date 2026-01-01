# Currency MCP Server Dockerfile
# Provides the get_exchange_rate tool for currency conversion
#
# NOTE: Kagenti pipeline replaces base image with UBI9

FROM python:3.11-slim

WORKDIR /opt/app-root/src

ENV PYTHONUNBUFFERED=1

# Copy only the needed files
COPY server.py .
COPY pyproject.toml .

# Install dependencies directly (simpler for single-file scripts)
RUN pip install --no-cache-dir fastmcp httpx

EXPOSE 8080

CMD ["python", "server.py"]
