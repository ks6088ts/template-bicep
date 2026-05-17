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

@description('The resource ID of the target Container Apps environment')
@minLength(1)
param environmentId string

@description('Optional. Resource IDs of User Assigned Managed Identities (UAMI) to attach. Defaults to empty array.')
param userAssignedIdentityResourceIds string[] = []

@description('When true, enables System Assigned Managed Identity')
param enableSystemAssignedIdentity bool = true

@description('Container image to run')
param containerImage string = 'nginx:latest'

@description('Container name within the app')
param containerName string = 'app'

@description('Optional. Override container command')
param containerCommand string[] = []

@description('Optional. Override container args')
param containerArgs string[] = []

@description('Container environment variables. Each element is `{ name, value }` or `{ name, secretRef }`.')
param containerEnv array = []

@description('CPU allocation (vCPU). Example: 0.5')
param cpu string = '0.5'

@description('Memory allocation. Example: 1Gi')
param memory string = '1Gi'

@description('Minimum replicas')
param minReplicas int = 0

@description('Maximum replicas')
param maxReplicas int = 3

@description('Ingress target port')
param targetPort int = 80

@description('When true, enables external HTTPS ingress')
param ingressExternal bool = true

@description('Ingress transport protocol')
@allowed([
  'auto'
  'http'
  'http2'
  'tcp'
])
param transport string = 'auto'

@description('Registries configuration. Each element is `{ server, identity }` where `identity` is a UAMI resource ID used for Entra ID-based pulls.')
param registries array = []

@description('Secrets configuration for the Container App')
param secrets array = []

@description('When true, enables Easy Auth (built-in authentication) with Microsoft Entra ID')
param enableEasyAuth bool = false

@description('When Easy Auth is enabled, require authentication (redirect unauthenticated clients to login)')
param easyAuthRequireAuthentication bool = true

@description('Client ID of the Entra ID app registration (required when Easy Auth is enabled)')
param easyAuthEntraClientId string = ''

@description('OpenID issuer URL. When empty, derives `https://login.microsoftonline.com/<tenantId>/v2.0`.')
param easyAuthEntraOpenIdIssuer string = ''

@description('Allowed audiences for Easy Auth token validation')
param easyAuthAllowedAudiences string[] = []

// ------------------
//    VARIABLES
// ------------------

var userAssignedIdentitiesObject = reduce(
  userAssignedIdentityResourceIds,
  {},
  (current, id) =>
    union(current, {
      '${id}': {}
    })
)

var identityType = enableSystemAssignedIdentity
  ? (length(userAssignedIdentityResourceIds) > 0 ? 'SystemAssigned, UserAssigned' : 'SystemAssigned')
  : (length(userAssignedIdentityResourceIds) > 0 ? 'UserAssigned' : 'None')

var easyAuthOpenIdIssuerResolved = empty(easyAuthEntraOpenIdIssuer)
  ? '${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'
  : easyAuthEntraOpenIdIssuer

var unauthenticatedClientAction = easyAuthRequireAuthentication ? 'RedirectToLoginPage' : 'AllowAnonymous'

// ------------------
//    RESOURCES
// ------------------

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: identityType == 'None'
    ? null
    : {
        type: identityType
        userAssignedIdentities: length(userAssignedIdentityResourceIds) > 0 ? userAssignedIdentitiesObject : null
      }
  properties: {
    managedEnvironmentId: environmentId
    configuration: {
      activeRevisionsMode: 'Single'
      secrets: secrets
      registries: registries
      ingress: {
        external: ingressExternal
        targetPort: targetPort
        transport: transport
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
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
}

resource authConfig 'Microsoft.App/containerApps/authConfigs@2024-03-01' = if (enableEasyAuth) {
  name: 'current'
  parent: containerApp
  properties: {
    platform: {
      enabled: true
    }
    globalValidation: {
      unauthenticatedClientAction: unauthenticatedClientAction
      redirectToProvider: 'azureactivedirectory'
    }
    identityProviders: {
      azureActiveDirectory: {
        enabled: true
        registration: {
          clientId: easyAuthEntraClientId
          openIdIssuer: easyAuthOpenIdIssuerResolved
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

@description('The fully qualified domain name (FQDN) of the Container App')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The latest revision name of the Container App')
output latestRevisionName string = containerApp.properties.latestRevisionName

@description('The system-assigned managed identity principal ID (empty when disabled)')
output systemAssignedPrincipalId string = containerApp.identity.?principalId ?? ''
