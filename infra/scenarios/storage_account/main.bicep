targetScope = 'subscription'

// ------------------
//    TYPES
// ------------------

@description('Reference to an existing User Assigned Managed Identity (UAMI).')
type uamiReference = {
  @description('The name of the existing User Assigned Managed Identity.')
  name: string

  @description('The resource group name where the existing UAMI lives.')
  resourceGroup: string
}

@description('A (UAMI, role definition) pair generated for each role assignment iteration.')
type uamiRolePair = {
  @description('Index of the UAMI in `existingUserAssignedIdentities` whose principalId receives the role.')
  uamiIndex: int

  @description('Role definition GUID to grant at Storage Account scope.')
  roleDefinitionGuid: string
}

@description('A (principal object ID, role definition) pair generated for each service principal/user role assignment iteration.')
type principalRolePair = {
  @description('The Microsoft Entra principal (object) ID that receives the role.')
  principalId: string

  @description('Role definition GUID to grant at Storage Account scope.')
  roleDefinitionGuid: string
}

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and Storage Account resources')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

@description('The SKU name for the Storage Account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
  'Premium_LRS'
])
param skuName string = 'Standard_LRS'

@description('The kind of Storage Account')
@allowed([
  'StorageV2'
  'BlockBlobStorage'
  'FileStorage'
])
param kind string = 'StorageV2'

@description('The access tier for the Storage Account')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHierarchicalNamespace bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Allow shared key access (Entra ID-only when false)')
param allowSharedKeyAccess bool = false

@description('Blob containers to create')
param blobContainers array = [
  {
    name: 'default'
  }
]

@description('Queues to create')
param queues array = [
  {
    name: 'default'
  }
]

@description('Tables to create')
param tables array = [
  {
    name: 'default'
  }
]

@description('File shares to create')
param fileShares array = [
  {
    name: 'default'
  }
]

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to grant Storage Data permissions. Defaults to an empty array, in which case no UAMI is attached.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object (principal) IDs of existing Microsoft Entra service principals to grant Storage Data permissions. Defaults to an empty array, in which case no service principal is attached.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant Storage Data permissions. Defaults to an empty array, in which case no user is attached.')
param existingUserObjectIds string[] = []

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Storage Account scope.')
param roleDefinitionIds string[] = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe' // Storage Blob Data Contributor
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88' // Storage Queue Data Contributor
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3' // Storage Table Data Contributor
  '69566ab7-960f-475b-8e7c-b3118f30c6bd' // Storage File Data SMB Share Contributor
]

@description('Enable Azure Monitor based observability resources (Log Analytics workspace and diagnostic settings).')
param enableObservability bool = false

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var storageAccountName = take(toLower(replace(replace('st${name}', '_', ''), '-', '')), 24)
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var storageDiagnosticSettingsName = take('diag-${storageAccountName}', 64)

// Cross-product each identity array with `roleDefinitionIds` into a flat list of struct pairs.
var uamiRolePairs uamiRolePair[] = flatten(map(
  range(0, length(existingUserAssignedIdentities)),
  uamiIndex =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      uamiIndex: uamiIndex
      roleDefinitionGuid: roleDefinitionGuid
    })
))

var servicePrincipalRolePairs principalRolePair[] = flatten(map(
  existingServicePrincipalObjectIds,
  principalId =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      principalId: principalId
      roleDefinitionGuid: roleDefinitionGuid
    })
))

var userRolePairs principalRolePair[] = flatten(map(
  existingUserObjectIds,
  principalId =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      principalId: principalId
      roleDefinitionGuid: roleDefinitionGuid
    })
))

// ------------------
//    EXISTING RESOURCES
// ------------------

resource uamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for uami in existingUserAssignedIdentities: {
    scope: az.resourceGroup(uami.resourceGroup)
    name: uami.name
  }
]

// ------------------
//    RESOURCES
// ------------------

