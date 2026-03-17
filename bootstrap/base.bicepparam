using './main.bicep'

var locationShort = 'we'
var environment = 'dev'
var org = '$ORG_NAME'

param location = 'swedencentral' // Azure location where the resources will be deployed
param tfstateResourceGroupName = 'rg-${environment}-${locationShort}-tfstate' // The name of resource group to create where the storage account for Terraform state will be located
param storageAccountName = 'sa${environment}${locationShort}${org}tfstate' // The name of the storage account to create where the Tearrform states will be located
param managedIdentityName = 'uai-${environment}-${locationShort}-identity-id' // The name of managed identity to create
param workspaceResourceGroupName = 'rg-${environment}-aks'
