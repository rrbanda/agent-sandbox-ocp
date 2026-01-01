#!/bin/bash
# =============================================================================
# Kagenti Uninstall Script for OpenShift
# =============================================================================
#
# This script completely removes Kagenti and all its components.
#
# Usage:
#   ./uninstall-kagenti.sh
#
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# Check cluster login
if ! oc whoami &> /dev/null; then
    log_error "Not logged into OpenShift. Run: oc login <cluster>"
    exit 1
fi

log_step "Kagenti Uninstall Script"
log_info "Logged in as: $(oc whoami)"

echo ""
log_warn "This will remove ALL Kagenti components including:"
echo "  - Kagenti Platform (kagenti-system)"
echo "  - MCP Gateway (mcp-system, gateway-system)"
echo "  - Keycloak (keycloak)"
echo "  - Istio (istio-system, istio-cni, istio-ztunnel)"
echo "  - cert-manager"
echo "  - Tekton pipelines"
echo ""

read -p "Are you sure you want to proceed? [y/N] " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Aborted."
    exit 0
fi

# =============================================================================
# Step 1: Uninstall Helm releases
# =============================================================================
log_step "Step 1: Uninstall Helm releases"

log_info "Uninstalling kagenti..."
helm uninstall kagenti -n kagenti-system 2>/dev/null || log_warn "kagenti not found"

log_info "Uninstalling mcp-gateway..."
helm uninstall mcp-gateway -n mcp-system 2>/dev/null || log_warn "mcp-gateway not found"

log_info "Uninstalling kagenti-deps..."
helm uninstall kagenti-deps -n kagenti-system 2>/dev/null || log_warn "kagenti-deps not found"

# =============================================================================
# Step 2: Delete namespaces
# =============================================================================
log_step "Step 2: Delete namespaces"

NAMESPACES=(
    "kagenti-system"
    "mcp-system"
    "gateway-system"
    "keycloak"
    "istio-system"
    "istio-cni"
    "istio-ztunnel"
    "cert-manager"
)

for NS in "${NAMESPACES[@]}"; do
    if oc get ns $NS &> /dev/null 2>&1; then
        log_info "Deleting namespace: $NS"
        oc delete ns $NS --wait=false 2>/dev/null || true
    else
        log_info "Namespace $NS does not exist"
    fi
done

# =============================================================================
# Step 3: Clean up CRDs
# =============================================================================
log_step "Step 3: Clean up CRDs (optional)"

log_info "Removing Kagenti CRDs..."
oc get crd -o name | grep -E "kagenti|toolhive" | xargs -r oc delete 2>/dev/null || true

log_info "Removing MCP CRDs..."
oc get crd -o name | grep -E "mcp.kagenti" | xargs -r oc delete 2>/dev/null || true

# Note: We don't remove Gateway API CRDs as they might be used by other components
log_warn "Gateway API CRDs NOT removed (may be used by other components)"

# =============================================================================
# Step 4: Wait for namespaces to terminate
# =============================================================================
log_step "Step 4: Waiting for namespaces to terminate"

log_info "This may take a few minutes..."

for i in {1..30}; do
    TERMINATING=$(oc get ns 2>/dev/null | grep -E "kagenti|mcp-system|gateway-system|keycloak|istio|cert-manager" | grep Terminating | wc -l)
    
    if [ "$TERMINATING" -eq 0 ]; then
        log_info "All namespaces terminated"
        break
    fi
    
    echo -n "."
    sleep 5
done
echo ""

# Check for any stuck namespaces
STUCK=$(oc get ns 2>/dev/null | grep -E "kagenti|mcp-system|gateway-system|keycloak|istio|cert-manager" | grep Terminating)
if [ -n "$STUCK" ]; then
    log_warn "Some namespaces are still terminating:"
    echo "$STUCK"
    echo ""
    log_info "To force delete stuck namespaces, run:"
    echo "  NAMESPACE=<stuck-namespace>"
    echo '  oc get namespace $NAMESPACE -o json | jq ".spec.finalizers = []" | oc replace --raw "/api/v1/namespaces/$NAMESPACE/finalize" -f -'
fi

# =============================================================================
# Step 5: Verify cleanup
# =============================================================================
log_step "Step 5: Verify cleanup"

log_info "Remaining Kagenti-related namespaces:"
oc get ns | grep -E "kagenti|mcp-system|gateway-system|keycloak|istio|cert-manager" || echo "  None found (clean!)"

log_info "Remaining Helm releases:"
helm list -A | grep -E "kagenti|mcp-gateway" || echo "  None found (clean!)"

echo ""
log_step "Uninstall Complete!"
log_info "Cluster is ready for a fresh Kagenti installation."

