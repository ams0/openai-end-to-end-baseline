module "azure_policies" {
  source = "./modules/azure-policies"
  resource_group_name = var.resource_group_name
  base_name = var.base_name
}

module "network" {
  source              = "./modules/network"
  resource_group_name = data.azurerm_resource_group.main.name
  location           = var.location
  tags               = local.common_tags
}

module "azure_firewall" {
  source                         = "./modules/azure-firewall"
  resource_group_name           = data.azurerm_resource_group.main.name
  location                      = var.location
  log_analytics_workspace_name  = azurerm_log_analytics_workspace.main.name
  virtual_network_name          = module.network.virtual_network_name
  agents_egress_subnet_name     = module.network.agents_egress_subnet_name
  jump_boxes_subnet_name        = module.network.jump_boxes_subnet_name
  tags                          = local.common_tags

  depends_on = [module.network]
}

module "jump_box" {
  source                        = "./modules/jump-box"
  resource_group_name          = data.azurerm_resource_group.main.name
  location                     = var.location
  base_name                    = var.base_name
  log_analytics_workspace_name = azurerm_log_analytics_workspace.main.name
  virtual_network_name         = module.network.virtual_network_name
  jump_box_subnet_name         = module.network.jump_box_subnet_name
  jump_box_admin_name          = "vmadmin"
  jump_box_admin_password      = var.jump_box_admin_password
  tags                         = local.common_tags

  depends_on = [module.azure_firewall]
}

module "ai_foundry" {
  source                           = "./modules/ai-foundry"
  resource_group_name             = data.azurerm_resource_group.main.name
  location                        = var.location
  base_name                       = var.base_name
  log_analytics_workspace_name    = azurerm_log_analytics_workspace.main.name
  agent_subnet_resource_id        = module.network.agents_egress_subnet_resource_id
  private_endpoint_subnet_resource_id = module.network.private_endpoints_subnet_resource_id
  ai_foundry_portal_user_principal_id = data.azurerm_client_config.current.object_id
  tags                            = local.common_tags

  depends_on = [module.azure_firewall]
}

module "ai_agent_service_dependencies" {
  source                              = "./modules/ai-agent-service-dependencies"
  resource_group_name                = data.azurerm_resource_group.main.name
  location                           = var.location
  base_name                          = var.base_name
  log_analytics_workspace_name       = azurerm_log_analytics_workspace.main.name
  debug_user_principal_id            = data.azurerm_client_config.current.object_id
  private_endpoint_subnet_resource_id = module.network.private_endpoints_subnet_resource_id
  tags                               = local.common_tags

  depends_on = [ azurerm_log_analytics_workspace.main ]
}

module "bing_grounding" {
  source              = "./modules/bing-grounding"
  resource_group_name = data.azurerm_resource_group.main.name
  base_name          = var.base_name
  tags               = local.common_tags
}
