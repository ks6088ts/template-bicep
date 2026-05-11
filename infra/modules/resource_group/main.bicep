targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the resource group')
@minLength(1)
@maxLength(90)
param name string

@description('The Azure region where the resource group will be created')
param location string

@description('Tags applied to the resource group')
param tags object = {}

// ------------------
//    RESOURCES
// ------------------

resource resourceGroup 'Microsoft.Resources/resourceGroups@2025-04-01' = {
  name: name
  location: location
  tags: tags
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the resource group')
output id string = resourceGroup.id

@description('The name of the resource group')
output name string = resourceGroup.name

@description('The location of the resource group')
output location string = resourceGroup.location
