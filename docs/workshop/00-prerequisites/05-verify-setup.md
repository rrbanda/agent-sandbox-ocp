# Step 05: Verify Setup

**Time**: 5 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Confirm all prerequisite components are installed and running before developers can start using the platform.

---

## Quick Check Script

Run this comprehensive verification:

```bash
#!/bin/bash
echo "==========================================="
echo "  AI Agent Sandbox - Prerequisites Check   "
echo "==========================================="
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_status() {
    if [ "$1" = "true" ]; then
        echo -e "${GREEN}✓ $2${NC}"
    else
        echo -e "${RED}✗ $2${NC}"
    fi
}

# 1. OSC Operator
echo "1. OpenShift Sandboxed Containers Operator"
OSC_INSTALLED=$(oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -c "Succeeded")
check_status "$([ $OSC_INSTALLED -gt 0 ] && echo true)" "Operator installed"

OSC_RUNNING=$(oc get pods -n openshift-sandboxed-containers-operator 2>/dev/null | grep -c "Running")
check_status "$([ $OSC_RUNNING -gt 0 ] && echo true)" "Controller running"

echo ""

# 2. Kagenti Platform
echo "2. Kagenti Platform"
KAGENTI_CRD=$(oc get crd agents.agent.kagenti.dev 2>/dev/null && echo "yes" || echo "no")
check_status "$([ "$KAGENTI_CRD" = "yes" ] && echo true)" "Agent CRD exists"

AGENTBUILD_CRD=$(oc get crd agentbuilds.agent.kagenti.dev 2>/dev/null && echo "yes" || echo "no")
check_status "$([ "$AGENTBUILD_CRD" = "yes" ] && echo true)" "AgentBuild CRD exists"

KAGENTI_CONTROLLER=$(oc get pods -n kagenti-system 2>/dev/null | grep -c "kagenti-controller.*Running")
check_status "$([ $KAGENTI_CONTROLLER -gt 0 ] && echo true)" "Controller running"

echo ""

# 3. Pipeline Infrastructure
echo "3. Pipeline Infrastructure (for AgentBuild)"
PIPELINE_CONFIGMAPS=$(oc get configmaps -n kagenti-system -l kagenti.operator.dev/tekton=step 2>/dev/null | grep -c "step")
check_status "$([ $PIPELINE_CONFIGMAPS -ge 3 ] && echo true)" "Pipeline step ConfigMaps ($PIPELINE_CONFIGMAPS found)"

echo ""

# 4. Istio Service Mesh
echo "4. Istio Service Mesh"
ISTIOD=$(oc get pods -n istio-system 2>/dev/null | grep -c "istiod.*Running")
check_status "$([ $ISTIOD -gt 0 ] && echo true)" "Istiod running"

echo ""

# 5. Kuadrant
echo "5. Kuadrant (Authorino)"
AUTHORINO=$(oc get pods -n kuadrant-system 2>/dev/null | grep -c "authorino.*Running")
check_status "$([ $AUTHORINO -gt 0 ] && echo true)" "Authorino running"

echo ""

# 6. Observability (Optional)
echo "6. Observability (Optional)"
PHOENIX=$(oc get pods -n kagenti-system 2>/dev/null | grep -c "phoenix.*Running")
check_status "$([ $PHOENIX -gt 0 ] && echo true)" "Phoenix running"

OTEL=$(oc get pods -n kagenti-system 2>/dev/null | grep -c "otel-collector.*Running")
check_status "$([ $OTEL -gt 0 ] && echo true)" "OTEL Collector running"

echo ""

# 7. URLs
echo "7. Access URLs"
KAGENTI_UI=$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$KAGENTI_UI" ]; then
    echo "   Kagenti UI: https://$KAGENTI_UI"
else
    echo "   Kagenti UI: Not exposed"
fi

PHOENIX_URL=$(oc get route phoenix -n kagenti-system -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$PHOENIX_URL" ]; then
    echo "   Phoenix:    https://$PHOENIX_URL"
else
    echo "   Phoenix:    Not exposed (use port-forward)"
fi

echo ""
echo "==========================================="
echo "  Prerequisites check complete!            "
echo "==========================================="
```

