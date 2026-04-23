# Copilot Instructions — dev-aks

## Project Overview

This repository manages a **development AKS (Azure Kubernetes Service) cluster** on Azure.
The core design goal is a cluster that can be torn down and rebuilt quickly at minimal cost.

### Repository Layout

| Path                     | Purpose                                                                                                                                     |
| ------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `bootstrap/`             | Bicep templates + AVM Bicep modules for one-time state bootstrapping (resource groups, storage account for tfstate, managed identity, RBAC) |
| `bootstrap/deploy-state` | Shell script to deploy bootstrap via `az deployment sub create`                                                                             |
| `terraform/`             | Terraform (AzureRM ~4.60, AzureAD ~3.1, Helm ~2.17, Kubernetes ~2.36) for AKS, VNet, ACR, Entra SSO, Helm bootstrap |
| `terraform/backend/`     | Per-environment `.tfvars` for the azurerm backend (OIDC + Azure AD auth) |
| `helm/argocd/`           | Argo CD Helm chart with Entra ID OIDC SSO |
| `helm/envoy-gateway/`    | Envoy Gateway chart (managed by Argo CD via app-of-apps) |
| `helm/argocd-apps/`      | App-of-apps — Argo CD manages Envoy Gateway and future cluster services |
| `.github/workflows/`     | Lifecycle: bootstrap, deploy, scale-down/up, clean, purge |

## Tech Stack & Conventions

### Terraform

- **Provider**: `hashicorp/azurerm ~> 4.60` with OIDC authentication.
- **Backend**: `azurerm` with `use_oidc = true` and `use_azuread_auth = true`.
- **AVM modules** (Azure Verified Modules) are preferred for all Azure resources:
  - `Azure/avm-res-network-virtualnetwork/azurerm` for VNets
  - `Azure/avm-res-containerregistry-registry/azurerm` for ACR
  - `Azure/naming/azurerm` for consistent resource naming
  - Browse the AVM registry at <https://aka.ms/avm> for additional modules.
- When an AVM module exists for a resource, **always use it** instead of raw `azurerm_*` resources.
- The AKS cluster (`azurerm_kubernetes_cluster`) is currently a raw resource because the AVM AKS module had bugs; re-evaluate before adding features.
- Use `module.naming.*` for resource names wherever possible.
- Organise resources into purpose-based `.tf` files (e.g., `aks.tf`, `vnet.tf`, `acr.tf`).
- Do **not** hardcode subscription IDs, tenant IDs, or secrets.

### Bicep (Bootstrap only)

- Uses **AVM Bicep modules** from the public Bicep registry (`br/public:avm/...`).
- `targetScope = 'subscription'` — deploys at subscription level.
- Parameterised via `.bicepparam` files; `base.bicepparam` is the template.

### AKS Cluster Details

- Kubernetes version: `1.33`, auto-upgrade channel: `patch`.
- Node pool: `Standard_B4s_v2`, autoscale 1-3 nodes, Ubuntu OS.
- Network: `kubenet` plugin, `calico` network policy, standard LB.
- Workload identity and OIDC issuer enabled.
- SKU tier: `Free` (dev cluster).

### Planned Work (see README TODO)

- **Egress**: Add egress controls (NAT Gateway or Azure Firewall + UDR).
- **TLS**: cert-manager + Let's Encrypt for proper HTTPS certificates.

## Coding Guidelines

1. **Infrastructure as Code only** — no manual Azure portal changes.
2. **AVM-first** — prefer Azure Verified Modules for both Terraform and Bicep.
3. Validate Terraform changes with `terraform fmt -check` and `terraform validate`.
4. Keep `.gitignore` patterns in mind: backend tfvars and bicepparam files (except templates) are ignored.
5. Use OIDC/workload identity for all authentication — never store credentials.
6. When adding Kubernetes manifests or Helm values, place them under a clearly named directory (e.g., `k8s/`, `argocd/`, `helm/`).
7. For Argo CD, prefer the **app-of-apps** or **ApplicationSet** pattern.
8. For Envoy ingress, prefer **Envoy Gateway** (Gateway API) over legacy Ingress resources.
9. Write clear commit messages describing _what_ and _why_.

## Key Azure Resource Names

- Resource group: `rg-dev-aks`
- Naming module generates unique suffixes for AKS, ACR, etc.
- Terraform state: stored in a storage account bootstrapped by the Bicep templates.

## Useful Commands

```sh
# Bootstrap (one-time)
cd bootstrap && ./deploy-state <subscription-id> <org-name>

# Terraform
cd terraform
terraform init --backend-config ./backend/<env>.tfvars --reconfigure
terraform plan
terraform apply
```
