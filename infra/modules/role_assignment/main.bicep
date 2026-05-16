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

var useStorageTarget = !empty(targetStorageAccountName)
var useAccountTarget = !useStorageTarget && !empty(targetAccountName)

var roleAssignmentName = empty(roleAssignmentNameSeed)
  ? guid(!empty(targetStorageAccountName) ? targetStorageAccountName : targetAccountName, principalId, roleDefinitionId)
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

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the role assignment')
output id string = roleAssignmentStorage.?id ?? roleAssignmentAccount.?id ?? ''

@description('The name of the role assignment')
output name string = roleAssignmentStorage.?name ?? roleAssignmentAccount.?name ?? roleAssignmentName
