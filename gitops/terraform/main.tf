# ──────────────────────────────────────────────────────────
# Example Azure resources — replace with your own
# ──────────────────────────────────────────────────────────

locals {
  merged_tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform-gitops"
  })
}

resource "azurerm_resource_group" "this" {
  name     = "rg-${var.project_name}-${var.environment}"
  location = var.location
  tags     = local.merged_tags
}

resource "azurerm_storage_account" "this" {
  name                     = replace("st${var.project_name}${var.environment}", "-", "")
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  tags                     = local.merged_tags
}