module resourceGroup '../../modules/resource_group/main.bicep' = {
  name: take('${name}-rg-deployment', 64)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module storageAccount '../../modules/storage_account/main.bicep' = {
  name: take('${name}-storage-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: storageAccountName
    location: location
    tags: tags
    skuName: skuName
    kind: kind
    accessTier: accessTier
    enableHierarchicalNamespace: enableHierarchicalNamespace
    publicNetworkAccess: publicNetworkAccess
    allowSharedKeyAccess: allowSharedKeyAccess
    blobContainers: blobContainers
    queues: queues
    tables: tables
    fileShares: fileShares
  }
  dependsOn: [resourceGroup]
}

module logAnalyticsWorkspace '../../modules/log_analytics_workspace/main.bicep' = if (enableObservability) {
  name: take('${name}-law-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module storageDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = if (enableObservability) {
  name: take('${name}-storage-diag-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: storageDiagnosticSettingsName
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    #disable-next-line BCP334
    targetStorageAccountName: storageAccountName
    storageServices: ['blob', 'queue', 'table', 'file']
  }
  dependsOn: [storageAccount]
}

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetStorageAccountName: storageAccountName
      principalId: uamis[pair.uamiIndex].properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        storageAccount.outputs.id,
        uamis[pair.uamiIndex].properties.principalId,
        pair.roleDefinitionGuid
      )
      principalType: 'ServicePrincipal'
    }
  }
]

module servicePrincipalRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in servicePrincipalRolePairs: {
    name: take('${name}-sp-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetStorageAccountName: storageAccountName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(storageAccount.outputs.id, pair.principalId, pair.roleDefinitionGuid)
      principalType: 'ServicePrincipal'
    }
  }
]

module userRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in userRolePairs: {
    name: take('${name}-user-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetStorageAccountName: storageAccountName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(storageAccount.outputs.id, pair.principalId, pair.roleDefinitionGuid)
      principalType: 'User'
    }
  }
]

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the created resource group')
output resourceGroupId string = resourceGroup.outputs.id

@description('The name of the created resource group')
output resourceGroupName string = resourceGroup.outputs.name

@description('The location of the created resource group')
output resourceGroupLocation string = resourceGroup.outputs.location

@description('The resource ID of the created Storage Account')
output storageAccountId string = storageAccount.outputs.id

@description('The name of the created Storage Account')
output storageAccountName string = storageAccount.outputs.name

@description('The blob endpoint')
output blobEndpoint string = storageAccount.outputs.blobEndpoint

@description('The queue endpoint')
output queueEndpoint string = storageAccount.outputs.queueEndpoint

@description('The table endpoint')
output tableEndpoint string = storageAccount.outputs.tableEndpoint

@description('The file endpoint')
output fileEndpoint string = storageAccount.outputs.fileEndpoint

@description('The DFS endpoint (for HNS-enabled accounts)')
output dfsEndpoint string = storageAccount.outputs.dfsEndpoint

@description('The names of created blob containers')
output blobContainerNames array = storageAccount.outputs.blobContainerNames

@description('The names of created queues')
output queueNames array = storageAccount.outputs.queueNames

@description('The names of created tables')
output tableNames array = storageAccount.outputs.tableNames

@description('The names of created file shares')
output fileShareNames array = storageAccount.outputs.fileShareNames

@description('The resource ID of the created Log Analytics workspace (empty when observability is disabled)')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.?outputs.id ?? ''

@description('The resource IDs of role assignments granted to every existing User Assigned Managed Identity (empty when no UAMI is attached)')
output uamiRoleAssignmentIds string[] = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('The resource IDs of role assignments granted to every existing service principal (empty when no service principal is attached)')
output servicePrincipalRoleAssignmentIds string[] = [
  for (pair, i) in servicePrincipalRolePairs: servicePrincipalRoleAssignments[i].outputs.id
]

@description('The resource IDs of role assignments granted to every existing user (empty when no user is attached)')
output userRoleAssignmentIds string[] = [for (pair, i) in userRolePairs: userRoleAssignments[i].outputs.id]
