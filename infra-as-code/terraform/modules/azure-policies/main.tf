


variable "base_name" {
  description = "This is the base name for each Azure resource name (6-8 chars)."
  type        = string
  validation {
    condition     = length(var.base_name) >= 6 && length(var.base_name) <= 8
    error_message = "base_name must be between 6 and 8 characters."
  }
}

variable "resource_group_name" {
  description = "The name of the resource group where the policies will be applied."
  type        = string
}

# Existing resource group (or define one)
data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

locals {
  policies = {
    aiServicesKeyAccessPolicy         = "71ef260a-8f18-47b7-abcb-62d0673d94dc"
    aiServicesNetworkAccessPolicy     = "037eea7a-bd0a-46c5-9a66-03aea78705d3"
    cosmosDbZoneRedundantPolicy       = "44c5a1f9-7ef6-4c38-880c-273e8f7a3c24"
    cosmosDbPrivateLinkPolicy         = "58440f8a-10c5-4151-bdce-dfbaad4a20b7"
    cosmosDbDisableLocalAuthPolicy    = "5450f5bd-9c72-4390-a9c4-a7aba4edfdd2"
    cosmosDbDisablePublicNetworkPolicy= "797b37f7-06b8-444c-b1ad-fc62867f335a"
    searchDisablePublicNetworkPolicy  = "ee980b6d-0eca-4501-8d54-f6290fd512c3"
    searchZoneRedundantPolicy         = "90bc8109-d21a-4692-88fc-51419391da3d"
    searchDisableLocalAuthPolicy      = "6300012e-e9a4-4649-b41f-a85f5c43be91"
    storageDisablePublicNetworkPolicy = "b2982f36-99f2-4db5-8eff-283140c09693"
    storageDisableSharedKeyPolicy     = "8c6a50c6-9ffd-4ae7-986f-5fa6111f9a54"
  }
}

resource "azurerm_resource_group_policy_assignment" "assignments" {
  for_each             = local.policies
  name                 = substr(md5("${data.azurerm_resource_group.rg.id}-${each.value}"), 0, 16)
  display_name         = "${var.base_name} - ${each.key}"
  resource_group_id    = data.azurerm_resource_group.rg.id
  policy_definition_id = "/providers/Microsoft.Authorization/policyDefinitions/${each.value}"
  enforce              = true

  parameters = jsonencode({
    effect = {
      value = "Audit"
    }
  })
}