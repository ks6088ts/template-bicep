// ------------------
//    PARAMETERS
// ------------------

@description('The name of the parent Azure AI Foundry account')
@minLength(2)
@maxLength(59)
param parentAccountName string

@description('The name of the Azure AI Foundry project')
@minLength(2)
@maxLength(64)
param name string

@description('The Azure region where the Azure AI Foundry project will be created')
param location string

@description('The display name of the Azure AI Foundry project')
@minLength(2)
@maxLength(64)
param displayName string = name

@description('The description of the Azure AI Foundry project')
@maxLength(1024)
param projectDescription string = ''

@description('Tags applied to the Azure AI Foundry project')
param tags object = {}

// ------------------
//    RESOURCES
// ------------------

resource parentAccount 'Microsoft.CognitiveServices/accounts@2026-03-01' existing = {
  name: parentAccountName
}

resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-12-01' = {
  parent: parentAccount
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: displayName
    ...(empty(projectDescription) ? {} : {
      description: projectDescription
    })
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure AI Foundry project')
output id string = foundryProject.id

@description('The name of the Azure AI Foundry project')
output name string = foundryProject.name
