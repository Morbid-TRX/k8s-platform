# WHY: Separate directory per environment instead of workspaces.
# Workspaces share a backend — too easy to run apply against the wrong env.
# Separate directories = separate state files = safer.

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws        = { source = "hashicorp/aws",        version = "~> 5.0" }
    tls        = { source = "hashicorp/tls",        version = "~> 4.0" }
    kubernetes = { source = "hashicorp/kubernetes", version = "~> 2.0" }
    helm       = { source = "hashicorp/helm",       version = "~> 2.0" }
  }

  # WHY: Remote state in S3 means everyone shares the same state file.
  # CHANGE THIS: Update bucket and table names before running terraform init.
  # Run first:
  #   aws s3 mb s3://YOUR-BUCKET-NAME --region ap-southeast-1
  #   aws dynamodb create-table --table-name YOUR-TABLE-NAME \
  #     --attribute-definitions AttributeName=LockID,AttributeType=S \
  #     --key-schema AttributeName=LockID,KeyType=HASH \
  #     --billing-mode PAY_PER_REQUEST
  backend "s3" {
    bucket         = "CHANGE-ME-k8s-platform-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "ap-southeast-1"
    encrypt        = true
    dynamodb_table = "CHANGE-ME-k8s-platform-tflock"
  }
}

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = local.common_tags
  }
}

locals {
  cluster_name = "${var.project_name}-${var.environment}"

  common_tags = {
    Project     = var.project_name
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source       = "../../modules/vpc"
  cluster_name = local.cluster_name
  vpc_cidr     = var.vpc_cidr
  tags         = local.common_tags
}

module "eks" {
  source             = "../../modules/eks"
  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  private_subnet_ids = module.vpc.private_subnet_ids
  node_instance_type = var.node_instance_type
  node_desired       = var.node_desired
  node_min           = var.node_min
  node_max           = var.node_max
  tags               = local.common_tags
}

module "ecr" {
  source       = "../../modules/ecr"
  cluster_name = local.cluster_name
  services     = ["api-service", "worker-service"]
  tags         = local.common_tags
}

# WHY: Configured AFTER EKS is created using its outputs.
# Using exec instead of a static token means auth stays fresh —
# static tokens expire, exec tokens are regenerated on each call.
provider "kubernetes" {
  host                   = module.eks.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
  }
}

provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_ca_certificate)
    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name]
    }
  }
}
