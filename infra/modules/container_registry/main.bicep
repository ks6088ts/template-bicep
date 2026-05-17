// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Container Registry')
@minLength(5)
@maxLength(50)
param name string

@description('The Azure region where the Azure Container Registry will be created')
param location string

@description('Tags applied to the Azure Container Registry')
param tags object = {}

@description('The SKU for the Azure Container Registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('Enable the admin user. Defaults to false for Entra ID-only access.')
param adminUserEnabled bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Enable anonymous pull access. Defaults to false.')
param anonymousPullEnabled bool = false

// ------------------
//    RESOURCES
// ------------------

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    anonymousPullEnabled: anonymousPullEnabled
    networkRuleBypassOptions: 'AzureServices'
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure Container Registry')
output id string = containerRegistry.id

@description('The name of the Azure Container Registry')
output name string = containerRegistry.name

@description('The login server URL of the Azure Container Registry')
output loginServer string = containerRegistry.properties.loginServer
