variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }
variable "cluster_name" { type = string }
variable "public_subnet_ids" { type = list(string) }
variable "private_subnet_ids" { type = list(string) }

variable "kubernetes_version" {
  description = "Kubernetes version; null lets AWS pick the current default"
  type        = string
  default     = null
}

variable "system_node_count" {
  description = "Node count for the system node group (kept at 1 by default for cost)"
  type        = number
  default     = 1
}

variable "system_node_instance_type" {
  description = "Instance type for the system node group; t3.small is the cheapest viable size for EKS"
  type        = string
  default     = "t3.small"
}
