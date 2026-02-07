resource "azurerm_key_vault" "this" {
  name                = "${var.project_name}-${var.environment}-kv"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization = true

  soft_delete_retention_days = 7
  purge_protection_enabled  = false

  tags = var.tags
}

resource "azurerm_role_assignment" "app_kv_secrets_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_identity_principal_id
}

resource "azurerm_key_vault_secret" "sample" { // Sample secret
  name         = "sample-secret"
  value        = "portfolio-demo"
  key_vault_id = azurerm_key_vault.this.id
}