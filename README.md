# Dev AKS

An Azure Kubernetes Server designed for devolvement.

Core Idea is to be able to delete and getting it up and running quick, 
for minimal cost.

## Bootstrap

```sh
cd ./bootstrap
cp base.bicepparam {org-name}.bicepparam
```

update the org-name and other parameters, then run.

```sh
./deploy-state {subscription-id} {org-name}
```

## Terraform

### Backend

use the template to make a copy `terraform/backend/template.tfvars

```sh
terraform init --backend-config ./backend/{env}.tfvars --reconfigure
```



# TODO

- [x] Terraform bootstrap
- [x] AVM TF - AKS AVM has bugs and issues in it
- [ ] Egress
- [ ] Argo

