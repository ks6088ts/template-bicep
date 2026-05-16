using 'main.bicep'

// 'storageaccount' is intentionally short so derived storage account name `st${name}`
// can stay within Azure's 24 character limit.
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

// Optional: enable Data Lake Gen2 (HNS)
// param enableHierarchicalNamespace = true

// Optional: enable Shared Key authorization (default is false for Entra ID-first auth)
// param allowSharedKeyAccess = false

// Optional: public network access
// param publicNetworkAccess = 'Enabled'

// Optional: pre-create Blob containers / Queues / Tables / File Shares
// param blobContainers = [{ name: 'default' }, { name: 'logs' }]
// param queues = [{ name: 'default' }, { name: 'jobs' }]
// param tables = [{ name: 'default' }]
// param fileShares = [{ name: 'default', shareQuota: 100 }]

// Optional: assign Storage Data roles to existing UAMI / service principal / user
// param existingUserAssignedIdentities = [
//   { name: 'id-app', resourceGroup: 'rg-foo' }
// ]
// param existingServicePrincipalObjectIds = []
// param existingUserObjectIds = []

// Optional: enable observability (default false)
// param enableObservability = true
