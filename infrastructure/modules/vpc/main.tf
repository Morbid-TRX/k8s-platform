# WHY: EKS needs a VPC with specific subnet tags so the AWS load balancer
# controller and Karpenter can discover subnets automatically. Without these
# tags, ingress creation and node provisioning silently fail.

terraform {
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

# WHY: We fetch available AZs dynamically so this works in any region
# without hardcoding zone names (e.g. ap-southeast-1a changes between accounts).
data "aws_availability_zones" "available" {
  state = "available"
}

locals {
  # WHY: 2 AZs is enough for dev. 3 gives better HA but triples NAT Gateway cost.
  azs = slice(data.aws_availability_zones.available.names, 0, 2)
}

resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true # WHY: Required for EKS node registration
  enable_dns_support   = true # WHY: Required for CoreDNS inside the cluster

  tags = merge(var.tags, {
    Name = "${var.cluster_name}-vpc"
  })
}

# WHY: Public subnets host the ALB. The tag kubernetes.io/role/elb=1 tells
# the AWS load balancer controller to use these for internet-facing LBs.
# Without this tag, ingress objects will get stuck pending forever.
resource "aws_subnet" "public" {
  count                   = length(local.azs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, count.index)
  availability_zone       = local.azs[count.index]
  map_public_ip_on_launch = true

  tags = merge(var.tags, {
    Name                                        = "${var.cluster_name}-public-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/elb"                    = "1"
  })
}

# WHY: Private subnets host EKS worker nodes. Nodes should never have public
# IPs — they reach the internet via NAT Gateway. The internal-elb tag allows
# internal load balancers to use these subnets.
resource "aws_subnet" "private" {
  count             = length(local.azs)
  vpc_id            = aws_vpc.main.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, count.index + 10)
  availability_zone = local.azs[count.index]

  tags = merge(var.tags, {
    Name                                        = "${var.cluster_name}-private-${local.azs[count.index]}"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
    "kubernetes.io/role/internal-elb"           = "1"
    # WHY: Karpenter uses this tag to discover which subnets to launch nodes in
    "karpenter.sh/discovery"                    = var.cluster_name
  })
}

resource "aws_internet_gateway" "main" {
  vpc_id = aws_vpc.main.id
  tags   = merge(var.tags, { Name = "${var.cluster_name}-igw" })
}

# WHY: One NAT Gateway per VPC (not per AZ) to save cost.
# CHANGE THIS for production: add count = length(local.azs) for HA.
# Cost impact: ~$32/mo per NAT Gateway.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.cluster_name}-nat-eip" })
}

resource "aws_nat_gateway" "main" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public[0].id
  tags          = merge(var.tags, { Name = "${var.cluster_name}-nat" })
  depends_on    = [aws_internet_gateway.main]
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.cluster_name}-public-rt" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.main.id
  }
  tags = merge(var.tags, { Name = "${var.cluster_name}-private-rt" })
}

resource "aws_route_table_association" "public" {
  count          = length(aws_subnet.public)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

resource "aws_route_table_association" "private" {
  count          = length(aws_subnet.private)
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}
