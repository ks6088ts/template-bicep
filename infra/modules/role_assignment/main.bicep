// ------------------
//    PARAMETERS
// ------------------

@description('The name of the target Azure AI Foundry account resource')
param targetAccountName string = ''

@description('The name of the target Azure Storage Account resource')
param targetStorageAccountName string = ''

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

var targetResourceName = !empty(targetStorageAccountName) ? targetStorageAccountName : targetAccountName
var roleAssignmentName = empty(roleAssignmentNameSeed)
  ? guid(targetResourceName, principalId, roleDefinitionId)
  : roleAssignmentNameSeed

// ------------------
//    RESOURCES
// ------------------

// NOTE: API version pinned to `2025-06-01` to match the parent Foundry account module.
resource targetAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (!empty(targetAccountName) && empty(targetStorageAccountName)) {
  name: targetAccountName
}

resource targetStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (!empty(targetStorageAccountName)) {
  name: targetStorageAccountName
}

resource roleAssignmentToAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(targetAccountName) && empty(targetStorageAccountName)) {
  name: roleAssignmentName
  scope: targetAccount
  properties: {
    principalId: principalId
    roleDefinitionId: roleDefinitionId
    principalType: principalType
  }
}

resource roleAssignmentToStorageAccount 'Microsoft.Authorization/roleAssignments@2022-04-01' = if (!empty(targetStorageAccountName)) {
  name: roleAssignmentName
  scope: targetStorageAccount
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
output id string = roleAssignmentToStorageAccount.?id ?? roleAssignmentToAccount.?id ?? ''

@description('The name of the role assignment')
output name string = roleAssignmentToStorageAccount.?name ?? roleAssignmentToAccount.?name ?? roleAssignmentName
