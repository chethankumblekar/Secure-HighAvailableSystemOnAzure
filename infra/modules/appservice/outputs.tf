output "app_service_plan_name" {
  value = azurerm_service_plan.this.name
  
}

output "app_app_name" {
  value = azurerm_linux_web_app.this.name
}

output "identity_principal_id" {
  value = azurerm_linux_web_app.this.identity[0].principal_id
}

output "staging_slot_name" {
  value = length(azurerm_linux_web_app_slot.staging) > 0 ? azurerm_linux_web_app_slot.staging[0].name : null
}