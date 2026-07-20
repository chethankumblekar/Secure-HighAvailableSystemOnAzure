variable "project_name" { type = string }
variable "environment" { type = string }
variable "tags" { type = map(string) }

variable "cluster_name" {
  description = "EKS cluster name, used to tag subnets for cluster/ELB auto-discovery"
  type        = string
}

variable "vpc_cidr" {
  description = "Address space for the VPC"
  type        = string
  default     = "10.20.0.0/16"
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.0.0/24", "10.20.1.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets, one per AZ"
  type        = list(string)
  default     = ["10.20.10.0/24", "10.20.11.0/24"]
}
