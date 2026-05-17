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

@description('The container image for the Container App')
param containerImage string = 'nginx:latest'

@description('Optional command override for the container')
param containerCommand string[] = []

@description('Optional arguments override for the container')
param containerArgs string[] = []

@description('The CPU allocation for the container')
param cpu string = '0.5'

@description('The memory allocation for the container')
param memory string = '1Gi'

@description('Minimum number of replicas')
@minValue(0)
param minReplicas int = 0

@description('Maximum number of replicas')
@minValue(1)
param maxReplicas int = 3

@description('Target port for ingress')
@minValue(1)
@maxValue(65535)
param targetPort int = 80

@description('When true, enables external ingress')
param ingressExternal bool = true

@description('The SKU name for Azure Container Registry')
@allowed([
  'Basic'
  'Standard'
  'Premium'
])
param acrSkuName string = 'Basic'

@description('When true, configures Easy Auth with Microsoft Entra ID provider')
param enableEasyAuth bool = false

@description('When true and Easy Auth is enabled, unauthenticated users are redirected to login page')
param easyAuthRequireAuthentication bool = true

@description('Client ID of the Microsoft Entra app registration used by Easy Auth')
param easyAuthEntraClientId string = ''

@description('Allowed audiences for Easy Auth token validation')
param easyAuthAllowedAudiences string[] = []

@description('Optional. Array of existing User Assigned Managed Identities (UAMI) to attach to the Container App and grant roles at Container App scope.')
param existingUserAssignedIdentities uamiReference[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra service principals to grant roles at Container App scope.')
param existingServicePrincipalObjectIds string[] = []

@description('Optional. Array of object IDs of existing Microsoft Entra users to grant roles at Container App scope.')
param existingUserObjectIds string[] = []

@description('Role definition GUIDs assigned to every existing UAMI, service principal, and user at Container App scope.')
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

var existingUamiResourceIds string[] = [for (uami, i) in existingUserAssignedIdentities: existingUamis[i].id]

// ------------------
//    EXISTING RESOURCES
// ------------------

resource existingUamis 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' existing = [
  for uami in existingUserAssignedIdentities: {
    scope: az.resourceGroup(uami.resourceGroup)
    name: uami.name
  }
]

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  scope: az.resourceGroup(resourceGroupName)
  #disable-next-line BCP334
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
    #disable-next-line BCP334
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
    #disable-next-line BCP334
    name: acrName
    location: location
    tags: tags
    skuName: acrSkuName
    adminUserEnabled: false
    publicNetworkAccess: 'Enabled'
    anonymousPullEnabled: false
  }
  dependsOn: [resourceGroup]
}

module userAssignedManagedIdentity '../../modules/user_assigned_managed_identity/main.bicep' = {
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
    logAnalyticsWorkspaceCustomerId: logAnalyticsWorkspace.properties.customerId
    logAnalyticsWorkspaceSharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
  }
  dependsOn: [
    logAnalyticsWorkspaceModule
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
        userAssignedManagedIdentity.outputs.id
      ],
      existingUamiResourceIds
    )
    enableSystemAssignedIdentity: true
    containerImage: containerImage
    containerName: 'app'
    containerCommand: containerCommand
    containerArgs: containerArgs
    containerEnv: []
    cpu: cpu
    memory: memory
    minReplicas: minReplicas
    maxReplicas: maxReplicas
    targetPort: targetPort
    ingressExternal: ingressExternal
    transport: 'auto'
    registries: [
      {
        server: containerRegistry.outputs.loginServer
        identity: userAssignedManagedIdentity.outputs.id
      }
    ]
    secrets: []
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
    principalId: userAssignedManagedIdentity.outputs.principalId
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleDefinitionGuid)
    roleAssignmentNameSeed: guid(
      containerRegistry.outputs.id,
      userAssignedManagedIdentity.outputs.principalId,
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
      principalId: existingUamis[pair.uamiIndex].properties.principalId
      roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', pair.roleDefinitionGuid)
      roleAssignmentNameSeed: guid(
        containerApp.outputs.id,
        existingUamis[pair.uamiIndex].properties.principalId,
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

@description('The resource ID of the created resource group')
output resourceGroupId string = resourceGroup.outputs.id

@description('The name of the created resource group')
output resourceGroupName string = resourceGroup.outputs.name

@description('The resource ID of the created Azure Container Registry')
output containerRegistryId string = containerRegistry.outputs.id

@description('The login server of the created Azure Container Registry')
output containerRegistryLoginServer string = containerRegistry.outputs.loginServer

@description('The resource ID of the created User Assigned Managed Identity')
output userAssignedIdentityId string = userAssignedManagedIdentity.outputs.id

@description('The principal ID of the created User Assigned Managed Identity')
output userAssignedIdentityPrincipalId string = userAssignedManagedIdentity.outputs.principalId

@description('The client ID of the created User Assigned Managed Identity')
output userAssignedIdentityClientId string = userAssignedManagedIdentity.outputs.clientId

@description('The resource ID of the created Log Analytics workspace')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspaceModule.outputs.id

@description('The resource ID of the created Container Apps Environment')
output containerAppEnvironmentId string = containerAppEnvironment.outputs.id

@description('The resource ID of the created Container App')
output containerAppId string = containerApp.outputs.id

@description('The name of the created Container App')
output containerAppName string = containerApp.outputs.name

@description('The fully qualified domain name (FQDN) of the created Container App')
output containerAppFqdn string = containerApp.outputs.fqdn

@description('The HTTPS URL of the created Container App')
output containerAppUrl string = empty(containerApp.outputs.fqdn) ? '' : 'https://${containerApp.outputs.fqdn}'

@description('The resource ID of the AcrPull role assignment granted to the created UAMI')
output acrPullRoleAssignmentId string = acrPullRoleAssignment.outputs.id

@description('The resource IDs of role assignments granted to every existing User Assigned Managed Identity at Container App scope')
output uamiRoleAssignmentIds string[] = [for (pair, i) in uamiRolePairs: uamiRoleAssignments[i].outputs.id]

@description('The resource IDs of role assignments granted to every existing service principal at Container App scope')
output servicePrincipalRoleAssignmentIds string[] = [
  for (pair, i) in servicePrincipalRolePairs: servicePrincipalRoleAssignments[i].outputs.id
]

@description('The resource IDs of role assignments granted to every existing user at Container App scope')
output userRoleAssignmentIds string[] = [for (pair, i) in userRolePairs: userRoleAssignments[i].outputs.id]
