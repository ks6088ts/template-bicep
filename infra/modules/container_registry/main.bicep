// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Container Registry (alphanumeric, 5-50).')
@minLength(5)
@maxLength(50)
param name string

@description('The Azure region where the Azure Container Registry will be created.')
param location string

@description('Tags applied to the Azure Container Registry.')
param tags object = {}

@description('The SKU name for the Azure Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param skuName string = 'Basic'

@description('Enable admin user authentication for the Azure Container Registry. Keep false for Entra ID-first access.')
param adminUserEnabled bool = false

@description('Public network access setting for the Azure Container Registry.')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Allow anonymous pull access to the registry.')
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
    policies: {
      // BCP037 is suppressed because this preview API supports anonymousPullEnabled under policies,
      // while the bundled Bicep type definition may lag behind the service contract.
      #disable-next-line BCP037
      anonymousPullEnabled: anonymousPullEnabled
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure Container Registry.')
output id string = containerRegistry.id

@description('The name of the Azure Container Registry.')
output name string = containerRegistry.name

@description('The login server endpoint of the Azure Container Registry.')
output loginServer string = containerRegistry.properties.loginServer
