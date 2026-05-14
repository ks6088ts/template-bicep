using 'main.bicep'

// NOTE: deviates from the scenario folder name because Azure rejects Cognitive Services / AI Foundry
// account names containing the trademarked word "microsoft" (ReservedResourceName). Underscores are
// also invalid in Foundry project names, so we use a hyphenated, non-reserved value here.
param name = 'templatebicepfoundry'
param foundryDeployments = [
  {
    location: 'japaneast'
    models: [
      {
        name: 'gpt-4o'
        modelName: 'gpt-4o'
        skuCapacity: 50
      }
      {
        name: 'text-embedding-3-large'
        modelName: 'text-embedding-3-large'
        skuName: 'Standard'
      }
      {
        name: 'text-embedding-3-small'
        modelName: 'text-embedding-3-small'
        skuName: 'Standard'
      }
    ]
  }
  {
    location: 'eastus2'
    models: [
      {
        name: 'gpt-5'
        modelName: 'gpt-5'
        modelVersion: '2025-08-07'
      }
    ]
  }
]
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// Enable API key based authentication on the Foundry account. Set to true to require Entra ID only.
param disableLocalAuth = false

// Optional: enable observability resources (Log Analytics, Application Insights, diagnostic settings,
// and Foundry project tracing connection). Leave commented out (or set to false) to preserve the
// existing behavior without observability resources.
param enableObservability = true

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

// roleDefinitionIds uses default from main.bicep.
