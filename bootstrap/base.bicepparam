using './main.bicep'

// ── Customise these per org/tenant ─────────────────────────
var locationShort = 'we'
var environment = 'dev'
var org = '$ORG_NAME'

param location = 'westeurope'
param tfstateResourceGroupName = 'rg-${environment}-${locationShort}-tfstate'
param storageAccountName = 'sa${environment}${locationShort}${org}tfstate'
param managedIdentityName = 'uai-${environment}-${locationShort}-identity-id'
param workspaceResourceGroupName = 'rg-${environment}-aks'
param superUser = '$SUPER_USER_OBJECT_ID' // Entra object ID of the super-user

// ── GitHub OIDC federation ─────────────────────────────────
param gitHubOrg = '$GITHUB_ORG'   // e.g. 'Luviz'
param gitHubRepo = '$GITHUB_REPO' // e.g. 'dev-aks'
param gitHubBranches = ['main']
param gitHubEnvironments = ['production']
