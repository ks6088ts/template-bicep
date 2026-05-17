// ------------------
//    PARAMETERS
// ------------------

@description('The name of the diagnostic settings resource.')
@maxLength(256)
param name string

@description('The resource ID of the Log Analytics workspace destination.')
param workspaceResourceId string

@description('Kind of the resource that diagnostic settings will be applied to.')
@allowed([
  'CognitiveServicesAccount'
  'PostgreSqlFlexibleServer'
  'StorageAccount'
])
param targetKind string

@description('Name of the target resource.')
param targetName string

@description('Storage sub-services to configure diagnostic settings for. Only used when `targetKind` is `StorageAccount`.')
param storageServices array = [
  'blob'
  'queue'
  'table'
  'file'
]

@description('Diagnostic log settings to configure.')
param logs array = [
  {
    categoryGroup: 'allLogs'
    enabled: true
  }
]

@description('Diagnostic metric settings to configure.')
param metrics array = [
  {
    category: 'AllMetrics'
    enabled: true
  }
]

// ------------------
//    VARIABLES
// ------------------

var isAccount = targetKind == 'CognitiveServicesAccount'
var isServer = targetKind == 'PostgreSqlFlexibleServer'
var isStorage = targetKind == 'StorageAccount'

// ------------------
//    EXISTING RESOURCES
// ------------------

resource cognitiveAccount 'Microsoft.CognitiveServices/accounts@2025-06-01' existing = if (isAccount) {
  name: targetName
}

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2024-08-01' existing = if (isServer) {
  name: targetName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' existing = if (isStorage) {
  name: targetName
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' existing = if (isStorage && contains(storageServices, 'blob')) {
  parent: storageAccount
  name: 'default'
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' existing = if (isStorage && contains(storageServices, 'queue')) {
  parent: storageAccount
  name: 'default'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' existing = if (isStorage && contains(storageServices, 'table')) {
  parent: storageAccount
  name: 'default'
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' existing = if (isStorage && contains(storageServices, 'file')) {
  parent: storageAccount
  name: 'default'
}

// ------------------
//    RESOURCES
// ------------------

resource diagnosticSettingsAccount 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isAccount) {
  scope: cognitiveAccount
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsServer 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isServer) {
  scope: postgresServer
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageBlob 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isStorage && contains(storageServices, 'blob')) {
  scope: blobService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageQueue 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isStorage && contains(storageServices, 'queue')) {
  scope: queueService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageTable 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isStorage && contains(storageServices, 'table')) {
  scope: tableService
  name: name
  properties: {
    workspaceId: workspaceResourceId
    logs: logs
    metrics: metrics
  }
}

resource diagnosticSettingsStorageFile 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = if (isStorage && contains(storageServices, 'file')) {
  scope: fileService
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

@description('The name of the diagnostic settings resource.')
output name string = name
