// ------------------
//    PARAMETERS
// ------------------

@description('The name of the User Assigned Managed Identity')
@minLength(3)
@maxLength(128)
param name string

@description('The Azure region where the User Assigned Managed Identity will be created')
param location string

@description('Tags applied to the User Assigned Managed Identity')
param tags object = {}

// ------------------
//    RESOURCES
// ------------------

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2024-11-30' = {
  name: name
  location: location
  tags: tags
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the User Assigned Managed Identity')
output id string = uami.id

@description('The name of the User Assigned Managed Identity')
output name string = uami.name

@description('The principal ID of the User Assigned Managed Identity (used for role assignments)')
output principalId string = uami.properties.principalId

@description('The client ID of the User Assigned Managed Identity')
output clientId string = uami.properties.clientId

@description('The tenant ID of the User Assigned Managed Identity')
output tenantId string = uami.properties.tenantId
