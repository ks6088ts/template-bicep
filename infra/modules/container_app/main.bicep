// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Container App')
@minLength(1)
@maxLength(32)
param name string

@description('The Azure region where the Container App will be created')
param location string

@description('Tags applied to the Container App')
param tags object = {}

@description('The resource ID of the Container Apps Environment')
@minLength(1)
param environmentId string

@description('Array of User Assigned Managed Identity resource IDs attached to the Container App')
param userAssignedIdentityResourceIds string[] = []

@description('When true, enables system-assigned managed identity for the Container App')
param enableSystemAssignedIdentity bool = true

@description('The container image for the Container App')
param containerImage string = 'nginx:latest'

@description('The container name inside the Container App template')
param containerName string = 'app'

@description('Optional command override for the container')
param containerCommand string[] = []

@description('Optional arguments override for the container')
param containerArgs string[] = []

@description('Environment variables for the container. Each item supports { name, value } or { name, secretRef }.')
param containerEnv array = []

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

@description('Ingress transport protocol')
@allowed([
  'auto'
  'http'
  'http2'
  'tcp'
])
param transport string = 'auto'

@description('Container registry settings. Each element supports { server, identity }.')
param registries array = []

@description('Container App secrets. Each element supports { name, value } or key-vault references.')
param secrets array = []

@description('When true, configures Easy Auth with Microsoft Entra ID provider')
param enableEasyAuth bool = false

@description('When true and Easy Auth is enabled, unauthenticated users are redirected to login page')
param easyAuthRequireAuthentication bool = true

@description('Client ID of the Microsoft Entra app registration used by Easy Auth')
param easyAuthEntraClientId string = ''

@description('OpenID issuer URL for Microsoft Entra ID. When empty, uses the current tenant issuer URL.')
param easyAuthEntraOpenIdIssuer string = ''

@description('Allowed audiences for Easy Auth token validation')
param easyAuthAllowedAudiences string[] = []

// ------------------
//    VARIABLES
// ------------------

var hasUserAssignedIdentity = length(userAssignedIdentityResourceIds) > 0
var identityType = hasUserAssignedIdentity
  ? (enableSystemAssignedIdentity ? 'SystemAssigned,UserAssigned' : 'UserAssigned')
  : 'SystemAssigned'
var userAssignedIdentitiesObject = reduce(
  userAssignedIdentityResourceIds,
  {},
  (acc, userAssignedIdentityResourceId) => union(acc, {
    '${userAssignedIdentityResourceId}': {}
  })
)
var effectiveOpenIdIssuer = empty(easyAuthEntraOpenIdIssuer)
  ? '${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'
  : easyAuthEntraOpenIdIssuer

// ------------------
//    RESOURCES
// ------------------

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      ingress: {
        external: ingressExternal
        targetPort: targetPort
        transport: transport
      }
      registries: registries
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          command: containerCommand
          args: containerArgs
          env: containerEnv
          resources: {
            cpu: json(cpu)
            memory: memory
          }
        }
      ]
      scale: {
        minReplicas: minReplicas
        maxReplicas: maxReplicas
      }
    }
  }
  identity: {
    type: identityType
    userAssignedIdentities: hasUserAssignedIdentity ? userAssignedIdentitiesObject : null
  }
}

resource containerAppAuthConfig 'Microsoft.App/containerApps/authConfigs@2024-03-01' = if (enableEasyAuth) {
  name: 'current'
  parent: containerApp
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: easyAuthRequireAuthentication ? 'RedirectToLoginPage' : 'AllowAnonymous'
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: easyAuthEntraClientId
          openIdIssuer: effectiveOpenIdIssuer
        }
        validation: {
          allowedAudiences: easyAuthAllowedAudiences
        }
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Container App')
output id string = containerApp.id

@description('The name of the Container App')
output name string = containerApp.name

@description('The fully qualified domain name (FQDN) of the Container App ingress')
output fqdn string = containerApp.properties.configuration.ingress.?fqdn ?? ''

@description('The latest revision name of the Container App')
output latestRevisionName string = containerApp.properties.latestRevisionName

@description('The system-assigned managed identity principal ID of the Container App (empty when system-assigned identity is disabled)')
output systemAssignedPrincipalId string = containerApp.identity.?principalId ?? ''
