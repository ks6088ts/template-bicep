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

// Foundry API key auth は無効（Entra ID のみ）
param disableLocalAuth = true

// Optional: attach existing User Assigned Managed Identities (UAMI) to receive Foundry inference
// role assignments. Leave commented out (or set to []) to keep the default behavior of skipping
// the role assignment (no UAMI is attached).
// param existingUserAssignedIdentities = [
//   { name: 'id-userassignedmanagedidentity', resourceGroup: 'rg-userassignedmanagedidentity' }
// ]

// Optional: attach existing Microsoft Entra service principals (by object ID) to receive Foundry
// inference role assignments. Leave commented out (or set to []) to keep the default behavior of
// skipping the role assignment (no service principal is attached). Use the service principal
// object ID (Enterprise Application), not the application/client ID. Example:
//   az ad sp show --id <app-id> --query id --output tsv
// param existingServicePrincipalObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]

// Optional: attach existing Microsoft Entra users (by object ID) to receive Foundry inference
// role assignments. Leave commented out (or set to []) to keep the default behavior of skipping
// the role assignment (no user is attached). Examples:
//   az ad signed-in-user show --query id --output tsv
//   az ad user show --id <upn-or-objectid> --query id --output tsv
// param existingUserObjectIds = [
//   '00000000-0000-0000-0000-000000000000'
// ]

// models / roleDefinitionIds use defaults from main.bicep.
// Adjust models (for example skuCapacity or modelName) to match target region availability and quota.

// Microsoft Entra ID administrator for the PostgreSQL Flexible Server.
//
// By default this parameter is omitted, and the scenario registers the
// principal executing the deployment (i.e. `deployer()`) as the administrator.
// That lets `make deploy SCENARIO=concierge` succeed with no manual edits.
//
// To override with a specific user / group / service principal, uncomment the
// block below and replace the placeholder values. To retrieve the signed-in
// user's information, run:
//   az ad signed-in-user show --query "{objectId:id, principalName:userPrincipalName, tenantId:tenantId}" -o json
// param entraAdministrator = {
//   objectId: '00000000-0000-0000-0000-000000000000'
//   principalName: 'admin@contoso.onmicrosoft.com'
//   principalType: 'User'
//   tenantId: '00000000-0000-0000-0000-000000000000'
// }

// Optional: override PostgreSQL version, SKU, and storage. Defaults from main.bicep are used when omitted.
// param postgresVersion = '18'
// param postgresSkuName = 'Standard_B1ms'
// param postgresSkuTier = 'Burstable'
// param postgresStorageSizeGB = 32

// Optional: enable or disable the pgvector extension (default: true).
// param enablePgvector = true

// Optional: override firewall rules. Default allows Azure services (0.0.0.0/0.0.0.0).
// param firewallRules = [
//   { name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }
//   { name: 'AllowMyIP', startIpAddress: '203.0.113.10', endIpAddress: '203.0.113.10' }
// ]

// Optional: override databases. Default creates a single 'appdb' database.
// param databases = [
//   { name: 'appdb' }
//   { name: 'vectordb' }
// ]
