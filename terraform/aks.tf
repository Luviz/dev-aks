resource "azurerm_kubernetes_cluster" "this" {
  name                = "aks-${module.naming.kubernetes_cluster.name_unique}"
  location            = data.azurerm_resource_group.this.location
  resource_group_name = data.azurerm_resource_group.this.name
  dns_prefix          = module.naming.kubernetes_cluster.name_unique

  kubernetes_version                = "1.33"
  automatic_upgrade_channel         = "patch"
  node_os_upgrade_channel           = "NodeImage"
  role_based_access_control_enabled = true
  workload_identity_enabled         = true
  oidc_issuer_enabled               = true
  sku_tier                          = "Free"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name                    = "agentpool"
    vm_size                 = "Standard_B4s_v2"
    auto_scaling_enabled    = true
    host_encryption_enabled = false
    min_count               = 1
    max_count               = 3
    max_pods                = 110
    os_sku                  = "Ubuntu"

    upgrade_settings {
      max_surge = "10%"
    }
  }

  network_profile {
    network_plugin    = "kubenet"
    network_policy    = "calico"
    load_balancer_sku = "standard"
  }

  lifecycle {
    ignore_changes = [
      kubernetes_version
    ]
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                            = module.avm-res-containerregistry-registry.resource_id
  role_definition_name             = "AcrPull"
  principal_id                     = azurerm_kubernetes_cluster.this.kubelet_identity[0].object_id
  skip_service_principal_aad_check = true
}

