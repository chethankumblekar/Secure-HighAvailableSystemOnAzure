module "resource_group" {
  source = "./modules/resource-group"

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
  
}

module "app_service" {
  source = "./modules/appservice"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
  app_insights_connection_string = module.monitoring.app_insights_connection_string
}

data "azurerm_client_config" "current" {}

module "keyvault" {
  source = "./modules/keyvault"

  project_name              = var.project_name
  environment               = var.environment
  location                  = var.location
  resource_group_name       = module.resource_group.name
  tenant_id                 = data.azurerm_client_config.current.tenant_id
  terraform_principal_id    = data.azurerm_client_config.current.object_id
  app_identity_principal_id = module.app_service.identity_principal_id
  tags                      = var.tags
}