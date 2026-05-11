using 'main.bicep'

param name = 'microsoft_foundry'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}
param existingUserAssignedIdentityName = 'id-user_assigned_managed_identity'
param existingUserAssignedIdentityResourceGroupName = 'rg-user_assigned_managed_identity'

// models / roleDefinitionIds use defaults from main.bicep.
// Adjust models (for example skuCapacity or modelName) to match target region availability and quota.
