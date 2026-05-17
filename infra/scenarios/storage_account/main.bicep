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

@description('A (UAMI, role definition) pair for granting storage data permissions to an existing UAMI at Storage Account scope.')
type uamiRolePair = {
  @description('Index of the UAMI in `existingUserAssignedIdentities` whose principalId receives the role.')
  uamiIndex: int

  @description('Role definition GUID to grant at Storage Account scope.')
  roleDefinitionGuid: string
}

@description('A (principal, role definition) pair for granting storage data permissions to an existing service principal or user at Storage Account scope.')
type principalRolePair = {
  @description('The Microsoft Entra principal (object) ID that receives the role.')
  principalId: string

  @description('The principal type for the role assignment.')
  principalType: 'ServicePrincipal' | 'User'

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

@description('The kind for the Storage Account')
@allowed([
  'StorageV2'
  'BlockBlobStorage'
  'FileStorage'
])
param kind string = 'StorageV2'

@description('The access tier for the Storage Account (StorageV2 only)')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('When true, enables hierarchical namespace (Data Lake Storage Gen2). StorageV2 only.')
param enableHierarchicalNamespace bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('When true, allows Shared Key (account key / SAS) authorization. Defaults to false for Entra ID-only access.')
param allowSharedKeyAccess bool = false

@description('Blob containers to create. Each element: { name: string, publicAccess?: None|Blob|Container }')
param blobContainers array = [
  {
    name: 'default'
  }
]

@description('Queues to create. Each element: { name: string, metadata?: object }')
param queues array = [
  {
    name: 'default'
  }
]

@description('Tables to create. Each element: { name: string }')
param tables array = [
  {
    name: 'default'
  }
]

@description('File shares to create. Each element: { name: string, shareQuota?: int, accessTier?: TransactionOptimized|Hot|Cool }')
param fileShares array = [
  {
    name: 'default'
  }
]

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to grant storage data permissions. Defaults to an empty array, in which case no UAMI is granted.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object (principal) IDs of existing Microsoft Entra service principals to grant storage data permissions. Defaults to an empty array.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant storage data permissions. Defaults to an empty array.')
param existingUserObjectIds string[] = []

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Storage Account scope.')
param roleDefinitionIds string[] = [
  'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  '974c5e8b-45b9-4653-ba55-5f855dd0fb88'
  '0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3'
  '69566ab7-960f-475b-8e7c-b3118f30c6bd'
]

@description('Enable Azure Monitor based observability resources (Log Analytics workspace and diagnostic settings).')
param enableObservability bool = false

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-templatebicep-${name}'
var storageAccountName = take(toLower(replace(replace('st${name}', '_', ''), '-', '')), 24)
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var storageDiagnosticSettingsName = take('diag-${storageAccountName}', 64)

// Cross-product each identity source with `roleDefinitionIds` into flat lists. `map`/`flatten`
// naturally produce empty lists for empty inputs, so no flag variables or `if` guards are needed
// at the loop sites. UAMI principalIds are resolved at deployment time inside the module loop
// (Bicep requires compile-time-known values in `var` cross products and `for` counts).
var uamiRolePairs uamiRolePair[] = flatten(map(
  range(0, length(existingUserAssignedIdentities)),
  uamiIndex =>
    map(roleDefinitionIds, role => {
      uamiIndex: uamiIndex
      roleDefinitionGuid: role
    })
))

var principalRolePairs principalRolePair[] = concat(
  flatten(map(
    existingServicePrincipalObjectIds,
    pid =>
      map(roleDefinitionIds, role => {
        principalId: pid
        principalType: 'ServicePrincipal'
        roleDefinitionGuid: role
      })
  )),
  flatten(map(
    existingUserObjectIds,
    pid =>
      map(roleDefinitionIds, role => {
        principalId: pid
        principalType: 'User'
        roleDefinitionGuid: role
      })
  ))
)

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
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module storageDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = if (enableObservability) {
  name: take('${name}-diag-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: storageDiagnosticSettingsName
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    targetKind: 'StorageAccount'
    targetName: storageAccountName
  }
  dependsOn: [
    storageAccount
  ]
}

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      targetKind: 'StorageAccount'
      targetName: storageAccountName
      principalId: uamis[pair.uamiIndex].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
    }
    dependsOn: [storageAccount]
  }
]

module principalRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in principalRolePairs: {
    name: take('${name}-principal-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      targetKind: 'StorageAccount'
      targetName: storageAccountName
      principalId: pair.principalId
      principalType: pair.principalType
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
    }
    dependsOn: [storageAccount]
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

@description('The blob endpoint of the created Storage Account')
output blobEndpoint string = storageAccount.outputs.blobEndpoint

@description('The queue endpoint of the created Storage Account')
output queueEndpoint string = storageAccount.outputs.queueEndpoint

@description('The table endpoint of the created Storage Account')
output tableEndpoint string = storageAccount.outputs.tableEndpoint

@description('The file endpoint of the created Storage Account')
output fileEndpoint string = storageAccount.outputs.fileEndpoint

@description('The dfs endpoint of the created Storage Account')
output dfsEndpoint string = storageAccount.outputs.dfsEndpoint

@description('The names of blob containers created')
output blobContainerNames array = storageAccount.outputs.blobContainerNames

@description('The names of queues created')
output queueNames array = storageAccount.outputs.queueNames

@description('The names of tables created')
output tableNames array = storageAccount.outputs.tableNames

@description('The names of file shares created')
output fileShareNames array = storageAccount.outputs.fileShareNames

@description('The resource ID of the created Log Analytics workspace (empty when observability is disabled)')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.?outputs.id ?? ''

@description('Resource IDs of role assignments granted to every existing User Assigned Managed Identity (empty when no UAMI is attached).')
output uamiRoleAssignmentIds string[] = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('Resource IDs of role assignments granted to every existing service principal and user (empty when none are attached).')
output principalRoleAssignmentIds string[] = [
  for (pair, i) in principalRolePairs: principalRoleAssignments[i].outputs.id
]
