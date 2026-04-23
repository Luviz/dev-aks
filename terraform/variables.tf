// ──────────────────────────────────────────────────────────
// Variables — single source of truth for all environments
// ──────────────────────────────────────────────────────────

variable "environment" {
  description = "Environment name (dev, staging, prod)."
  type        = string
  default     = "dev"
}

variable "location" {
  description = "Azure region for all resources."
  type        = string
  default     = "westeurope"
}

variable "location_short" {
  description = "Short location code used in naming (e.g. we, ne, eus)."
  type        = string
  default     = "we"
}

variable "resource_group_name" {
  description = "Name of the pre-existing workspace resource group."
  type        = string
  default     = "rg-dev-aks"
}

// ── Entra ID / SSO ────────────────────────────────────────

variable "tenant_id" {
  description = "Azure AD / Entra tenant ID."
  type        = string
}

variable "argocd_admin_email" {
  description = "Email of the user who should have Argo CD admin access."
  type        = string
}

variable "argocd_admin_object_id" {
  description = "Entra object ID of the Argo CD admin user (required for guest/external accounts)."
  type        = string
  default     = ""
}

// ── Front Door ──────────────────────────────────────────────

variable "frontdoor_origin_host" {
  description = "Placeholder origin hostname/IP for Front Door. Updated post-deploy with real Envoy Gateway LB IP."
  type        = string
  default     = "10.0.0.1"
}

variable "dns_zone_name" {
  description = "Name of the Azure DNS Zone (for future custom domain)."
  type        = string
  default     = ""
}

// ── Argo CD ────────────────────────────────────────────────

variable "argocd_github_app_id" {
  description = "GitHub App ID used by Argo CD to access repositories."
  type        = string
  default     = ""
}

variable "argocd_github_app_installation_id" {
  description = "GitHub App installation ID for the target org."
  type        = string
  default     = ""
}

variable "argocd_github_app_private_key" {
  description = "PEM-encoded private key for the GitHub App."
  type        = string
  sensitive   = true
  default     = ""
}
