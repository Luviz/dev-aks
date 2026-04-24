# Dev AKS

An Azure Kubernetes Service cluster designed for development and testing.
Spin up quickly, tear down when done — minimal cost when idle.

## Architecture

```
GitHub Actions ─── Bootstrap (Bicep/AVM) ──→ tfstate storage + managed identity
                │
                ├── Deploy (Terraform)    ──→ AKS + ACR + VNet + Entra SSO
                │                               │
                │                               ├─→ Argo CD (Helm) ──→ Envoy Gateway
                │                               │
                │                               └─→ Azure Front Door ──→ argocd.aks.luvizdev.com
                │
                ├── Scale Down / Scale Up  ──→ az aks stop/start (fast, cheap)
                ├── Clean                  ──→ terraform destroy (keeps state)
                └── Purge                  ──→ destroy + wipe state (nuclear)

Argo CD ─── gitops/applications/ ──→ infra-terraform (TF runner Job)
                                  ──→ workloads (K8s apps consuming TF outputs)
```

## Quick Start

### Prerequisites

- Azure subscription with Owner access
- GitHub repo with OIDC federation configured (done by bootstrap)
- Azure CLI + Terraform ~1.9

### 1. Bootstrap (one-time per subscription)

```sh
cd bootstrap
cp base.bicepparam <org-name>.bicepparam
# Edit the .bicepparam file with your values
./deploy-state <subscription-id> <org-name> [location]
```

Or via GitHub Actions: run the **Bootstrap** workflow.

### 2. Configure GitHub Repository

Set these as GitHub Actions **variables** (Settings → Environments → production):

| Variable | Example |
|---|---|
| `AZURE_CLIENT_ID` | UAI client ID from bootstrap output |
| `AZURE_TENANT_ID` | `8a704dd9-896d-4f97-bca1-1b8720c76951` |
| `AZURE_SUBSCRIPTION_ID` | `37c9effe-ba3f-4b42-aaa7-afdcfeafa9b2` |
| `AKS_CLUSTER_NAME` | From terraform output |
| `AKS_RESOURCE_GROUP` | `rg-dev-aks` |
| `TFSTATE_STORAGE_ACCOUNT` | From bootstrap output |

### 3. Deploy

```sh
cd terraform
terraform init --backend-config ./backend/<env>.tfvars --reconfigure
terraform plan -var-file="<env>.tfvars"
terraform apply -var-file="<env>.tfvars"
```

Or via GitHub Actions: run the **Deploy** workflow.

### 4. Access Argo CD

After deployment, Argo CD is available at **https://argocd.aks.luvizdev.com**.
Login with your Entra ID account (SSO).

## Cost Management (3 Levels)

| Level | Action | What's preserved | Resume speed |
|---|---|---|---|
| **Scale Down** | `az aks stop` | Everything (VNet, ACR, state, config) | ~3 min |
| **Clean** | `terraform destroy` | Bootstrap resources + tfstate | ~10 min |
| **Purge** | destroy + wipe state + delete RG | Nothing | Full bootstrap required |

## GitOps

The `gitops/` folder enables cluster-driven infrastructure management via Argo CD + Terraform.
Devs can add Azure resources in `gitops/terraform/`, and workloads that consume them in `gitops/workloads/`.

- **TF state in K8s secrets** — self-contained, readable from any pod
- **Workload Identity** — no stored Azure credentials
- **Argo CD orchestration** — hooks run TF, syncs deploy workloads

A downloadable boilerplate template is available in `gitops/boilerplate/` for bootstrapping
new GitOps repos. See [docs/gitops-guide.md](docs/gitops-guide.md) for the full guide.

## Repository Structure

```
├── .github/workflows/
│   ├── bootstrap.yml           # One-time infra bootstrap
│   ├── deploy.yml              # Full deployment
│   ├── scale-down.yml          # Stop AKS (minimal cost)
│   ├── scale-up.yml            # Resume AKS
│   ├── clean.yml               # Terraform destroy
│   ├── purge.yml               # Nuclear reset
│   └── build-boilerplate.yml   # Package gitops boilerplate archive
├── bootstrap/                  # Bicep/AVM — state storage + identity
├── terraform/                  # AKS, VNet, ACR, Entra SSO, Front Door, DNS
├── helm/
│   ├── argocd/                 # Argo CD with Entra OIDC SSO
│   ├── envoy-gateway/          # Envoy Gateway (managed by Argo)
│   └── argocd-apps/            # App-of-apps (Envoy + GitOps apps)
├── gitops/                     # Cluster-driven infra via Argo + TF
│   ├── applications/           # Argo CD Application manifests
│   ├── terraform/              # TF code (Kubernetes backend)
│   ├── terraform-runner/       # K8s Job + RBAC + Workload Identity
│   ├── workloads/              # Example app consuming TF outputs
│   └── boilerplate/            # Empty template for new GitOps repos
└── docs/
    └── gitops-guide.md         # Full GitOps onboarding guide
```

## TODO

- [x] Terraform bootstrap
- [x] AVM TF - AKS AVM has bugs and issues in it
- [x] Argo CD with Entra SSO
- [x] Envoy Gateway (managed by Argo)
- [x] GitHub Actions lifecycle (deploy/scale/clean/purge)
- [x] Azure Front Door with managed TLS
- [x] Custom domain (argocd.aks.luvizdev.com via Azure DNS + Cloudflare delegation)
- [x] GitOps boilerplate (Argo CD + Terraform + Kubernetes backend)
- [ ] Egress (NAT Gateway or Azure Firewall)
- [ ] cert-manager + Let's Encrypt for non-Front Door services

