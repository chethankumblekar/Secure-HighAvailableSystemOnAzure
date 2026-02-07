resource "arzurerm_log_analytics_workspace" "this" {
  name                = "${var.project_name}-log-analytics-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  tags                = var.tags
}

resource "azurerm_application_insights" "this" {
  name                = "${var.project_name}-app-insights-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  application_type     = "web"
  workspace_id = azurerm_log_analytics_workspace.this.id
  tags                = var.tags
}

resource "azurerm_monitor_metric_alert" "http_5xx" {
  name                = "${var.project_name}-${var.environment}-http5xx"
  resource_group_name = var.resource_group_name
  scopes              = [azurerm_application_insights.this.id]

  description = "Alert on HTTP 5xx errors"
  severity    = 3
  frequency   = "PT5M"
  window_size = "PT5M"

  criteria {
    metric_namespace = "Microsoft.Insights/components"
    metric_name      = "ServerExceptions"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 0
  }

  tags = var.tags
}