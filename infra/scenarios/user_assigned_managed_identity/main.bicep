targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and User Assigned Managed Identities')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

@description('A single User Assigned Managed Identity (UAMI) to create in the shared resource group.')
type userAssignedIdentitySpec = {
  @description('The full name of the User Assigned Managed Identity (must satisfy the underlying module name constraints: 3-128 chars).')
  name: string
}

@description('Array of User Assigned Managed Identities to create in the shared resource group `rg-templatebicep-{name}`. Names must be unique within the array.')
param userAssignedIdentities userAssignedIdentitySpec[]

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-templatebicep-${name}'

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

module uami '../../modules/user_assigned_managed_identity/main.bicep' = [
  for (identity, i) in userAssignedIdentities: {
    name: take('${name}-uami-${i}-deployment', 64)
    scope: az.resourceGroup(resourceGroupName)
    params: {
      name: identity.name
      location: location
      tags: tags
    }
    dependsOn: [resourceGroup]
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

@description('Array of created User Assigned Managed Identities (same order as the `userAssignedIdentities` input parameter).')
output userAssignedIdentities array = [
  for (identity, i) in userAssignedIdentities: {
    id: uami[i].outputs.id
    name: uami[i].outputs.name
    principalId: uami[i].outputs.principalId
    clientId: uami[i].outputs.clientId
    tenantId: uami[i].outputs.tenantId
  }
]
