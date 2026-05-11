using 'main.bicep'

// NOTE: deviates from the scenario folder name because Azure rejects Cognitive Services / AI Foundry
// account names containing the trademarked word "microsoft" (ReservedResourceName). Underscores are
// also invalid in Foundry project names, so we use a hyphenated, non-reserved value here.
param name = 'templatebicepfoundry'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Enable API key based authentication on the Foundry account. Set to true to require Entra ID only.
param disableLocalAuth = false

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
