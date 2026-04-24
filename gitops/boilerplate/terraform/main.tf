# ──────────────────────────────────────────────────────────
# Add your Azure resources here
# ──────────────────────────────────────────────────────────

locals {
  merged_tags = merge(var.tags, {
    environment = var.environment
    managed-by  = "terraform-gitops"
  })
}

# Example: uncomment to create a resource group
# resource "azurerm_resource_group" "this" {
#   name     = "rg-${var.project_name}-${var.environment}"
#   location = var.location
#   tags     = local.merged_tags
# }
