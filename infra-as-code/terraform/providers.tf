# Terraform version constraints and provider configurations

terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
    }
    random = {
      source  = "hashicorp/random"
    }
    pkcs12 = {
      source  = "chilicat/pkcs12"
    }
          azapi = {
            source  = "azure/azapi"
          }
  }
}

# Configure the Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy = true
    }
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

# Configure the Random Provider
provider "random" {
  # Configuration options
}
