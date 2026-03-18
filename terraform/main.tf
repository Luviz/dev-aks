terraform {
  backend "azurerm" {
    use_oidc         = true
    use_azuread_auth = true
  }
  required_version = "~> 1.7"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60.0"
    }
  }
}

provider "azurerm" {
  use_oidc                     = true
  disable_terraform_partner_id = true
  storage_use_azuread          = true
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}
