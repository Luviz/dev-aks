// ──────────────────────────────────────────────────────────
// Entra ID App Registration — Argo CD OIDC SSO
// ──────────────────────────────────────────────────────────

data "azuread_client_config" "current" {}

// ── Argo CD app registration ──────────────────────────────

resource "azuread_application" "argocd" {
  display_name = "argocd-${var.environment}-sso"
  owners       = [data.azuread_client_config.current.object_id]

  sign_in_audience = "AzureADMyOrg"

  web {
    # Placeholder redirect — updated post-deploy once the LB IP is known
    redirect_uris = [
      "https://argocd.localhost/auth/callback",
    ]

    implicit_grant {
      id_token_issuance_enabled = true
    }
  }

  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }
  }

  optional_claims {
    id_token {
      name = "email"
    }
    id_token {
      name = "preferred_username"
    }
  }

  group_membership_claims = ["SecurityGroup"]

  tags = ["argocd", var.environment]
}

resource "azuread_service_principal" "argocd" {
  client_id = azuread_application.argocd.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "azuread_application_password" "argocd" {
  application_id = azuread_application.argocd.id
  display_name   = "argocd-${var.environment}-secret"
  end_date       = timeadd(timestamp(), "8760h") # 1 year

  lifecycle {
    ignore_changes = [end_date]
  }
}
