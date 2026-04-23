// ──────────────────────────────────────────────────────────
// Helm releases — bootstrap Argo CD, then Argo manages the rest
// ──────────────────────────────────────────────────────────

locals {
  argocd_namespace = "argocd"
  envoy_namespace  = "envoy-gateway"
  repo_url         = "https://github.com/Luviz/dev-aks.git"
}

// ── Argo CD ────────────────────────────────────────────────

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = local.argocd_namespace
  create_namespace = true
  chart            = "${path.module}/../helm/argocd"

  timeout = 600
  wait    = true

  values = [yamlencode({
    route = {
      enabled = false  # HTTPRoute created by post-deploy after Gateway API CRDs exist
    }
    "argo-cd" = {
      configs = {
        cm = {
          "oidc.config" = yamlencode({
            name            = "Entra ID"
            issuer          = "https://login.microsoftonline.com/${var.tenant_id}/v2.0"
            clientID        = azuread_application.argocd.client_id
            clientSecret    = "$oidc.entra.clientSecret"
            requestedScopes = ["openid", "profile", "email"]
          })
        }
        rbac = {
          "policy.csv" = "g, ${var.argocd_admin_email}, role:admin"
        }
        secret = {
          extra = {
            "oidc.entra.clientSecret" = azuread_application_password.argocd.value
          }
        }
      }
    }
  })]

  depends_on = [
    azurerm_kubernetes_cluster.this,
    azuread_application_password.argocd,
  ]
}

// ── App-of-Apps (Envoy Gateway managed by Argo) ───────────

resource "helm_release" "argocd_apps" {
  name             = "argocd-apps"
  namespace        = local.argocd_namespace
  create_namespace = false
  chart            = "${path.module}/../helm/argocd-apps"

  timeout = 300
  wait    = true

  set {
    name  = "repoURL"
    value = local.repo_url
  }

  set {
    name  = "targetRevision"
    value = "main"
  }

  depends_on = [helm_release.argocd]
}

// Post-deploy logic moved to the GitHub Actions workflow steps
// (kubectl/helm CLI need kubeconfig which isn't available during terraform apply)
