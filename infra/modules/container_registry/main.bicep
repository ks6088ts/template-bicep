// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Container Registry (ACR). Must be 5-50 characters and alphanumeric only.')
@minLength(5)
@maxLength(50)
param name string

@description('The Azure region where the registry will be created')
param location string

@description('Tags applied to the registry')
param tags object = {}

@description('The SKU name for the registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('When true, enables the admin user (username/password). Defaults to false for Entra ID authentication.')
param adminUserEnabled bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('When true, allows anonymous pull access. Defaults to false.')
param anonymousPullEnabled bool = false

// ------------------
//    RESOURCES
// ------------------

resource registry 'Microsoft.ContainerRegistry/registries@2023-11-01-preview' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  properties: {
    adminUserEnabled: adminUserEnabled
    publicNetworkAccess: publicNetworkAccess
    networkRuleBypassOptions: 'AzureServices'
    policies: {
      #disable-next-line BCP037
      anonymousPullEnabled: anonymousPullEnabled
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the registry')
output id string = registry.id

@description('The name of the registry')
output name string = registry.name

@description('The login server hostname of the registry')
output loginServer string = registry.properties.loginServer
