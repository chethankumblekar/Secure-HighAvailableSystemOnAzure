variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }
variable "subnet_id" { type = string }

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for AKS diagnostics"
  type        = string
}

variable "sku_tier" {
  description = "AKS control plane SKU tier"
  type        = string
  default     = "Free"
}

variable "kubernetes_version" {
  description = "Kubernetes version; null lets Azure pick the current default"
  type        = string
  default     = null
}

variable "system_node_count" {
  description = "Node count for the system pool (kept at 1 by default for cost)"
  type        = number
  default     = 1
}

variable "system_node_vm_size" {
  description = "VM size for the system pool; B-series is the cheapest burstable option"
  type        = string
  default     = "Standard_B2s"
}
