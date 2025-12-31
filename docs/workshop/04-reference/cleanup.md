# Cleanup

Remove all workshop resources from the cluster.

## Quick Cleanup

Delete the entire namespace (removes all resources):

```bash
# Delete the agent namespace
oc delete namespace currency-kagenti

# Optionally delete ADK Web UI
oc delete namespace adk-web
```

## Selective Cleanup

**Remove Agent Only:**
```bash
oc delete -f manifests/currency-kagenti/agent/
```

**Remove Security Policies Only:**
```bash
oc delete -f manifests/currency-kagenti/security/
```

**Remove Platform Setup:**
```bash
oc delete -f manifests/currency-kagenti/platform/
```

## Verify Cleanup

```bash
# Check namespace is gone
oc get namespace currency-kagenti
# Should return: Error from server (NotFound): namespaces "currency-kagenti" not found

# Check no resources remain
oc get all -n currency-kagenti
```

## Keep Platform Components

If you want to keep Kagenti, OSC, and other operators for future use, only delete the workshop-specific resources:

```bash
# Delete only the currency-kagenti namespace
oc delete namespace currency-kagenti

# Operators and cluster-wide components remain
oc get csv -n openshift-sandboxed-containers-operator
oc get pods -n kagenti-system
```

## Full Teardown (Including Operators)

!!! warning "Destructive"
    This removes all operators. Only do this if you're done with the entire platform.

```bash
# Delete Kagenti
helm uninstall kagenti -n kagenti-system

# Delete KataConfig
oc delete kataconfig example-kataconfig

# Delete operators via OperatorHub UI or:
oc delete csv -n openshift-sandboxed-containers-operator --all
```

