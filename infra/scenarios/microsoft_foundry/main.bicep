targetScope = 'subscription'

// ------------------
//    TYPES
// ------------------

@description('Reference to an existing User Assigned Managed Identity (UAMI).')
type uamiReference = {
  @description('The name of the existing User Assigned Managed Identity.')
  name: string

  @description('The resource group name where the existing UAMI lives.')
  resourceGroup: string
}

@description('A (UAMI, role definition) pair generated for each role assignment iteration.')
type uamiRolePair = {
  @description('Index of the UAMI in `existingUserAssignedIdentities` whose principalId receives the role.')
  uamiIndex: int

  @description('Role definition GUID to grant at Foundry account scope.')
  roleDefinitionGuid: string
}

@description('A (principal object ID, role definition) pair generated for each service principal/user role assignment iteration.')
type principalRolePair = {
  @description('The Microsoft Entra principal (object) ID that receives the role.')
  principalId: string

  @description('Role definition GUID to grant at Foundry account scope.')
  roleDefinitionGuid: string
}

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

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no UAMI is attached.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object (principal) IDs of existing Microsoft Entra service principals to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no service principal is attached.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no user is attached.')
param existingUserObjectIds string[] = []

@description('Disable local authentication (API keys) on the Azure AI Foundry account. Set to false to enable API key based authentication.')
param disableLocalAuth bool = true

@description('Enable Azure Monitor based observability resources (Log Analytics, Application Insights, diagnostic settings, and Foundry project tracing connection).')
param enableObservability bool = false

@description('The list of model deployments to create in Azure AI Foundry. Defaults target models broadly available in regions such as japaneast; override via main.bicepparam if the target region/quota differs.')
param models array = [
  {
    name: 'gpt-4o'
    modelName: 'gpt-4o'
    modelFormat: 'OpenAI'
    skuName: 'GlobalStandard'
    skuCapacity: 50
  }
  {
    name: 'gpt-5'
    modelName: 'gpt-5'
    modelVersion: '2025-08-07'
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

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Azure AI Foundry account scope.')
param roleDefinitionIds string[] = [
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
]

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var foundryAccountName = take(toLower(replace('aif-${name}', '_', '-')), 59)
var foundryProjectName = take('proj-${name}', 64)
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var applicationInsightsName = take(toLower(replace('appi-${name}', '_', '-')), 260)
var foundryDiagnosticSettingsName = take('diag-${foundryAccountName}', 64)
var foundryAppInsightsConnectionName = take('appinsights-${foundryProjectName}', 64)

// Cross-product each identity array with `roleDefinitionIds` into a flat list of struct pairs.
// `map`/`flatten` keep the cross product readable and naturally produce an empty list when the
// identity array is empty, so no flag variables or `if` guards are required at the loop sites.
var uamiRolePairs uamiRolePair[] = flatten(map(
  range(0, length(existingUserAssignedIdentities)),
  uamiIndex =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      uamiIndex: uamiIndex
      roleDefinitionGuid: roleDefinitionGuid
    })
))

var servicePrincipalRolePairs principalRolePair[] = flatten(map(
  existingServicePrincipalObjectIds,
  principalId =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      principalId: principalId
      roleDefinitionGuid: roleDefinitionGuid
    })
))

var userRolePairs principalRolePair[] = flatten(map(
  existingUserObjectIds,
  principalId =>
    map(roleDefinitionIds, roleDefinitionGuid => {
      principalId: principalId
      roleDefinitionGuid: roleDefinitionGuid
    })
))

// ------------------
//    EXISTING RESOURCES
// ------------------

resource uamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for uami in existingUserAssignedIdentities: {
    scope: az.resourceGroup(uami.resourceGroup)
    name: uami.name
  }
]

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
    #disable-next-line BCP334
    name: foundryAccountName
    location: location
    tags: tags
    disableLocalAuth: disableLocalAuth
  }
  dependsOn: [resourceGroup]
}

module foundryProject '../../modules/microsoft_foundry_project/main.bicep' = {
  name: take('${name}-foundry-project-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    parentAccountName: foundryAccountName
    name: foundryProjectName
    location: location
    displayName: foundryProjectName
    tags: tags
  }
  dependsOn: [foundryAccount]
}

module logAnalyticsWorkspace '../../modules/log_analytics_workspace/main.bicep' = if (enableObservability) {
  name: take('${name}-law-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module applicationInsights '../../modules/application_insights/main.bicep' = if (enableObservability) {
  name: take('${name}-appi-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: applicationInsightsName
    location: location
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    tags: tags
  }
}

module foundryDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = if (enableObservability) {
  name: take('${name}-diag-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: foundryDiagnosticSettingsName
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    #disable-next-line BCP334
    targetAccountName: foundryAccountName
  }
  dependsOn: [
    foundryAccount
  ]
}

module foundryAppInsightsConnection '../../modules/microsoft_foundry_connection/main.bicep' = if (enableObservability) {
  name: take('${name}-appinsights-connection-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    parentAccountName: foundryAccountName
    name: foundryAppInsightsConnectionName
    parentProjectName: foundryProjectName
    category: 'AppInsights'
    target: applicationInsights.?outputs.id ?? ''
    credentialKey: applicationInsights.?outputs.connectionString ?? ''
    resourceId: applicationInsights.?outputs.id ?? ''
    location: location
    isSharedToAll: false
  }
  dependsOn: [
    foundryProject
  ]
}

@batchSize(1)
module modelDeployments '../../modules/microsoft_foundry_model_deployment/main.bicep' = [
  for (model, i) in models: {
    name: take('${name}-model-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
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
  }
]

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: foundryAccountName
      principalId: uamis[pair.uamiIndex].properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        foundryAccount.outputs.id,
        uamis[pair.uamiIndex].properties.principalId,
        pair.roleDefinitionGuid
      )
      principalType: 'ServicePrincipal'
    }
  }
]

module servicePrincipalRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in servicePrincipalRolePairs: {
    name: take('${name}-sp-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: foundryAccountName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(foundryAccount.outputs.id, pair.principalId, pair.roleDefinitionGuid)
      principalType: 'ServicePrincipal'
    }
  }
]

module userRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in userRolePairs: {
    name: take('${name}-user-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: foundryAccountName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(foundryAccount.outputs.id, pair.principalId, pair.roleDefinitionGuid)
      principalType: 'User'
    }
  }
]

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

@description('The resource ID of the created Log Analytics workspace (empty when observability is disabled)')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.?outputs.id ?? ''

@description('The resource ID of the created Application Insights component (empty when observability is disabled)')
output applicationInsightsId string = applicationInsights.?outputs.id ?? ''

@description('The connection string of the created Application Insights component (empty when observability is disabled)')
output applicationInsightsConnectionString string = applicationInsights.?outputs.connectionString ?? ''

@description('The resource IDs of role assignments granted to every existing User Assigned Managed Identity (empty when no UAMI is attached)')
output uamiRoleAssignmentIds string[] = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('The resource IDs of role assignments granted to every existing service principal (empty when no service principal is attached)')
output servicePrincipalRoleAssignmentIds string[] = [
  for (pair, i) in servicePrincipalRolePairs: servicePrincipalRoleAssignments[i].outputs.id
]

@description('The resource IDs of role assignments granted to every existing user (empty when no user is attached)')
output userRoleAssignmentIds string[] = [for (pair, i) in userRolePairs: userRoleAssignments[i].outputs.id]
