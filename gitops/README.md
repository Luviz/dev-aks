# GitOps — Cluster-Driven Infrastructure

This folder contains a GitOps boilerplate for managing Azure resources from within AKS,
orchestrated by Argo CD.

## How It Works

```
┌─────────────┐     syncs      ┌───────────────────┐
│  Argo CD    │ ──────────────▶│ terraform-runner/  │
│  (in-cluster)│               │ (Terraform CR)     │
└─────────────┘                └────────┬──────────┘
       │                                │ reconciles
       │ syncs                          ▼
       │                       ┌───────────────────┐    provisions   ┌──────────────┐
       │                       │ terraform-operator │ ──────────────▶│  Azure       │
       │                       │ (CRD controller)   │                │  resources   │
       │                       └───────────────────┘                └──────────────┘
       ▼
┌─────────────┐                ┌───────────────────┐
│  workloads/ │ ◀──────────────│ TF outputs (status)│
│  (apps)     │                │                    │
└─────────────┘                └───────────────────┘
```

1. **Argo CD** watches `gitops/applications/` and syncs apps:
   - `infra-terraform` — manages the Terraform CR
   - `workloads` — deploys application manifests
2. **terraform-operator** (GalleyBytes) watches `Terraform` CRs and runs
   plan/apply in runner pods with Workload Identity.
3. **terraform/** holds the TF code. State is stored as K8s secrets
   (Kubernetes backend) — no external storage needed.
4. **TF outputs** are available via the Terraform CR status and can be
   consumed by workloads.

## Folder Structure

| Path                | Purpose                                          |
| ------------------- | ------------------------------------------------ |
| `applications/`     | Argo CD Application manifests                    |
| `terraform/`        | Terraform code for Azure resources               |
| `terraform-runner/` | K8s manifests: Terraform CR, ServiceAccount       |
| `workloads/`        | Application deployments consuming TF outputs     |

## Quick Start

### 1. Add Azure Resources

Edit `terraform/main.tf` to add your Azure resources:

```hcl
resource "azurerm_resource_group" "example" {
  name     = "rg-my-project"
  location = var.location
}
```

### 2. Export Outputs

Add outputs in `terraform/outputs.tf`:

```hcl
output "resource_group_name" {
  value = azurerm_resource_group.example.name
}
```

These are automatically synced to the `gitops-tf-outputs` ConfigMap.

### 3. Consume in Workloads

Reference the ConfigMap in your deployment:

```yaml
envFrom:
  - configMapRef:
      name: gitops-tf-outputs
```

### 4. Commit & Push

Argo CD will detect changes, run the TF Job, and deploy your workloads.

## Terraform State

State is stored as Kubernetes secrets using the `kubernetes` backend:

```sh
# View state
kubectl get secret tfstate-default -n gitops-system -o jsonpath='{.data.tfstate}' | base64 -d

# List all TF state secrets
kubectl get secrets -n gitops-system -l app.kubernetes.io/managed-by=terraform
```

## Workload Identity

The TF runner uses Azure Workload Identity to authenticate with Azure.
The ServiceAccount in `terraform-runner/serviceaccount.yaml` is annotated
with the managed identity client ID from the bootstrap layer.

Update `configmap-tfvars.yaml` to set `ARM_CLIENT_ID` and `ARM_SUBSCRIPTION_ID`
for your environment.

## Adding New TF Modules

1. Create a new `.tf` file in `terraform/`
2. Add outputs you want exposed in `terraform/outputs.tf`
3. Commit and let Argo CD sync
