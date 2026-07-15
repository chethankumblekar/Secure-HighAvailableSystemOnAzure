variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, dr)"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
}

variable "vnet_cidr" {
  description = "Address space for the VNet"
  type        = string
  default     = "10.10.0.0/16"
}

variable "aks_subnet_cidr" {
  description = "Address space for the AKS node subnet"
  type        = string
  default     = "10.10.1.0/24"
}

variable "aks_system_node_count" {
  description = "Node count for the AKS system pool (kept at 1 by default for cost)"
  type        = number
  default     = 1
}

variable "aks_system_node_vm_size" {
  description = "VM size for the AKS system pool; B-series is the cheapest burstable option"
  type        = string
  default     = "Standard_B2s"
}

