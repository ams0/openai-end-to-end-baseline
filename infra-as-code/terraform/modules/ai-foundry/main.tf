# AI Foundry Module
# Deploy Azure AI Foundry with Azure AI Foundry Agent capability

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The region for deployment"
  type        = string
}

variable "base_name" {
  description = "The base name for resources"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "The name of the log analytics workspace"
  type        = string
}

variable "agent_subnet_resource_id" {
  description = "The resource ID for the subnet that the Azure AI Foundry Agents will egress through"
  type        = string
}

variable "private_endpoint_subnet_resource_id" {
  description = "The resource ID for the subnet that private endpoints in the workload should surface in"
  type        = string
}

variable "ai_foundry_portal_user_principal_id" {
  description = "Your principal ID for Azure AI Foundry portal access"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Local variables
locals {
  ai_foundry_name = "aif${var.base_name}"
}

# Data sources
data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

# AI Services Account (Cognitive Services multi-service account)
resource "azurerm_cognitive_account" "ai_foundry" {
  name                = local.ai_foundry_name
  location            = var.location
  resource_group_name = var.resource_group_name
  kind                = "CognitiveServices"
  sku_name            = "S0"
  custom_subdomain_name = local.ai_foundry_name

  network_acls {
    default_action = "Deny"
    ip_rules       = []
    virtual_network_rules {
      subnet_id = var.agent_subnet_resource_id
    }
  }

  tags = var.tags
}

# Private DNS Zone for Cognitive Services
resource "azurerm_private_dns_zone" "cognitive_services" {
  name                = "privatelink.cognitiveservices.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for AI Services
resource "azurerm_private_dns_zone" "ai_services" {
  name                = "privatelink.services.ai.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private DNS Zone for OpenAI
resource "azurerm_private_dns_zone" "openai" {
  name                = "privatelink.openai.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Private Endpoint for AI Services
resource "azurerm_private_endpoint" "ai_foundry" {
  name                = "pe-${local.ai_foundry_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  subnet_id           = var.private_endpoint_subnet_resource_id

  private_service_connection {
    name                           = "psc-${local.ai_foundry_name}"
    private_connection_resource_id = azurerm_cognitive_account.ai_foundry.id
    is_manual_connection           = false
    subresource_names              = ["account"]
  }

  private_dns_zone_group {
    name                 = "pdzg-${local.ai_foundry_name}"
    private_dns_zone_ids = [azurerm_private_dns_zone.cognitive_services.id]
  }

  tags = var.tags
}

# Role Assignment for user access
resource "azurerm_role_assignment" "cognitive_services_user" {
  scope                = azurerm_cognitive_account.ai_foundry.id
  role_definition_id   = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/providers/Microsoft.Authorization/roleDefinitions/a97b65f3-24c7-4388-baec-2e87135dc908"
  principal_id         = var.ai_foundry_portal_user_principal_id
}

# Data source for current client config
data "azurerm_client_config" "current" {}

# Diagnostic settings
resource "azurerm_monitor_diagnostic_setting" "ai_foundry" {
  name                       = "aifoundry-diagnostics"
  target_resource_id         = azurerm_cognitive_account.ai_foundry.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "Audit"
  }

  enabled_log {
    category = "RequestResponse"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Outputs
output "ai_foundry_name" {
  description = "The name of the AI Foundry resource"
  value       = azurerm_cognitive_account.ai_foundry.name
}

output "ai_foundry_id" {
  description = "The ID of the AI Foundry resource"
  value       = azurerm_cognitive_account.ai_foundry.id
}

output "ai_foundry_endpoint" {
  description = "The endpoint of the AI Foundry resource"
  value       = azurerm_cognitive_account.ai_foundry.endpoint
}
