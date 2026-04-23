locals {
  resource_group_name = var.resource_group_name
}

locals {
  acr_name = module.naming.container_registry.name_unique
}