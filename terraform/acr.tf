module "avm-res-containerregistry-registry" {
  source              = "Azure/avm-res-containerregistry-registry/azurerm"
  version             = "0.5.1"
  resource_group_name = data.azurerm_resource_group.this.name
  location            = data.azurerm_resource_group.this.location
  name                = local.acr_name
}
