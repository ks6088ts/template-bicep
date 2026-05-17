using 'main.bicep'

param name = 'templatebicepca'
param location = 'japaneast'
param tags = {
  environment: 'dev'
  owner: 'ks6088ts'
  SecurityControl: 'Ignore'
  CostControl: 'Ignore'
}

// --- Container settings (override as needed) ---
// param containerImage = 'nginx:latest'
// param containerCommand = []
// param containerArgs = []
// param cpu = '0.5'
// param memory = '1Gi'
// param minReplicas = 0
// param maxReplicas = 3
// param targetPort = 80
// param ingressExternal = true

// --- Easy Auth (Entra ID) ---
// param enableEasyAuth = true
// param easyAuthRequireAuthentication = true
// param easyAuthEntraClientId = '00000000-0000-0000-0000-000000000000'
// param easyAuthAllowedAudiences = [
//   'api://00000000-0000-0000-0000-000000000000'
// ]

// --- Optional RBAC at Container App scope ---
// param existingUserAssignedIdentities = []
// param existingServicePrincipalObjectIds = []
// param existingUserObjectIds = []
// param roleDefinitionIds = []

