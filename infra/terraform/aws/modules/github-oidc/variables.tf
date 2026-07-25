variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }

variable "github_repo" {
  description = "GitHub repo allowed to assume this role, as owner/repo"
  type        = string
}

variable "create_oidc_provider" {
  description = "Whether to create the GitHub Actions OIDC provider. IAM allows only one per URL per account: if this account already has one (from another project), apply fails with EntityAlreadyExists. Set this false and re-apply to reuse the existing provider instead."
  type        = bool
  default     = true
}
