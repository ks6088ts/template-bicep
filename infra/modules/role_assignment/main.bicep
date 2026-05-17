// ------------------
//    PARAMETERS
// ------------------

@description('The name of the target Azure AI Foundry (Cognitive Services) account resource. Provide either this or targetStorageAccountName.')
@minLength(0)
@maxLength(59)
param targetAccountName string = ''

@description('The name of the target Azure Storage Account resource. Provide either this or targetAccountName.')
@minLength(0)
@maxLength(24)
param targetStorageAccountName string = ''

@description('The name of the target Azure Container Registry (ACR) resource. Provide either this or one of the other target*Name parameters.')
@minLength(0)
@maxLength(50)
param targetRegistryName string = ''

@description('The name of the target Azure Container App resource. Provide either this or one of the other target*Name parameters.')
@minLength(0)
@maxLength(32)
param targetContainerAppName string = ''

@description('The principal ID that receives the role assignment')
@minLength(1)
param principalId string

@description('The fully qualified role definition resource ID')
@minLength(1)
param roleDefinitionId string

@description('The principal type for the role assignment')
@allowed([
  'Device'
  'ForeignGroup'
  'Group'
  'ServicePrincipal'
  'User'
])
param principalType string = 'ServicePrincipal'

@description('Optional deterministic seed for role assignment name; when omitted, a deterministic name is generated')
param roleAssignmentNameSeed string = ''

// ------------------
//    VARIABLES
// ------------------

var useContainerAppTarget = !empty(targetContainerAppName)
var useRegistryTarget = !useContainerAppTarget && !empty(targetRegistryName)
var useStorageTarget = !useContainerAppTarget && !useRegistryTarget && !empty(targetStorageAccountName)
var useAccountTarget = !useContainerAppTarget && !useRegistryTarget && !useStorageTarget && !empty(targetAccountName)

var roleAssignmentScopeName = useContainerAppTarget
  ? targetContainerAppName
  : (useRegistryTarget ? targetRegistryName : (useStorageTarget ? targetStorageAccountName : targetAccountName))

var roleAssignmentName = empty(roleAssignmentNameSeed)
  ? guid(roleAssignmentScopeName, principalId, roleDefinitionId)
  : roleAssignmentNameSeed

// ------------------
//    RESOURCES
// ------------------

// NOTE: API version pinned to `2025-06-01` to match the parent Foundry account module.
resource targetAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (!empty(targetAccountName)) {
  #disable-next-line BCP334
  name: !empty(targetAccountName) ? targetAccountName : 'placeholder'
}

resource targetStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (!empty(targetStorageAccountName)) {
  #disable-next-line BCP334
  name: !empty(targetStorageAccountName) ? targetStorageAccountName : 'placeholder'
}

resource targetRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' existing = if (!empty(targetRegistryName)) {
  #disable-next-line BCP334
  name: !empty(targetRegistryName) ? targetRegistryName : 'placeholder'
}

resource targetContainerApp 'Microsoft.App/containerApps@2024-03-01' existing = if (!empty(targetContainerAppName)) {
  #disable-next-line BCP334
  name: !empty(targetContainerAppName) ? targetContainerAppName : 'placeholder'
}

resource roleAssignmentAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (useAccountTarget) {
  name: roleAssignmentName
  scope: targetAccount
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentStorage 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (useStorageTarget) {
  name: roleAssignmentName
  scope: targetStorageAccount
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentRegistry 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (useRegistryTarget) {
  name: roleAssignmentName
  scope: targetRegistry
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentContainerApp 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (useContainerAppTarget) {
  name: roleAssignmentName
  scope: targetContainerApp
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the role assignment')
output id string = roleAssignmentContainerApp.?id ?? roleAssignmentRegistry.?id ?? roleAssignmentStorage.?id ?? roleAssignmentAccount.?id ?? ''

@description('The name of the role assignment')
output name string = roleAssignmentContainerApp.?name ?? roleAssignmentRegistry.?name ?? roleAssignmentStorage.?name ?? roleAssignmentAccount.?name ?? roleAssignmentName
