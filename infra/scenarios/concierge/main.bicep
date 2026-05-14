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

@description('Per-Foundry model deployment definition. Mirrors the shape accepted by the microsoft_foundry_model_deployment module.')
type foundryModel = {
  name: string
  modelName: string
  modelVersion: string?
  modelFormat: string?
  skuName: string?
  skuCapacity: int?
  raiPolicyName: string?
}

@description('A Microsoft Foundry account to provision. One AI Foundry account + one project will be created for each entry.')
type foundryDeployment = {
  @description('Optional. Azure region for this Foundry account. When omitted, falls back to the scenario-level `location`.')
  location: string?

  @description('Optional. Override for the Foundry account name. When omitted, derived from the scenario name and location.')
  name: string?

  @description('Optional. Models to deploy under this Foundry account. When omitted, the scenario-level default model list is used.')
  models: foundryModel[]?
}

@description('A (foundry index, UAMI index, role definition) tuple generated for each role assignment iteration.')
type foundryUamiRolePair = {
  @description('Index of the Foundry in `effectiveFoundries` whose account scope receives the role assignment.')
  foundryIndex: int

  @description('Index of the UAMI in `existingUserAssignedIdentities` whose principalId receives the role.')
  uamiIndex: int

  @description('Role definition GUID to grant at Foundry account scope.')
  roleDefinitionGuid: string
}

@description('A (foundry index, principal object ID, role definition) tuple generated for each service principal/user role assignment iteration.')
type foundryPrincipalRolePair = {
  @description('Index of the Foundry in `effectiveFoundries` whose account scope receives the role assignment.')
  foundryIndex: int

  @description('The Microsoft Entra principal (object) ID that receives the role.')
  principalId: string

  @description('Role definition GUID to grant at Foundry account scope.')
  roleDefinitionGuid: string
}

@description('Resolved Foundry deployment settings after applying defaults and derived names.')
type effectiveFoundryDeployment = {
  location: string
  name: string
  projectName: string
  diagnosticSettingsName: string
  appInsightsConnectionName: string
  models: foundryModel[]
}

@description('A flattened (Foundry, model) pair used for sequential model deployment loops.')
type foundryModelPair = {
  foundryIndex: int
  foundryAccountName: string
  model: foundryModel
}

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and Azure resources')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

@description('Feature flag: when true, deploys Log Analytics + workspace-based Application Insights and configures Foundry tracing/diagnostic settings.')
param enableApplicationInsights bool = true

@description('Feature flag: when true, deploys PostgreSQL Flexible Server (Entra ID-only) with optional pgvector and diagnostic settings.')
param enablePostgresql bool = true

@description('Microsoft Foundry accounts to provision. Defaults to a single Foundry at the scenario `location` with the default model list, preserving the previous behavior.')
@minLength(1)
param foundries foundryDeployment[] = [
  {}
]

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Azure AI Foundry account scope.')
param roleDefinitionIds string[] = [
  '5e0bd9bd-7b93-4f28-af87-19fc36ad61bd'
]

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no UAMI is attached.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object (principal) IDs of existing Microsoft Entra service principals to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no service principal is attached.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant Azure AI Foundry inference permissions. Defaults to an empty array, in which case no user is attached.')
param existingUserObjectIds string[] = []

@description('Disable local authentication (API keys) on the Azure AI Foundry account. Set to false to enable API key based authentication.')
param disableLocalAuth bool = true

@description('Microsoft Entra ID administrator for the PostgreSQL Flexible Server. When omitted, the principal executing the deployment (returned by deployer()) is registered as the administrator so the scenario can be deployed without any manual edits.')
param entraAdministrator {
  @description('The object ID (principal ID) of the Entra principal')
  objectId: string

  @description('The display name or UPN of the Entra principal')
  principalName: string

  @description('The type of the Entra principal')
  principalType: ('User' | 'Group' | 'ServicePrincipal')

  @description('The tenant ID for the Entra administrator')
  tenantId: string
}?

@description('PostgreSQL major version. Defaults to 18 to match the pgvector/pgvector:pg18 reference image.')
param postgresVersion string = '18'

@description('The compute SKU name for the flexible server')
param postgresSkuName string = 'Standard_B1ms'

@description('The SKU tier for the flexible server')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param postgresSkuTier string = 'Burstable'

@description('Storage size in GB for the flexible server')
param postgresStorageSizeGB int = 32

