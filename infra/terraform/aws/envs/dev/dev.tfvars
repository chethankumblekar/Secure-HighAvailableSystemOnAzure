project_name = "tenantforge"
environment  = "dev"
region       = "eu-north-1"

vpc_cidr             = "10.20.0.0/16"
public_subnet_cidrs  = ["10.20.0.0/24", "10.20.1.0/24"]
private_subnet_cidrs = ["10.20.10.0/24", "10.20.11.0/24"]

eks_system_node_count         = 1
eks_system_node_instance_type = "t3.small"

tags = {
  owner       = "chethan"
  project     = "tenantforge"
  purpose     = "flagship platform-engineering project - AWS reference impl"
  costcontrol = "enabled"
}
