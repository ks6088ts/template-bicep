// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Container Apps environment')
@minLength(1)
@maxLength(32)
param name string

@description('The Azure region where the Container Apps environment will be created')
param location string

@description('Tags applied to the Container Apps environment')
param tags object = {}

@description('Log Analytics workspace customer ID (GUID)')
@minLength(1)
param logAnalyticsWorkspaceCustomerId string

@description('Log Analytics workspace shared key. Required for environment creation.')
@secure()
@minLength(1)
param logAnalyticsWorkspaceSharedKey string

@description('When true, enables zone redundancy (region dependent)')
param zoneRedundant bool = false

// ------------------
//    RESOURCES
// ------------------

resource environment 'Microsoft.App/managedEnvironments@2024-03-01' = {
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

@description('The resource ID of the Container Apps environment')
output id string = environment.id

@description('The name of the Container Apps environment')
output name string = environment.name

@description('The default domain assigned to this environment')
output defaultDomain string = environment.properties.defaultDomain

@description('The static IP address of this environment (empty when not assigned)')
output staticIp string = environment.properties.?staticIp ?? ''
