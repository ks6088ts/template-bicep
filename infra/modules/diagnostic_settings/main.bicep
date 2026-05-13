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

@description('The name of the existing Azure AI Foundry (Cognitive Services) account that diagnostic settings will be applied to. Provide either this or targetServerName.')
param targetAccountName string = ''

@description('The name of the existing Azure Database for PostgreSQL Flexible Server that diagnostic settings will be applied to. Provide either this or targetAccountName.')
param targetServerName string = ''

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

resource targetAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (!empty(targetAccountName)) {
  #disable-next-line BCP334
  name: !empty(targetAccountName) ? targetAccountName : 'placeholder'
}

resource targetServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' existing = if (!empty(targetServerName)) {
  #disable-next-line BCP334
  name: !empty(targetServerName) ? targetServerName : 'placeholder'
}

// ------------------
//    RESOURCES
// ------------------

resource diagnosticSettingsAccount 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetAccountName)) {
  scope: targetAccount
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsServer 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetServerName)) {
  scope: targetServer
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
output id string = diagnosticSettingsServer.?id ?? diagnosticSettingsAccount.?id ?? ''

@description('The name of the diagnostic settings resource')
output name string = diagnosticSettingsServer.?name ?? diagnosticSettingsAccount.?name ?? name
