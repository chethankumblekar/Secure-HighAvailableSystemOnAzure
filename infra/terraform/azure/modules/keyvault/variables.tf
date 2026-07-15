variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tenant_id" { type = string }
variable "tags" { type = map(string) }


variable "workload_identity_principal_id" {
  description = "Object ID of the AKS kubelet identity that workloads use to read secrets"
  type        = string
}
variable "terraform_principal_id" {
  type        = string
  description = "Object ID of Terraform execution identity"
}