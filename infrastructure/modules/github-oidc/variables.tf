variable "prefix" {
  description = "Prefix for IAM resource names (e.g. k8s-platform-dev)"
  type        = string
  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9\\-]{1,28}[a-z0-9]$", var.prefix))
    error_message = "prefix must be lowercase letters, numbers, and hyphens (2-30 chars)."
  }
}

variable "github_org" {
  description = "GitHub organisation or username"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9\\-]+$", var.github_org))
    error_message = "github_org must contain only letters, numbers, and hyphens."
  }
}

variable "github_repo" {
  description = "GitHub repository name"
  type        = string
  validation {
    condition     = can(regex("^[a-zA-Z0-9_\\.\\-]+$", var.github_repo))
    error_message = "github_repo must contain only letters, numbers, underscores, dots, and hyphens."
  }
}

variable "ecr_repository_arns" {
  description = "List of ECR repository ARNs this role can push to"
  type        = list(string)
  validation {
    condition = alltrue([
      for arn in var.ecr_repository_arns :
      can(regex("^arn:aws:ecr:[a-z0-9-]+:[0-9]{12}:repository/.+$", arn))
    ])
    error_message = "All entries must be valid ECR repository ARNs."
  }
}

variable "tags" {
  description = "Tags applied to all IAM resources"
  type        = map(string)
  default     = {}
}
