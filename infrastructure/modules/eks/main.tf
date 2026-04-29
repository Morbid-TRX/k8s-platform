# WHY: The EKS module provisions the control plane, worker nodes, and all
# the IAM plumbing. EKS IAM is the #1 source of confusion — there are
# THREE separate roles and they're easy to mix up.
#
# Role 1 — eks_cluster_role: used BY the EKS control plane to call AWS APIs
#           (create ENIs, describe EC2, manage LBs on your behalf)
# Role 2 — eks_node_role: used BY EC2 worker nodes to pull ECR images
#           and register with the cluster
# Role 3 — IRSA roles: used BY pods to access specific AWS services
#           without giving every pod full node-level permissions

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
    tls = { source = "hashicorp/tls", version = "~> 4.0" }
  }
}

# ── Control Plane Role ───────────────────────────────────────────────────────

resource "aws_iam_role" "eks_cluster" {
  name = "${var.cluster_name}-cluster-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "eks.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  role       = aws_iam_role.eks_cluster.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
}

# ── KMS Key for Secret Encryption ───────────────────────────────────────────

resource "aws_kms_key" "eks" {
  description             = "EKS Secret Encryption - ${var.cluster_name}"
  deletion_window_in_days = 7
  enable_key_rotation     = true
  # WHY: Rotating the key annually is a security best practice and
  # costs nothing extra. Disable only if you have a specific reason.
  tags = var.tags
}

# ── EKS Cluster ─────────────────────────────────────────────────────────────

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version

  vpc_config {
    subnet_ids              = var.private_subnet_ids
    endpoint_private_access = true
    # WHY: Public access lets you run kubectl from your laptop.
    # CHANGE THIS to false in production — use a bastion or VPN instead.
    endpoint_public_access  = true
    public_access_cidrs     = var.allowed_cidr_blocks
  }

  encryption_config {
    provider {
      key_arn = aws_kms_key.eks.arn
    }
    # WHY: Encrypts K8s Secrets at rest in etcd. Without this, secrets
    # are just base64-encoded — anyone with etcd access can read them.
    resources = ["secrets"]
  }

  # WHY: These three log types catch the most important events:
  # api = all API calls, audit = who did what, authenticator = IAM auth issues.
  # scheduler and controllerManager are verbose — enable only for deep debugging.
  enabled_cluster_log_types = ["api", "audit", "authenticator"]

  depends_on = [aws_iam_role_policy_attachment.eks_cluster_policy]
  tags       = var.tags
}

# ── Node Group Role ──────────────────────────────────────────────────────────

resource "aws_iam_role" "eks_nodes" {
  name = "${var.cluster_name}-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "node_worker" {
  role       = aws_iam_role.eks_nodes.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
}

resource "aws_iam_role_policy_attachment" "node_ecr" {
  role       = aws_iam_role.eks_nodes.name
  # WHY: ReadOnly is enough — nodes only pull images, never push.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

resource "aws_iam_role_policy_attachment" "node_cni" {
  role       = aws_iam_role.eks_nodes.name
  # WHY: The VPC CNI plugin needs this to assign pod IPs from your VPC CIDR.
  # Without it pods can't get IP addresses and stay in Pending forever.
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
}

# ── Node Group ───────────────────────────────────────────────────────────────

resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "${var.cluster_name}-nodes"
  node_role_arn   = aws_iam_role.eks_nodes.arn
  subnet_ids      = var.private_subnet_ids

  # WHY: t3.medium (2 vCPU, 4GB RAM) is the minimum for a real platform stack.
  # t3.small runs out of memory once Prometheus is added.
  # CHANGE THIS to t3.large or m5.large for production workloads.
  instance_types = [var.node_instance_type]

  scaling_config {
    desired_size = var.node_desired
    min_size     = var.node_min
    # WHY: max=5 gives Karpenter room to burst without runaway costs.
    max_size     = var.node_max
  }

  update_config {
    # WHY: Replaces one node at a time during updates — keeps cluster available.
    max_unavailable = 1
  }

  # WHY: AL2 not AL2023 — most Helm charts are tested against AL2.
  # AL2023 has breaking changes in some tooling as of 2024.
  ami_type = "AL2_x86_64"

  depends_on = [
    aws_iam_role_policy_attachment.node_worker,
    aws_iam_role_policy_attachment.node_ecr,
    aws_iam_role_policy_attachment.node_cni,
  ]

  tags = var.tags
}

# ── OIDC Provider ────────────────────────────────────────────────────────────
# WHY: IRSA (IAM Roles for Service Accounts) lets individual pods assume
# IAM roles without sharing node-level credentials. This is how ArgoCD,
# External Secrets, and Karpenter authenticate to AWS securely.
# Without this, you'd have to give every pod on the node full AWS access.

data "tls_certificate" "eks" {
  url = aws_eks_cluster.main.identity[0].oidc[0].issuer
}

resource "aws_iam_openid_connect_provider" "eks" {
  client_id_list  = ["sts.amazonaws.com"]
  thumbprint_list = [data.tls_certificate.eks.certificates[0].sha1_fingerprint]
  url             = aws_eks_cluster.main.identity[0].oidc[0].issuer
  tags            = var.tags
}
