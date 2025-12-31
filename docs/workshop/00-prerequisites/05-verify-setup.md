# Step 05: Verify Setup

**Time**: 5 minutes

## What You'll Do

Confirm all prerequisite components are running before proceeding with the workshop.

## Verification Script

Run this comprehensive check:

```bash
#!/bin/bash
echo "=========================================="
echo "AI Agent Sandbox - Prerequisites Check"
echo "=========================================="
echo ""

# 1. OSC Operator
echo "1. OpenShift Sandboxed Containers Operator:"
if oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -q sandboxed; then
    echo "    Installed"
else
    echo "    Not installed"
fi

# 2. RuntimeClass
echo ""
echo "2. Kata RuntimeClass:"
if oc get runtimeclass kata 2>/dev/null; then
    echo "    Available"
else
    echo "   ⚠️  Not yet available (KataConfig may still be installing)"
fi

# 3. Istio
echo ""
echo "3. Istio Service Mesh:"
if oc get pods -n istio-system 2>/dev/null | grep -q istiod; then
    echo "    Running"
else
    echo "    Not installed"
fi

# 4. Kuadrant
echo ""
echo "4. Kuadrant (Authorino):"
if oc get pods -n kuadrant-system 2>/dev/null | grep -q authorino; then
    echo "    Running"
else
    echo "    Not installed"
fi

# 5. Kagenti Controller
echo ""
echo "5. Kagenti Controller:"
if oc get pods -n kagenti-system 2>/dev/null | grep -q kagenti-controller; then
    echo "    Running"
else
    echo "    Not installed"
fi

# 6. Kagenti UI
echo ""
echo "6. Kagenti UI:"
KAGENTI_UI=$(oc get route kagenti-ui -n kagenti-system -o jsonpath='{.spec.host}' 2>/dev/null)
if [ -n "$KAGENTI_UI" ]; then
    echo "    Available at: https://$KAGENTI_UI"
else
    echo "    Not available"
fi

# 7. Phoenix (Observability)
echo ""
echo "7. Phoenix (Observability):"
if oc get pods -n kagenti-system 2>/dev/null | grep -q phoenix; then
    echo "    Running"
else
    echo "   ⚠️  Not installed (optional)"
fi

echo ""
echo "=========================================="
echo "Prerequisites check complete!"
echo "=========================================="
```

## Expected Results

| Component | Status | Notes |
|-----------|--------|-------|
| OSC Operator |  Installed | Required for Kata |
| Kata RuntimeClass |  Available | May take 10+ min after KataConfig |
| Istio |  Running | Required for egress control |
| Kuadrant |  Running | Required for policy enforcement |
| Kagenti Controller |  Running | Manages Agent CRDs |
| Kagenti UI |  Available | Optional but useful |
| Phoenix |  Running | Optional observability |

## What If Something Is Missing?

| Missing Component | Action |
|-------------------|--------|
| OSC Operator | Go back to [Step 01](01-install-osc.md) |
| Kata RuntimeClass | Apply KataConfig - covered in [Module 02](../02-platform-setup/02-configure-kata.md) |
| Istio | Go back to [Step 02](02-install-istio.md) |
| Kuadrant | Go back to [Step 03](03-install-kuadrant.md) |
| Kagenti | Go back to [Step 04](04-deploy-kagenti.md) |

## Module Complete! 🎉

All prerequisites are installed. You're ready to start the workshop!

---

👉 [Continue to Module 01: Introduction](../01-introduction/index.md)

