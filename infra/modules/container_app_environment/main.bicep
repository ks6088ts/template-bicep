// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Container Apps Environment.')
@maxLength(32)
param name string

@description('The Azure region where the Azure Container Apps Environment will be created.')
param location string

@description('Tags applied to the Azure Container Apps Environment.')
param tags object = {}

@description('The Log Analytics workspace customer ID used by Container Apps Environment app logs configuration.')
param logAnalyticsWorkspaceCustomerId string

@description('The Log Analytics workspace shared key used by Container Apps Environment app logs configuration.')
@secure()
param logAnalyticsWorkspaceSharedKey string

@description('Enable zone redundancy for the Azure Container Apps Environment.')
param zoneRedundant bool = false

// ------------------
//    RESOURCES
// ------------------

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsWorkspaceSharedKey
      }
    }
    zoneRedundant: zoneRedundant
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure Container Apps Environment.')
output id string = containerAppEnvironment.id

@description('The name of the Azure Container Apps Environment.')
output name string = containerAppEnvironment.name

@description('The default domain of the Azure Container Apps Environment.')
output defaultDomain string = containerAppEnvironment.properties.defaultDomain

@description('The static IP address of the Azure Container Apps Environment (empty when not allocated).')
output staticIp string = containerAppEnvironment.properties.?staticIp ?? ''
