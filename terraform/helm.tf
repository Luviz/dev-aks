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

  # Entra OIDC SSO
  set {
    name = "argo-cd.configs.cm.oidc\\.config"
    value = yamlencode(<<-EOT
      name: Entra ID
      issuer: https://login.microsoftonline.com/${var.tenant_id}/v2.0
      clientID: ${azuread_application.argocd.client_id}
      clientSecret: $oidc.entra.clientSecret
      requestedScopes:
        - openid
        - profile
        - email
    EOT
    )
  }

  set_sensitive {
    name  = "argo-cd.configs.secret.extra.oidc\\.entra\\.clientSecret"
    value = azuread_application_password.argocd.value
  }

  # RBAC — admin for the designated user
  set {
    name  = "argo-cd.configs.rbac.policy\\.csv"
    value = "g, ${var.argocd_admin_email}, role:admin"
  }

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

// ── Post-deploy: capture LB IP and update Entra + Argo ────

resource "terraform_data" "post_deploy" {
  triggers_replace = [
    helm_release.argocd_apps.metadata[0].revision,
  ]

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-SCRIPT
      set -euo pipefail

      echo "==> Waiting for Envoy Gateway LoadBalancer IP..."
      for i in $(seq 1 60); do
        LB_IP=$(kubectl get svc -n ${local.envoy_namespace} \
          -l gateway.envoyproxy.io/owning-gateway-name=default-gateway \
          -o jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
        if [[ -n "$LB_IP" && "$LB_IP" != "null" ]]; then
          break
        fi
        echo "  Attempt $i/60 — waiting 10s..."
        sleep 10
      done

      if [[ -z "$LB_IP" || "$LB_IP" == "null" ]]; then
        echo "ERROR: Could not get LoadBalancer IP after 10 minutes" >&2
        exit 1
      fi

      DASHED_IP=$(echo "$LB_IP" | tr '.' '-')
      ARGOCD_HOST="argocd-$${DASHED_IP}.nip.io"
      ARGOCD_URL="https://$${ARGOCD_HOST}"

      echo "==> LB IP: $LB_IP"
      echo "==> Argo CD URL: $ARGOCD_URL"

      # Update Entra redirect URI
      echo "==> Updating Entra app redirect URI..."
      az ad app update \
        --id "${azuread_application.argocd.client_id}" \
        --web-redirect-uris "$${ARGOCD_URL}/auth/callback" \
        --only-show-errors

      # Update Argo CD config
      echo "==> Patching Argo CD config..."
      kubectl -n ${local.argocd_namespace} patch configmap argocd-cm \
        --type merge -p "{\"data\":{\"url\":\"$${ARGOCD_URL}\"}}"

      # Update helm values for the HTTPRoute
      helm upgrade argocd ${path.module}/../helm/argocd \
        --namespace ${local.argocd_namespace} \
        --reuse-values \
        --set "route.host=$${ARGOCD_HOST}" \
        --set "argo-cd.global.domain=$${ARGOCD_HOST}" \
        --wait --timeout 5m

      echo "==> Post-deploy complete."
      echo "    Argo CD: $${ARGOCD_URL}"
      echo "    Login with: ${var.argocd_admin_email}"
    SCRIPT
  }

  depends_on = [helm_release.argocd_apps]
}
