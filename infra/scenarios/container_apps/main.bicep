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

  @description('Role definition GUID to grant at Container App scope.')
  roleDefinitionGuid: string
}

@description('A (principal object ID, role definition) pair generated for each service principal/user role assignment iteration.')
type principalRolePair = {
  @description('The Microsoft Entra principal (object) ID that receives the role.')
  principalId: string

  @description('Role definition GUID to grant at Container App scope.')
  roleDefinitionGuid: string
}

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and Container Apps resources')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

@description('Container image to run in the Container App')
param containerImage string = 'nginx:latest'

@description('Optional. Override container command')
param containerCommand string[] = []

@description('Optional. Override container args')
param containerArgs string[] = []

@description('CPU allocation (vCPU). Example: 0.5')
param cpu string = '0.5'

@description('Memory allocation. Example: 1Gi')
param memory string = '1Gi'

@description('Minimum replicas')
param minReplicas int = 0

@description('Maximum replicas')
param maxReplicas int = 3

@description('Ingress target port')
param targetPort int = 80

@description('When true, enables external HTTPS ingress')
param ingressExternal bool = true

@description('The SKU name for the Azure Container Registry (ACR)')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSkuName string = 'Basic'

@description('When true, enables Easy Auth (built-in authentication) with Microsoft Entra ID on the Container App endpoint')
param enableEasyAuth bool = false

@description('When Easy Auth is enabled, require authentication (redirect unauthenticated clients to login)')
param easyAuthRequireAuthentication bool = true

@description('Client ID of the Entra ID app registration (required when Easy Auth is enabled)')
param easyAuthEntraClientId string = ''

@description('Allowed audiences for Easy Auth token validation')
param easyAuthAllowedAudiences string[] = []

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to attach to the Container App and grant roles at Container App scope. Defaults to an empty array.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object (principal) IDs of existing Microsoft Entra service principals to grant roles at Container App scope. Defaults to an empty array.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant roles at Container App scope. Defaults to an empty array.')
param existingUserObjectIds string[] = []

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Container App scope. Defaults to empty array (no role assignments).')
param roleDefinitionIds string[] = []

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var acrName = take(toLower(replace(replace('acr${name}', '_', ''), '-', '')), 50)
var uamiName = take(toLower(replace('id-${name}', '_', '-')), 128)
var containerAppEnvironmentName = take(toLower(replace('cae-${name}', '_', '-')), 32)
var containerAppName = take(toLower(replace('ca-${name}', '_', '-')), 32)

var acrPullRoleDefinitionGuid = '7f951dda-4ed3-4680-a7ca-43fe172d538d'

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

var existingUamiResourceIds string[] = [for (uami, i) in existingUserAssignedIdentities: uamis[i].id]

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

module logAnalyticsWorkspace '../../modules/log_analytics_workspace/main.bicep' = {
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

resource logAnalyticsWorkspaceResource 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: az.resourceGroup(resourceGroupName)
  name: logAnalyticsWorkspaceName
}

module containerRegistry '../../modules/container_registry/main.bicep' = {
  name: take('${name}-acr-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: acrName
    location: location
    tags: tags
    skuName: acrSkuName
    adminUserEnabled: false
    anonymousPullEnabled: false
  }
  dependsOn: [resourceGroup]
}

