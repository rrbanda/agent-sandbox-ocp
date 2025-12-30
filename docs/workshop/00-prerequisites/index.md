# Module 00: Prerequisites

**Duration**: 45-60 minutes (one-time setup)  
**Persona**: 👷 Platform Admin

This module covers the **one-time cluster setup** required before running the workshop. If these components are already installed, you can skip to [Module 01: Introduction](../01-introduction/index.md).

## What You'll Install

| Component | Purpose | Installation |
|-----------|---------|--------------|
| OpenShift Sandboxed Containers | VM isolation (Kata) | Operator + KataConfig |
| Istio Service Mesh | Network egress control | Operator |
| Kuadrant | API policy enforcement | Operator |
| Kagenti | AI Agent platform | Helm chart |

## Prerequisites Checklist

Before starting, ensure you have:

- [ ] OpenShift 4.14+ cluster with admin access
- [ ] `oc` CLI installed ([Download](http://mirror.openshift.com/pub/openshift-v4/clients/ocp/4.18.20/openshift-client-linux-4.18.20.tar.gz))
- [ ] `helm` CLI installed ([Install Helm](https://helm.sh/docs/intro/install/))
- [ ] Cluster admin credentials

## Steps

| Step | Description | Time |
|------|-------------|------|
| [01 - Install OSC](01-install-osc.md) | OpenShift Sandboxed Containers Operator | 10 min |
| [02 - Install Istio](02-install-istio.md) | Istio Service Mesh | 10 min |
| [03 - Install Kuadrant](03-install-kuadrant.md) | Kuadrant Operator | 10 min |
| [04 - Deploy Kagenti](04-deploy-kagenti.md) | Kagenti Platform via Helm | 15 min |
| [05 - Verify Setup](05-verify-setup.md) | Confirm all components are running | 5 min |

---

## Quick Check: Is This Already Done?

Run this command to check if prerequisites are already installed:

```bash
echo "=== Checking Prerequisites ===" && \
echo "" && \
echo "1. OSC Operator:" && \
oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -i sandboxed || echo "   ❌ Not installed" && \
echo "" && \
echo "2. KataConfig:" && \
oc get kataconfig 2>/dev/null || echo "   ❌ Not configured" && \
echo "" && \
echo "3. Istio:" && \
oc get pods -n istio-system 2>/dev/null | grep istiod || echo "   ❌ Not installed" && \
echo "" && \
echo "4. Kuadrant:" && \
oc get pods -n kuadrant-system 2>/dev/null | grep authorino || echo "   ❌ Not installed" && \
echo "" && \
echo "5. Kagenti:" && \
oc get pods -n kagenti-system 2>/dev/null | grep kagenti-controller || echo "   ❌ Not installed"
```

If all components show as running, skip to [Module 01: Introduction](../01-introduction/index.md).

---

## Let's Begin

👉 [Step 01: Install OpenShift Sandboxed Containers](01-install-osc.md)

