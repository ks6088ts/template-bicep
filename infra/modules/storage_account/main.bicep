// ------------------
//    PARAMETERS
// ------------------

@description('The name of the storage account')
@minLength(3)
@maxLength(24)
param name string

@description('The location for the storage account')
param location string

@description('Tags applied to the storage account')
param tags object = {}

@description('The SKU name for the storage account')
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

@description('The kind of the storage account')
@allowed([
  'StorageV2'
  'BlockBlobStorage'
  'FileStorage'
])
param kind string = 'StorageV2'

@description('The access tier for the storage account')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHierarchicalNamespace bool = false

@description('Public network access for the storage account')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Minimum TLS version for the storage account')
@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

@description('Allow Shared Key authorization. Default false to enforce Entra ID-first access.')
param allowSharedKeyAccess bool = false

@description('Default action for network ACLs')
@allowed([
  'Allow'
  'Deny'
])
param networkAclsDefaultAction string = 'Allow'

@description('Bypass setting for network ACLs')
param networkAclsBypass string = 'AzureServices'

@description('Blob containers to create under blobServices/default')
param blobContainers array = [
  {
    name: 'default'
  }
]

@description('Queues to create under queueServices/default')
param queues array = [
  {
    name: 'default'
  }
]

@description('Tables to create under tableServices/default')
param tables array = [
  {
    name: 'default'
  }
]

@description('File shares to create under fileServices/default')
param fileShares array = [
  {
    name: 'default'
  }
]

@description('Soft delete retention days for blobs')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 7

@description('Soft delete retention days for blob containers')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 7

@description('Enable blob versioning')
param enableBlobVersioning bool = false

@description('Enable blob change feed')
param enableChangeFeed bool = false

@description('Soft delete retention days for file shares')
@minValue(1)
@maxValue(365)
param fileShareSoftDeleteRetentionDays int = 7

// ------------------
//    VARIABLES
// ------------------

var supportsBlob = kind != 'FileStorage'
var supportsQueue = kind == 'StorageV2'
var supportsTable = kind == 'StorageV2'
var supportsFile = kind != 'BlockBlobStorage'
var storageAccountProperties = union({
  minimumTlsVersion: minimumTlsVersion
  supportsHttpsTrafficOnly: true
  allowSharedKeyAccess: allowSharedKeyAccess
  defaultToOAuthAuthentication: true
  allowBlobPublicAccess: false
  allowCrossTenantReplication: false
  isHnsEnabled: enableHierarchicalNamespace
  publicNetworkAccess: publicNetworkAccess
  networkAcls: {
    bypass: networkAclsBypass
    defaultAction: networkAclsDefaultAction
  }
}, kind == 'FileStorage' ? {} : {
  accessTier: accessTier
})

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

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2024-01-01' = if (supportsQueue) {
  parent: storageAccount
  name: 'default'
}

resource tableService 'Microsoft.Storage/storageAccounts/tableServices@2024-01-01' = if (supportsTable) {
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

resource containerResources 'Microsoft.Storage/storageAccounts/blobServices/containers@2024-01-01' = [
  for container in blobContainers: if (supportsBlob) {
    parent: blobService
    name: container.name
    properties: {
      publicAccess: container.?publicAccess ?? 'None'
    }
  }
]

resource queueResources 'Microsoft.Storage/storageAccounts/queueServices/queues@2024-01-01' = [
  for queue in queues: if (supportsQueue) {
    parent: queueService
    name: queue.name
    properties: {
      metadata: queue.?metadata ?? {}
    }
  }
]

resource tableResources 'Microsoft.Storage/storageAccounts/tableServices/tables@2024-01-01' = [
  for table in tables: if (supportsTable) {
    parent: tableService
    name: table.name
  }
]

resource fileShareResources 'Microsoft.Storage/storageAccounts/fileServices/shares@2024-01-01' = [
  for fileShare in fileShares: if (supportsFile) {
    parent: fileService
    name: fileShare.name
    properties: {
      shareQuota: int(fileShare.?shareQuota ?? 100)
      accessTier: string(fileShare.?accessTier ?? 'TransactionOptimized')
    }
  }
]

var requestedBlobContainerNames = [for container in blobContainers: container.name]
var requestedQueueNames = [for queue in queues: queue.name]
var requestedTableNames = [for table in tables: table.name]
var requestedFileShareNames = [for fileShare in fileShares: fileShare.name]

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the created storage account')
output id string = storageAccount.id

@description('The name of the created storage account')
output name string = storageAccount.name

@description('The primary endpoints of the storage account')
output primaryEndpoints object = storageAccount.properties.primaryEndpoints

@description('The blob endpoint of the storage account')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.?blob ?? ''

@description('The queue endpoint of the storage account')
output queueEndpoint string = storageAccount.properties.primaryEndpoints.?queue ?? ''

@description('The table endpoint of the storage account')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.?table ?? ''

@description('The file endpoint of the storage account')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.?file ?? ''

@description('The dfs endpoint of the storage account')
output dfsEndpoint string = storageAccount.properties.primaryEndpoints.?dfs ?? ''

@description('The names of blob containers created on the storage account')
output blobContainerNames array = supportsBlob ? requestedBlobContainerNames : []

@description('The names of queues created on the storage account')
output queueNames array = supportsQueue ? requestedQueueNames : []

@description('The names of tables created on the storage account')
output tableNames array = supportsTable ? requestedTableNames : []

@description('The names of file shares created on the storage account')
output fileShareNames array = supportsFile ? requestedFileShareNames : []
