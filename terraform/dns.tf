// ──────────────────────────────────────────────────────────
// Azure DNS Zone — empty, for future custom domain
// ──────────────────────────────────────────────────────────

resource "azurerm_dns_zone" "this" {
  count               = var.dns_zone_name != "" ? 1 : 0
  name                = var.dns_zone_name
  resource_group_name = data.azurerm_resource_group.this.name

  tags = {
    environment = var.environment
  }
}
