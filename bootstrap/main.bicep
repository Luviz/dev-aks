// ──────────────────────────────────────────────────────────
// Bootstrap: tfstate storage, managed identity, OIDC federation
// Designed to be portable across tenants and subscriptions.
// ──────────────────────────────────────────────────────────

targetScope = 'subscription'

// ── Core parameters ────────────────────────────────────────

@description('Optional. Location of the Resource Group. It uses the deployment\'s location when not provided.')
param location string = deployment().location

@description('Required. The name of the Resource Group for Terraform state files.')
param tfstateResourceGroupName string

@maxLength(24)
@description('Required. Name of the Storage Account. Must be lower-case.')
param storageAccountName string

@description('Required. Name of the User Assigned Identity.')
param managedIdentityName string

@description('Required. Name of the workspace Resource Group (where AKS etc. live).')
param workspaceResourceGroupName string

@description('Object ID of a super-user who gets direct access to tfstate data plane.')
param superUser string

// ── GitHub OIDC federation ─────────────────────────────────

@description('GitHub organisation or username that owns the repo (e.g. "Luviz").')
param gitHubOrg string

@description('GitHub repository name (e.g. "dev-aks").')
param gitHubRepo string

@description('Git branches that are allowed to authenticate via OIDC. Default: main.')
param gitHubBranches array = ['main']

@description('Allow GitHub environment-based OIDC subjects. Leave empty to skip.')
param gitHubEnvironments array = ['production']

// ── Resource Groups ────────────────────────────────────────

module tfstateResourceGroup 'br/public:avm/res/resources/resource-group:0.4.2' = {
  name: 'tfstateResourceGroupDeployment'
  params: {
    name: tfstateResourceGroupName
    location: location
    enableTelemetry: false
    tags: {
      deploymentType: 'bicep'
    }
  }
}

module workspaceResourceGroup 'br/public:avm/res/resources/resource-group:0.4.2' = {
  name: 'workspaceResourceGroupDeployment'
  params: {
    name: workspaceResourceGroupName
    location: location
    enableTelemetry: false
    tags: {
      deploymentType: 'bicep'
    }
  }
}

// ── Storage Account (tfstate) ──────────────────────────────

module storageAccount 'br/public:avm/res/storage/storage-account:0.31.0' = {
  name: 'storageAccountDeployment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    name: storageAccountName
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    allowBlobPublicAccess: true
    tags: {
      deploymentType: 'bicep'
    }
    blobServices: {
      automaticSnapshotPolicyEnabled: true
      containerDeleteRetentionPolicyDays: 10
      containerDeleteRetentionPolicyEnabled: true
      containers: [
        {
          name: 'tfstate'
          publicAccess: 'None'
          roleAssignments: [
            {
              principalId: userAssignedIdentity.outputs.principalId
              principalType: 'ServicePrincipal'
              roleDefinitionIdOrName: 'Storage Blob Data Contributor'
            }
          ]
        }
      ]
      deleteRetentionPolicyDays: 9
      deleteRetentionPolicyEnabled: true
      isVersioningEnabled: true
      lastAccessTimeTrackingPolicyEnabled: true
      versionDeletePolicyDays: 3
    }
    networkAcls: {
      defaultAction: 'Allow'
    }
    enableTelemetry: false
  }
}

// ── Managed Identity + GitHub OIDC federation ──────────────

var ghIssuer = 'https://token.actions.githubusercontent.com'

var branchCredentials = [
  for branch in gitHubBranches: {
    name: 'gh-${gitHubOrg}-${gitHubRepo}-branch-${branch}'
    audiences: ['api://AzureADTokenExchange']
    issuer: ghIssuer
    subject: 'repo:${gitHubOrg}/${gitHubRepo}:ref:refs/heads/${branch}'
  }
]

var envCredentials = [
  for env in gitHubEnvironments: {
    name: 'gh-${gitHubOrg}-${gitHubRepo}-env-${env}'
    audiences: ['api://AzureADTokenExchange']
    issuer: ghIssuer
    subject: 'repo:${gitHubOrg}/${gitHubRepo}:environment:${env}'
  }
]

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.0' = {
  name: 'userAssignedIdentityDeployment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    name: managedIdentityName
    location: location
    enableTelemetry: false
    federatedIdentityCredentials: concat(branchCredentials, envCredentials)
    tags: {
      deploymentType: 'bicep'
    }
  }
  dependsOn: [
    tfstateResourceGroup
  ]
}

// ── Role Assignments ───────────────────────────────────────

module workspaceRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'workspaceRoleAssignmentDeployment'
  scope: az.resourceGroup(workspaceResourceGroupName)
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionIdOrName: 'Owner'
    principalType: 'ServicePrincipal'
    enableTelemetry: false
  }
  dependsOn: [
    workspaceResourceGroup
  ]
}

// Storage Blob Data Owner on the tfstate RG
module tfstateRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'tfstateRoleAssignment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'ServicePrincipal'
    enableTelemetry: false
  }
  dependsOn: [
    tfstateResourceGroup
  ]
}

module tfstateUserRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'tfstateUserRoleAssignment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    principalId: superUser
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    enableTelemetry: false
    principalType: 'User'
  }
}

// ── Outputs ────────────────────────────────────────────────

output managedIdentityClientId string = userAssignedIdentity.outputs.clientId
output managedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId
output managedIdentityName string = userAssignedIdentity.outputs.name
output storageAccountName string = storageAccount.outputs.name
output tfstateResourceGroupName string = tfstateResourceGroupName
output workspaceResourceGroupName string = workspaceResourceGroupName
