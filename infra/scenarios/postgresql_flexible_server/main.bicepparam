using 'main.bicep'

param name = 'postgresqlflexibleserver'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Microsoft Entra ID administrator for the PostgreSQL Flexible Server.
//
// By default this parameter is omitted, and the scenario registers the
// principal executing the deployment (i.e. `deployer()`) as the administrator.
// That lets `make deploy SCENARIO=postgresql_flexible_server` succeed with no
// manual edits to this file.
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

// Optional: enable observability resources (Log Analytics workspace and diagnostic settings).
// Leave commented out (or set to false) to preserve the default behavior without observability.
param enableObservability = true

// Optional: override PostgreSQL version, SKU, and storage. Defaults from main.bicep are used when omitted.
// The default PostgreSQL major version is '18' to match the pgvector/pgvector:pg18 reference container image.
// param version = '18'
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
