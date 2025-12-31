# What to Know About OpenShift Sandboxed Containers (OSC)

---

## 1. What OSC Is (and What It Is Not)

**OpenShift Sandboxed Containers (OSC)** is a security capability in **OpenShift** that allows selected Kubernetes workloads to run **inside lightweight virtual machines (VMs)** instead of directly on the host kernel.

OSC is implemented using **Kata Containers** and is integrated into OpenShift via CRI-O and Kubernetes `RuntimeClass`.

**Key idea**

> OSC uses VMs to protect the *platform*, not to expose VMs as workloads.

OSC preserves Kubernetes-native workflows (Pods, Jobs, logs, scheduling) while changing the runtime isolation boundary.

---

## 2. Why OSC Exists (The Core Problem)

Standard containers:

- Share the host kernel
- Are efficient and fast
- Increase risk when workloads are:
  - Untrusted or user-supplied
  - Third-party or externally sourced
  - Dynamically generated or executed

A container escape vulnerability can result in **node-level compromise**.

OSC exists to **reduce blast radius** by removing shared-kernel dependency for higher-risk workloads.

---

## 3. How OSC Changes the Runtime Model

### Standard container execution

```
Pod → Container → CRI-O → Host Kernel
```

### Sandboxed container execution

```
Pod → Kata Runtime → Lightweight VM → Guest Kernel → Container
```

This means:

- Each pod runs behind a **VM boundary**
- Containers no longer share the host kernel
- Kernel escape affects only the VM, not the node

### Architecture images

- [OpenShift Sandboxed Containers overview](https://docs.openshift.com/container-platform/latest/sandboxed_containers/)
- [Kata Containers architecture](https://katacontainers.io/docs/concepts/)

---

## 4. What "Using OSC for a Namespace" Really Means

OSC is **pod-level**, not namespace-level by default.

When we say:

> "This namespace is sandboxed using OSC"

We technically mean:

1. Pods in the namespace are **required** to specify:

```yaml
runtimeClassName: kata
```

2. Admission or policy prevents non-Kata pods from running
3. Scheduling ensures pods land on nodes that support Kata

The namespace becomes a **sandbox boundary through enforcement**, not automatically.

---

## 5. Why This Makes Sense for Sandbox Workloads

Using OSC for sandbox namespaces is appropriate when workloads:

* Execute untrusted or semi-trusted inputs
* Run third-party tools or binaries
* Perform parsing, conversion, scraping, testing, or build-style execution
* Operate in multi-tenant clusters
* Must not risk node compromise

### What OSC provides

* VM-grade isolation
* Reduced kernel-sharing risk
* Blast-radius containment
* No VM lifecycle management for users

---

## 6. What OSC Explicitly Does *Not* Do

OSC does **not**:

* Inspect or validate code
* Detect malware or malicious behavior
* Enforce policy by itself
* Replace SCCs, RBAC, NetworkPolicy, or SELinux
* Automatically sandbox all pods without enforcement

> OSC is a **runtime isolation control**, not a security policy engine.

---

## 7. OSC vs Full Virtual Machines

| Aspect        | Sandboxed Containers | OpenShift Virtualization |
| ------------- | -------------------- | ------------------------ |
| Primary unit  | Pod                  | VirtualMachine           |
| VM visibility | Hidden               | Explicit                 |
| OS management | Platform-owned       | User-owned               |
| Lifecycle     | Pod lifecycle        | VM lifecycle             |
| Use case      | Risk isolation       | Legacy / OS control      |

**Rule of thumb**

* OSC: "I want container workflows, but safer."
* VMs: "I need to manage an operating system."

### Comparison images

* [OpenShift Virtualization architecture](https://docs.openshift.com/container-platform/latest/virt/about-virt.html)
* [Kata vs KubeVirt conceptual comparison](https://katacontainers.io/docs/why-kata/)

---

## 8. When OSC Is a Good Fit (and When It's Not)

### Strong fit

* Sandbox execution environments
* Ephemeral or job-based workloads
* Multi-tenant shared clusters
* Higher-risk execution paths

### Caution / weaker fit

* GPU-heavy inference paths
* Ultra-low-latency services
* Long-lived stateful workloads

---

## 9. Relevance to AI Agents (Without Over-Claiming)

Modern AI agents often interact with **tools and execution environments** beyond simple model inference. While the LLM itself typically runs as a standard service, **some agent workflows include execution steps** that:

* Run third-party tools or binaries
* Process untrusted or user-supplied inputs
* Perform parsing, conversion, testing, or build-like operations
* Operate in shared or multi-tenant clusters

In these cases, the risk profile resembles traditional **sandbox workloads**, not pure inference services.

**OSC is relevant only for these execution components**, not for the LLM itself.

### What OSC helps with in agent-based systems

* Reduces blast radius if an execution step is compromised
* Avoids shared-kernel exposure for higher-risk tool execution
* Preserves Kubernetes-native workflows for tool execution
* Provides a consistent isolation boundary across tools

### What OSC does *not* address for agents

* Model behavior, prompt safety, or hallucinations
* Tool selection or authorization logic
* Client-side tool execution
* Policy enforcement or content inspection

> In agent architectures, OSC should be viewed as a **runtime isolation control for execution workloads**, not as an "AI security feature."

---

## 10. A Defensible Technical Statement

> OpenShift Sandboxed Containers allow higher-risk workloads to run behind a lightweight VM boundary while preserving Kubernetes-native workflows. By requiring pods in sandbox namespaces to use the Kata runtime, we reduce the impact of container escape vulnerabilities and limit node-level blast radius without introducing full VM lifecycle management.

---

## 11. Key Takeaway

> **OSC is not about making containers smarter — it's about making failures safer.**

---

## References / Sources

* [Red Hat Documentation – OpenShift Sandboxed Containers](https://docs.openshift.com/container-platform/latest/sandboxed_containers/)
* [Kata Containers Project](https://katacontainers.io/)
* [CNCF Kata Containers Overview](https://www.cncf.io/projects/kata-containers/)
* [Red Hat Blog – OpenShift Sandboxed Containers](https://www.redhat.com/en/blog/openshift-sandboxed-containers)
* [OpenShift Virtualization (KubeVirt)](https://docs.openshift.com/container-platform/latest/virt/)

