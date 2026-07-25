locals {
  cluster_name = "${var.project_name}-${var.environment}-eks"
}

module "vpc" {
  source = "./modules/vpc"

  project_name         = var.project_name
  environment          = var.environment
  tags                 = var.tags
  cluster_name         = local.cluster_name
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
}

module "eks" {
  source = "./modules/eks"

  project_name              = var.project_name
  environment               = var.environment
  tags                      = var.tags
  cluster_name              = local.cluster_name
  public_subnet_ids         = module.vpc.public_subnet_ids
  private_subnet_ids        = module.vpc.private_subnet_ids
  system_node_count         = var.eks_system_node_count
  system_node_instance_type = var.eks_system_node_instance_type
}

module "alb" {
  source = "./modules/alb"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

module "iam" {
  source = "./modules/iam"

  project_name              = var.project_name
  environment               = var.environment
  tags                      = var.tags
  oidc_provider_arn         = module.eks.oidc_provider_arn
  oidc_issuer_url           = module.eks.oidc_issuer_url
  lb_controller_policy_arn  = module.alb.lb_controller_policy_arn
  finops_reporter_namespace = "observability"
}

module "waf" {
  source = "./modules/waf"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
}

# Deliberately NOT torn down by the routine apply-demo-destroy cycle (see
# docs/demo-script.md's destroy step, which -targets everything except this
# module): an IAM role + OIDC provider cost $0 whether or not the cluster
# exists, and .github/workflows/finops-scheduled.yml needs this role to keep
# running as a standing guardrail even after VPC/EKS/ALB/WAF are destroyed.
module "github_oidc" {
  source = "./modules/github-oidc"

  project_name = var.project_name
  environment  = var.environment
  tags         = var.tags
  github_repo  = "chethankumblekar/tenantforge"
}
