resource "azurerm_service_plan" "this" {
  name                = "${var.project_name}-${var.environment}-plan"
  resource_group_name = var.resource_group_name
  location            = var.location

  os_type  = "Linux"
  sku_name = "F1" 

  tags = var.tags
}

resource "azurerm_linux_web_app" "this" {
  name                = "${var.project_name}-${var.environment}-app"
  resource_group_name = var.resource_group_name
  location            = var.location
  service_plan_id     = azurerm_service_plan.this.id

  https_only = true

  identity {
    type = "SystemAssigned"
  }

  site_config {
    always_on = false
    application_stack {
      docker_image_name = "nginx:latest"
    }
  }
  app_settings = {
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = var.app_insights_connection_string
  }

  tags = var.tags
}


resource "azurerm_linux_web_app_slot" "staging" {
  name           = "staging"
  app_service_id = azurerm_linux_web_app.this.id

  https_only = true

  site_config {
    application_stack {
      docker_image_name = "nginx:latest"
    }
  }

  tags = var.tags
}