# Jump Box Module
# Deploys Azure Bastion and the jump box, which is used for private access to Azure AI Foundry and its dependencies

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

variable "virtual_network_name" {
  description = "The name of the virtual network"
  type        = string
}

variable "jump_box_subnet_name" {
  description = "The name of the jump box subnet"
  type        = string
}

variable "jump_box_admin_name" {
  description = "The admin username for the jump box"
  type        = string
}

variable "jump_box_admin_password" {
  description = "The admin password for the jump box"
  type        = string
  sensitive   = true
}

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default     = {}
}

# Data sources
data "azurerm_subnet" "bastion" {
  name                 = "AzureBastionSubnet"
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_subnet" "jump_box" {
  name                 = var.jump_box_subnet_name
  virtual_network_name = var.virtual_network_name
  resource_group_name  = var.resource_group_name
}

data "azurerm_log_analytics_workspace" "main" {
  name                = var.log_analytics_workspace_name
  resource_group_name = var.resource_group_name
}

# Public IP for Azure Bastion
resource "azurerm_public_ip" "bastion" {
  name                = "pip-bastion-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"

  tags = var.tags
}

# Azure Bastion Host
resource "azurerm_bastion_host" "main" {
  name                = "bastion-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  sku                 = "Basic"

  ip_configuration {
    name                 = "configuration"
    subnet_id            = data.azurerm_subnet.bastion.id
    public_ip_address_id = azurerm_public_ip.bastion.id
  }

  tags = var.tags
}

# Network Interface for Jump Box VM
resource "azurerm_network_interface" "jump_box" {
  name                = "nic-jumpbox-${var.base_name}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = data.azurerm_subnet.jump_box.id
    private_ip_address_allocation = "Dynamic"
  }

  tags = var.tags
}

# Jump Box Virtual Machine
resource "azurerm_windows_virtual_machine" "jump_box" {
  name                = "vm-${var.base_name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = "Standard_D4s_v6"
  admin_username      = var.jump_box_admin_name
  admin_password      = var.jump_box_admin_password

  network_interface_ids = [
    azurerm_network_interface.jump_box.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  tags = var.tags
}

# VM Extension for monitoring
resource "azurerm_virtual_machine_extension" "monitor_agent" {
  name                 = "AzureMonitorWindowsAgent"
  virtual_machine_id   = azurerm_windows_virtual_machine.jump_box.id
  publisher            = "Microsoft.Azure.Monitor"
  type                 = "AzureMonitorWindowsAgent"
  type_handler_version = "1.0"

  tags = var.tags
}

# Diagnostic settings for Network Interface
resource "azurerm_monitor_diagnostic_setting" "jump_box_nic" {
  name                       = "jumpbox-nic-diagnostics"
  target_resource_id         = azurerm_network_interface.jump_box.id
  log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id

  enabled_metric {
    category = "AllMetrics"
  }
}

# Outputs
output "jump_box_vm_name" {
  description = "The name of the jump box virtual machine"
  value       = azurerm_windows_virtual_machine.jump_box.name
}

output "jump_box_vm_id" {
  description = "The ID of the jump box virtual machine"
  value       = azurerm_windows_virtual_machine.jump_box.id
}

output "bastion_host_name" {
  description = "The name of the Azure Bastion host"
  value       = azurerm_bastion_host.main.name
}

output "bastion_host_id" {
  description = "The ID of the Azure Bastion host"
  value       = azurerm_bastion_host.main.id
}
