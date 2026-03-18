locals {
  resource_group_name = "rg-dev-aks"
}

locals {
    acr_name = module.naming.container_registry.name_unique
}