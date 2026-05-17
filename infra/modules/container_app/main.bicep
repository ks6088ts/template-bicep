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

@description('User Assigned Managed Identity resource IDs to attach to the Container App')
param userAssignedIdentityResourceIds string[] = []

@description('Enable system-assigned managed identity for the Container App')
param enableSystemAssignedIdentity bool = true

@description('Container image to use')
param containerImage string = 'nginx:latest'

@description('Container name')
param containerName string = 'app'

@description('Container command override')
param containerCommand string[] = []

@description('Container args override')
param containerArgs string[] = []

@description('Container environment variables. Format: [{ name, value }] or [{ name, secretRef }]')
param containerEnv array = []

@description('CPU allocation for the container')
param cpu string = '0.5'

@description('Memory allocation for the container')
param memory string = '1Gi'

@description('Minimum number of replicas')
param minReplicas int = 0

@description('Maximum number of replicas')
param maxReplicas int = 3

@description('Target port for ingress')
param targetPort int = 80

@description('Enable external ingress (public HTTPS endpoint)')
param ingressExternal bool = true

@description('Transport protocol for ingress')
@allowed([
  'auto'
  'http'
  'http2'
  'tcp'
])
param transport string = 'auto'

@description('Registry configurations. Format: [{ server, identity }]')
param registries array = []

@description('Secret configurations. Format: [{ name, value }]')
param secrets array = []

@description('Enable Easy Auth (built-in authentication) for the Container App')
param enableEasyAuth bool = false

@description('Require authentication when Easy Auth is enabled (redirect unauthenticated users)')
param easyAuthRequireAuthentication bool = true

@description('Entra ID App Registration client ID for Easy Auth')
param easyAuthEntraClientId string = ''

@description('Entra ID OpenID issuer URL for Easy Auth (defaults to tenant v2.0 endpoint)')
param easyAuthEntraOpenIdIssuer string = ''

@description('Allowed audiences for Entra ID authentication')
param easyAuthAllowedAudiences string[] = []

// ------------------
//    VARIABLES
// ------------------

var hasUserAssignedIdentities = length(userAssignedIdentityResourceIds) > 0

var identityConfig = hasUserAssignedIdentities && enableSystemAssignedIdentity
  ? {
      type: 'SystemAssigned,UserAssigned'
      userAssignedIdentities: reduce(
        userAssignedIdentityResourceIds,
        {},
        (acc, id) => union(acc, { '${id}': {} })
      )
    }
  : hasUserAssignedIdentities
      ? {
          type: 'UserAssigned'
          userAssignedIdentities: reduce(
            userAssignedIdentityResourceIds,
            {},
            (acc, id) => union(acc, { '${id}': {} })
          )
        }
      : enableSystemAssignedIdentity
          ? {
              type: 'SystemAssigned'
            }
          : {
              type: 'None'
            }

var effectiveEasyAuthIssuer = !empty(easyAuthEntraOpenIdIssuer)
  ? easyAuthEntraOpenIdIssuer
  : 'https://${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'

// ------------------
//    RESOURCES
// ------------------

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: name
  location: location
  tags: tags
  identity: identityConfig
  properties: {
    environmentId: environmentId
    configuration: {
      ingress: {
        external: ingressExternal
        targetPort: targetPort
        transport: transport
        allowInsecure: false
      }
      registries: registries
      secrets: secrets
    }
    template: {
      containers: [
        {
          name: containerName
          image: containerImage
          command: empty(containerCommand) ? null : containerCommand
          args: empty(containerArgs) ? null : containerArgs
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
  parent: containerApp
  name: 'current'
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
          openIdIssuer: effectiveEasyAuthIssuer
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

@description('The FQDN of the Container App')
output fqdn string = containerApp.properties.configuration.ingress.fqdn

@description('The name of the latest revision')
output latestRevisionName string = containerApp.properties.latestRevisionName

@description('The system-assigned managed identity principal ID (empty if system-assigned identity is not enabled)')
output systemAssignedPrincipalId string = enableSystemAssignedIdentity
  ? containerApp.identity.principalId
  : ''
