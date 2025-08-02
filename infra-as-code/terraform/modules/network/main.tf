# Network Module - Virtual Network, Subnets, NSGs, and Route Tables
# Establishes the private network for the workload

variable "resource_group_name" {
  description = "The name of the resource group"
  type        = string
}

variable "location" {
  description = "The region for deployment"
  type        = string
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Local variables
locals {
  # Azure AI Foundry Agent Service currently has a limitation on subnet prefixes.
  # 10.x was not supported, as such 192.168.x.x was used.
  virtual_network_address_prefix     = "192.168.0.0/16"
  app_gateway_subnet_prefix          = "192.168.1.0/24"
  app_services_subnet_prefix         = "192.168.0.0/24"
  private_endpoints_subnet_prefix    = "192.168.2.0/27"
  build_agents_subnet_prefix         = "192.168.2.32/27"
  bastion_subnet_prefix              = "192.168.2.64/26"
  jump_box_subnet_prefix             = "192.168.2.128/28"
  ai_agents_egress_subnet_prefix     = "192.168.3.0/24"
  azure_firewall_subnet_prefix       = "192.168.4.0/26"
  azure_firewall_management_subnet_prefix = "192.168.4.64/26"
  
  # Production readiness change: protect your public IPs in this architecture with DDoS protection by setting this to true.
  enable_ddos_protection = false
}

# DDoS Protection Plan (optional)
resource "azurerm_network_ddos_protection_plan" "main" {
  count               = local.enable_ddos_protection ? 1 : 0
  name                = "ddos-workload"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Route Table for egress traffic control
resource "azurerm_route_table" "egress" {
  name                = "rt-workload-egress"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Network Security Groups
resource "azurerm_network_security_group" "app_service_subnet" {
  name                = "nsg-appServicePlan"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "app_gateway_subnet" {
  name                = "nsg-appGateway"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "65200-65535"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPSInbound"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowHTTPInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "private_endpoints_subnet" {
  name                = "nsg-privateEndpoints"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "build_agents_subnet" {
  name                = "nsg-buildAgents"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "bastion_subnet" {
  name                = "nsg-AzureBastionSubnet"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHttpsInbound"
    priority                   = 120
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "Internet"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowGatewayManagerInbound"
    priority                   = 130
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "GatewayManager"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowAzureLoadBalancerInbound"
    priority                   = 140
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowBastionHostCommunication"
    priority                   = 150
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowSshRdpOutbound"
    priority                   = 100
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["22", "3389"]
    source_address_prefix      = "*"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowAzureCloudOutbound"
    priority                   = 110
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "AzureCloud"
  }

  security_rule {
    name                       = "AllowBastionCommunication"
    priority                   = 120
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_ranges    = ["8080", "5701"]
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  security_rule {
    name                       = "AllowGetSessionInformation"
    priority                   = 130
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "Internet"
  }

  tags = var.tags
}

resource "azurerm_network_security_group" "jump_box_subnet" {
  name                = "nsg-jumpBoxes"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_network_security_group" "ai_agents_egress_subnet" {
  name                = "nsg-aiAgentsEgress"
  location            = var.location
  resource_group_name = var.resource_group_name

  tags = var.tags
}

# Note: Azure Firewall subnets (AzureFirewallSubnet and AzureFirewallManagementSubnet) 
# cannot have NSGs attached - they are managed by the Azure Firewall service itself

# Virtual Network
resource "azurerm_virtual_network" "main" {
  name                = "vnet-workload"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [local.virtual_network_address_prefix]

  dynamic "ddos_protection_plan" {
    for_each = local.enable_ddos_protection ? [1] : []
    content {
      id     = azurerm_network_ddos_protection_plan.main[0].id
      enable = true
    }
  }

  tags = var.tags
}

# Subnets
resource "azurerm_subnet" "app_service_plan" {
  name                 = "snet-appServicePlan"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.app_services_subnet_prefix]

}

resource "azurerm_subnet_network_security_group_association" "app_service_plan" {
  subnet_id                 = azurerm_subnet.app_service_plan.id
  network_security_group_id = azurerm_network_security_group.app_service_subnet.id
}

resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-appGateway"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.app_gateway_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  subnet_id                 = azurerm_subnet.app_gateway.id
  network_security_group_id = azurerm_network_security_group.app_gateway_subnet.id
}

resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-privateEndpoints"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.private_endpoints_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "private_endpoints" {
  subnet_id                 = azurerm_subnet.private_endpoints.id
  network_security_group_id = azurerm_network_security_group.private_endpoints_subnet.id
}

resource "azurerm_subnet_route_table_association" "private_endpoints" {
  subnet_id      = azurerm_subnet.private_endpoints.id
  route_table_id = azurerm_route_table.egress.id
}

resource "azurerm_subnet" "build_agents" {
  name                 = "snet-buildAgents"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.build_agents_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "build_agents" {
  subnet_id                 = azurerm_subnet.build_agents.id
  network_security_group_id = azurerm_network_security_group.build_agents_subnet.id
}

resource "azurerm_subnet_route_table_association" "build_agents" {
  subnet_id      = azurerm_subnet.build_agents.id
  route_table_id = azurerm_route_table.egress.id
}

resource "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.bastion_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "bastion" {
  subnet_id                 = azurerm_subnet.bastion.id
  network_security_group_id = azurerm_network_security_group.bastion_subnet.id
}

resource "azurerm_subnet" "jump_boxes" {
  name                 = "snet-jumpBoxes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.jump_box_subnet_prefix]
}

resource "azurerm_subnet_network_security_group_association" "jump_boxes" {
  subnet_id                 = azurerm_subnet.jump_boxes.id
  network_security_group_id = azurerm_network_security_group.jump_box_subnet.id
}

resource "azurerm_subnet_route_table_association" "jump_boxes" {
  subnet_id      = azurerm_subnet.jump_boxes.id
  route_table_id = azurerm_route_table.egress.id
}

resource "azurerm_subnet" "ai_agents_egress" {
  name                 = "snet-aiAgentsEgress"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.ai_agents_egress_subnet_prefix]
  service_endpoints    = ["Microsoft.CognitiveServices"]
}

resource "azurerm_subnet_network_security_group_association" "ai_agents_egress" {
  subnet_id                 = azurerm_subnet.ai_agents_egress.id
  network_security_group_id = azurerm_network_security_group.ai_agents_egress_subnet.id
}

resource "azurerm_subnet_route_table_association" "ai_agents_egress" {
  subnet_id      = azurerm_subnet.ai_agents_egress.id
  route_table_id = azurerm_route_table.egress.id
}

resource "azurerm_subnet" "azure_firewall" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.azure_firewall_subnet_prefix]
}

