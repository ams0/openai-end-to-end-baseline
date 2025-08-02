# Bing Grounding Module
# Deploy the Bing account for Internet grounding data
terraform {
  required_providers {
    azapi = {
      source  = "azure/azapi"
    }
  }
}

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "base_name" {
  description = "The base name for resources"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

# Note: Bing Search API v7 resource
# https://github.com/hashicorp/terraform-provider-azurerm/issues/9102
# resource "azurerm_cognitive_account" "bing" {
#   name                = "bing-${var.base_name}"
#   location            = "global"
#   resource_group_name = var.resource_group_name
#   kind                = "Bing.Search.v7"
#   sku_name            = "S1"

#   tags = var.tags
#}

resource "azapi_resource" "bingSearchAccount" {
  type                      = "Microsoft.Bing/accounts@2020-06-10"
  schema_validation_enabled = false
  name                      = "bing-${var.base_name}"
  parent_id                 = data.azurerm_resource_group.main.id
  location                  = "global"
  body = {
    sku = {
      name = "S1"
    }
    kind = "Bing.Search.v7" # or "Bing.CustomSearch"
  }
  response_export_values = ["*"]
}

# get the bing search api access keys
data "azapi_resource_action" "bingSearchAccount" {
  type        = "Microsoft.Bing/accounts@2020-06-10"
  resource_id = azapi_resource.bingSearchAccount.id
  action      = "listKeys"
  method      = "POST"
  response_export_values = ["*"]
}

# Outputs
# output "bing_account_name" {
#   description = "The name of the Bing account"
#   value       = data.azapi_resource_action.bingSearchAccount.response["name"]
# }

# output "bing_account_id" {
#   description = "The ID of the Bing account"
#   value       = data.azapi_resource_action.bingSearchAccount.response["id"]
# }
