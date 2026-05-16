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

@description('The name of the existing Azure Storage Account that diagnostic settings will be applied to. When set, diagnostic settings are created at the storage sub-service scopes (blob/queue/table/file).')
param targetStorageAccountName string = ''

@description('The storage sub-services to configure diagnostic settings for when targetStorageAccountName is set.')
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

var useStorageTarget = !empty(targetStorageAccountName)
var useServerTarget = !useStorageTarget && !empty(targetServerName)
var useAccountTarget = !useStorageTarget && !useServerTarget && !empty(targetAccountName)

resource targetAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (useAccountTarget) {
  #disable-next-line BCP334
  name: !empty(targetAccountName) ? targetAccountName : 'placeholder'
}

resource targetServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' existing = if (useServerTarget) {
  #disable-next-line BCP334
  name: !empty(targetServerName) ? targetServerName : 'placeholder'
}

resource targetStorageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (useStorageTarget) {
  #disable-next-line BCP334
  name: !empty(targetStorageAccountName) ? targetStorageAccountName : 'placeholder'
}

resource targetBlobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' existing = if (useStorageTarget && contains(storageServices, 'blob')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetQueueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' existing = if (useStorageTarget && contains(storageServices, 'queue')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetTableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' existing = if (useStorageTarget && contains(storageServices, 'table')) {
  parent: targetStorageAccount
  name: 'default'
}

resource targetFileService 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' existing = if (useStorageTarget && contains(storageServices, 'file')) {
  parent: targetStorageAccount
  name: 'default'
}

// ------------------
//    RESOURCES
// ------------------

resource diagnosticSettingsAccount 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useAccountTarget) {
  scope: targetAccount
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsServer 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useServerTarget) {
  scope: targetServer
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useStorageTarget && contains(storageServices, 'blob')) {
  scope: targetBlobService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageQueue 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useStorageTarget && contains(storageServices, 'queue')) {
  scope: targetQueueService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageTable 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useStorageTarget && contains(storageServices, 'table')) {
  scope: targetTableService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageFile 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (useStorageTarget && contains(storageServices, 'file')) {
  scope: targetFileService
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

var storageDiagnosticSettingIds = concat(
  contains(storageServices, 'blob') ? [diagnosticSettingsStorageBlob.?id ?? ''] : [],
  contains(storageServices, 'queue') ? [diagnosticSettingsStorageQueue.?id ?? ''] : [],
  contains(storageServices, 'table') ? [diagnosticSettingsStorageTable.?id ?? ''] : [],
  contains(storageServices, 'file') ? [diagnosticSettingsStorageFile.?id ?? ''] : []
)

var storageDiagnosticSettingId = length(storageDiagnosticSettingIds) > 0 ? storageDiagnosticSettingIds[0] : ''

@description('The resource ID of the diagnostic settings resource')
output id string = diagnosticSettingsServer.?id ?? diagnosticSettingsAccount.?id ?? storageDiagnosticSettingId ?? ''

@description('The name of the diagnostic settings resource')
output name string = diagnosticSettingsServer.?name ?? diagnosticSettingsAccount.?name ?? name
