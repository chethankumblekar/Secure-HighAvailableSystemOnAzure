variable "project_name" {
  description = "Project name"
  type        = string
}

variable "environment" {
  description = "Environment name (dev, dr)"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "tags" {
  description = "Common resource tags"
  type        = map(string)
  default     = {}
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

variable "eks_system_node_count" {
  description = "Node count for the EKS system node group (kept at 1 by default for cost)"
  type        = number
  default     = 1
}

variable "eks_system_node_instance_type" {
  description = "Instance type for the EKS system node group; t3.small is the cheapest viable size for EKS"
  type        = string
  default     = "t3.small"
}
