output "cluster_name" { value = module.eks.cluster_name }
output "cluster_endpoint" { value = module.eks.cluster_endpoint }
output "ecr_urls" { value = module.ecr.repository_urls }
output "vpc_id" { value = module.vpc.vpc_id }
output "github_actions_role_arn" {
  description = "Add this to GitHub secrets as AWS_ROLE_ARN"
  value       = module.github_oidc.role_arn
}
