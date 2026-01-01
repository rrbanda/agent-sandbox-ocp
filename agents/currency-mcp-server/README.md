# Currency MCP Server

A Model Context Protocol (MCP) server that provides the `get_exchange_rate` tool for currency conversion.

## Overview

This MCP server uses [FastMCP](https://github.com/jlowin/fastmcp) to expose a tool that fetches real-time exchange rates from the [Frankfurter API](https://www.frankfurter.app/).

## Tool: get_exchange_rate

Converts between currencies using real-time exchange rates.

**Arguments:**
- `currency_from` (str): Source currency code (e.g., "USD")
- `currency_to` (str): Target currency code (e.g., "EUR")
- `currency_date` (str): Date for rate or "latest" (default: "latest")

**Returns:**
```json
{
  "amount": 1.0,
  "base": "USD",
  "date": "2024-12-30",
  "rates": {"EUR": 0.96}
}
```

## Local Development

```bash
# Install dependencies
uv sync

# Run the server
uv run server.py

# Test the server (in another terminal)
uv run test_server.py
```

## Container Build

```bash
# Build the image
podman build -t currency-mcp-server .

# Run the container
podman run -p 8080:8080 currency-mcp-server
```

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `PORT` | `8080` | Port for the MCP server |

## License

Apache 2.0

