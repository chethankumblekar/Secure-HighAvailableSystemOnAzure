output "app_insights_connection_string" {
  value = azurerm_application_insights.this.connection_string
}

output "app_insights_name" {
  value = azurerm_application_insights.this.name
}