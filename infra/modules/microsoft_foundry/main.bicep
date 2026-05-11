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

@description('Enable System Assigned Managed Identity for the Azure AI Foundry account')
param enableSystemAssignedIdentity bool = false

// ------------------
//    RESOURCES
// ------------------

resource foundryAccountWithIdentity 'Microsoft.CognitiveServices/accounts@2026-03-01' = if (enableSystemAssignedIdentity) {
  name: name
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
  identity: {
    type: 'SystemAssigned'
  }
}

resource foundryAccountWithoutIdentity 'Microsoft.CognitiveServices/accounts@2026-03-01' = if (!enableSystemAssignedIdentity) {
  name: name
  location: location
  kind: 'AIServices'
  sku: {
    name: 'S0'
  }
  tags: tags
  properties: {
    customSubDomainName: customSubDomainName
    publicNetworkAccess: publicNetworkAccess
    disableLocalAuth: disableLocalAuth
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure AI Foundry account')
output id string = enableSystemAssignedIdentity ? foundryAccountWithIdentity!.id : foundryAccountWithoutIdentity!.id

@description('The name of the Azure AI Foundry account')
output name string = enableSystemAssignedIdentity ? foundryAccountWithIdentity!.name : foundryAccountWithoutIdentity!.name

@description('The endpoint of the Azure AI Foundry account')
output endpoint string = enableSystemAssignedIdentity ? foundryAccountWithIdentity!.properties.endpoint : foundryAccountWithoutIdentity!.properties.endpoint

@description('The principal ID of the Azure AI Foundry account System Assigned Managed Identity (null when disabled)')
output principalId string? = enableSystemAssignedIdentity ? foundryAccountWithIdentity!.identity.principalId : null
