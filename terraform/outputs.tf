// ──────────────────────────────────────────────────────────
// Outputs — consumed by GH Actions and post-deploy scripts
// ──────────────────────────────────────────────────────────

// ── AKS ────────────────────────────────────────────────────

output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.this.name
}

output "aks_resource_group" {
  value = data.azurerm_resource_group.this.name
}

output "aks_oidc_issuer_url" {
  value = azurerm_kubernetes_cluster.this.oidc_issuer_url
}

output "aks_kube_config_host" {
  value     = azurerm_kubernetes_cluster.this.kube_config[0].host
  sensitive = true
}

// ── ACR ────────────────────────────────────────────────────

output "acr_name" {
  value = module.avm-res-containerregistry-registry.resource.name
}

output "acr_login_server" {
  value = module.avm-res-containerregistry-registry.resource.login_server
}

// ── Entra SSO ──────────────────────────────────────────────

output "argocd_entra_client_id" {
  value = azuread_application.argocd.client_id
}

output "argocd_entra_client_secret" {
  value     = azuread_application_password.argocd.value
  sensitive = true
}

output "argocd_entra_issuer_url" {
  value = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
}

// ── Argo CD ────────────────────────────────────────────────

output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "argocd_entra_issuer_url_full" {
  description = "Full OIDC issuer URL for Entra ID."
  value       = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
}
