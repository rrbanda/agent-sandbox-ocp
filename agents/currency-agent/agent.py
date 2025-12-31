"""Currency Agent with MCP Gateway Support.

This agent connects to the MCP Gateway (Envoy) with proper Host header routing,
enabling OPA policy enforcement for tool calls.
"""
import logging
import os

from dotenv import load_dotenv
from google.adk.agents import LlmAgent
from google.adk.a2a.utils.agent_to_a2a import to_a2a
from google.adk.tools.mcp_tool import MCPToolset, StreamableHTTPConnectionParams

logger = logging.getLogger(__name__)
logging.basicConfig(format="[%(levelname)s]: %(message)s", level=logging.INFO)

load_dotenv()

SYSTEM_INSTRUCTION = (
    "You are a specialized assistant for currency conversions. "
    "Your sole purpose is to use the 'get_exchange_rate' tool to answer questions about currency exchange rates. "
    "If the user asks about anything other than currency conversion or exchange rates, "
    "politely state that you cannot help with that topic and can only assist with currency-related queries. "
    "Do not attempt to answer unrelated questions or use tools for other purposes."
)

# MCP Gateway configuration
MCP_SERVER_URL = os.getenv(
    "MCP_SERVER_URL",
    "http://mcp-gateway-istio.gateway-system.svc.cluster.local:8080/mcp"
)
MCP_HOST_HEADER = os.getenv("MCP_HOST_HEADER", "currency-mcp.mcp.local")

logger.info("--- 🔧 Connecting to MCP Gateway... ---")
logger.info(f"    URL: {MCP_SERVER_URL}")
logger.info(f"    Host Header: {MCP_HOST_HEADER}")
logger.info("--- 🤖 Creating ADK Currency Agent... ---")

root_agent = LlmAgent(
    model="gemini-2.5-flash",
    name="currency_agent",
    description="An agent that can help with currency conversions",
    instruction=SYSTEM_INSTRUCTION,
    tools=[
        MCPToolset(
            connection_params=StreamableHTTPConnectionParams(
                url=MCP_SERVER_URL,
                # Set Host header for MCP Gateway routing
                headers={
                    "Host": MCP_HOST_HEADER,
                }
            )
        )
    ],
)

# Make the agent A2A-compatible
a2a_app = to_a2a(root_agent, port=10000)
