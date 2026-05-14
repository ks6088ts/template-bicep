using 'main.bicep'

// NOTE: 'concierge' is short and satisfies all naming constraints:
// - aif-concierge (13 chars), psql-concierge (14 chars)
// - Foundry account limit (59 chars) and no reserved word 'microsoft'
param name = 'concierge'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Feature flags: concierge full stack by default
// Set to false to exclude Application Insights / PostgreSQL from the deployment
param enableApplicationInsights = true
param enablePostgresql = true

// Foundry API key auth is disabled (Entra ID only)
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

// Microsoft Entra ID administrator for the PostgreSQL Flexible Server (used when enablePostgresql = true).
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

// models / roleDefinitionIds / postgresVersion / postgresSkuName / postgresSkuTier /
// postgresStorageSizeGB / enablePgvector / firewallRules / databases use defaults from main.bicep.
// Adjust models (for example skuCapacity or modelName) to match target region availability and quota.
