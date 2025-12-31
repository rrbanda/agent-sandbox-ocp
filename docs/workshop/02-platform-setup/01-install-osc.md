# Step 01: Verify OSC Installation

**Time**: 2 minutes  
**Persona**: 👷 Platform Admin

## What You'll Do

Verify that the OpenShift Sandboxed Containers (OSC) Operator was installed during the prerequisites phase.

---

## Prerequisite Check

The OSC Operator should have been installed in [Module 00: Prerequisites](../00-prerequisites/01-install-osc.md).

If not installed yet, go back and complete that step first.

---

## Quick Verification

```bash
echo "=== OSC Installation Check ===" && \
echo "" && \
echo "1. Operator CSV:" && \
oc get csv -n openshift-sandboxed-containers-operator 2>/dev/null | grep -E "sandboxed|NAME" && \
echo "" && \
echo "2. Operator Pods:" && \
oc get pods -n openshift-sandboxed-containers-operator 2>/dev/null | grep -E "controller|NAME" && \
echo "" && \
echo "3. KataConfig CRD Available:" && \
oc get crd kataconfigs.kataconfiguration.openshift.io >/dev/null 2>&1&& echo "   Yes" || echo "   No"
```

## Expected Output

| Check | Expected |
|-------|----------|
| CSV Phase | `Succeeded` |
| Controller Pod | `Running` |
| KataConfig CRD | `Yes` |

---

## What If It's Not Installed?

If any check fails, complete the installation:

👉 [Module 00: Install OSC](../00-prerequisites/01-install-osc.md)

---

## What's Different in This Module?

- **Module 00 (Prerequisites)**: Installs the OSC Operator
- **Module 02 (Platform Setup)**: Applies `KataConfig` to enable Kata on nodes

The next step configures the actual Kata runtime.

---

## Next Step

👉 [Step 02: Configure Kata Runtime](02-configure-kata.md)
