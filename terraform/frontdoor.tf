// ──────────────────────────────────────────────────────────
// Azure Front Door Standard — TLS termination & stable hostname
// ──────────────────────────────────────────────────────────

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = "afd-${module.naming.cdn_profile.name_unique}"
  resource_group_name = data.azurerm_resource_group.this.name
  sku_name            = "Standard_AzureFrontDoor"

  tags = {
    environment = var.environment
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "argocd" {
  name                     = "argocd-${module.naming.cdn_endpoint.name_unique}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
}

resource "azurerm_cdn_frontdoor_origin_group" "argocd" {
  name                     = "argocd-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  session_affinity_enabled = false

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    path                = "/healthz"
    protocol            = "Http"
    interval_in_seconds = 30
    request_type        = "HEAD"
  }
}

// Origin uses a placeholder IP — updated post-deploy with the real Envoy Gateway LB IP.
// origin_host_header must match the HTTPRoute hostname so Envoy Gateway routes correctly.
resource "azurerm_cdn_frontdoor_origin" "envoy_gateway" {
  name                          = "envoy-gateway-lb"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.argocd.id

  enabled                        = true
  host_name                      = var.frontdoor_origin_host
  http_port                      = 80
  https_port                     = 443
  origin_host_header             = var.argocd_hostname
  certificate_name_check_enabled = false
  priority                       = 1
  weight                         = 1000
}

resource "azurerm_cdn_frontdoor_route" "argocd" {
  name                          = "argocd-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.argocd.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.argocd.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.envoy_gateway.id]

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.argocd.id]

  supported_protocols    = ["Https", "Http"]
  patterns_to_match      = ["/*"]
  forwarding_protocol    = "HttpOnly"
  https_redirect_enabled = true

  link_to_default_domain = true
}

// ── Custom domain with managed TLS ──────────────────────────

resource "azurerm_cdn_frontdoor_custom_domain" "argocd" {
  name                     = "argocd-custom-domain"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  dns_zone_id              = azurerm_dns_zone.this.id
  host_name                = var.argocd_hostname

  tls {
    certificate_type    = "ManagedCertificate"
    minimum_tls_version = "TLS12"
  }
}

resource "azurerm_cdn_frontdoor_custom_domain_association" "argocd" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.argocd.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.argocd.id]
}
