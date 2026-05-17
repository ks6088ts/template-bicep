// ------------------
//    PARAMETERS
// ------------------

@description('The name of the parent Azure AI Foundry account')
@maxLength(59)
param parentAccountName string

@description('The name of the parent Azure AI Foundry project')
@maxLength(64)
param parentProjectName string

@description('The name of the connection resource')
@minLength(1)
@maxLength(64)
param name string

@description('The connection category for the Foundry project')
@minLength(1)
param category string

@description('The target endpoint or resource ID for the connection')
@minLength(1)
param target string

@description('Optional credential key used for ApiKey-based connections')
@secure()
param credentialKey string = ''

@description('The Azure region of the connected resource')
param location string

@description('The Azure resource ID of the connected resource')
@minLength(1)
param resourceId string

@description('Whether the connection is shared to all resources in the project')
param isSharedToAll bool = false

// ------------------
//    RESOURCES
// ------------------

resource parentAccount 'Microsoft.CognitiveServices/accounts@2025-12-01' existing = {
  name: parentAccountName
}

resource parentProject 'Microsoft.CognitiveServices/accounts/projects@2025-12-01' existing = {
  parent: parentAccount
  name: parentProjectName
}

resource connection 'Microsoft.CognitiveServices/accounts/projects/connections@2025-12-01' = {
  parent: parentProject
  name: name
  properties: {
    authType: 'ApiKey'
    category: category
    target: target
    ...(empty(credentialKey)
      ? {}
      : {
          credentials: {
            key: credentialKey
          }
        })
    isSharedToAll: isSharedToAll
    metadata: {
      ApiType: 'Azure'
      ResourceId: resourceId
      location: location
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Foundry project connection')
output id string = connection.id

@description('The name of the Foundry project connection')
output name string = connection.name
