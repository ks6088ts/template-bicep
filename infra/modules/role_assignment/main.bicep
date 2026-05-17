// ------------------
//    PARAMETERS
// ------------------

@description('Kind of the resource that the role is scoped to (legacy parameter; prefer target*Name parameters).')
@allowed([
  ''
  'CognitiveServicesAccount'
  'StorageAccount'
  'ContainerRegistry'
  'ContainerApp'
])
param targetKind string = ''

@description('Name of the target resource (legacy parameter paired with targetKind; prefer target*Name parameters).')
param targetName string = ''

@description('Name of the target Cognitive Services account scope.')
param targetAccountName string = ''

@description('Name of the target Storage account scope.')
param targetStorageAccountName string = ''

@description('Name of the target Container Registry scope.')
param targetRegistryName string = ''

@description('Name of the target Container App scope.')
param targetContainerAppName string = ''

@description('Principal (object) ID that receives the role assignment.')
param principalId string

@description('Fully qualified role definition resource ID.')
param roleDefinitionId string

@description('Principal type for the role assignment.')
@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

// ------------------
//    VARIABLES
// ------------------

var legacyTargetAccountName = targetKind == 'CognitiveServicesAccount' ? targetName : ''
var legacyTargetStorageAccountName = targetKind == 'StorageAccount' ? targetName : ''
var legacyTargetRegistryName = targetKind == 'ContainerRegistry' ? targetName : ''
var legacyTargetContainerAppName = targetKind == 'ContainerApp' ? targetName : ''

var resolvedStorageAccountName = !empty(targetStorageAccountName)
  ? targetStorageAccountName
  : legacyTargetStorageAccountName
var resolvedAccountName = !empty(targetAccountName) ? targetAccountName : legacyTargetAccountName
var resolvedRegistryName = !empty(targetRegistryName) ? targetRegistryName : legacyTargetRegistryName
var resolvedContainerAppName = !empty(targetContainerAppName) ? targetContainerAppName : legacyTargetContainerAppName

var roleAssignmentScopeName = !empty(resolvedStorageAccountName)
  ? resolvedStorageAccountName
  : !empty(resolvedAccountName)
      ? resolvedAccountName
      : !empty(resolvedRegistryName) ? resolvedRegistryName : resolvedContainerAppName

var roleAssignmentScopeKind = !empty(resolvedStorageAccountName)
  ? 'StorageAccount'
  : !empty(resolvedAccountName)
      ? 'CognitiveServicesAccount'
      : !empty(resolvedRegistryName) ? 'ContainerRegistry' : 'ContainerApp'

var isStorage = roleAssignmentScopeKind == 'StorageAccount'
var isCognitiveServices = roleAssignmentScopeKind == 'CognitiveServicesAccount'
var isRegistry = roleAssignmentScopeKind == 'ContainerRegistry'
var isContainerApp = roleAssignmentScopeKind == 'ContainerApp'

var roleAssignmentName = guid(roleAssignmentScopeKind, roleAssignmentScopeName, principalId, roleDefinitionId)

// ------------------
//    RESOURCES
// ------------------

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (isCognitiveServices) {
  name: roleAssignmentScopeName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (isStorage) {
  name: roleAssignmentScopeName
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = if (isRegistry) {
  name: roleAssignmentScopeName
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' existing = if (isContainerApp) {
  name: roleAssignmentScopeName
}

resource roleAssignmentAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isCognitiveServices) {
  name: roleAssignmentName
  scope: cognitiveAccount
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isStorage) {
  name: roleAssignmentName
  scope: storageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentRegistry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isRegistry) {
  name: roleAssignmentName
  scope: containerRegistry
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentContainerApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (isContainerApp) {
  name: roleAssignmentName
  scope: containerApp
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the role assignment.')
output id string = isStorage
  ? roleAssignmentStorage.id
  : isCognitiveServices
      ? roleAssignmentAccount.id
      : isRegistry ? roleAssignmentRegistry.id : roleAssignmentContainerApp.id

@description('The name (GUID) of the role assignment.')
output name string = roleAssignmentName
