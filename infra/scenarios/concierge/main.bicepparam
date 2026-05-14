using 'main.bicep'

param name = 'concierge'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Feature flags (concierge full stack by default)
param enableApplicationInsights = true
param enablePostgresql = true

// Foundry API key auth is disabled (Entra ID only)
param disableLocalAuth = true

// Other parameters use defaults from main.bicep.
// PostgreSQL Entra administrator falls back to deployer() when omitted, so this
// file is deployable as-is.

// Optional: override Foundry model deployments.
// Adjust models (for example skuCapacity or modelName) to match target region availability and quota.
// param models = [
//   {
//     name: 'gpt-4o'
//     modelName: 'gpt-4o'
//     modelFormat: 'OpenAI'
//     skuName: 'GlobalStandard'
//     skuCapacity: 50
//   }
// ]

// Optional: attach existing identities to receive Foundry inference role assignments.
// Leaving these commented out (or setting them to []) skips role assignments for that category.
//
// param existingUserAssignedIdentities = [
//   { name: 'id-userassignedmanagedidentity', resourceGroup: 'rg-userassignedmanagedidentity' }
// ]
//
// param existingServicePrincipalObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]
//
// param existingUserObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]
//
// Optional: override PostgreSQL server sizing.
// param postgresVersion = '18'
// param postgresSkuName = 'Standard_B1ms'
// param postgresSkuTier = 'Burstable'
// param postgresStorageSizeGB = 32
//
// Optional: disable or enable pgvector extension allow-listing (default: true).
// param enablePgvector = true
//
// Optional: override firewall rules. Default allows Azure services (0.0.0.0/0.0.0.0).
// param firewallRules = [
//   { name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }
//   { name: 'AllowMyIP', startIpAddress: '203.0.113.10', endIpAddress: '203.0.113.10' }
// ]
//
// Optional: override databases. Default creates a single 'appdb' database.
// param databases = [
//   { name: 'appdb' }
//   { name: 'vectordb' }
// ]

