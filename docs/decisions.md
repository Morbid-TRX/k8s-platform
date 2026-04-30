# Architecture Decision Records

This document explains the key decisions made in this project and why.

---

## ADR-001: Use kind for local Kubernetes instead of minikube

**Decision**: kind (Kubernetes IN Docker)
**Alternatives considered**: minikube, k3s, Docker Desktop K8s
**Why**:
- kind runs inside Docker which is already installed
- Closer to real multi-node clusters — you can simulate multiple nodes locally
- Used by the Kubernetes project itself for CI testing
- minikube spins up a VM which is heavier and slower on Windows

---

## ADR-002: Use ArgoCD for GitOps instead of Flux

**Decision**: ArgoCD
**Alternatives considered**: Flux, Jenkins X
**Why**:
- ArgoCD has a UI — easier to understand what's deployed and why
- More widely adopted in job descriptions as of 2024
- Better for portfolio — screenshots of the ArgoCD dashboard are impressive

---

## ADR-003: Namespace-per-tenant for multi-tenancy

**Decision**: One Kubernetes namespace per tenant
**Alternatives considered**: vCluster, separate clusters
**Why**:
- Namespace isolation is free and built into Kubernetes
- Separate clusters per tenant is expensive and overkill for this scale
- vCluster is powerful but adds complexity not needed at this stage
- NetworkPolicy + RBAC + ResourceQuota at namespace level is the industry standard

---

## ADR-004: Helm for platform tooling, raw manifests for app workloads

**Decision**: Helm for platform (ArgoCD, Prometheus), raw YAML for services
**Alternatives considered**: Helm for everything, Kustomize
**Why**:
- Platform tools have official Helm charts — no reason to reinvent
- Raw YAML for our own services keeps things readable and explicit
- Kustomize adds a learning curve without much benefit at this stage

---

## ADR-005: Local-first, cloud-later approach

**Decision**: Build and validate everything locally with kind before touching AWS
**Alternatives considered**: Build directly on EKS
**Why**:
- EKS control plane costs $72/mo even with zero workloads
- Local kind cluster is free and fast to iterate on
- Same manifests work on both — only the ingress and storage classes differ

---

## ADR-006: Configure yamllint rules to match project standards

**Decision**: Disable document-start, truthy, comments-indentation rules. Set line-length to 150.
**Alternatives considered**: Fix every file to match default yamllint rules
**Why**:
- GitHub Actions uses `on:` which yamllint flags as truthy but is 100% valid
- `---` document start is optional in YAML — enforcing it everywhere is pedantic
- 120 char line limit is too short for GitHub Actions expressions
- Configure the tool to match the project, not the other way around
