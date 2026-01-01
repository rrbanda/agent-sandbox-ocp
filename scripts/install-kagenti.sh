#!/bin/bash
# =============================================================================
# Kagenti Installation Script for OpenShift
# =============================================================================
#
# This script installs Kagenti on OpenShift with all required fixes.
#
# Prerequisites:
#   - oc CLI logged in as cluster-admin
#   - helm CLI installed (v3.18+)
#   - Secrets file (default: /tmp/.secrets.yaml)
#
# Usage:
#   ./install-kagenti.sh
#
# Environment Variables:
#   SECRETS_FILE      - Path to secrets file (default: /tmp/.secrets.yaml)
#   KAGENTI_VERSION   - Kagenti version (default: 0.2.0-alpha.2)
#   GATEWAY_VERSION   - MCP Gateway version (default: 0.4.0)
#   SKIP_CERT_MANAGER - Set to "true" to skip cert-manager removal check
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SECRETS_FILE="${SECRETS_FILE:-/tmp/.secrets.yaml}"
KAGENTI_VERSION="${KAGENTI_VERSION:-0.2.0-alpha.2}"
GATEWAY_VERSION="${GATEWAY_VERSION:-0.4.0}"

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# =============================================================================
# Pre-flight Checks
# =============================================================================
log_step "Pre-flight Checks"

# Check oc
if ! command -v oc &> /dev/null; then
    log_error "oc CLI not found. Please install OpenShift CLI."
    exit 1
fi

# Check helm
if ! command -v helm &> /dev/null; then
    log_error "helm CLI not found. Please install Helm v3.18+."
    exit 1
fi

# Check cluster login
if ! oc whoami &> /dev/null; then
    log_error "Not logged into OpenShift. Run: oc login <cluster>"
    exit 1
fi
log_info "Logged in as: $(oc whoami)"

# Check secrets file
if [ ! -f "$SECRETS_FILE" ]; then
    log_error "Secrets file not found: $SECRETS_FILE"
    echo ""
    echo "Create it with:"
    echo "cat > $SECRETS_FILE << 'EOF'"
    echo 'secrets:'
    echo '  githubUser: YOUR_GITHUB_USERNAME'
    echo '  githubToken: "YOUR_GITHUB_PAT"'
    echo '  openaiApiKey: "YOUR_API_KEY"'
    echo '  quayUser: YOUR_QUAY_USERNAME    # Optional'
    echo '  quayToken: "YOUR_QUAY_TOKEN"    # Optional'
    echo 'EOF'
    exit 1
fi
log_info "Secrets file: $SECRETS_FILE"

# Get cluster domain
DOMAIN=apps.$(oc get dns cluster -o jsonpath='{ .spec.baseDomain }')
log_info "Cluster domain: $DOMAIN"
log_info "Kagenti version: $KAGENTI_VERSION"
log_info "MCP Gateway version: $GATEWAY_VERSION"

# =============================================================================
# Step 1: Check for existing cert-manager
# =============================================================================
log_step "Step 1: Check for existing cert-manager"

# Kagenti installs its own cert-manager. If Red Hat's version exists, it conflicts.
if oc get ns cert-manager-operator &> /dev/null 2>&1; then
    log_warn "Found existing cert-manager-operator (Red Hat's version)"
    log_warn "Kagenti installs its own cert-manager, so this must be removed."
    
    if [ "$SKIP_CERT_MANAGER" != "true" ]; then
        read -p "Remove existing cert-manager? [y/N] " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing cert-manager..."
            oc delete deploy cert-manager cert-manager-cainjector cert-manager-webhook -n cert-manager 2>/dev/null || true
            oc delete service cert-manager cert-manager-webhook -n cert-manager 2>/dev/null || true
            oc delete subscription -n cert-manager-operator --all 2>/dev/null || true
            oc delete csv -n cert-manager-operator --all 2>/dev/null || true
            oc delete ns cert-manager cert-manager-operator --wait=false 2>/dev/null || true
            log_info "Waiting for namespaces to terminate..."
            sleep 15
        else
            log_error "Cannot proceed with existing cert-manager. Exiting."
            exit 1
        fi
    fi
else
    log_info "No existing cert-manager found (good - Kagenti will install it)"
fi

# =============================================================================
# Step 2: Configure OVN for Istio Ambient Mode
# =============================================================================
log_step "Step 2: Configure OVN for Istio Ambient Mode"

# Istio Ambient Mode requires routingViaHost for proper traffic routing
NETWORK_TYPE=$(oc get network.config/cluster -o jsonpath='{.spec.networkType}')
log_info "Network type: $NETWORK_TYPE"

if [ "$NETWORK_TYPE" == "OVNKubernetes" ]; then
    log_info "Enabling routingViaHost for Istio Ambient Mode..."
    oc patch network.operator.openshift.io cluster --type=merge \
      -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}' 2>/dev/null || true
    log_info "OVN configured"
else
    log_warn "Non-OVN network detected. Istio Ambient Mode may not work correctly."
fi

# =============================================================================
# Step 3: Install Gateway API CRDs
# =============================================================================
log_step "Step 3: Install Gateway API CRDs"

# CRITICAL: kagenti-deps does NOT install these, but MCP Gateway requires them
if oc get crd httproutes.gateway.networking.k8s.io &> /dev/null 2>&1; then
    log_info "Gateway API CRDs already installed"
