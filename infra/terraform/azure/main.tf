module "resource_group" {
  source = "./modules/resource-group"

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags
}

module "network" {
  source = "./modules/network"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
  vnet_cidr           = var.vnet_cidr
  aks_subnet_cidr     = var.aks_subnet_cidr
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
}

module "aks" {
  source = "./modules/aks"

  project_name               = var.project_name
  environment                = var.environment
  location                   = var.location
  resource_group_name        = module.resource_group.name
  tags                       = var.tags
  subnet_id                  = module.network.aks_subnet_id
  log_analytics_workspace_id = module.monitoring.log_analytics_workspace_id
  system_node_count          = var.aks_system_node_count
  system_node_vm_size        = var.aks_system_node_vm_size
}

data "azurerm_client_config" "current" {}

module "keyvault" {
  source = "./modules/keyvault"

  project_name                   = var.project_name
  environment                    = var.environment
  location                       = var.location
  resource_group_name            = module.resource_group.name
  tenant_id                      = data.azurerm_client_config.current.tenant_id
  terraform_principal_id         = data.azurerm_client_config.current.object_id
  workload_identity_principal_id = module.aks.kubelet_identity_object_id
  tags                           = var.tags
}

module "policy" {
  source = "./modules/policy"

  resource_group_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${module.resource_group.name}"
  required_tag_name = "owner"
}
