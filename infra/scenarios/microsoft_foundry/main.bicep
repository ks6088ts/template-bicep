targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and Azure AI Foundry resources')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

@description('The name of the existing User Assigned Managed Identity that will call Azure AI Foundry')
@minLength(3)
@maxLength(128)
param existingUserAssignedIdentityName string

@description('The resource group name where the existing User Assigned Managed Identity exists')
@minLength(1)
@maxLength(90)
param existingUserAssignedIdentityResourceGroupName string

@description('The list of model deployments to create in Azure AI Foundry')
param models array = [
  {
    name: 'gpt-5.4'
    modelName: 'gpt-5.4'
    modelFormat: 'OpenAI'
    skuName: 'GlobalStandard'
    skuCapacity: 50
  }
  {
    name: 'gpt-5.4-nano'
    modelName: 'gpt-5.4-nano'
    modelFormat: 'OpenAI'
    skuName: 'GlobalStandard'
    skuCapacity: 50
  }
  {
    name: 'text-embedding-3-large'
    modelName: 'text-embedding-3-large'
    modelFormat: 'OpenAI'
    skuName: 'Standard'
    skuCapacity: 50
  }
  {
    name: 'text-embedding-3-small'
    modelName: 'text-embedding-3-small'
    modelFormat: 'OpenAI'
    skuName: 'Standard'
    skuCapacity: 50
  }
]

@description('Role definition GUIDs assigned to the existing User Assigned Managed Identity at Azure AI Foundry account scope')
param roleDefinitionIds array = [
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
]

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var foundryAccountName = take(toLower(replace('aif-${name}', '_', '-')), 59)
var foundryProjectName = take('proj-${name}', 64)

// ------------------
//    EXISTING RESOURCES
// ------------------

resource existingUserAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = {
  scope: az.resourceGroup(existingUserAssignedIdentityResourceGroupName)
  name: existingUserAssignedIdentityName
}

// ------------------
//    RESOURCES
// ------------------

module resourceGroup '../../modules/resource_group/main.bicep' = {
  name: take('${name}-rg-deployment', 64)
  params: {
    name: resourceGroupName
    location: location
    tags: tags
  }
}

module foundryAccount '../../modules/microsoft_foundry/main.bicep' = {
  name: take('${name}-foundry-account-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: foundryAccountName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module foundryProject '../../modules/microsoft_foundry_project/main.bicep' = {
  name: take('${name}-foundry-project-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    parentAccountName: foundryAccountName
    name: foundryProjectName
    location: location
    displayName: foundryProjectName
    tags: tags
  }
  dependsOn: [foundryAccount]
}

@batchSize(1)
module modelDeployments '../../modules/microsoft_foundry_model_deployment/main.bicep' = [for (model, i) in models: {
  name: take('${name}-model-${i}-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    parentAccountName: foundryAccountName
    name: model.name
    modelName: model.modelName
    modelVersion: string(model.?modelVersion ?? '')
    modelFormat: string(model.?modelFormat ?? 'OpenAI')
    skuName: string(model.?skuName ?? 'GlobalStandard')
    skuCapacity: int(model.?skuCapacity ?? 50)
    raiPolicyName: string(model.?raiPolicyName ?? '')
  }
  dependsOn: [foundryProject]
}]

module roleAssignments '../../modules/role_assignment/main.bicep' = [for roleDefinitionGuid in roleDefinitionIds: {
  name: take('${name}-role-${substring(roleDefinitionGuid, 0, 8)}-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    targetAccountName: foundryAccountName
    principalId: existingUserAssignedIdentity.properties.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', roleDefinitionGuid)
    roleAssignmentNameSeed: guid(foundryAccount.outputs.id, existingUserAssignedIdentity.properties.principalId, roleDefinitionGuid)
    principalType: 'ServicePrincipal'
  }
}]

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the created resource group')
output resourceGroupId string = resourceGroup.outputs.id

@description('The name of the created resource group')
output resourceGroupName string = resourceGroup.outputs.name

@description('The location of the created resource group')
output resourceGroupLocation string = resourceGroup.outputs.location

@description('The resource ID of the created Azure AI Foundry account')
output foundryAccountId string = foundryAccount.outputs.id

@description('The name of the created Azure AI Foundry account')
output foundryAccountName string = foundryAccount.outputs.name

@description('The endpoint of the created Azure AI Foundry account')
output foundryEndpoint string = foundryAccount.outputs.endpoint

@description('The resource ID of the created Azure AI Foundry project')
output foundryProjectId string = foundryProject.outputs.id

@description('The name of the created Azure AI Foundry project')
output foundryProjectName string = foundryProject.outputs.name

@description('The names of model deployments requested by this scenario')
output deployedModelNames array = [for model in models: model.name]

@description('The resource IDs of role assignments granted to the existing User Assigned Managed Identity')
output roleAssignmentIds array = [for i in range(0, length(roleDefinitionIds)): roleAssignments[i].outputs.id]
