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

@description('The name of the existing Azure AI Foundry (Cognitive Services) account that diagnostic settings will be applied to')
@minLength(1)
param targetAccountName string

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
//    EXISTING RESOURCES
// ------------------

resource targetAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = {
  #disable-next-line BCP334
  name: targetAccountName
}

// ------------------
//    RESOURCES
// ------------------

resource diagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: targetAccount
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
