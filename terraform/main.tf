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
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.36"
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

provider "azuread" {}

provider "kubernetes" {
  host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
  cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
  token                  = azurerm_kubernetes_cluster.this.kube_config[0].password
}

provider "helm" {
  kubernetes {
    host                   = azurerm_kubernetes_cluster.this.kube_config[0].host
    cluster_ca_certificate = base64decode(azurerm_kubernetes_cluster.this.kube_config[0].cluster_ca_certificate)
    token                  = azurerm_kubernetes_cluster.this.kube_config[0].password
  }
}
