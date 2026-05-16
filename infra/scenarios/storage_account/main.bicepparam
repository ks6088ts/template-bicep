using 'main.bicep'

// 'tplbicepstg' is used to stay within the 24-character limit for the derived
// storage account name 'sttpbicepstg' (13 chars) after removing hyphens and underscores.
param name = 'tplbicepstg'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Optional: SKU / kind / access tier overrides
// param skuName = 'Standard_LRS'
// param kind = 'StorageV2'
// param accessTier = 'Hot'

// Optional: Data Lake Gen2 (HNS) enablement
// param enableHierarchicalNamespace = true

// Optional: enable shared key access (default: false, Entra ID-only)
// param allowSharedKeyAccess = false

// Optional: public network access
// param publicNetworkAccess = 'Enabled'

// Optional: pre-create Blob containers / Queues / Tables / File Shares
// param blobContainers = [{ name: 'default' }, { name: 'logs' }]
// param queues = [{ name: 'default' }, { name: 'jobs' }]
// param tables = [{ name: 'default' }]
// param fileShares = [{ name: 'default', shareQuota: 100 }]

// Optional: attach existing UAMI / SP / User to receive Storage Data role assignments
// param existingUserAssignedIdentities = [
//   { name: 'id-app', resourceGroup: 'rg-foo' }
// ]
// param existingServicePrincipalObjectIds = []
// param existingUserObjectIds = []

// Optional: enable observability (Log Analytics workspace + Storage diagnostic settings)
// param enableObservability = false
