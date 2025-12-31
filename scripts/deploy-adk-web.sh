#!/bin/bash
# Deploy Google ADK Web UI on OpenShift
#
# This script deploys the ADK Web UI with the Currency Agent for visual demos.
# Reference: https://github.com/google/adk-web
#
# Usage:
#   ./scripts/deploy-adk-web.sh [GEMINI_API_KEY]
#
# If no API key is provided, the script will:
#   1. Check for GOOGLE_API_KEY environment variable
#   2. Try to copy from agent-sandbox namespace
#   3. Prompt for manual entry

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MANIFESTS_DIR="$SCRIPT_DIR/../manifests/adk-web"

echo "=============================================="
echo "  Google ADK Web UI - OpenShift Deployment"
echo "=============================================="
echo ""

# Check if logged in
if ! oc whoami &>/dev/null; then
  echo "ERROR: Not logged in to OpenShift. Run 'oc login' first."
  exit 1
fi

# Step 1: Create namespace
echo "=== Step 1: Creating namespace ==="
oc apply -f "$MANIFESTS_DIR/00-namespace.yaml"
echo ""

# Step 2: Set up Gemini API key
echo "=== Step 2: Configuring Gemini API key ==="

# Try to get key from different sources
if [ -n "$1" ]; then
  GEMINI_KEY="$1"
  echo "Using key from command line argument"
elif [ -n "$GOOGLE_API_KEY" ]; then
  GEMINI_KEY="$GOOGLE_API_KEY"
  echo "Using key from GOOGLE_API_KEY environment variable"
else
  # Try to copy from agent-sandbox namespace
  GEMINI_KEY=$(oc get secret gemini-api-key -n agent-sandbox -o jsonpath='{.data.GOOGLE_API_KEY}' 2>/dev/null | base64 -d 2>/dev/null || echo "")
  if [ -n "$GEMINI_KEY" ]; then
    echo "Using key from agent-sandbox namespace"
  else
    echo "Enter your Gemini API key (get one at https://aistudio.google.com/app/apikey):"
    read -s GEMINI_KEY
  fi
fi

if [ -z "$GEMINI_KEY" ]; then
  echo "ERROR: No API key provided. Please provide a Gemini API key."
  exit 1
fi

# Create or update secret
oc delete secret gemini-api-key -n adk-web 2>/dev/null || true
oc create secret generic gemini-api-key \
  --from-literal=GOOGLE_API_KEY="$GEMINI_KEY" \
  -n adk-web
echo " Gemini API key configured"
echo ""

# Step 3: Deploy ADK Server
echo "=== Step 3: Deploying ADK Server ==="
oc apply -f "$MANIFESTS_DIR/01-adk-server.yaml"
echo ""

# Step 4: Wait for deployment
echo "=== Step 4: Waiting for deployment ==="
echo "Note: First startup takes ~60s to install google-adk package"
oc rollout status deployment/adk-server -n adk-web --timeout=180s || true
echo ""

# Show status
echo "=============================================="
echo "  Deployment Status"
echo "=============================================="
echo ""
echo "Pods:"
oc get pods -n adk-web -l app=adk-server
echo ""

# Get URL
ADK_URL=$(oc get route adk-server -n adk-web -o jsonpath='{.spec.host}' 2>/dev/null)

echo "=============================================="
echo "   ADK Web UI Ready!"
echo "=============================================="
echo ""
echo "🌐 Web UI URL: https://$ADK_URL/dev-ui/"
echo ""
echo "Quick Test:"
echo "  1. Open the URL above in your browser"
echo "  2. Select 'currency_agent' from the dropdown"
echo "  3. Ask: 'What is 100 USD in EUR?'"
echo ""
echo "API Endpoints:"
echo "  • List agents: https://$ADK_URL/list-apps"
echo "  • Health:      https://$ADK_URL/health"
echo ""
