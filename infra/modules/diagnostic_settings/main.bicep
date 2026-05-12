// ------------------
//    PARAMETERS
// ------------------

@description('The name of the diagnostic settings resource')
@minLength(1)
@maxLength(256)
param name string

@description('The resource ID of the Log Analytics workspace destination')
@minLength(1)
param workspaceResourceId string

@description('The target resource ID where diagnostic settings will be applied')
@minLength(1)
param targetResourceId string

@description('The diagnostic log settings to configure')
param logs array = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

@description('The diagnostic metric settings to configure')
param metrics array = [
  {
    category: 'AllMetrics'
    enabled: true
  }
]

// ------------------
//    RESOURCES
// ------------------

#disable-next-line BCP081
resource targetResource 'Microsoft.Resources/resources@2021-04-01' existing = {
  name: targetResourceId
}

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: targetResource
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the diagnostic settings resource')
output id string = diagnosticSettings.id

@description('The name of the diagnostic settings resource')
output name string = diagnosticSettings.name
