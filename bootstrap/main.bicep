@description('Optional. Location of the Resource Group. It uses the deployment\'s location when not provided.')
param location string = deployment().location

@description('Required. The name of the Resource Group for Terraform state files.')
param tfstateResourceGroupName string

@maxLength(24)
@description('Required. Name of the Storage Account. Must be lower-case.')
param storageAccountName string


@description('Required. Name of the User Assigned Identity.')
param managedIdentityName string

@description('Required. Name target RG.')
param workspaceResourceGroupName string

@description('super user to get access tfstate data plain.')
param superUser string


// @description('Required. The subject for the managed identity federated credentials.')
// param azureDevOpsFederatedCredentialsSubject string

targetScope = 'subscription'

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

module storageAccount 'br/public:avm/res/storage/storage-account:0.31.0' = {
  name: 'storageAccountDeployment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    name: storageAccountName
    kind: 'StorageV2'
    skuName: 'Standard_LRS'
    allowSharedKeyAccess: false
    // allowBlobPublicAccess should be set to false when a private network is available
    // and the storage account should use private endpoint
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
      // defaultAction should be set to 'Deny' when a private network is available
      // and the storage account uses private endpoint
      defaultAction: 'Allow'
    }
    enableTelemetry: false
  }
}

module userAssignedIdentity 'br/public:avm/res/managed-identity/user-assigned-identity:0.5.0' = {
  name: 'userAssignedIdentityDeployment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    name: managedIdentityName
    location: location
    enableTelemetry: false
    tags: {
      deploymentType: 'bicep'
    }
  }
  dependsOn: [
    tfstateResourceGroup
  ]
}

module workspaceRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'workspaceRoleAssignmentDeployment'
  scope: az.resourceGroup(workspaceResourceGroupName)
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionIdOrName: 'Owner'
    principalType: 'ServicePrincipal'
    enableTelemetry: false
  }
}

module tfstateRoleAssignment 'br/public:avm/res/authorization/role-assignment/rg-scope:0.1.1' = {
  name: 'tfstateRoleAssignment'
  scope: az.resourceGroup(tfstateResourceGroupName)
  params: {
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionIdOrName: '/providers/Microsoft.Authorization/roleDefinitions/ba92f5b4-2d11-453d-a403-e96b0029c9fe'
    principalType: 'ServicePrincipal'
    enableTelemetry: false
  }
}

// adding super user with access

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
