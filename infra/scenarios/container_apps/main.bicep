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

@description('A (UAMI, role definition) pair for granting Container App scoped permissions to an existing UAMI.')
type uamiRolePair = {
  @description('Index of the UAMI in `existingUserAssignedIdentities` whose principalId receives the role.')
  uamiIndex: int

  @description('Role definition GUID to grant at Container App scope.')
  roleDefinitionGuid: string
}

@description('A (principal, role definition) pair for granting Container App scoped permissions to an existing principal.')
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

@description('Container image to run in the Azure Container App.')
param containerImage string = 'nginx:latest'

@description('Optional startup command override for the container.')
param containerCommand string[] = []

@description('Optional startup argument override for the container.')
param containerArgs string[] = []

@description('Container CPU allocation (for example, 0.5).')
param cpu string = '0.5'

@description('Container memory allocation (for example, 1Gi).')
param memory string = '1Gi'

@description('Minimum replica count for the Azure Container App.')
@minValue(0)
param minReplicas int = 0

@description('Maximum replica count for the Azure Container App.')
@minValue(1)
param maxReplicas int = 3

@description('Ingress target port exposed by the container.')
@minValue(1)
@maxValue(65535)
param targetPort int = 80

@description('Enable external HTTPS ingress for the Azure Container App.')
param ingressExternal bool = true

@description('The SKU name for the Azure Container Registry.')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSkuName string = 'Basic'

@description('Enable Easy Auth (built-in authentication, Entra ID provider) on the Azure Container App endpoint.')
param enableEasyAuth bool = false

@description('When Easy Auth is enabled, require authentication by redirecting unauthenticated users to login page.')
param easyAuthRequireAuthentication bool = true

@description('Entra ID App Registration client ID used by Easy Auth. Required when `enableEasyAuth = true`.')
param easyAuthEntraClientId string = ''

@description('Allowed audiences for Easy Auth token validation.')
param easyAuthAllowedAudiences string[] = []

@description('Optional. Existing UAMIs to attach to the Azure Container App and grant roles at Container App scope.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Existing Microsoft Entra service principal object IDs to grant roles at Container App scope.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Existing Microsoft Entra user object IDs to grant roles at Container App scope.')
param existingUserObjectIds string[] = []

@description('Role definition GUIDs assigned to each principal provided in existing* arrays at Container App scope.')
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

var uamiRolePairs uamiRolePair[] = flatten(map(
  range(0, length(existingUserAssignedIdentities)),
  uamiIndex =>
    map(roleDefinitionIds, role => {
      uamiIndex: uamiIndex
      roleDefinitionGuid: role
    })
))

var servicePrincipalRolePairs principalRolePair[] = flatten(map(
  existingServicePrincipalObjectIds,
  pid =>
    map(roleDefinitionIds, role => {
      principalId: pid
      roleDefinitionGuid: role
    })
))

var userRolePairs principalRolePair[] = flatten(map(
  existingUserObjectIds,
  pid =>
    map(roleDefinitionIds, role => {
      principalId: pid
      roleDefinitionGuid: role
    })
))

var existingAttachedUserAssignedIdentityResourceIds = [
  for i in range(0, length(existingUserAssignedIdentities)): uamis[i].id
]

var attachedUserAssignedIdentityResourceIds = concat(
  [userAssignedManagedIdentity.outputs.id],
  existingAttachedUserAssignedIdentityResourceIds
)

// ------------------
//    EXISTING RESOURCES
// ------------------

resource uamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for uami in existingUserAssignedIdentities: {
    scope: az.resourceGroup(uami.resourceGroup)
    name: uami.name
  }
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: az.resourceGroup(resourceGroupName)
  name: logAnalyticsWorkspaceName
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

