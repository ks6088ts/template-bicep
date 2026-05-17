using 'main.bicep'

param name = 'storageaccount'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Optional: SKU / kind / access tier override
// param skuName = 'Standard_LRS'
// param kind = 'StorageV2'
// param accessTier = 'Hot'

// Optional: enable Data Lake Storage Gen2 (HNS) (StorageV2 only)
// param enableHierarchicalNamespace = true

// Optional: enable Shared Key (default: false, Entra ID-only by default)
// param allowSharedKeyAccess = true

// Optional: public network access
// param publicNetworkAccess = 'Enabled'

// Optional: pre-create Blob containers / Queues / Tables / File shares
// param blobContainers = [{ name: 'default' }, { name: 'logs' }]
// param queues = [{ name: 'default' }, { name: 'jobs' }]
// param tables = [{ name: 'default' }]
// param fileShares = [{ name: 'default', shareQuota: 100 }]

// Optional: grant storage data roles to existing UAMI / service principals / users
// param existingUserAssignedIdentities = [
//   { name: 'id-app', resourceGroup: 'rg-foo' }
// ]
// param existingServicePrincipalObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]
// param existingUserObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]

// Optional: enable observability resources (Log Analytics workspace and diagnostic settings).
// param enableObservability = true
