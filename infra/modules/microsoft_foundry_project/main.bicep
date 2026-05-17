// ------------------
//    PARAMETERS
// ------------------

@description('The name of the parent Azure AI Foundry account')
@maxLength(59)
param parentAccountName string

@description('The name of the Azure AI Foundry project')
@maxLength(64)
param name string

@description('The Azure region where the Azure AI Foundry project will be created')
param location string

@description('The display name of the Azure AI Foundry project')
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

resource parentAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  name: parentAccountName
}

// NOTE: Pinned to GA `2025-06-01` (matches the foundry-samples `00-basic` working sample).
// Newer GA versions (e.g. `2025-12-01`, `2026-03-01`) have been observed returning persistent
// 500 InternalServerError on project PUT in some regions, causing the ARM deployment to be
// cancelled after the 8-minute retry budget. The parent account API version must also be
// pinned to `2025-06-01` (see `modules/microsoft_foundry/main.bicep`); mixing a newer account
// API version with this project API version reproduces the same 500 error. See foundry-samples
// issue #236.
resource foundryProject 'Microsoft.CognitiveServices/accounts/projects@2025-06-01' = {
  parent: parentAccount
  name: name
  location: location
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    displayName: displayName
    ...(empty(projectDescription)
      ? {}
      : {
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
