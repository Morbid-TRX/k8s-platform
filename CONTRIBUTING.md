# Contributing to k8s-platform

This document explains how to work on this project — environment setup,
branch workflow, running things locally, and how CI/CD works.

---

## Prerequisites

| Tool | Purpose | Install |
|------|---------|---------|
| Docker Desktop | kind cluster + container builds | https://docker.com |
| kubectl | Kubernetes CLI | `winget install Kubernetes.kubectl` |
| kind | Local Kubernetes cluster | `winget install Kubernetes.kind` |
| helm | Package manager for Kubernetes | `winget install Helm.Helm` |
| k9s | Kubernetes TUI (optional but useful) | `winget install derailed.k9s` |
| pre-commit | Local git hooks | `pip install pre-commit` |
| Terraform | Infrastructure provisioning | https://developer.hashicorp.com/terraform/install |
| aws-vault | Secure AWS credential storage | https://github.com/99designs/aws-vault |
| Git | Version control | https://git-scm.com |

---

## Initial setup

### 1. Clone the repo

```bash
git clone https://github.com/Morbid-TRX/k8s-platform.git
cd k8s-platform
```

### 2. Install pre-commit hooks

```bash
pre-commit install
```

Hooks that run on every commit:
- `trailing-whitespace` — removes trailing whitespace
- `end-of-file-fixer` — ensures files end with a newline
- `check-yaml` — validates YAML syntax
- `check-merge-conflict` — detects unresolved merge conflicts
- `detect-private-key` — scans for accidentally committed private keys
- `gitleaks` — scans for hardcoded secrets
- `helmlint` — lints Helm charts

### 3. Start the local cluster

Make sure Docker Desktop is running, then:

```bash
kind create cluster --name k8s-platform --config kind-config.yaml
```

### 4. Install the platform stack

Follow the Local Setup section in README.md — install NGINX ingress,
ArgoCD, observability stack, and Kyverno in order.

### 5. AWS setup (for infrastructure changes only)

For changes to `infrastructure/` you need:
- An AWS account (Free Tier is sufficient)
- aws-vault configured with an IAM user that can assume a deployment role

```bash
aws-vault add terraform-admin
aws-vault exec terraform-execution -- aws iam list-open-id-connect-providers
```

---

## Branch workflow

This project uses **branch protection** — you cannot push directly to `main`.
All changes must go through a pull request.

```
main (protected)
└── your-branch → PR → CI must pass → merge
```

### Naming conventions

| Type | Pattern | Example |
|------|---------|---------|
| Feature | `feat/description` | `feat/add-hpa-worker-service` |
| Bug fix | `fix/description` | `fix/promtail-dns-resolution` |
| Docs | `docs/description` | `docs/contributing` |
| Chore | `chore/description` | `chore/trigger-cd-pipeline` |

### Step-by-step

```bash
# 1. Always branch from latest main
git checkout main
git pull origin main
git checkout -b feat/your-feature

# 2. Make your changes, then commit
git add .
git commit -m "feat: describe what you did"
# pre-commit hooks run automatically here

# 3. If hooks auto-fix files, stage and re-commit
git add .
git commit -m "chore: apply pre-commit auto-fixes"

# 4. Push and open a PR
git push -u origin feat/your-feature
```

Open the PR on GitHub, wait for CI to pass, merge.

---

## CI/CD pipeline

### CI — runs on every push and PR

| Job | What it does | Blocks merge? |
|-----|-------------|--------------|
| pre-commit checks | Runs all pre-commit hooks | Yes |
| lint yaml files | Validates all YAML files | Yes |
| lint helm charts | Lints all Helm charts in `platform/` | Yes |

### CD — runs on push to main when `services/` changes

| Step | Tool | Details |
|------|------|---------|
| OIDC auth | aws-actions/configure-aws-credentials | Assumes IAM role — no static keys |
| ECR login | aws-actions/amazon-ecr-login | Authenticates Docker to ECR |
| Buildx setup | docker/setup-buildx-action | Enables GHA cache for Docker layers |
| Build + push | docker/build-push-action | Builds and pushes to ECR with versioned tag |

---

## Making infrastructure changes

All Terraform changes live in `infrastructure/`. The dev environment
is the only one currently active.

```bash
cd infrastructure/environments/dev
aws-vault exec terraform-execution -- terraform plan
aws-vault exec terraform-execution -- terraform apply
```

> Never run `terraform apply` without reviewing `terraform plan` first.
> The S3 buckets have `prevent_destroy = true` — they cannot be accidentally destroyed.

---

## Project structure

```
k8s-platform/
├── .github/workflows/     # CI and CD pipelines
├── infrastructure/        # Terraform — ECR, IAM, state backend
├── platform/              # Helm values + ArgoCD app definitions
├── tenants/               # Per-tenant Kubernetes configs
├── services/              # Microservice source code + Dockerfiles
├── docs/screenshots/      # Proof of deployment screenshots
└── kind-config.yaml       # Local cluster configuration
```

---

## Questions?

This is a solo learning project. Check the README for the high-level
overview and the CHANGELOG for what changed in each version.
