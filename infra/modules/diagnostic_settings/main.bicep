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

@description('The name of the existing Azure Storage Account that diagnostic settings will be applied to. Provide this to create diagnostic settings on storage sub-services.')
param targetStorageAccountName string = ''

@description('The storage services to configure diagnostics for when targetStorageAccountName is provided.')
param storageServices array = [
  'blob'
  'queue'
  'table'
  'file'
]

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

resource targetStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (!empty(targetStorageAccountName)) {
  #disable-next-line BCP334
  name: !empty(targetStorageAccountName) ? targetStorageAccountName : 'placeholder'
}

resource targetStorageBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' existing = if (!empty(targetStorageAccountName) && contains(storageServices, 'blob')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetStorageQueueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' existing = if (!empty(targetStorageAccountName) && contains(storageServices, 'queue')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetStorageTableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' existing = if (!empty(targetStorageAccountName) && contains(storageServices, 'table')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetStorageFileService 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' existing = if (!empty(targetStorageAccountName) && contains(storageServices, 'file')) {
  parent: targetStorageAccount
  name: 'default'
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

resource diagnosticSettingsBlobService 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetStorageAccountName) && contains(storageServices, 'blob')) {
  scope: targetStorageBlobService
  name: '${name}-blob'
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsQueueService 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetStorageAccountName) && contains(storageServices, 'queue')) {
  scope: targetStorageQueueService
  name: '${name}-queue'
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsTableService 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetStorageAccountName) && contains(storageServices, 'table')) {
  scope: targetStorageTableService
  name: '${name}-table'
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsFileService 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (!empty(targetStorageAccountName) && contains(storageServices, 'file')) {
  scope: targetStorageFileService
  name: '${name}-file'
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

var diagnosticSettingsResourceId = diagnosticSettingsBlobService.?id ?? diagnosticSettingsQueueService.?id ?? diagnosticSettingsTableService.?id ?? diagnosticSettingsFileService.?id ?? diagnosticSettingsServer.?id ?? diagnosticSettingsAccount.?id ?? ''
var diagnosticSettingsResourceName = diagnosticSettingsBlobService.?name ?? diagnosticSettingsQueueService.?name ?? diagnosticSettingsTableService.?name ?? diagnosticSettingsFileService.?name ?? diagnosticSettingsServer.?name ?? diagnosticSettingsAccount.?name ?? name

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the diagnostic settings resource')
output id string = diagnosticSettingsResourceId

@description('The name of the diagnostic settings resource')
output name string = diagnosticSettingsResourceName
