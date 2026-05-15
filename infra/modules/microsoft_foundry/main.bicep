// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure AI Foundry account')
@minLength(2)
@maxLength(59)
param name string

@description('The Azure region where the Azure AI Foundry account will be created')
param location string

@description('Tags applied to the Azure AI Foundry account')
param tags object = {}

@description('The custom subdomain name for the Azure AI Foundry account endpoint')
@minLength(2)
@maxLength(64)
param customSubDomainName string = name

@description('Controls public network access to the Azure AI Foundry account')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Disable local authentication (API keys) and require Entra ID authentication')
param disableLocalAuth bool = true

// ------------------
//    RESOURCES
// ------------------

// NOTE: Pinned to GA `2025-06-01` (matches the foundry-samples `00-basic` working sample).
// Newer API versions (e.g. `2025-12-01`, `2026-03-01`) have been observed to create the
// account in a state where the child project PUT returns persistent 500 InternalServerError,
// causing the ARM deployment to be cancelled after the retry budget. See foundry-samples
// issue #236.
resource foundryAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' = {
  name: name
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  tags: tags
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
    allowProjectManagement: true
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure AI Foundry account')
output id string = foundryAccount.id

@description('The name of the Azure AI Foundry account')
output name string = foundryAccount.name

@description('The endpoint of the Azure AI Foundry account')
output endpoint string = foundryAccount.properties.endpoint

@description('The principal ID of the Azure AI Foundry account System Assigned Managed Identity')
output principalId string = foundryAccount.identity.principalId
