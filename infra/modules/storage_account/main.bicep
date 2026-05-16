// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Storage Account (3-24 lowercase alphanumeric characters)')
@minLength(3)
@maxLength(24)
param name string

@description('The location for the Storage Account resource')
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

@description('The kind of Storage Account')
@allowed([
  'StorageV2'
  'BlockBlobStorage'
  'FileStorage'
])
param kind string = 'StorageV2'

@description('The access tier for the Storage Account')
@allowed([
  'Hot'
  'Cool'
])
param accessTier string = 'Hot'

@description('Enable hierarchical namespace (Data Lake Gen2)')
param enableHierarchicalNamespace bool = false

@description('Public network access setting')
@allowed([
  'Enabled'
  'Disabled'
])
param publicNetworkAccess string = 'Enabled'

@description('Minimum TLS version')
@allowed([
  'TLS1_0'
  'TLS1_1'
  'TLS1_2'
])
param minimumTlsVersion string = 'TLS1_2'

@description('Allow shared key access (Entra ID-only when false)')
param allowSharedKeyAccess bool = false

@description('Network ACL default action')
@allowed([
  'Allow'
  'Deny'
])
param networkAclsDefaultAction string = 'Allow'

@description('Blob containers to create')
param blobContainers array = [
  {
    name: 'default'
  }
]

@description('Queues to create')
param queues array = [
  {
    name: 'default'
  }
]

@description('Tables to create')
param tables array = [
  {
    name: 'default'
  }
]

@description('File shares to create')
param fileShares array = [
  {
    name: 'default'
  }
]

@description('Blob soft delete retention days')
@minValue(1)
@maxValue(365)
param blobSoftDeleteRetentionDays int = 7

@description('Container soft delete retention days')
@minValue(1)
@maxValue(365)
param containerSoftDeleteRetentionDays int = 7

@description('Enable blob versioning')
param enableBlobVersioning bool = false

@description('Enable change feed')
param enableChangeFeed bool = false

@description('File share soft delete retention days')
@minValue(1)
@maxValue(365)
param fileShareSoftDeleteRetentionDays int = 7

// ------------------
//    RESOURCES
// ------------------

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
  }
  kind: kind
  properties: {
    accessTier: accessTier
    isHnsEnabled: enableHierarchicalNamespace
    publicNetworkAccess: publicNetworkAccess
    minimumTlsVersion: minimumTlsVersion
    allowSharedKeyAccess: allowSharedKeyAccess
    defaultToOAuthAuthentication: true
    allowBlobPublicAccess: false
    allowCrossTenantReplication: false
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: networkAclsDefaultAction
      bypass: 'AzureServices'
    }
  }
}

// Blob services - only if kind supports it
resource blobServices 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = if (kind == 'StorageV2' || kind == 'BlockBlobStorage') {
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

// Blob containers
resource containers 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = [
  for container in blobContainers: if (kind == 'StorageV2' || kind == 'BlockBlobStorage') {
    parent: blobServices
    name: container.name
    properties: {
      publicAccess: container.?publicAccess ?? 'None'
    }
  }
]

// Queue services - only if kind supports it
resource queueServices 'Microsoft.Storage/storageAccounts/queueServices@2023-05-01' = if (kind == 'StorageV2') {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Queues
resource queuesResource 'Microsoft.Storage/storageAccounts/queueServices/queues@2023-05-01' = [
  for queue in queues: if (kind == 'StorageV2') {
    parent: queueServices
    name: queue.name
    properties: {
      metadata: queue.?metadata ?? {}
    }
  }
]

// Table services - only if kind supports it
resource tableServices 'Microsoft.Storage/storageAccounts/tableServices@2023-05-01' = if (kind == 'StorageV2') {
  parent: storageAccount
  name: 'default'
  properties: {}
}

// Tables
resource tablesResource 'Microsoft.Storage/storageAccounts/tableServices/tables@2023-05-01' = [
  for table in tables: if (kind == 'StorageV2') {
    parent: tableServices
    name: table.name
    properties: {}
  }
]

// File services - only if kind supports it
resource fileServices 'Microsoft.Storage/storageAccounts/fileServices@2023-05-01' = if (kind == 'StorageV2' || kind == 'FileStorage') {
  parent: storageAccount
  name: 'default'
  properties: {
    shareDeleteRetentionPolicy: {
      enabled: true
      days: fileShareSoftDeleteRetentionDays
    }
  }
}

// File shares
resource fileSharesResource 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = [
  for share in fileShares: if (kind == 'StorageV2' || kind == 'FileStorage') {
    parent: fileServices
    name: share.name
    properties: {
      shareQuota: share.?shareQuota ?? 100
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

@description('The blob endpoint')
output blobEndpoint string = storageAccount.properties.primaryEndpoints.?blob ?? ''

@description('The queue endpoint')
output queueEndpoint string = storageAccount.properties.primaryEndpoints.?queue ?? ''

@description('The table endpoint')
output tableEndpoint string = storageAccount.properties.primaryEndpoints.?table ?? ''

@description('The file endpoint')
output fileEndpoint string = storageAccount.properties.primaryEndpoints.?file ?? ''

@description('The DFS endpoint (for HNS-enabled accounts)')
output dfsEndpoint string = storageAccount.properties.primaryEndpoints.?dfs ?? ''

@description('The names of created blob containers')
output blobContainerNames array = [for (container, i) in blobContainers: containers[i].name]

@description('The names of created queues')
output queueNames array = [for (queue, i) in queues: queuesResource[i].name]

@description('The names of created tables')
output tableNames array = [for (table, i) in tables: tablesResource[i].name]

@description('The names of created file shares')
output fileShareNames array = [for (share, i) in fileShares: fileSharesResource[i].name]