@description('When true, enables the pgvector extension by setting azure.extensions configuration to VECTOR')
param enablePgvector bool = true

@description('Firewall rules to create on the flexible server. Defaults to an "Allow Azure services" rule (0.0.0.0/0.0.0.0).')
param firewallRules array = [
  {
    name: 'AllowAllAzureServices'
    startIpAddress: '0.0.0.0'
    endIpAddress: '0.0.0.0'
  }
]

@description('Databases to create on the flexible server. Defaults to a single "appdb" database for validation.')
param databases array = [
  {
    name: 'appdb'
  }
]

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var postgresServerName = take(toLower(replace('psql-${name}', '_', '-')), 63)
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var applicationInsightsName = take(toLower(replace('appi-${name}', '_', '-')), 260)
var postgresDiagnosticSettingsName = take('diag-${postgresServerName}', 256)

var defaultFoundryModels foundryModel[] = [
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

var foundryLocations string[] = [for foundry in foundries: string(foundry.?location ?? location)]
var normalizedFoundryLocations string[] = [
  for foundryLocation in foundryLocations: replace(toLower(foundryLocation), ' ', '')
]
var foundryLocationEntryCounts int[] = [
  for i in range(0, length(foundries)): length(filter(
    range(0, length(foundries)),
    j => normalizedFoundryLocations[j] == normalizedFoundryLocations[i]
  ))
]
var foundryLocationSuffixes string[] = [
  for i in range(0, length(foundries)): foundryLocationEntryCounts[i] > 1 ? '-${i}' : ''
]
var derivedFoundryAccountNames string[] = [
  for i in range(0, length(foundries)): take(
    toLower(replace('aif-${name}-${normalizedFoundryLocations[i]}${foundryLocationSuffixes[i]}', '_', '-')),
    59
  )
]
var derivedFoundryProjectNames string[] = [
  for i in range(0, length(foundries)): take(
    'proj-${name}-${normalizedFoundryLocations[i]}${foundryLocationSuffixes[i]}',
    64
  )
]

var effectiveFoundries effectiveFoundryDeployment[] = [
  for i in range(0, length(foundries)): {
    location: foundryLocations[i]
    name: !empty(string(foundries[i].?name ?? '')) ? string(foundries[i].?name ?? '') : derivedFoundryAccountNames[i]
    projectName: derivedFoundryProjectNames[i]
    diagnosticSettingsName: take(
      'diag-${!empty(string(foundries[i].?name ?? '')) ? string(foundries[i].?name ?? '') : derivedFoundryAccountNames[i]}',
      64
    )
    appInsightsConnectionName: take('appinsights-${derivedFoundryProjectNames[i]}', 64)
    models: foundries[i].?models ?? defaultFoundryModels
  }
]

// Cross-product each identity array with `roleDefinitionIds` and each Foundry into a flat list of struct pairs.
var uamiRolePairs foundryUamiRolePair[] = flatten(map(
  range(0, length(effectiveFoundries)),
  foundryIndex =>
    flatten(map(
      range(0, length(existingUserAssignedIdentities)),
      uamiIndex =>
        map(roleDefinitionIds, roleDefinitionGuid => {
          foundryIndex: foundryIndex
          uamiIndex: uamiIndex
          roleDefinitionGuid: roleDefinitionGuid
        })
    ))
))

var servicePrincipalRolePairs foundryPrincipalRolePair[] = flatten(map(
  range(0, length(effectiveFoundries)),
  foundryIndex =>
    flatten(map(
      existingServicePrincipalObjectIds,
      principalId =>
        map(roleDefinitionIds, roleDefinitionGuid => {
          foundryIndex: foundryIndex
          principalId: principalId
          roleDefinitionGuid: roleDefinitionGuid
        })
    ))
))

var userRolePairs foundryPrincipalRolePair[] = flatten(map(
  range(0, length(effectiveFoundries)),
  foundryIndex =>
    flatten(map(
      existingUserObjectIds,
      principalId =>
        map(roleDefinitionIds, roleDefinitionGuid => {
          foundryIndex: foundryIndex
          principalId: principalId
          roleDefinitionGuid: roleDefinitionGuid
        })
    ))
))

var foundryModelPairs foundryModelPair[] = flatten(map(
  range(0, length(effectiveFoundries)),
  i =>
    map(effectiveFoundries[i].models, model => {
      foundryIndex: i
      foundryAccountName: effectiveFoundries[i].name
      model: model
    })
))

// Resolve the effective Microsoft Entra administrator for PostgreSQL.
// When the caller does not pass `entraAdministrator`, fall back to the principal
// executing the deployment (the `deployer()` function), so the scenario can be
// deployed with no manual parameter edits.
var deployerInfo = deployer()
var deployerUserPrincipalName = deployerInfo.?userPrincipalName ?? ''
var effectiveEntraAdministrator = entraAdministrator ?? {
  objectId: deployerInfo.objectId
  principalName: empty(deployerUserPrincipalName) ? deployerInfo.objectId : deployerUserPrincipalName
  principalType: empty(deployerUserPrincipalName) ? 'ServicePrincipal' : 'User'
  tenantId: deployerInfo.tenantId
}

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

module foundryAccounts '../../modules/microsoft_foundry/main.bicep' = [
  for (foundry, i) in effectiveFoundries: {
    name: take('${name}-foundry-${i}-account-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      name: foundry.name
      location: foundry.location
      tags: tags
      disableLocalAuth: disableLocalAuth
    }
    dependsOn: [resourceGroup]
  }
]

module foundryProjects '../../modules/microsoft_foundry_project/main.bicep' = [
  for (foundry, i) in effectiveFoundries: {
    name: take('${name}-foundry-${i}-project-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      parentAccountName: foundry.name
      name: foundry.projectName
      location: foundry.location
      displayName: foundry.projectName
      tags: tags
    }
    dependsOn: [foundryAccounts[i]]
  }
]

module logAnalyticsWorkspace '../../modules/log_analytics_workspace/main.bicep' = if (enableApplicationInsights) {
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

module applicationInsights '../../modules/application_insights/main.bicep' = if (enableApplicationInsights) {
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

module foundryDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = [
  for (foundry, i) in effectiveFoundries: if (enableApplicationInsights) {
    name: take('${name}-foundry-${i}-diag-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      name: foundry.diagnosticSettingsName
      workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
      #disable-next-line BCP334
      targetAccountName: foundry.name
    }
    dependsOn: [
      foundryAccounts[i]
    ]
  }
]

module foundryAppInsightsConnections '../../modules/microsoft_foundry_connection/main.bicep' = [
  for (foundry, i) in effectiveFoundries: if (enableApplicationInsights) {
    name: take('${name}-foundry-${i}-appinsights-connection-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      parentAccountName: foundry.name
      name: foundry.appInsightsConnectionName
      parentProjectName: foundry.projectName
      category: 'AppInsights'
      target: applicationInsights.?outputs.id ?? ''
      credentialKey: applicationInsights.?outputs.connectionString ?? ''
      resourceId: applicationInsights.?outputs.id ?? ''
      location: location
      isSharedToAll: false
    }
    dependsOn: [
      foundryProjects[i]
    ]
  }
]

@batchSize(1)
module modelDeployments '../../modules/microsoft_foundry_model_deployment/main.bicep' = [
  for (pair, i) in foundryModelPairs: {
    name: take('${name}-foundry-${pair.foundryIndex}-model-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      parentAccountName: pair.foundryAccountName
      name: pair.model.name
      modelName: pair.model.modelName
      modelVersion: string(pair.model.?modelVersion ?? '')
      modelFormat: string(pair.model.?modelFormat ?? 'OpenAI')
      skuName: string(pair.model.?skuName ?? 'GlobalStandard')
      skuCapacity: int(pair.model.?skuCapacity ?? 50)
      raiPolicyName: string(pair.model.?raiPolicyName ?? '')
    }
    dependsOn: [foundryProjects[pair.foundryIndex]]
  }
]

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-foundry-${pair.foundryIndex}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: effectiveFoundries[pair.foundryIndex].name
      principalId: uamis[pair.uamiIndex].properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        foundryAccounts[pair.foundryIndex].outputs.id,
        uamis[pair.uamiIndex].properties.principalId,
        pair.roleDefinitionGuid
      )
      principalType: 'ServicePrincipal'
    }
  }
]

module servicePrincipalRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in servicePrincipalRolePairs: {
    name: take('${name}-foundry-${pair.foundryIndex}-sp-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: effectiveFoundries[pair.foundryIndex].name
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        foundryAccounts[pair.foundryIndex].outputs.id,
        pair.principalId,
        pair.roleDefinitionGuid
      )
      principalType: 'ServicePrincipal'
    }
  }
]

module userRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in userRolePairs: {
    name: take('${name}-foundry-${pair.foundryIndex}-user-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetAccountName: effectiveFoundries[pair.foundryIndex].name
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        foundryAccounts[pair.foundryIndex].outputs.id,
        pair.principalId,
        pair.roleDefinitionGuid
      )
      principalType: 'User'
    }
  }
]

module postgresServer '../../modules/postgresql_flexible_server/main.bicep' = if (enablePostgresql) {
  name: take('${name}-psql-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: postgresServerName
    location: location
    tags: tags
    version: postgresVersion
    skuName: postgresSkuName
    skuTier: postgresSkuTier
    storageSizeGB: postgresStorageSizeGB
    entraAdministrator: effectiveEntraAdministrator
    firewallRules: firewallRules
    databases: databases
    enablePgvector: enablePgvector
  }
  dependsOn: [resourceGroup]
}

module postgresDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = if (enablePostgresql && enableApplicationInsights) {
  name: take('${name}-psql-diag-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: postgresDiagnosticSettingsName
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    #disable-next-line BCP334
    targetServerName: postgresServerName
  }
  dependsOn: [postgresServer]
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the created resource group')
output resourceGroupId string = resourceGroup.outputs.id

@description('The name of the created resource group')
output resourceGroupName string = resourceGroup.outputs.name

@description('The location of the created resource group')
output resourceGroupLocation string = resourceGroup.outputs.location

@description('The resource IDs of created Azure AI Foundry accounts')
output foundryAccountIds string[] = [for i in range(0, length(effectiveFoundries)): foundryAccounts[i].outputs.id]

@description('The names of created Azure AI Foundry accounts')
output foundryAccountNames string[] = [for i in range(0, length(effectiveFoundries)): foundryAccounts[i].outputs.name]

@description('The endpoints of created Azure AI Foundry accounts')
output foundryEndpoints string[] = [for i in range(0, length(effectiveFoundries)): foundryAccounts[i].outputs.endpoint]

@description('The resource IDs of created Azure AI Foundry projects')
output foundryProjectIds string[] = [for i in range(0, length(effectiveFoundries)): foundryProjects[i].outputs.id]

@description('The names of created Azure AI Foundry projects')
output foundryProjectNames string[] = [for i in range(0, length(effectiveFoundries)): foundryProjects[i].outputs.name]

@description('Model deployment names grouped by Foundry account')
output deployedModelNames array = [
  for (foundry, i) in effectiveFoundries: {
    foundryAccountName: foundry.name
    models: map(filter(foundryModelPairs, pair => pair.foundryIndex == i), pair => pair.model.name)
  }
]

@description('The resource ID of the created Log Analytics workspace (empty when Application Insights is disabled)')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.?outputs.id ?? ''

@description('The resource ID of the created Application Insights component (empty when Application Insights is disabled)')
output applicationInsightsId string = applicationInsights.?outputs.id ?? ''

@description('The connection string of the created Application Insights component (empty when Application Insights is disabled)')
output applicationInsightsConnectionString string = applicationInsights.?outputs.connectionString ?? ''

@description('The resource ID of the created PostgreSQL Flexible Server (empty when PostgreSQL is disabled)')
output postgresServerId string = postgresServer.?outputs.id ?? ''

@description('The name of the created PostgreSQL Flexible Server (empty when PostgreSQL is disabled)')
output postgresServerName string = postgresServer.?outputs.name ?? ''

@description('The fully qualified domain name (FQDN) of the created PostgreSQL Flexible Server (empty when PostgreSQL is disabled)')
output postgresServerFqdn string = postgresServer.?outputs.fullyQualifiedDomainName ?? ''

@description('The names of databases created on the flexible server (empty when PostgreSQL is disabled)')
output databaseNames array = postgresServer.?outputs.databaseNames ?? []

@description('The resource IDs of role assignments granted to every existing User Assigned Managed Identity (empty when no UAMI is attached)')
output uamiRoleAssignmentIds string[] = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('The resource IDs of role assignments granted to every existing service principal (empty when no service principal is attached)')
output servicePrincipalRoleAssignmentIds string[] = [
  for (pair, i) in servicePrincipalRolePairs: servicePrincipalRoleAssignments[i].outputs.id
]

@description('The resource IDs of role assignments granted to every existing user (empty when no user is attached)')
output userRoleAssignmentIds string[] = [for (pair, i) in userRolePairs: userRoleAssignments[i].outputs.id]