# Note: Azure Firewall subnet cannot have NSG attached - it's managed by the firewall service itself

resource "azurerm_subnet" "azure_firewall_management" {
  name                 = "AzureFirewallManagementSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [local.azure_firewall_management_subnet_prefix]
}

# Note: Azure Firewall Management subnet cannot have NSG attached - it's managed by the firewall service itself

# Outputs
output "virtual_network_name" {
  description = "The name of the virtual network"
  value       = azurerm_virtual_network.main.name
}

output "virtual_network_id" {
  description = "The ID of the virtual network"
  value       = azurerm_virtual_network.main.id
}

output "app_services_subnet_name" {
  description = "The name of the app services subnet"
  value       = azurerm_subnet.app_service_plan.name
}

output "app_services_subnet_id" {
  description = "The ID of the app services subnet"
  value       = azurerm_subnet.app_service_plan.id
}

output "application_gateway_subnet_name" {
  description = "The name of the application gateway subnet"
  value       = azurerm_subnet.app_gateway.name
}

output "application_gateway_subnet_id" {
  description = "The ID of the application gateway subnet"
  value       = azurerm_subnet.app_gateway.id
}

output "private_endpoints_subnet_name" {
  description = "The name of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.name
}

output "private_endpoints_subnet_id" {
  description = "The ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "private_endpoints_subnet_resource_id" {
  description = "The resource ID of the private endpoints subnet"
  value       = azurerm_subnet.private_endpoints.id
}

output "build_agents_subnet_name" {
  description = "The name of the build agents subnet"
  value       = azurerm_subnet.build_agents.name
}

output "build_agents_subnet_id" {
  description = "The ID of the build agents subnet"
  value       = azurerm_subnet.build_agents.id
}

output "bastion_subnet_name" {
  description = "The name of the bastion subnet"
  value       = azurerm_subnet.bastion.name
}

output "bastion_subnet_id" {
  description = "The ID of the bastion subnet"
  value       = azurerm_subnet.bastion.id
}

output "jump_box_subnet_name" {
  description = "The name of the jump box subnet"
  value       = azurerm_subnet.jump_boxes.name
}

output "jump_box_subnet_id" {
  description = "The ID of the jump box subnet"
  value       = azurerm_subnet.jump_boxes.id
}

output "jump_boxes_subnet_name" {
  description = "The name of the jump boxes subnet (alias)"
  value       = azurerm_subnet.jump_boxes.name
}

output "agents_egress_subnet_name" {
  description = "The name of the AI agents egress subnet"
  value       = azurerm_subnet.ai_agents_egress.name
}

output "agents_egress_subnet_id" {
  description = "The ID of the AI agents egress subnet"
  value       = azurerm_subnet.ai_agents_egress.id
}

output "agents_egress_subnet_resource_id" {
  description = "The resource ID of the AI agents egress subnet"
  value       = azurerm_subnet.ai_agents_egress.id
}

output "azure_firewall_subnet_name" {
  description = "The name of the Azure Firewall subnet"
  value       = azurerm_subnet.azure_firewall.name
}

output "azure_firewall_subnet_id" {
  description = "The ID of the Azure Firewall subnet"
  value       = azurerm_subnet.azure_firewall.id
}

output "azure_firewall_management_subnet_name" {
  description = "The name of the Azure Firewall Management subnet"
  value       = azurerm_subnet.azure_firewall_management.name
}

output "azure_firewall_management_subnet_id" {
  description = "The ID of the Azure Firewall Management subnet"
  value       = azurerm_subnet.azure_firewall_management.id
}

output "egress_route_table_id" {
  description = "The ID of the egress route table"
  value       = azurerm_route_table.egress.id
}
