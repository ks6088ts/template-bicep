// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Log Analytics workspace')
@minLength(4)
@maxLength(63)
param name string

@description('The Azure region where the Log Analytics workspace will be created')
param location string

@description('Tags applied to the Log Analytics workspace')
param tags object = {}

@description('The retention period (days) for workspace data')
@minValue(30)
@maxValue(730)
param retentionInDays int = 30

// ------------------
//    RESOURCES
// ------------------

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: retentionInDays
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Log Analytics workspace')
output id string = logAnalyticsWorkspace.id

@description('The name of the Log Analytics workspace')
output name string = logAnalyticsWorkspace.name
