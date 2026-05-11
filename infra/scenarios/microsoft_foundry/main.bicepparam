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

// Optional: attach an existing User Assigned Managed Identity (UAMI) to receive Foundry inference
// role assignments. Leave these commented out to keep the default behavior of skipping the role
// assignment (no UAMI is attached).
// param existingUserAssignedIdentityName = 'id-userassignedmanagedidentity'
// param existingUserAssignedIdentityResourceGroupName = 'rg-userassignedmanagedidentity'

// models / roleDefinitionIds use defaults from main.bicep.
// Adjust models (for example skuCapacity or modelName) to match target region availability and quota.
