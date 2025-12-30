# Step 03: Install Kuadrant

**Time**: 10 minutes

## What You'll Do

Install Kuadrant for API policy enforcement. Kagenti uses Kuadrant's AuthPolicy with OPA to validate tool calls.

## Why This Is Needed

Kuadrant provides:
- **AuthPolicy**: Attach authorization rules to API routes
- **Authorino**: Policy decision engine with OPA support
- **Rate Limiting**: Protect against abuse (optional)

## Steps

### Option A: Install via Kagenti Dependencies (Recommended)

If you're installing Kagenti via Helm, Kuadrant is included in the `kagenti-deps` chart. Skip to [Step 04: Deploy Kagenti](04-deploy-kagenti.md).

### Option B: Install via OperatorHub

#### 1. Install Kuadrant Operator

1. Open OpenShift Console
2. Go to **Operators** → **OperatorHub**
3. Search for **"Kuadrant"**
4. Click **Install**
5. Accept defaults and click **Install**

#### 2. Create Kuadrant Instance

```bash
oc apply -f - <<EOF
apiVersion: kuadrant.io/v1beta1
kind: Kuadrant
metadata:
  name: kuadrant
  namespace: kuadrant-system
spec: {}
EOF
```

#### 3. Verify Installation

```bash
oc get pods -n kuadrant-system

# Expected output:
# NAME                                              READY   STATUS
# authorino-xxxxxxxxx-xxxxx                        1/1     Running
# kuadrant-operator-controller-manager-xxxxx       1/1     Running
# limitador-xxxxxxxxx-xxxxx                        1/1     Running
```

## Verify Kuadrant Is Ready

```bash
# Check Authorino is running
oc get pods -n kuadrant-system -l app=authorino

# Check AuthPolicy CRD is available
oc get crd authpolicies.kuadrant.io
```

---

👉 [Next: Deploy Kagenti](04-deploy-kagenti.md)

