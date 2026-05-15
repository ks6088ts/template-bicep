using 'main.bicep'

param name = 'userassignedmanagedidentity'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}
param userAssignedIdentities = [
  {
    name: 'id-userassignedmanagedidentity-app'
  }
  {
    name: 'id-userassignedmanagedidentity-worker'
  }
]