---

## Component-by-Component Verification

### 1. OSC Operator

```bash
# Operator installed and running
oc get csv -n openshift-sandboxed-containers-operator | grep sandboxed
oc get pods -n openshift-sandboxed-containers-operator

# KataConfig CRD available
oc get crd kataconfigs.kataconfiguration.openshift.io
```

### 2. Kagenti Platform

```bash
# CRDs exist
oc get crd | grep kagenti

# Controller running
oc get pods -n kagenti-system | grep kagenti-controller

# Helm releases
helm list -n kagenti-system
```

### 3. Pipeline Infrastructure

```bash
# Step ConfigMaps exist
oc get configmaps -n kagenti-system -l kagenti.operator.dev/tekton=step

# Tekton installed
oc get pods -n openshift-pipelines
```

### 4. Istio & Kuadrant

```bash
# Istio
oc get pods -n istio-system | grep istiod

# Kuadrant
oc get pods -n kuadrant-system | grep authorino
```

---

## Expected Results

| Component | Check | Status |
|-----------|-------|--------|
| **OSC Operator** | CSV in `Succeeded` state | ✓ Required |
| **OSC Operator** | Controller pod running | ✓ Required |
| **Kagenti** | Agent CRD exists | ✓ Required |
| **Kagenti** | AgentBuild CRD exists | ✓ Required |
| **Kagenti** | Controller running | ✓ Required |
| **Pipeline Steps** | 5+ ConfigMaps | ✓ Required for AgentBuild |
| **Istio** | Istiod running | ✓ Required |
| **Kuadrant** | Authorino running | ✓ Required |
| **Phoenix** | Pod running | ○ Optional |
| **OTEL** | Pod running | ○ Optional |

---

## What If Something Is Missing?

| Missing Component | Action |
|-------------------|--------|
| OSC Operator | Go to [Step 01: Install OSC](01-install-osc.md) |
| Kagenti CRDs | Go to [Step 04: Deploy Kagenti](04-deploy-kagenti.md) |
| Pipeline ConfigMaps | Reinstall Kagenti: `helm upgrade kagenti kagenti/kagenti -n kagenti-system --reuse-values` |
| Istio | Check Kagenti deps: `helm status kagenti-deps -n kagenti-system` |
| Kuadrant | Check Kagenti deps: `helm status kagenti-deps -n kagenti-system` |

---

## KataConfig Check

Note: `KataConfig` is **not applied** in prerequisites. It will be configured in [Module 02: Platform Setup](../02-platform-setup/02-configure-kata.md).

To check if Kata is already configured:

```bash
oc get kataconfig
oc get runtimeclass kata
```

If `kata` RuntimeClass exists, Kata is already configured.

---

## What Platform Admins Have Completed

After prerequisites, the platform provides:

| Capability | Status | Notes |
|------------|--------|-------|
| OSC Operator | ✓ Installed | Ready to apply KataConfig |
| Kagenti CRDs | ✓ Available | Agent, AgentBuild, Tool |
| Pipeline Infrastructure | ✓ Ready | For source-to-image builds |
| Istio | ✓ Running | For egress control |
| Kuadrant | ✓ Running | For API policies |

---

## What Developers Can Expect

Once prerequisites are verified, developers can:

1. ✓ Create AgentBuild CRs to build images from source
2. ✓ Create Agent CRs to deploy agents
3. ✓ Use Kata runtime for VM isolation (after KataConfig)
4. ✓ View traces in Phoenix
5. ✓ Access the Kagenti UI

---

## Module Complete! 🎉

All prerequisites are installed. You're ready to start the workshop!

---

## Next Steps

Choose your path:

| Path | Description |
|------|-------------|
| [Module 01: Introduction](../01-introduction/index.md) | Learn about AI agents and the security model |
| [Module 02: Platform Setup](../02-platform-setup/index.md) | Configure KataConfig and namespaces |
| [Module 03: Develop Agent](../03-develop-agent/index.md) | Build your first AI agent |

---

👉 [Continue to Module 01: Introduction](../01-introduction/index.md)
