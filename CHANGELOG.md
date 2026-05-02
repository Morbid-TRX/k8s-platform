# Changelog

All notable changes to this project will be documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

---

## [Unreleased]

---

## [0.3.0] - 2026-05-02

### Added
- AWS ECR repositories — `k8s-platform-dev/api-service` and `k8s-platform-dev/worker-service`
  - KMS encrypted, immutable tags, scan on push, lifecycle policies (keep 10 tagged, expire untagged after 7 days)
- GitHub Actions OIDC provider + IAM role (`k8s-platform-dev-github-actions`)
  - No static AWS credentials — short-lived tokens only
  - Role scoped strictly to `repo:Morbid-TRX/k8s-platform:*`
  - IAM policy scoped to this cluster's ECR repos only
- Terraform `github-oidc` module — reusable OIDC + IAM pattern
- Terraform `ecr` module — ECR repositories with lifecycle policies
- Remote Terraform state — S3 bucket (encrypted, versioned) + DynamoDB lock table
- Variable validation rules across all Terraform modules
- CD pipeline (`cd.yaml`) — builds and pushes Docker images to ECR via OIDC
- Docker Buildx setup for GHA cache support
- README updated — AWS infrastructure section, CD pipeline table, project structure tree, screenshots

### Fixed
- Removed `latest-dev` mutable tag — conflicts with ECR immutable tag policy
- Removed auto-commit step — branch protection conflict, deferred until EKS is running
- Fixed Node.js 20 deprecation warnings — forced Node.js 24 via `FORCE_JAVASCRIPT_ACTIONS_TO_NODE24`
- Fixed semicolon syntax in Terraform variables files
- Fixed em dash in IAM role description — AWS only accepts ASCII

### Security
- Zero static AWS credentials in GitHub secrets
- ECR images scanned on every push via `scan_on_push = true`
- IAM role assumption scoped to specific GitHub repo via OIDC conditions
- ECR push permissions scoped to this cluster's repositories only

---

## [0.2.0] - 2026-04-30

### Added
- ArgoCD GitOps apps for tenant-a, tenant-b, api-service, worker-service
- Horizontal Pod Autoscaler for api-service (CPU 70%, memory 80%)
- Kyverno security policies — disallow root, disallow latest tag, require resource limits, require pod labels
- tenant-b namespace with NetworkPolicy, RBAC, ResourceQuota
- worker-service deployment with graceful shutdown
- Loki + Promtail log aggregation wired to Grafana

### Fixed
- Promtail DNS resolution — corrected Loki service URL
- Loki version compatibility with Grafana (upgraded to 2.9.3)
- topologySpreadConstraints removed for local kind compatibility

---

## [0.1.0] - 2026-04-29

### Added
- Initial project scaffold — Terraform modules for VPC, EKS, ECR
- Helm values for ArgoCD, Prometheus, Grafana, Loki, Kyverno, ingress-nginx
- Multi-tenant namespace configs with NetworkPolicy and RBAC
- API and worker microservices with Dockerfiles
- GitHub Actions CI pipeline — pre-commit, yamllint, helm lint
- GitHub Actions CD pipeline — build, push to ECR, GitOps update
- kind cluster config for local development
- NGINX ingress controller
- ArgoCD installed and accessible
- Prometheus + Grafana observability stack
- Architecture decision records

---

[Unreleased]: https://github.com/Morbid-TRX/k8s-platform/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/Morbid-TRX/k8s-platform/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/Morbid-TRX/k8s-platform/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/Morbid-TRX/k8s-platform/releases/tag/v0.1.0
