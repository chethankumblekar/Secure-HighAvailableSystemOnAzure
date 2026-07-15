variable "project_name" { type = string }
variable "environment" { type = string }
variable "location" { type = string }
variable "resource_group_name" { type = string }
variable "tags" { type = map(string) }

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
