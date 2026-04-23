// ── Template: copy to <env>.tfvars and fill in values ──────
// These are gitignored — never commit real values.

environment         = "dev"
location            = "westeurope"
location_short      = "we"
resource_group_name = "rg-dev-aks"

tenant_id          = "YOUR_TENANT_ID"
argocd_admin_email = "you@example.com"

# GitHub App for Argo CD (leave empty to skip repo config)
# argocd_github_app_id              = ""
# argocd_github_app_installation_id = ""
# argocd_github_app_private_key     = ""
