###############################################################
# GitHub Actions OIDC Provider + IAM Role for ECR access
#
# WHY OIDC? GitHub Actions can assume an AWS IAM role directly
# using a short-lived token — no static AWS credentials stored
# in GitHub secrets. Token expires when the workflow finishes.
#
# WHY a module? Multiple environments (dev, prod) may need their
# own OIDC role with different permissions. A module enforces
# consistency and allows per-environment scoping.
###############################################################

# WHY data source instead of resource? The OIDC provider is
# account-level — only one can exist per provider URL. Using
# a data source means we reference the existing one if it exists,
# rather than trying to create a duplicate and erroring.
resource "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"

  # WHY sts.amazonaws.com? This is the audience GitHub Actions
  # uses when requesting AWS credentials. AWS validates this
  # matches before allowing role assumption.
  client_id_list = ["sts.amazonaws.com"]

  # WHY this thumbprint? It's the SHA1 fingerprint of GitHub's
  # OIDC TLS certificate. AWS uses it to validate tokens are
  # genuinely from GitHub Actions and not forged.
  thumbprint_list = [
    "6938fd4d98bab03faadb97b34396831e3780aea1",
    "1c58a3a8518e8759bf075b76b750d4f2df264fcd",
  ]

  tags = var.tags
}

# Trust policy — only GitHub Actions from the specified repo
# can assume this role.
data "aws_iam_policy_document" "github_oidc_trust" {
  statement {
    effect  = "Allow"
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [aws_iam_openid_connect_provider.github.arn]
    }

    # WHY two conditions? "aud" validates the token audience.
    # "sub" validates the source repo — prevents other GitHub
    # repos from assuming this role even if they use OIDC.
    condition {
      test     = "StringEquals"
      variable = "token.actions.githubusercontent.com:aud"
      values   = ["sts.amazonaws.com"]
    }

    condition {
      test     = "StringLike"
      variable = "token.actions.githubusercontent.com:sub"
      values   = ["repo:${var.github_org}/${var.github_repo}:*"]
    }
  }
}

resource "aws_iam_role" "github_actions" {
  name               = "${var.prefix}-github-actions"
  description        = "Assumed by GitHub Actions via OIDC - no static credentials"
  assume_role_policy = data.aws_iam_policy_document.github_oidc_trust.json
  tags               = merge(var.tags, { Role = "github-actions" })
}

# ECR permissions — exactly what the CD pipeline needs to
# build and push Docker images. Nothing more.
data "aws_iam_policy_document" "ecr_push" {
  # WHY GetAuthorizationToken on *? This action does not support
  # resource-level permissions — AWS requires Resource = "*".
  statement {
    sid    = "ECRAuth"
    effect = "Allow"
    actions = [
      "ecr:GetAuthorizationToken",
    ]
    resources = ["*"]
  }

  # Scoped to the specific ECR repositories for this cluster.
  # WHY scoped? Prevents this role from pushing to unrelated repos
  # in the same AWS account.
  statement {
    sid    = "ECRPush"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
      "ecr:BatchGetImage",
      "ecr:GetDownloadUrlForLayer",
    ]
    resources = var.ecr_repository_arns
  }
}

resource "aws_iam_policy" "ecr_push" {
  name   = "${var.prefix}-github-actions-ecr-push"
  policy = data.aws_iam_policy_document.ecr_push.json
  tags   = var.tags
}

resource "aws_iam_role_policy_attachment" "ecr_push" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.ecr_push.arn
}
