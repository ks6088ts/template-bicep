// ------------------
//    PARAMETERS
// ------------------

@description('Kind of the resource that the role is scoped to.')
@allowed([
  'CognitiveServicesAccount'
  'StorageAccount'
])
param targetKind string

@description('Name of the target resource (Cognitive Services account or Storage account).')
param targetName string

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

var isStorage = targetKind == 'StorageAccount'
var roleAssignmentName = guid(targetKind, targetName, principalId, roleDefinitionId)

// ------------------
//    RESOURCES
// ------------------

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (!isStorage) {
  name: targetName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (isStorage) {
  name: targetName
}

resource roleAssignmentAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!isStorage) {
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

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the role assignment.')
output id string = isStorage ? roleAssignmentStorage.id : roleAssignmentAccount.id

@description('The name (GUID) of the role assignment.')
output name string = roleAssignmentName
