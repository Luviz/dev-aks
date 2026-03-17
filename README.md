# Dev AKS

An Azure Kubernetes Server designed for devolvement.

Core Idea is to be able to delete and getting it up and running quick, 
for minimal cost.

# Bootstrap

```sh
cd ./bootstrap
cp base.bicepparam {org-name}.bicepparam
```

update the org-name and other parameters, then run.

```sh
./deploy-state {subscription-id} {org-name}
```

# TODO

- [x] Terraform bootstrap
- [ ] AVM TF
- [ ] Egress
- [ ] Argo