module logAnalyticsWorkspaceModule '../../modules/log_analytics_workspace/main.bicep' = {
  name: take('${name}-law-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module containerRegistry '../../modules/container_registry/main.bicep' = {
  name: take('${name}-acr-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: acrName
    location: location
    tags: tags
    skuName: acrSkuName
    adminUserEnabled: false
    anonymousPullEnabled: false
  }
  dependsOn: [resourceGroup]
}

module userAssignedManagedIdentity '../../modules/user_assigned_managed_identity/main.bicep' = {
  name: take('${name}-uami-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
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
    name: containerAppEnvironmentName
    location: location
    tags: tags
    logAnalyticsWorkspaceCustomerId: logAnalyticsWorkspace.properties.customerId
    logAnalyticsWorkspaceSharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
  }
  dependsOn: [logAnalyticsWorkspaceModule]
}

module containerApp '../../modules/container_app/main.bicep' = {
  name: take('${name}-ca-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: containerAppName
    location: location
    tags: tags
    environmentId: containerAppEnvironment.outputs.id
    userAssignedIdentityResourceIds: attachedUserAssignedIdentityResourceIds
    containerImage: containerImage
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
        identity: userAssignedManagedIdentity.outputs.id
      }
    ]
    enableEasyAuth: enableEasyAuth
    easyAuthRequireAuthentication: easyAuthRequireAuthentication
    easyAuthEntraClientId: easyAuthEntraClientId
    easyAuthAllowedAudiences: easyAuthAllowedAudiences
  }
}

module acrPullRoleAssignment '../../modules/role_assignment/main.bicep' = {
  name: take('${name}-acrpull-role-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    targetRegistryName: acrName
    principalId: userAssignedManagedIdentity.outputs.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
  }
  dependsOn: [
    containerRegistry
  ]
}

module uamiRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in uamiRolePairs: {
    name: take('${name}-uami-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      targetContainerAppName: containerAppName
      principalId: uamis[pair.uamiIndex].properties.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
    }
    dependsOn: [containerApp]
  }
]

module servicePrincipalRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in servicePrincipalRolePairs: {
    name: take('${name}-sp-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      targetContainerAppName: containerAppName
      principalId: pair.principalId
      principalType: 'ServicePrincipal'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
    }
    dependsOn: [containerApp]
  }
]

module userRoleAssignments '../../modules/role_assignment/main.bicep' = [
  for (pair, i) in userRolePairs: {
    name: take('${name}-user-role-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      targetContainerAppName: containerAppName
      principalId: pair.principalId
      principalType: 'User'
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
    }
    dependsOn: [containerApp]
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

@description('ACR login server')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('Created UAMI resource ID')
output userAssignedIdentityId string = userAssignedManagedIdentity.outputs.id

@description('Created UAMI principal ID')
output userAssignedIdentityPrincipalId string = userAssignedManagedIdentity.outputs.principalId

@description('Created UAMI client ID')
output userAssignedIdentityClientId string = userAssignedManagedIdentity.outputs.clientId

@description('Log Analytics workspace resource ID')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspaceModule.outputs.id

@description('Container Apps Environment resource ID')
output containerAppEnvironmentId string = containerAppEnvironment.outputs.id

@description('Container App resource ID')
output containerAppId string = containerApp.outputs.id

@description('Container App name')
output containerAppName string = containerApp.outputs.name

@description('Container App FQDN')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('Container App URL')
output containerAppUrl string = 'https://${containerApp.outputs.fqdn}'

@description('AcrPull role assignment ID created for the scenario-managed UAMI')
output acrPullRoleAssignmentId string = acrPullRoleAssignment.outputs.id

@description('Role assignment IDs created for existing UAMIs at Container App scope')
output uamiRoleAssignmentIds array = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('Role assignment IDs created for existing service principals at Container App scope')
output servicePrincipalRoleAssignmentIds array = [
  for (pair, i) in servicePrincipalRolePairs: servicePrincipalRoleAssignments[i].outputs.id
]

@description('Role assignment IDs created for existing users at Container App scope')
output userRoleAssignmentIds array = [for (pair, i) in userRolePairs: userRoleAssignments[i].outputs.id]
