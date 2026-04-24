terraform {
  required_version = "~> 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.60"
    }
  }
}

# Workload Identity injects ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID,
# and AZURE_FEDERATED_TOKEN_FILE as environment variables into the pod.
provider "azurerm" {
  use_oidc                     = true
  disable_terraform_partner_id = true
  features {}
}
