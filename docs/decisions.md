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

---

## ADR-007: Direct pushes to main for solo developer

**Decision**: Allow direct pushes to main in some cases
**Why**:
- Branch protection requires at least 1 approver to merge a PR
- As a solo developer you cannot approve your own PRs
- Workaround: untick "Do not allow bypassing" so repo owner can push directly
- In a real team this would be locked down — every change goes through PR + review

---

## ADR-008: imagePullPolicy: Never for local kind development

**Decision**: Use locally built images with imagePullPolicy: Never
**Alternatives considered**: LocalStack ECR, kind registry
**Why**:
- kind clusters cannot pull from ECR without real AWS credentials
- Building locally and loading with `kind load docker-image` is the fastest iteration loop
- imagePullPolicy: Never tells K8s to never attempt a registry pull
- CHANGE THIS to IfNotPresent or Always when deploying to EKS with real ECR URLs

---

## ADR-009: Single replica for worker-service

**Decision**: worker-service runs with replicas: 1
**Alternatives considered**: replicas: 2 with leader election
**Why**:
- Worker processes jobs sequentially — multiple replicas would process the same jobs
- In production with a real queue (SQS, Kafka), you'd scale workers based on queue depth via KEDA
- HPA is not applied to worker-service for the same reason — scale based on queue, not CPU

---

## ADR-010: Kyverno over OPA/Gatekeeper

**Decision**: Kyverno for policy enforcement
**Alternatives considered**: OPA Gatekeeper, Pod Security Admission
**Why**:
- Kyverno policies are plain YAML — no need to learn Rego
- Better docs and more active community as of 2024
- Pod Security Admission is built-in but less flexible — can't enforce custom rules like required labels
- OPA is more powerful but overkill for this project scope