module userAssignedIdentity '../../modules/user_assigned_managed_identity/main.bicep' = {
  name: take('${name}-uami-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: uamiName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module containerAppEnvironment '../../modules/container_app_environment/main.bicep' = {
  name: take('${name}-cae-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: containerAppEnvironmentName
    location: location
    tags: tags
    logAnalyticsWorkspaceCustomerId: logAnalyticsWorkspaceResource.properties.customerId
    logAnalyticsWorkspaceSharedKey: listKeys(logAnalyticsWorkspaceResource.id, logAnalyticsWorkspaceResource.apiVersion).primarySharedKey
  }
  dependsOn: [
    logAnalyticsWorkspace
  ]
}

module containerApp '../../modules/container_app/main.bicep' = {
  name: take('${name}-ca-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    name: containerAppName
    location: location
    tags: tags
    environmentId: containerAppEnvironment.outputs.id
    userAssignedIdentityResourceIds: concat(
      [
        userAssignedIdentity.outputs.id
      ],
      existingUamiResourceIds
    )
    enableSystemAssignedIdentity: true
    containerImage: containerImage
    containerName: 'app'
    containerCommand: containerCommand
    containerArgs: containerArgs
    cpu: cpu
    memory: memory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    targetPort: targetPort
    ingressExternal: ingressExternal
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: userAssignedIdentity.outputs.id
      }
    ]
    enableEasyAuth: enableEasyAuth
    easyAuthRequireAuthentication: easyAuthRequireAuthentication
    easyAuthEntraClientId: easyAuthEntraClientId
    easyAuthAllowedAudiences: easyAuthAllowedAudiences
  }
}

module acrPullRoleAssignment '../../modules/role_assignment/main.bicep' = {
  name: take('${name}-acr-pull-role-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    #disable-next-line BCP334
    targetRegistryName: acrName
    principalId: userAssignedIdentity.outputs.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionGuid)
    roleAssignmentNameSeed: guid(
      containerRegistry.outputs.id,
      userAssignedIdentity.outputs.principalId,
      acrPullRoleDefinitionGuid
    )
    principalType: 'ServicePrincipal'
  }
}

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      #disable-next-line BCP334
      targetContainerAppName: containerAppName
      principalId: uamis[pair.uamiIndex].properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        containerApp.outputs.id,
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
      targetContainerAppName: containerAppName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(containerApp.outputs.id, pair.principalId, pair.roleDefinitionGuid)
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
      targetContainerAppName: containerAppName
      principalId: pair.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(containerApp.outputs.id, pair.principalId, pair.roleDefinitionGuid)
      principalType: 'User'
    }
  }
]

// ------------------
//    OUTPUTS
// ------------------

@description('RG resource ID')
output resourceGroupId string = resourceGroup.outputs.id

@description('RG name')
output resourceGroupName string = resourceGroup.outputs.name

@description('ACR resource ID')
output containerRegistryId string = containerRegistry.outputs.id

@description('ACR loginServer')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('Resource ID of the created UAMI')
output userAssignedIdentityId string = userAssignedIdentity.outputs.id

@description('Principal ID of the created UAMI')
output userAssignedIdentityPrincipalId string = userAssignedIdentity.outputs.principalId

@description('Client ID of the created UAMI')
output userAssignedIdentityClientId string = userAssignedIdentity.outputs.clientId

@description('Log Analytics resource ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.outputs.id

@description('Container Apps Environment resource ID')
output containerAppEnvironmentId string = containerAppEnvironment.outputs.id

@description('Container App resource ID')
output containerAppId string = containerApp.outputs.id

@description('Container App name')
output containerAppName string = containerApp.outputs.name

@description('Container App FQDN')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('Container App URL for quick verification')
output containerAppUrl string = 'https://${containerApp.outputs.fqdn}'

@description('Role assignment ID of AcrPull granted to the created UAMI at ACR scope')
output acrPullRoleAssignmentId string = acrPullRoleAssignment.outputs.id

@description('Role assignment IDs granted to the supplied UAMIs (empty when no UAMI is attached)')
output uamiRoleAssignmentIds array = [for i in range(0, length(uamiRolePairs)): uamiRoleAssignments[i].outputs.id]

@description('Role assignment IDs granted to the supplied service principals (empty when no service principal is attached)')
output servicePrincipalRoleAssignmentIds array = [
  for i in range(0, length(servicePrincipalRolePairs)): servicePrincipalRoleAssignments[i].outputs.id
]

@description('Role assignment IDs granted to the supplied users (empty when no user is attached)')
output userRoleAssignmentIds array = [for i in range(0, length(userRolePairs)): userRoleAssignments[i].outputs.id]
