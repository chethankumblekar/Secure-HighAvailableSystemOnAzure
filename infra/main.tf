module "resource_group" {
  source = "./modules/resource-group"

  project_name = var.project_name
  environment  = var.environment
  location     = var.location
  tags         = var.tags
}

module "app_service" {
  source = "./modules/appservice"

  project_name        = var.project_name
  environment         = var.environment
  location            = var.location
  resource_group_name = module.resource_group.name
  tags                = var.tags
}

data "azurerm_client_config" "current" {}

module "keyvault" {
  source = "./modules/keyvault"

  project_name            = var.project_name
  environment             = var.environment
  location                = var.location
  resource_group_name     = module.resource_group.name
  tenant_id               = data.azurerm_client_config.current.tenant_id
  app_identity_principal_id = module.appservice.identity_principal_id
  tags                    = var.tags
}

