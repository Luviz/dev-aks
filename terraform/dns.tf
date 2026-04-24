// ──────────────────────────────────────────────────────────
// Azure DNS Zone — subdomain delegated from Cloudflare
// ──────────────────────────────────────────────────────────

resource "azurerm_dns_zone" "this" {
  name                = var.dns_zone_name
  resource_group_name = data.azurerm_resource_group.this.name

  tags = {
    environment = var.environment
  }
}

// CNAME: argocd.aks.luvizdev.com → Front Door endpoint
resource "azurerm_dns_cname_record" "argocd" {
  name                = "argocd"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = data.azurerm_resource_group.this.name
  ttl                 = 300
  record              = azurerm_cdn_frontdoor_endpoint.argocd.host_name
}

// TXT: Front Door domain ownership validation
resource "azurerm_dns_txt_record" "argocd_validation" {
  name                = "_dnsauth.argocd"
  zone_name           = azurerm_dns_zone.this.name
  resource_group_name = data.azurerm_resource_group.this.name
  ttl                 = 3600

  record {
    value = azurerm_cdn_frontdoor_custom_domain.argocd.validation_token
  }
}
