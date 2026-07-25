output "vpc_id" {
  value = module.vpc.vpc_id
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "eks_cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "eks_oidc_issuer_url" {
  value = module.eks.oidc_issuer_url
}

output "lb_controller_role_arn" {
  value = module.iam.lb_controller_role_arn
}

output "finops_cost_reporter_role_arn" {
  value = module.iam.finops_cost_reporter_role_arn
}

output "waf_web_acl_arn" {
  value = module.waf.web_acl_arn
}

output "finops_ci_role_arn" {
  value = module.github_oidc.finops_ci_role_arn
}
