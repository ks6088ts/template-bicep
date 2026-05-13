using 'main.bicep'

// NOTE: 'templatebicepostgres' is used to stay within the 63-character limit for the derived
// server name 'psql-templatebicepostgres' (25 chars) and avoid hyphens in the base name.
param name = 'templatebicepostgres'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Set the Entra ID administrator for the PostgreSQL Flexible Server.
// Replace the placeholder values with the actual objectId, principalName, and tenantId.
// To retrieve the signed-in user's information, run:
//   az ad signed-in-user show --query "{objectId:id, principalName:userPrincipalName, tenantId:tenantId}" -o json
param entraAdministrator = {
  objectId: '00000000-0000-0000-0000-000000000000'
  principalName: 'admin@contoso.onmicrosoft.com'
  principalType: 'User'
  tenantId: '00000000-0000-0000-0000-000000000000'
}

// Optional: enable observability resources (Log Analytics workspace and diagnostic settings).
// Leave commented out (or set to false) to preserve the default behavior without observability.
param enableObservability = true

// Optional: override PostgreSQL version, SKU, and storage. Defaults from main.bicep are used when omitted.
// param version = '16'
// param skuName = 'Standard_B1ms'
// param skuTier = 'Burstable'
// param storageSizeGB = 32

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
