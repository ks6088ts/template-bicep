// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Database for PostgreSQL Flexible Server')
@maxLength(63)
param name string

@description('The Azure region where the PostgreSQL Flexible Server will be created')
param location string

@description('Tags applied to the PostgreSQL Flexible Server')
param tags object = {}

@description('PostgreSQL major version. Defaults to 18 to match the pgvector/pgvector:pg18 reference image.')
param version string = '18'

@description('The compute SKU name for the flexible server')
param skuName string = 'Standard_B1ms'

@description('The SKU tier for the flexible server')
@allowed(['Burstable', 'GeneralPurpose', 'MemoryOptimized'])
param skuTier string = 'Burstable'

@description('Storage size in GB for the flexible server')
param storageSizeGB int = 32

@description('Microsoft Entra ID administrator configuration')
param entraAdministrator {
  @description('The object ID (principal ID) of the Entra principal')
  objectId: string

  @description('The display name or UPN of the Entra principal')
  principalName: string

  @description('The type of the Entra principal')
  principalType: ('User' | 'Group' | 'ServicePrincipal')

  @description('The tenant ID for the Entra administrator')
  tenantId: string
}

@description('Firewall rules to create on the flexible server. Each element: { name, startIpAddress, endIpAddress }')
param firewallRules array = []

@description('Databases to create on the flexible server. Each element: { name, charset?, collation? }')
param databases array = []

@description('When true, enables the pgvector extension by setting azure.extensions configuration to VECTOR')
param enablePgvector bool = true

// ------------------
//    RESOURCES
// ------------------

resource postgresServer 'Microsoft.DBforPostgreSQL/flexibleServers@2025-08-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: skuName
    tier: skuTier
  }
  properties: {
    version: version
    authConfig: {
      activeDirectoryAuth: 'Enabled'
      passwordAuth: 'Disabled'
      tenantId: entraAdministrator.tenantId
    }
    storage: {
      storageSizeGB: storageSizeGB
    }
    network: {
      publicNetworkAccess: 'Enabled'
    }
    // TODO: highAvailability and backup properties are intentionally omitted here;
    //       add parameters and configure them for production workloads.
  }
}

// NOTE: The Entra administrator must be registered while the server is in an
//       accessible (Ready) state. Other child resources (firewall rules,
//       databases, configurations) all transition the server to an "Updating"
//       state and, if executed in parallel, cause the administrator operation
//       to fail with `AadAuthOperationCannotBePerformedWhenServerIsNotAccessible`.
//       The dependencies below serialize the child operations so the Entra
//       administrator is created first, and all other operations follow.
resource entraAdmin 'Microsoft.DBforPostgreSQL/flexibleServers/administrators@2025-08-01' = {
  parent: postgresServer
  name: entraAdministrator.objectId
  properties: {
    principalType: entraAdministrator.principalType
    principalName: entraAdministrator.principalName
    tenantId: entraAdministrator.tenantId
  }
}

resource firewallRuleResources 'Microsoft.DBforPostgreSQL/flexibleServers/firewallRules@2025-08-01' = [
  for rule in firewallRules: {
    parent: postgresServer
    name: rule.name
    properties: {
      startIpAddress: rule.startIpAddress
      endIpAddress: rule.endIpAddress
    }
    dependsOn: [entraAdmin]
  }
]

resource databaseResources 'Microsoft.DBforPostgreSQL/flexibleServers/databases@2025-08-01' = [
  for db in databases: {
    parent: postgresServer
    name: db.name
    properties: {
      charset: db.?charset ?? 'UTF8'
      collation: db.?collation ?? 'en_US.utf8'
    }
    dependsOn: [entraAdmin, firewallRuleResources]
  }
]

resource pgvectorConfig 'Microsoft.DBforPostgreSQL/flexibleServers/configurations@2025-08-01' = if (enablePgvector) {
  parent: postgresServer
  name: 'azure.extensions'
  properties: {
    value: 'VECTOR'
    source: 'user-override'
  }
  dependsOn: [entraAdmin, firewallRuleResources, databaseResources]
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the PostgreSQL Flexible Server')
output id string = postgresServer.id

@description('The name of the PostgreSQL Flexible Server')
output name string = postgresServer.name

@description('The fully qualified domain name (FQDN) of the PostgreSQL Flexible Server')
output fullyQualifiedDomainName string = postgresServer.properties.fullyQualifiedDomainName

@description('The names of databases created on the flexible server')
output databaseNames array = [for (db, i) in databases: databaseResources[i].name]

@description('The resource IDs of firewall rules created on the flexible server')
output firewallRuleIds array = [for (rule, i) in firewallRules: firewallRuleResources[i].id]
