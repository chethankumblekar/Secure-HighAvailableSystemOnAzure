variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }

variable "oidc_provider_arn" {
  description = "ARN of the EKS cluster's IAM OIDC provider"
  type        = string
}

variable "oidc_issuer_url" {
  description = "OIDC issuer URL of the EKS cluster"
  type        = string
}

variable "lb_controller_policy_arn" {
  description = "ARN of the IAM policy granting AWS Load Balancer Controller permissions"
  type        = string
}

variable "lb_controller_namespace" {
  description = "Kubernetes namespace the AWS Load Balancer Controller service account lives in"
  type        = string
  default     = "kube-system"
}

variable "lb_controller_service_account_name" {
  description = "Kubernetes service account name the AWS Load Balancer Controller uses"
  type        = string
  default     = "aws-load-balancer-controller"
}

variable "finops_reporter_namespace" {
  description = "Kubernetes namespace the FinOps cost-reporter CronJob's service account lives in"
  type        = string
  default     = "observability"
}

variable "finops_reporter_service_account_name" {
  description = "Kubernetes service account name the FinOps cost-reporter CronJob uses"
  type        = string
  default     = "cost-reporter"
}
