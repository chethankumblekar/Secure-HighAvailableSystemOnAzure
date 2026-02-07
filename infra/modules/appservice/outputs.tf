output "app_service_plan_name" {
  value = azurerm_service_plan.this.name
  
}

output "app_app_name" {
  value = azurerm_linux_web_app.this.name
}

output "app_staging_name" {
  value = azurerm_linux_web_app_slot.staging.name
}

output "identity_principal_id" {
  value = azurerm_linux_web_app.this.identity[0].principal_id
}