else
    log_info "Installing Gateway API CRDs (required by MCP Gateway)..."
    kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.2.0/standard-install.yaml
    
    # Verify
    if ! oc get crd httproutes.gateway.networking.k8s.io &> /dev/null 2>&1; then
        log_error "Gateway API CRDs installation failed"
        exit 1
    fi
    log_info "Gateway API CRDs installed"
fi

# =============================================================================
# Step 4: Create gateway-system namespace (pre-labeled for Helm)
# =============================================================================
log_step "Step 4: Create gateway-system namespace"

# CRITICAL: Kagenti chart expects this namespace to exist
# BUT it also wants to "manage" it, so we pre-label it for Helm adoption
if oc get ns gateway-system &> /dev/null 2>&1; then
    log_info "gateway-system namespace already exists, ensuring Helm labels..."
else
    log_info "Creating gateway-system namespace..."
    oc create namespace gateway-system
fi

# Add Helm labels so kagenti chart can adopt it
log_info "Adding Helm management labels..."
oc label namespace gateway-system app.kubernetes.io/managed-by=Helm --overwrite
oc annotate namespace gateway-system meta.helm.sh/release-name=kagenti --overwrite
oc annotate namespace gateway-system meta.helm.sh/release-namespace=kagenti-system --overwrite
log_info "Namespace ready for Kagenti"

# =============================================================================
# Step 5: Install kagenti-deps
# =============================================================================
log_step "Step 5: Install kagenti-deps"

log_info "This installs: Istio, Keycloak, cert-manager, Tekton, OTEL, ToolHive"
log_info "This may take 5-10 minutes..."

# Note: SPIRE is disabled because SpiffeCSIDriver CRDs don't exist on OpenShift
helm install --create-namespace -n kagenti-system kagenti-deps \
  oci://ghcr.io/kagenti/kagenti/kagenti-deps \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set components.spire.enabled=false \
  --set domain=${DOMAIN} \
  --timeout 20m

log_info "kagenti-deps installed"

# =============================================================================
# Step 6: Install MCP Gateway
# =============================================================================
log_step "Step 6: Install MCP Gateway"

helm install mcp-gateway oci://ghcr.io/kagenti/charts/mcp-gateway \
  --create-namespace --namespace mcp-system \
  --version $GATEWAY_VERSION \
  --timeout 10m

log_info "MCP Gateway installed"

# =============================================================================
# Step 7: Fix MCP Gateway broker-router (Chart Bug Workaround)
# =============================================================================
log_step "Step 7: Fix MCP Gateway broker-router"

# The mcp-gateway chart 0.4.0 passes --mcp-broker-config-address flag, 
# but the current image doesn't support it. This causes CrashLoopBackOff.
# We apply the fix proactively since it's always needed for chart 0.4.0.
# 
# Bug report: https://github.com/kagenti/mcp-gateway/issues (to be filed)

log_info "Applying fix: removing unsupported --mcp-broker-config-address flag..."

oc patch deployment mcp-gateway-broker-router -n mcp-system --type='json' -p='[
  {"op": "replace", "path": "/spec/template/spec/containers/0/command", "value": [
    "./mcp_gateway",
    "--mcp-gateway-config=/config/config.yaml",
    "--mcp-broker-public-address=0.0.0.0:8080",
    "--mcp-router-address=0.0.0.0:50051",
    "--mcp-gateway-public-host=mcp.127-0-0-1.sslip.io",
    "--log-level=-4"
  ]}
]'

log_info "Waiting for pod to restart..."
sleep 10
log_info "Fix applied"

# =============================================================================
# Step 8: Install Kagenti Platform
# =============================================================================
log_step "Step 8: Install Kagenti Platform"

helm upgrade --install -n kagenti-system \
  -f $SECRETS_FILE kagenti oci://ghcr.io/kagenti/kagenti/kagenti \
  --version $KAGENTI_VERSION \
  --set openshift=true \
  --set domain=${DOMAIN} \
  --set agentOAuthSecret.spiffePrefix=spiffe://${DOMAIN}/sa \
  --set uiOAuthSecret.useServiceAccountCA=false \
  --set agentOAuthSecret.useServiceAccountCA=false \
  --timeout 15m

log_info "Kagenti Platform installed"

# =============================================================================
# Step 9: Wait for all pods
# =============================================================================
log_step "Step 9: Waiting for pods to be ready"

sleep 30

# =============================================================================
# Step 10: Print access information
# =============================================================================
log_step "Installation Complete!"

echo ""
echo -e "${GREEN}Access URLs:${NC}"
echo "  Kagenti UI:    https://$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo "  Keycloak:      https://$(oc get route keycloak -n keycloak -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo "  MCP Inspector: https://$(oc get route mcp-inspector -n kagenti-system -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo "  Phoenix:       https://$(oc get route phoenix -n kagenti-system -o jsonpath='{.status.ingress[0].host}' 2>/dev/null)"
echo ""
echo -e "${GREEN}Keycloak Credentials:${NC}"
oc get secret keycloak-initial-admin -n keycloak -o go-template='  Username: {{.data.username | base64decode}}
  Password: {{.data.password | base64decode}}{{"\n"}}' 2>/dev/null || echo "  (credentials not yet available)"
echo ""
echo -e "${GREEN}Pod Status:${NC}"
echo "  kagenti-system:"
oc get pods -n kagenti-system --no-headers 2>/dev/null | grep -v Completed | awk '{print "    " $1 ": " $3}' || true
echo "  mcp-system:"
oc get pods -n mcp-system --no-headers 2>/dev/null | awk '{print "    " $1 ": " $3}' || true
echo ""
log_info "Open the Kagenti UI to get started!"
