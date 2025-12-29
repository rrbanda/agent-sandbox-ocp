#!/bin/bash
# Enable Istio sidecar injection for required namespaces

set -e

echo "Enabling Istio for kuadrant-system..."
oc label namespace kuadrant-system istio-discovery=enabled istio-injection=enabled --overwrite

echo "Enabling Istio for mcp-system..."
oc label namespace mcp-system istio-discovery=enabled istio-injection=enabled --overwrite

echo "Restarting Authorino..."
oc rollout restart deployment/authorino -n kuadrant-system

echo "Restarting MCP components..."
oc delete pods -n mcp-system --all

echo "Waiting for pods to be ready..."
sleep 30

echo "Checking status..."
oc get pods -n kuadrant-system -l authorino-resource=authorino
oc get pods -n mcp-system

echo "Done!"
