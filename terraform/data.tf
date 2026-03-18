data "azurerm_resource_group" "this" {
  name = local.resource_group_name
}

data "azurerm_client_config" "current" {}