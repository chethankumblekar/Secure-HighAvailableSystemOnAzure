project_name = "tenantforge"
environment  = "dr"
location     = "South India"

vnet_cidr               = "10.20.0.0/16"
aks_subnet_cidr         = "10.20.1.0/24"
aks_system_node_count   = 1
aks_system_node_vm_size = "Standard_B2s"

tags = {
  owner       = "chethan"
  project     = "tenantforge"
  purpose     = "flagship platform-engineering project — DR drill"
  costcontrol = "enabled"
}
