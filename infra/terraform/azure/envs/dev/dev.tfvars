project_name = "tenantforge"
environment  = "dev"
location     = "Central India"

vnet_cidr               = "10.10.0.0/16"
aks_subnet_cidr         = "10.10.1.0/24"
aks_system_node_count   = 1
aks_system_node_vm_size = "Standard_B2s"

tags = {
  owner       = "chethan"
  project     = "tenantforge"
  purpose     = "flagship platform-engineering project"
  costcontrol = "enabled"
}
