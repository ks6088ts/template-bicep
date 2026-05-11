targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and User Assigned Managed Identity')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-${name}'
var userAssignedIdentityName = 'id-${name}'

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

module userAssignedManagedIdentity '../../modules/user_assigned_managed_identity/main.bicep' = {
  name: take('${name}-uami-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: userAssignedIdentityName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
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

@description('The resource ID of the created User Assigned Managed Identity')
output userAssignedIdentityId string = userAssignedManagedIdentity.outputs.id

@description('The name of the created User Assigned Managed Identity')
output userAssignedIdentityName string = userAssignedManagedIdentity.outputs.name

@description('The principal ID of the created User Assigned Managed Identity')
output userAssignedIdentityPrincipalId string = userAssignedManagedIdentity.outputs.principalId

@description('The client ID of the created User Assigned Managed Identity')
output userAssignedIdentityClientId string = userAssignedManagedIdentity.outputs.clientId

@description('The tenant ID of the created User Assigned Managed Identity')
output userAssignedIdentityTenantId string = userAssignedManagedIdentity.outputs.tenantId
