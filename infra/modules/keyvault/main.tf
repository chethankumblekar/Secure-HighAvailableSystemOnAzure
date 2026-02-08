resource "random_string" "kv_suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_key_vault" "this" {
  name                = "${var.environment}-kv-${random_string.kv_suffix.result}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tenant_id           = var.tenant_id
  sku_name            = "standard"

  enable_rbac_authorization = true
  soft_delete_retention_days = 7
  purge_protection_enabled  = false

  tags = var.tags
}

resource "azurerm_role_assignment" "terraform_kv_admin" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.terraform_principal_id
  depends_on = [ azurerm_key_vault.this ]
}

resource "azurerm_role_assignment" "app_kv_secrets_reader" {
  scope                = azurerm_key_vault.this.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.app_identity_principal_id

  depends_on = [ azurerm_key_vault.this ]
}

resource "azurerm_key_vault_secret" "sample" {
  name         = "sample-secret"
  value        = "portfolio-demo"
  key_vault_id = azurerm_key_vault.this.id

  depends_on = [
    azurerm_role_assignment.terraform_kv_admin
  ]
}