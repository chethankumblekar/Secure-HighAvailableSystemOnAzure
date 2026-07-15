resource "azurerm_kubernetes_cluster" "this" {
  name                = "${var.project_name}-${var.environment}-aks"
  location            = var.location
  resource_group_name = var.resource_group_name
  dns_prefix          = "${var.project_name}-${var.environment}"

  sku_tier           = var.sku_tier
  kubernetes_version = var.kubernetes_version

  # Zero-trust: no static kubelet/cluster secrets, workloads federate via OIDC.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "azure"
  }

  default_node_pool {
    name           = "system"
    vm_size        = var.system_node_vm_size
    node_count     = var.system_node_count
    vnet_subnet_id = var.subnet_id
    tags           = var.tags
  }

  identity {
    type = "SystemAssigned"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  tags = var.tags
}
