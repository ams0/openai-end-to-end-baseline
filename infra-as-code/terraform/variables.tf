variable "resource_group_name" {
  description = "value of the resource group name"
  type        = string
}

variable "location" {
  description = "value of the location for deployment"
  type        = string
  
}

variable "base_name" {
  description = "value of the base name for resources"
  type        = string
  
}

variable "jump_box_admin_password" {
  description = "The password for the jump box admin user"
  type        = string
  sensitive   = true
  
}