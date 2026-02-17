targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario')
param name string

@description('The location for the resource group')
param location string

// ------------------
//    VARIABLES
// ------------------

var randomName string = '${name}-${uniqueString(subscription().id, location, name)}'

// ------------------
//    RESOURCES
// ------------------

// ------------------
//    OUTPUTS
// ------------------

output randomName string = randomName
