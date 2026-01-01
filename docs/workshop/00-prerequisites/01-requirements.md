# OpenShift Requirements

**Duration**: 5 minutes

Before installing Kagenti and its dependencies, verify your OpenShift cluster meets these requirements.

---

## Cluster Requirements

| Requirement | Minimum | Recommended |
|-------------|---------|-------------|
| **OpenShift Version** | 4.14 | 4.16+ |
| **Worker Nodes** | 3 | 3+ |
| **Worker Node CPU** | 8 vCPU | 16 vCPU |
| **Worker Node Memory** | 32 GB | 64 GB |
| **Storage** | 100 GB | 200 GB |

!!! warning "Kata Containers require bare-metal or nested virtualization"
    Kata Containers run VMs inside pods. Your worker nodes must support virtualization:
    
    - **Bare-metal**: Works natively
    - **Cloud VMs**: Must have nested virtualization enabled
    - **AWS**: Use `.metal` instance types (e.g., `m5.metal`)
    - **Azure**: Use `Standard_D*_v3` with nested virtualization
    - **GCP**: Enable nested virtualization on instances

---

## Verify Cluster Access

```bash
# Check you're logged in
oc whoami
# Should return your username

# Check you have admin access
oc auth can-i create clusterrole
# Should return: yes

# Check cluster version
oc version
# OpenShift version should be 4.14+
```

---

## Check Network Configuration

Kagenti uses Istio in Ambient Mode, which requires OVN configuration:

```bash
# Check network type
oc get network.config/cluster -o jsonpath='{.spec.networkType}'
# Should return: OVNKubernetes
```

If using OVNKubernetes, enable routing via host:

```bash
oc patch network.operator.openshift.io cluster --type=merge \
  -p '{"spec":{"defaultNetwork":{"ovnKubernetesConfig":{"gatewayConfig":{"routingViaHost":true}}}}}'
```

---

## Check for Conflicting Operators

Kagenti installs its own cert-manager. If Red Hat's cert-manager is already installed, it will conflict.

```bash
# Check for existing cert-manager
oc get ns cert-manager-operator 2>/dev/null && echo "⚠️ cert-manager found - will need to remove"
oc get ns cert-manager 2>/dev/null && echo "⚠️ cert-manager found - will need to remove"
```

If cert-manager exists, you'll remove it in the Kagenti installation step.

---

## Required CLI Tools

### oc (OpenShift CLI)

```bash
# Check if installed
oc version

# Install if missing (macOS)
brew install openshift-cli

# Install if missing (Linux)
curl -LO https://mirror.openshift.com/pub/openshift-v4/clients/ocp/latest/openshift-client-linux.tar.gz
tar xzf openshift-client-linux.tar.gz
sudo mv oc kubectl /usr/local/bin/
```

### helm (Helm CLI)

```bash
# Check if installed
helm version

# Install if missing (macOS)
brew install helm

# Install if missing (Linux)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

!!! note "Helm version"
    Kagenti requires Helm v3.18+ for OCI chart support.

---

## Required Credentials

Prepare these credentials before proceeding:

### GitHub Personal Access Token

1. Go to [GitHub → Settings → Developer settings → Personal access tokens](https://github.com/settings/tokens)
2. Create a new token (classic) with `repo` scope
3. Save the token securely

### Gemini API Key

1. Go to [Google AI Studio](https://aistudio.google.com/app/apikey)
2. Create an API key
3. Save the key securely

### Quay.io Credentials (for container registry)

1. Go to [Quay.io](https://quay.io) and sign in
2. Go to Account Settings → Generate Encrypted Password
3. Save your username and encrypted password

---

## Create Secrets File

Create the secrets file that the installation script will use:

```bash
cat > /tmp/.secrets.yaml << 'EOF'
secrets:
  githubUser: YOUR_GITHUB_USERNAME
  githubToken: "ghp_your_github_token"
  openaiApiKey: "your_gemini_or_openai_key"
  quayUser: YOUR_QUAY_USERNAME
  quayToken: "your_quay_encrypted_password"
EOF
```

Edit `/tmp/.secrets.yaml` with your actual credentials.

---

## Pre-flight Summary

| Check | Command | Expected |
|-------|---------|----------|
| Logged in | `oc whoami` | Your username |
| Admin access | `oc auth can-i create clusterrole` | `yes` |
| OpenShift 4.14+ | `oc version` | Server Version: 4.14+ |
| OVN network | `oc get network.config/cluster -o jsonpath='{.spec.networkType}'` | `OVNKubernetes` |
| Helm installed | `helm version` | v3.18+ |
| Secrets file | `cat /tmp/.secrets.yaml` | Contains your credentials |

---

## Ready for Installation

Your cluster meets the requirements. Next, we'll install OpenShift Sandboxed Containers.

👉 **[Step 2: Install OSC](02-install-osc.md)**

