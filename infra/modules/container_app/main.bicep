// ------------------
//    PARAMETERS
// ------------------

@description('The name of the Azure Container App.')
@maxLength(32)
param name string

@description('The Azure region where the Azure Container App will be created.')
param location string

@description('Tags applied to the Azure Container App.')
param tags object = {}

@description('The resource ID of the Azure Container Apps Environment used by this app.')
param environmentId string

@description('Resource IDs of User Assigned Managed Identities attached to the Azure Container App.')
param userAssignedIdentityResourceIds string[] = []

@description('Enable System Assigned Managed Identity on the Azure Container App.')
param enableSystemAssignedIdentity bool = true

@description('Container image to run.')
param containerImage string = 'nginx:latest'

@description('Container name inside template.containers.')
param containerName string = 'app'

@description('Optional startup command override for the container.')
param containerCommand string[] = []

@description('Optional startup argument override for the container.')
param containerArgs string[] = []

@description('Container environment variables. Each element supports { name, value } or { name, secretRef }.')
param containerEnv array = []

@description('Container CPU allocation as string (for example, 0.5).')
param cpu string = '0.5'

@description('Container memory allocation (for example, 1Gi).')
param memory string = '1Gi'

@description('Minimum replica count.')
@minValue(0)
param minReplicas int = 0

@description('Maximum replica count.')
@minValue(1)
param maxReplicas int = 3

@description('Ingress target port exposed by the container.')
@minValue(1)
@maxValue(65535)
param targetPort int = 80

@description('Enable external ingress for the Azure Container App.')
param ingressExternal bool = true

@description('Ingress transport protocol.')
@allowed([
  'auto'
  'http'
  'http2'
  'tcp'
])
param transport string = 'auto'

@description('Registry connections. Each element: { server, identity }. identity should be a UAMI resource ID.')
param registries array = []

@description('Secret definitions for the Azure Container App configuration.')
param secrets array = []

@description('Enable Easy Auth (built-in authentication) for the Azure Container App.')
param enableEasyAuth bool = false

@description('When Easy Auth is enabled, require authentication by redirecting unauthenticated users to login page.')
param easyAuthRequireAuthentication bool = true

@description('Entra ID App Registration client ID used by Easy Auth (required when enableEasyAuth = true).')
param easyAuthEntraClientId string = ''

@description('OpenID issuer for Entra ID. If empty, defaults to login endpoint + tenantId.')
param easyAuthEntraOpenIdIssuer string = ''

@description('Allowed audiences for Easy Auth token validation.')
param easyAuthAllowedAudiences string[] = []

// ------------------
//    VARIABLES
// ------------------

var userAssignedIdentities = reduce(
  userAssignedIdentityResourceIds,
  {},
  (acc, id) =>
    union(acc, {
      '${id}': {}
    })
)

var identityType = enableSystemAssignedIdentity && !empty(userAssignedIdentityResourceIds)
  ? 'SystemAssigned,UserAssigned'
  : !enableSystemAssignedIdentity && !empty(userAssignedIdentityResourceIds)
      ? 'UserAssigned'
      : enableSystemAssignedIdentity ? 'SystemAssigned' : 'None'

var easyAuthOpenIdIssuer = empty(easyAuthEntraOpenIdIssuer)
  ? '${environment().authentication.loginEndpoint}${subscription().tenantId}/v2.0'
  : easyAuthEntraOpenIdIssuer

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
        userAssignedIdentities: contains(identityType, 'UserAssigned') ? userAssignedIdentities : null
      }
  properties: {
    managedEnvironmentId: environmentId
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
          openIdIssuer: easyAuthOpenIdIssuer
        }
        validation: empty(easyAuthAllowedAudiences)
          ? null
          : {
              allowedAudiences: easyAuthAllowedAudiences
            }
      }
    }
  }
}

// ------------------
//    OUTPUTS
// ------------------

@description('The resource ID of the Azure Container App.')
output id string = containerApp.id

@description('The name of the Azure Container App.')
output name string = containerApp.name

@description('The FQDN of the Azure Container App ingress endpoint (empty when ingress is disabled).')
output fqdn string = containerApp.properties.configuration.ingress.?fqdn ?? ''

@description('The latest revision name of the Azure Container App.')
output latestRevisionName string = containerApp.properties.latestRevisionName

@description('The principal ID of the System Assigned Managed Identity (empty when not enabled).')
output systemAssignedPrincipalId string = containerApp.identity.?principalId ?? ''
