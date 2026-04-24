# GitOps Boilerplate

A ready-to-use template for managing Azure resources from AKS via Argo CD + Terraform.

## Setup

1. Copy this folder to your repo (or extract the archive)
2. Edit configuration (see below)
3. Register with Argo CD

## Configuration Checklist

- [ ] `terraform-runner/serviceaccount.yaml` — set `azure.workload.identity/client-id`
- [ ] `terraform-runner/terraform-cr.yaml` — update `terraformModule.source` repo URL
- [ ] `terraform-runner/terraform-cr.yaml` — set subscription, tenant, project name in `taskOptions`
- [ ] `terraform/main.tf` — add your Azure resources
- [ ] `terraform/outputs.tf` — add outputs (operator writes them to a status)
- [ ] `workloads/` — replace example-app with your workloads
- [ ] `applications/*.yaml` — update `repoURL` to your Git repo

## Register with Argo CD

### Option A: Add to app-of-apps

Add an Application template in `helm/argocd-apps/templates/` pointing to your
repo's `applications/` folder.

### Option B: Apply directly

```sh
kubectl apply -f applications/ -n argocd
```

### Option C: Use the gitops/applications/ folder

Add your Application YAML to the existing `gitops/applications/` folder in the
dev-aks repo and include it in the kustomization.yaml.

## More Info

See [docs/gitops-guide.md](../docs/gitops-guide.md) in the dev-aks repo.
