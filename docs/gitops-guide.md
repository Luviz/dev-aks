# GitOps Guide — Cluster-Driven Infrastructure with Argo CD

This guide explains the GitOps structure in this repository and how to register
new repos for Argo CD to manage.

## Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Folder Structure](#folder-structure)
- [Terraform State](#terraform-state)
- [Registering a New GitOps Repo](#registering-a-new-gitops-repo)
- [Using the Boilerplate](#using-the-boilerplate)
- [Workload Identity Setup](#workload-identity-setup)
- [Consuming Terraform Outputs](#consuming-terraform-outputs)
- [Troubleshooting](#troubleshooting)

---

## Overview

The `gitops/` folder enables a pattern where **Argo CD manages both Kubernetes
workloads and Azure infrastructure** from within the AKS cluster. Terraform runs
as a Kubernetes Job (triggered by Argo CD sync hooks), and its state is stored as
Kubernetes secrets — making everything self-contained within the cluster.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│ AKS Cluster                                                      │
│                                                                  │
│  ┌──────────┐    watches     ┌──────────────────┐                │
│  │ Argo CD  │ ──────────────▶│ Git repo          │                │
│  └────┬─────┘                │ gitops/            │                │
│       │                      └──────────────────┘                │
│       │ syncs                                                    │
│       ▼                                                          │
│  ┌──────────────────┐   runs    ┌─────────────────┐             │
│  │ terraform-runner │ ─────────▶│ Terraform        │             │
│  │ (K8s Job)        │           │ → Azure resources│             │
│  └────────┬─────────┘           └─────────────────┘             │
│           │                                                      │
│           │ outputs                                              │
│           ▼                                                      │
│  ┌──────────────────┐   env     ┌─────────────────┐             │
│  │ gitops-tf-outputs│ ─────────▶│ workloads/       │             │
│  │ (ConfigMap)      │           │ (Deployments)    │             │
│  └──────────────────┘           └─────────────────┘             │
│                                                                  │
│  State: K8s Secrets (tfstate-default in gitops-system)           │
│  Auth:  Azure Workload Identity (no stored credentials)          │
└──────────────────────────────────────────────────────────────────┘
```

## Folder Structure

```
gitops/
├── applications/                 # Argo CD Application definitions
│   ├── kustomization.yaml
│   ├── infra-terraform.yaml      # Points to terraform-runner/
│   └── workloads.yaml            # Points to workloads/
│
├── terraform/                    # Terraform code for Azure resources
│   ├── backend.tf                # Kubernetes backend (state → K8s secrets)
│   ├── providers.tf              # azurerm with Workload Identity (OIDC)
│   ├── main.tf                   # Your Azure resources go here
│   ├── variables.tf              # Input variables
│   ├── outputs.tf                # Outputs available via Terraform CR status
│
├── terraform-runner/             # K8s manifests for terraform-operator
│   ├── kustomization.yaml
│   ├── namespace.yaml            # gitops-system namespace
│   ├── serviceaccount.yaml       # Workload Identity SA
│   └── terraform-cr.yaml         # Terraform CR (operator reconciles this)
│
├── workloads/                    # K8s workloads consuming TF outputs
│   ├── kustomization.yaml
│   └── example-app/
│       ├── deployment.yaml       # References gitops-tf-outputs ConfigMap
│       └── service.yaml
│
└── boilerplate/                  # Empty template for new repos
```

## Terraform State

State is stored using the **Kubernetes backend** — each state file becomes a
Kubernetes secret in the `gitops-system` namespace.

```hcl
# backend.tf
terraform {
  backend "kubernetes" {
    secret_suffix = "default"
    namespace     = "gitops-system"
  }
}
```

### Reading state from K8s

```sh
# View the raw state
kubectl get secret tfstate-default -n gitops-system \
  -o jsonpath='{.data.tfstate}' | base64 -d | jq .

# List all TF state secrets
kubectl get secrets -n gitops-system -l app.kubernetes.io/managed-by=terraform
```

### Why Kubernetes backend?

| Feature | Kubernetes Backend | Azure Storage Backend |
|---|---|---|
| External deps | None | Storage account + SAS/RBAC |
| Cluster lifecycle | State tied to cluster | State persists independently |
| Access from pods | Native (K8s API) | Needs Azure SDK |
| Best for | Ephemeral dev clusters | Long-lived environments |

For dev/test clusters that are torn down regularly, the Kubernetes backend keeps
everything self-contained. If you need persistent state across cluster rebuilds,
switch to the Azure Storage backend.

---

## Registering a New GitOps Repo

To have Argo CD manage a new Git repository, you create an Argo CD `Application`
resource. There are three ways to do this:

### Option 1: Add to app-of-apps (recommended)

Add a new template in `helm/argocd-apps/templates/`:

```yaml
# helm/argocd-apps/templates/my-project.yaml
{{- if .Values.myProject.enabled }}
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-project
  namespace: {{ .Release.Namespace }}
  labels:
    {{- include "argocd-apps.labels" . | nindent 4 }}
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: {{ .Values.myProject.repoURL | quote }}
    targetRevision: {{ .Values.myProject.targetRevision | default "main" }}
    path: {{ .Values.myProject.path }}
  destination:
    server: https://kubernetes.default.svc
    namespace: {{ .Values.myProject.namespace }}
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
{{- end }}
```

And add values in `helm/argocd-apps/values.yaml`:

```yaml
myProject:
  enabled: true
  repoURL: "https://github.com/my-org/my-project.git"
  targetRevision: main
  path: k8s/
  namespace: my-project
```

### Option 2: Add an Application manifest to gitops/applications/

Create a YAML file in `gitops/applications/` and add it to the kustomization:

```yaml
# gitops/applications/my-project.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: my-project
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/my-org/my-project.git
    targetRevision: main
    path: k8s/
  destination:
    server: https://kubernetes.default.svc
    namespace: my-project
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

```yaml
# gitops/applications/kustomization.yaml
resources:
  - infra-terraform.yaml
  - workloads.yaml
  - my-project.yaml          # ← add here
```

### Option 3: ApplicationSet (for many repos with similar structure)

If you have many repos with the same GitOps layout, use an `ApplicationSet`:

```yaml
apiVersion: argoproj.io/v1alpha1
kind: ApplicationSet
metadata:
  name: team-projects
  namespace: argocd
spec:
  generators:
    - list:
        elements:
          - name: project-a
            repoURL: https://github.com/my-org/project-a.git
            path: k8s/
          - name: project-b
            repoURL: https://github.com/my-org/project-b.git
            path: k8s/
  template:
    metadata:
      name: "{{name}}"
    spec:
      project: default
      source:
        repoURL: "{{repoURL}}"
        targetRevision: main
        path: "{{path}}"
      destination:
        server: https://kubernetes.default.svc
        namespace: "{{name}}"
      syncPolicy:
        automated:
          prune: true
          selfHeal: true
        syncOptions:
          - CreateNamespace=true
```

### Private repos

For private Git repos, create a secret in the `argocd` namespace:

```sh
kubectl create secret generic my-repo-creds \
  -n argocd \
  --from-literal=url=https://github.com/my-org/my-private-repo.git \
  --from-literal=username=git \
  --from-literal=password=<PAT or deploy key>
kubectl label secret my-repo-creds -n argocd \
  argocd.argoproj.io/secret-type=repository
```

Or use SSH:

```sh
kubectl create secret generic my-repo-ssh \
  -n argocd \
  --from-literal=url=git@github.com:my-org/my-private-repo.git \
  --from-literal=sshPrivateKey="$(cat ~/.ssh/deploy_key)" \
  --from-literal=type=git
kubectl label secret my-repo-ssh -n argocd \
  argocd.argoproj.io/secret-type=repository
```

---

## Using the Boilerplate

A ready-to-use boilerplate is available in `gitops/boilerplate/`. You can either
copy it manually or download the pre-built archive from GitHub Actions.

### Download the archive

1. Go to **Actions** → **Build GitOps Boilerplate** → latest run
2. Download the `gitops-boilerplate` artifact
3. Extract: `tar xzf gitops-boilerplate.tar.gz`

### Set up a new repo from the boilerplate

```sh
# 1. Extract the boilerplate
tar xzf gitops-boilerplate.tar.gz
cd gitops-boilerplate

# 2. Edit the configuration
#    Update placeholders in terraform-runner/configmap-tfvars.yaml:
#    - ARM_SUBSCRIPTION_ID
#    - ARM_TENANT_ID
#    - TF_VAR_project_name
#    - TF_VAR_location

#    Update terraform-runner/serviceaccount.yaml:
#    - azure.workload.identity/client-id

# 3. Add your Terraform resources
#    Edit terraform/main.tf with your Azure resources
#    Add outputs in terraform/outputs.tf

# 4. Add your workloads
#    Replace workloads/example-app/ with your deployments

# 5. Commit and register with Argo CD
#    See "Registering a New GitOps Repo" above
```

---

## Workload Identity Setup

The terraform-runner uses Azure Workload Identity to authenticate with Azure
without storing credentials. This requires:

1. **A User-Assigned Managed Identity** (created in the bootstrap layer or manually)
2. **A Federated Credential** linking the K8s SA to the managed identity

### Create the identity (if not done by bootstrap)

```sh
# Create the managed identity
az identity create \
  -g rg-dev-aks \
  -n id-gitops-terraform-runner \
  --query '{clientId:clientId, principalId:principalId}' -o json

# Assign Contributor on the target subscription/RG
az role assignment create \
  --assignee <principalId> \
  --role Contributor \
  --scope /subscriptions/<sub-id>

# Create federated credential
az identity federated-credential create \
  -g rg-dev-aks \
  --identity-name id-gitops-terraform-runner \
  -n gitops-terraform-runner \
  --issuer $(az aks show -g rg-dev-aks -n <aks-name> --query oidcIssuerProfile.issuerUrl -o tsv) \
  --subject system:serviceaccount:gitops-system:terraform-runner \
  --audiences api://AzureADTokenExchange
```

### Update the ServiceAccount

Set the client ID in `terraform-runner/serviceaccount.yaml`:

```yaml
annotations:
  azure.workload.identity/client-id: "<YOUR_CLIENT_ID>"
```

---

## Consuming Terraform Outputs

After the terraform-operator applies the Terraform CR, outputs are available
in the CR's status. You can read them with:

```sh
# View Terraform CR status and outputs
kubectl get terraform gitops-infra -n gitops-system -o jsonpath='{.status}' | jq .

# View specific output
kubectl get terraform gitops-infra -n gitops-system -o jsonpath='{.status.outputs.resource_group_name}'
```

To make outputs available as a ConfigMap for workloads, create an ExternalSecret
or a simple CronJob that reads the CR status and writes to a ConfigMap.

---

## Troubleshooting

### Terraform CR not reconciling

```sh
# Check Terraform CR status
kubectl get terraform -n gitops-system
kubectl describe terraform gitops-infra -n gitops-system

# View runner pod logs
kubectl get pods -n gitops-system -l app.kubernetes.io/created-by=terraform-operator
kubectl logs -n gitops-system -l app.kubernetes.io/created-by=terraform-operator --tail=100

# Check operator logs
kubectl logs -n tf-system -l app.kubernetes.io/name=terraform-operator --tail=50
```

### State locked

```sh
# Check for state lock lease
kubectl get leases -n gitops-system

# Force unlock (use with caution)
kubectl delete lease tflock-default -n gitops-system
```

### ConfigMap not created

If you need TF outputs in a ConfigMap, create a CronJob or use the Kubernetes
Replicator operator to sync from the Terraform CR status.

### Argo CD not syncing

```sh
# Check app status
argocd app get infra-terraform
argocd app get workloads

# Force sync
argocd app sync infra-terraform
```
