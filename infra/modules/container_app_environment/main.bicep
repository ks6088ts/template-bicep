// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Container Apps Environment')
@minLength(1)
@maxLength(32)
param name string

@description('The Azure region where the Container Apps Environment will be created')
param location string

@description('Tags applied to the Container Apps Environment')
param tags object = {}

@description('The Log Analytics workspace customer ID')
@minLength(1)
param logAnalyticsWorkspaceCustomerId string

@description('The Log Analytics workspace shared key')
@secure()
@minLength(1)
param logAnalyticsWorkspaceSharedKey string

@description('Whether zone redundancy is enabled for the Container Apps Environment')
param zoneRedundant bool = false

// ------------------
//    RESOURCES
// ------------------

resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    zoneRedundant: zoneRedundant
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspaceCustomerId
        sharedKey: logAnalyticsWorkspaceSharedKey
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Container Apps Environment')
output id string = containerAppEnvironment.id

@description('The name of the Container Apps Environment')
output name string = containerAppEnvironment.name

@description('The default domain of the Container Apps Environment')
output defaultDomain string = containerAppEnvironment.properties.defaultDomain

@description('The static IP of the Container Apps Environment')
output staticIp string = containerAppEnvironment.properties.staticIp
