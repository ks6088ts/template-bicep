// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Storage Account. Must be 3-24 characters and lowercase alphanumeric.')
@minLength(3)
@maxLength(24)
param name string

@description('The Azure region where the Storage Account will be created')
param location string

@description('Tags applied to the Storage Account')
param tags object = {}

@description('The SKU name for the Storage Account')
@allowed([
  'Standard_LRS'
  'Standard_GRS'
  'Standard_RAGRS'
  'Standard_ZRS'
  'Standard_GZRS'
  'Standard_RAGZRS'
  'Premium_LRS'
])
param skuName string = 'Standard_LRS'

@description('The kind for the Storage Account')
@allowed([
  'StorageV2'
  'BlockBlobStorage'
  'FileStorage'
])
param kind string = 'StorageV2'

@description('The access tier for the Storage Account (StorageV2 only)')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('When true, enables hierarchical namespace (Data Lake Storage Gen2). StorageV2 only.')
param enableHierarchicalNamespace bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('The minimum TLS version to enforce')
@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

@description('When true, allows Shared Key (account key / SAS) authorization. Defaults to false for Entra ID-only access.')
param allowSharedKeyAccess bool = false

@description('Network ACL default action. Defaults to Allow for generic templates; set Deny for locked-down deployments.')
@allowed([
  'Allow'
  'Deny'
])
param networkAclsDefaultAction string = 'Allow'

@description('Blob containers to create. Each element: { name: string, publicAccess?: None|Blob|Container }')
param blobContainers array = [
  {
    name: 'default'
  }
]

@description('Queues to create. Each element: { name: string, metadata?: object }')
param queues array = [
  {
    name: 'default'
  }
]

@description('Tables to create. Each element: { name: string }')
param tables array = [
  {
    name: 'default'
  }
]

@description('File shares to create. Each element: { name: string, shareQuota?: int, accessTier?: TransactionOptimized|Hot|Cool }')
param fileShares array = [
  {
    name: 'default'
  }
]

@description('Soft delete retention days for blob soft delete (1-365)')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 7

@description('Soft delete retention days for container soft delete (1-365)')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 7

@description('When true, enables blob versioning')
param enableBlobVersioning bool = false

@description('When true, enables change feed on the default blob service')
param enableChangeFeed bool = false

@description('Soft delete retention days for file share soft delete (1-365)')
@minValue(1)
@maxValue(365)
param fileShareSoftDeleteRetentionDays int = 7

// ------------------
//    VARIABLES
// ------------------

var supportsBlob = kind == 'StorageV2' || kind == 'BlockBlobStorage'
var supportsQueueAndTable = kind == 'StorageV2'
var supportsFile = kind == 'StorageV2' || kind == 'FileStorage'

var requestedBlobContainerNames = [for container in blobContainers: container.name]
var requestedQueueNames = [for queue in queues: queue.name]
var requestedTableNames = [for table in tables: table.name]
var requestedFileShareNames = [for share in fileShares: share.name]

var storageAccountProperties = union({
  allowSharedKeyAccess: allowSharedKeyAccess
  defaultToOAuthAuthentication: true
  allowBlobPublicAccess: false
  allowCrossTenantReplication: false
  supportsHttpsTrafficOnly: true
  minimumTlsVersion: minimumTlsVersion
  publicNetworkAccess: publicNetworkAccess
  networkAcls: {
    bypass: 'AzureServices'
    defaultAction: networkAclsDefaultAction
  }
}, kind == 'StorageV2' ? {
  accessTier: accessTier
  isHnsEnabled: enableHierarchicalNamespace
} : {})

// ------------------
//    RESOURCES
// ------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2024-01-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: storageAccountProperties
}

resource blobService 'Microsoft.Storage/storageAccounts/blobServices@2024-01-01' = if (supportsBlob) {
  parent: storageAccount
  name: 'default'
  properties: {
    deleteRetentionPolicy: {
      enabled: true
      days: blobSoftDeleteRetentionDays
    }
    containerDeleteRetentionPolicy: {
      enabled: true
      days: containerSoftDeleteRetentionDays
    }
    isVersioningEnabled: enableBlobVersioning
    changeFeed: {
      enabled: enableChangeFeed
    }
  }
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = if (supportsQueueAndTable) {
  parent: storageAccount
  name: 'default'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = if (supportsQueueAndTable) {
  parent: storageAccount
  name: 'default'
}

resource fileService 'Microsoft.Storage/storageAccounts/fileServices@2024-01-01' = if (supportsFile) {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: fileShareSoftDeleteRetentionDays
    }
  }
}

resource blobContainerResources 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [
  for container in blobContainers: if (supportsBlob) {
    parent: blobService
    name: container.name
    properties: {
      publicAccess: container.?publicAccess ?? 'None'
    }
  }
]

resource queueResources 'Microsoft.Storage/storageAccounts/queueServices/queues@2024-01-01' = [
  for queue in queues: if (supportsQueueAndTable) {
    parent: queueService
    name: queue.name
    properties: {
      metadata: queue.?metadata ?? {}
    }
  }
]

resource tableResources 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = [
  for table in tables: if (supportsQueueAndTable) {
    parent: tableService
    name: table.name
  }
]

resource fileShareResources 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-01-01' = [
  for share in fileShares: if (supportsFile) {
    parent: fileService
    name: share.name
    properties: {
      shareQuota: int(share.?shareQuota ?? 100)
      accessTier: share.?accessTier ?? 'TransactionOptimized'
    }
  }
]

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Storage Account')
output id string = storageAccount.id

@description('The name of the Storage Account')
output name string = storageAccount.name

@description('The primary endpoints of the Storage Account')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('The blob endpoint (empty when not available)')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.?blob ?? ''

@description('The queue endpoint (empty when not available)')
output queueEndpoint string = storageAccount.properties.primaryEndpoints.?queue ?? ''

@description('The table endpoint (empty when not available)')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.?table ?? ''

@description('The file endpoint (empty when not available)')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.?file ?? ''

@description('The dfs endpoint (empty when not available)')
output dfsEndpoint string = storageAccount.properties.primaryEndpoints.?dfs ?? ''

@description('The names of blob containers created')
output blobContainerNames array = supportsBlob ? requestedBlobContainerNames : []

@description('The names of queues created')
output queueNames array = supportsQueueAndTable ? requestedQueueNames : []

@description('The names of tables created')
output tableNames array = supportsQueueAndTable ? requestedTableNames : []

@description('The names of file shares created')
output fileShareNames array = supportsFile ? requestedFileShareNames : []
