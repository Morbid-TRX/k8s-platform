# Changelog

All notable changes to this project will be documented here.
Format based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/).

## [Unreleased]

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

## [0.1.0] - 2026-04-30
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
