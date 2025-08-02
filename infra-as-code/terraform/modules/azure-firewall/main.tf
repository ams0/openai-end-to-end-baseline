# Azure Firewall Module
# Control egress traffic through Azure Firewall restrictions

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The region for deployment"
  type        = string
}

variable "log_analytics_workspace_name" {
  description = "The name of the log analytics workspace"
  type        = string
}

variable "virtual_network_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "agents_egress_subnet_name" {
  description = "The name of the agents egress subnet"
  type        = string
}

variable "jump_boxes_subnet_name" {
  description = "The name of the jump boxes subnet"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "azurerm_virtual_network" "main" {
  name                = var.virtual_network_name
  resource_group_name = var.resource_group_name
}

data "azurerm_subnet" "firewall" {
  name                 = "AzureFirewallSubnet"
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

# Public IP for Azure Firewall
resource "azurerm_public_ip" "firewall" {
  name                = "pip-firewall"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Public IP for Azure Firewall Management
resource "azurerm_public_ip" "firewall_management" {
  name                = "pip-firewall-management"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Azure Firewall Policy
resource "azurerm_firewall_policy" "main" {
  name                = "afwp-workload"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Basic"

  tags = var.tags
}

# Firewall Policy Rule Collection Group
resource "azurerm_firewall_policy_rule_collection_group" "main" {
  name               = "workload-rules"
  firewall_policy_id = azurerm_firewall_policy.main.id
  priority           = 500

  application_rule_collection {
    name     = "web-browsing"
    priority = 500
    action   = "Allow"

    rule {
      name = "allow-web-browsing"
      protocols {
        type = "Http"
        port = 80
      }
      protocols {
        type = "Https"
        port = 443
      }
      source_addresses      = ["192.168.0.0/16"]
      destination_fqdns     = ["*"]
    }
  }

  network_rule_collection {
    name     = "time-servers"
    priority = 400
    action   = "Allow"

    rule {
      name                  = "allow-ntp"
      protocols             = ["UDP"]
      source_addresses      = ["192.168.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["123"]
    }
  }

  network_rule_collection {
    name     = "dns-servers"
    priority = 300
    action   = "Allow"

    rule {
      name                  = "allow-dns"
      protocols             = ["UDP", "TCP"]
      source_addresses      = ["192.168.0.0/16"]
      destination_addresses = ["*"]
      destination_ports     = ["53"]
    }
  }
}

# Azure Firewall
resource "azurerm_firewall" "main" {
  name                = "afw-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku_name            = "AZFW_VNet"
  sku_tier            = "Basic"
  firewall_policy_id  = azurerm_firewall_policy.main.id

  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.azurerm_subnet.firewall.id
    public_ip_address_id = azurerm_public_ip.firewall.id
  }

  management_ip_configuration {
    name                 = "management"
    subnet_id            = data.azurerm_subnet.firewall_management.id
    public_ip_address_id = azurerm_public_ip.firewall_management.id
  }

  tags = var.tags
}

# Route to force traffic through firewall
resource "azurerm_route" "firewall" {
  name                = "udr-default-to-firewall"
  resource_group_name = var.resource_group_name
  route_table_name    = "rt-workload-egress"
  address_prefix      = "0.0.0.0/0"
  next_hop_type       = "VirtualAppliance"
  next_hop_in_ip_address = azurerm_firewall.main.ip_configuration[0].private_ip_address

  depends_on = [azurerm_firewall.main]
}

# Diagnostic settings for Azure Firewall
resource "azurerm_monitor_diagnostic_setting" "firewall" {
  name                       = "firewall-diagnostics"
  target_resource_id         = azurerm_firewall.main.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_log {
    category = "AzureFirewallApplicationRule"
  }

  enabled_log {
    category = "AzureFirewallNetworkRule"
  }

  enabled_log {
    category = "AzureFirewallDnsProxy"
  }

  enabled_metric {
    category = "AllMetrics"
  }
}

# Outputs
output "firewall_name" {
  description = "The name of the Azure Firewall"
  value       = azurerm_firewall.main.name
}

output "firewall_id" {
  description = "The ID of the Azure Firewall"
  value       = azurerm_firewall.main.id
}

output "firewall_private_ip" {
  description = "The private IP address of the Azure Firewall"
  value       = azurerm_firewall.main.ip_configuration[0].private_ip_address
}

output "firewall_public_ip" {
  description = "The public IP address of the Azure Firewall"
  value       = azurerm_public_ip.firewall.ip_address
}
