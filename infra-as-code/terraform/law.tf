resource "azurerm_log_analytics_workspace" "main" {
  name                = "log-workload"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = 10

  tags = local.common_tags
}