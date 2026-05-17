targetScope = 'subscription'

// ------------------
//    PARAMETERS
// ------------------

@description('The name of the scenario, used to derive resource names')
@minLength(1)
@maxLength(64)
param name string

@description('The location for the resource group and PostgreSQL Flexible Server resources')
param location string

@description('Tags applied to all resources')
param tags object = {
  scenario: name
  managedBy: 'bicep'
}

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
param version string = '18'

@description('The compute SKU name for the flexible server')
param skuName string = 'Standard_B1ms'

@description('The SKU tier for the flexible server')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param skuTier string = 'Burstable'

@description('Storage size in GB for the flexible server')
param storageSizeGB int = 32

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

@description('Enable Azure Monitor based observability resources (Log Analytics workspace and diagnostic settings).')
param enableObservability bool = false

// ------------------
//    VARIABLES
// ------------------

var resourceGroupName = 'rg-templatebicep-${name}'
var postgresServerName = take(toLower(replace('psql-${name}', '_', '-')), 63)
var logAnalyticsWorkspaceName = take(toLower(replace('law-${name}', '_', '-')), 63)
var postgresDiagnosticSettingsName = take('diag-${postgresServerName}', 256)

// Resolve the effective Microsoft Entra administrator.
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

module postgresServer '../../modules/postgresql_flexible_server/main.bicep' = {
  name: take('${name}-psql-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: postgresServerName
    location: location
    tags: tags
    version: version
    skuName: skuName
    skuTier: skuTier
    storageSizeGB: storageSizeGB
    entraAdministrator: effectiveEntraAdministrator
    firewallRules: firewallRules
    databases: databases
    enablePgvector: enablePgvector
  }
  dependsOn: [resourceGroup]
}

module logAnalyticsWorkspace '../../modules/log_analytics_workspace/main.bicep' = if (enableObservability) {
  name: take('${name}-law-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: logAnalyticsWorkspaceName
    location: location
    tags: tags
  }
  dependsOn: [resourceGroup]
}

module postgresDiagnosticSettings '../../modules/diagnostic_settings/main.bicep' = if (enableObservability) {
  name: take('${name}-psql-diag-deployment', 64)
  scope: az.resourceGroup(resourceGroupName)
  params: {
    name: postgresDiagnosticSettingsName
    workspaceResourceId: logAnalyticsWorkspace.?outputs.id ?? ''
    targetKind: 'PostgreSqlFlexibleServer'
    targetName: postgresServerName
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

@description('The resource ID of the created PostgreSQL Flexible Server')
output postgresServerId string = postgresServer.outputs.id

@description('The name of the created PostgreSQL Flexible Server')
output postgresServerName string = postgresServer.outputs.name

@description('The fully qualified domain name (FQDN) of the created PostgreSQL Flexible Server')
output postgresServerFqdn string = postgresServer.outputs.fullyQualifiedDomainName

@description('The names of databases created on the flexible server')
output databaseNames array = postgresServer.outputs.databaseNames

@description('The resource ID of the created Log Analytics workspace (empty when observability is disabled)')
output logAnalyticsWorkspaceId string = logAnalyticsWorkspace.?outputs.id ?? ''
