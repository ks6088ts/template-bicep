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

@description('The customer ID (workspace ID) of the Log Analytics workspace')
@minLength(1)
param logAnalyticsWorkspaceCustomerId string

@description('The shared key of the Log Analytics workspace')
@secure()
@minLength(1)
param logAnalyticsWorkspaceSharedKey string

@description('Enable zone redundancy for the Container Apps Environment')
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

@description('The resource ID of the Container Apps Environment')
output id string = containerAppEnvironment.id

@description('The name of the Container Apps Environment')
output name string = containerAppEnvironment.name

@description('The default domain of the Container Apps Environment')
output defaultDomain string = containerAppEnvironment.properties.defaultDomain

@description('The static IP address of the Container Apps Environment')
output staticIp string = containerAppEnvironment.properties.staticIp
