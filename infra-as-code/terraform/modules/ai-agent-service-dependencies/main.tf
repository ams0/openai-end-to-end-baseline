# AI Agent Service Dependencies Module
# Deploys Azure Storage, Azure AI Search, and Cosmos DB

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

variable "debug_user_principal_id" {
  description = "Principal ID for debugging access"
  type        = string
}

variable "private_endpoint_subnet_resource_id" {
  description = "The resource ID for private endpoints subnet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

# Storage Account
resource "azurerm_storage_account" "ai_agent" {
  name                     = "st${var.base_name}aiagent"
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  min_tls_version          = "TLS1_2"
  shared_access_key_enabled = true

  network_rules {
    default_action = "Deny"
    bypass         = ["AzureServices"]
  }

  tags = var.tags
}

# AI Search Service
resource "azurerm_search_service" "main" {
  name                = "srch-${var.base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "basic"

  tags = var.tags
}

# Cosmos DB Account
resource "azurerm_cosmosdb_account" "main" {
  name                = "cosmos-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"
  local_authentication_disabled = true

  consistency_policy {
    consistency_level = "Session"
  }

  geo_location {
    location          = var.location
    failover_priority = 0
  }

  tags = var.tags
}

# Outputs
output "storage_account_name" {
  description = "The name of the storage account"
  value       = azurerm_storage_account.ai_agent.name
}

output "ai_search_name" {
  description = "The name of the AI Search service"
  value       = azurerm_search_service.main.name
}

output "cosmos_db_account_name" {
  description = "The name of the Cosmos DB account"
  value       = azurerm_cosmosdb_account.main.name
}
