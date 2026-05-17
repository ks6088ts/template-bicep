---
title: Container Apps Scenario
description: A Bicep scenario that provisions Azure Container Apps with a dedicated UAMI, ACR (Entra ID auth, admin disabled), Log Analytics-backed environment, external HTTPS ingress, and optional Easy Auth (Entra ID)
ms.date: 2026-05-17
---

# Container Apps Scenario

A Bicep scenario that provisions a minimal Azure Container Apps workload with:

* Azure Container Registry (ACR) with Entra ID authentication and admin user disabled (keyless)
* Container Apps Environment backed by Log Analytics
* Container App with external HTTPS ingress (default: nginx)
* User Assigned Managed Identity (UAMI) for ACR pull access
* Optional Easy Auth (built-in Entra ID authentication) for the Container App endpoint

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace (always created for Container Apps Environment).
3. [`container_registry` module](../../modules/container_registry/main.bicep) — creates an Azure Container Registry with admin user disabled.
4. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates a UAMI for the Container App to pull images from ACR.
5. [`container_app_environment` module](../../modules/container_app_environment/main.bicep) — creates a Container Apps Environment connected to Log Analytics.
6. [`container_app` module](../../modules/container_app/main.bicep) — creates the Container App with the specified image, ingress, and optional Easy Auth.
7. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants AcrPull to the created UAMI and optionally grants roles at Container App scope.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Creating all necessary infrastructure (RG, Log Analytics, ACR, UAMI, Environment, Container App).
* Granting AcrPull role to the UAMI at ACR scope (required for Entra ID authentication).
* Optionally attaching existing UAMIs and granting RBAC roles at Container App scope.
* Optionally enabling Easy Auth (Entra ID) for the Container App endpoint.
* Surfacing module outputs to deployment consumers.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for all resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `containerImage` | `string` | `'nginx:latest'` | Container image to use for the Container App. |
| `containerCommand` | `string[]` | `[]` | Container command override. |
| `containerArgs` | `string[]` | `[]` | Container args override. |
| `cpu` | `string` | `'0.5'` | CPU allocation for the container. |
| `memory` | `string` | `'1Gi'` | Memory allocation for the container. |
| `minReplicas` | `int` | `0` | Minimum number of replicas (0 allows scale to zero). |
| `maxReplicas` | `int` | `3` | Maximum number of replicas. |
| `targetPort` | `int` | `80` | Target port for ingress (nginx default). |
| `ingressExternal` | `bool` | `true` | Enable external ingress (public HTTPS endpoint). |
| `acrSkuName` | `string` | `'Basic'` | ACR SKU (`Basic`, `Standard`, `Premium`). |
| `enableEasyAuth` | `bool` | `false` | Enable Easy Auth (built-in Entra ID authentication) for the Container App endpoint. |
| `easyAuthRequireAuthentication` | `bool` | `true` | Require authentication when Easy Auth is enabled (redirect unauthenticated users). |
| `easyAuthEntraClientId` | `string` | `''` | Entra ID App Registration client ID for Easy Auth (required when `enableEasyAuth = true`). |
| `easyAuthAllowedAudiences` | `string[]` | `[]` | Allowed audiences for Entra ID authentication. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to attach to the Container App and grant roles to. Each element: `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Optional. Entra service principal object IDs to grant roles to at Container App scope. |
| `existingUserObjectIds` | `string[]` | `[]` | Optional. Entra user object IDs to grant roles to at Container App scope. |
| `roleDefinitionIds` | `string[]` | `[]` | Role definition GUIDs to grant to every principal at Container App scope (defaults to empty, no additional roles). |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `containerRegistryId` | `string` | Resource ID of the Azure Container Registry. |
| `containerRegistryLoginServer` | `string` | Login server URL of the Azure Container Registry. |
| `userAssignedIdentityId` | `string` | Resource ID of the created User Assigned Managed Identity. |
| `userAssignedIdentityPrincipalId` | `string` | Principal ID of the created UAMI. |
| `userAssignedIdentityClientId` | `string` | Client ID of the created UAMI. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the Log Analytics workspace. |
| `containerAppEnvironmentId` | `string` | Resource ID of the Container Apps Environment. |
| `containerAppId` | `string` | Resource ID of the Container App. |
| `containerAppName` | `string` | Name of the Container App. |
| `containerAppFqdn` | `string` | FQDN of the Container App (`*.<region>.azurecontainerapps.io`). |
| `containerAppUrl` | `string` | HTTPS URL of the Container App (`https://<fqdn>`). |
| `acrPullRoleAssignmentId` | `string` | Resource ID of the AcrPull role assignment for the created UAMI. |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs for existing UAMIs at Container App scope. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs for service principals at Container App scope. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs for users at Container App scope. |

## Usage

Deploy with the bundled `bicepparam` file:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Or with the repository `Makefile`:

```bash
make deploy SCENARIO=container_apps
```

## Architecture

```text
infra/
├── modules/
│   ├── container_app/
│   │   └── main.bicep                         # Reusable Container App module
│   ├── container_app_environment/
│   │   └── main.bicep                         # Reusable Container Apps Environment module
│   ├── container_registry/
│   │   └── main.bicep                         # Reusable Azure Container Registry module
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics Workspace module
│   ├── resource_group/
│   │   └── main.bicep                         # Reusable resource group module
│   ├── role_assignment/
│   │   └── main.bicep                         # Reusable role assignment module (extended for ACR and Container App)
│   └── user_assigned_managed_identity/
│       └── main.bicep                         # Reusable UAMI module
└── scenarios/
    └── container_apps/
        ├── main.bicep                         # Scenario entry point (this scenario)
        ├── main.bicepparam                    # Parameter file
        ├── main.json                          # Compiled ARM template
        └── README.md                          # This file
```

The scenario creates a resource group, then provisions:

1. Log Analytics workspace (required for Container Apps Environment)
2. Azure Container Registry with admin user disabled
3. User Assigned Managed Identity
4. AcrPull role assignment for the UAMI at ACR scope
5. Container Apps Environment connected to Log Analytics
6. Container App with external HTTPS ingress

## Verifying the Deployment

After deployment completes, verify the Container App is accessible:

```bash
# Get the Container App FQDN
FQDN=$(az deployment sub show \
  --name container_apps_deployment \
  --query properties.outputs.containerAppFqdn.value -o tsv)

# Verify nginx is accessible (default image)
curl https://$FQDN
```

You should see the nginx welcome page HTML.

## Easy Auth (Entra ID Authentication)

To enable Easy Auth (built-in Entra ID authentication) for the Container App endpoint, you must first create an Entra ID App Registration.

### Prerequisites

1. Create an Entra ID App Registration:

```bash
# Create the app registration
APP_NAME="container-app-auth"
APP_ID=$(az ad app create \
  --display-name $APP_NAME \
  --query appId -o tsv)

echo "Created App Registration with Client ID: $APP_ID"

# Create a service principal for the app
az ad sp create --id $APP_ID
```

2. After deploying the Container App, get the FQDN and configure the redirect URI:

```bash
# Get the Container App FQDN
FQDN=$(az deployment sub show \
  --name container_apps_deployment \
  --query properties.outputs.containerAppFqdn.value -o tsv)

# Add the redirect URI to the app registration
az ad app update \
  --id $APP_ID \
  --web-redirect-uris "https://${FQDN}/.auth/login/aad/callback"
```

### Enable Easy Auth

Update `main.bicepparam` to enable Easy Auth:

```bicep
param enableEasyAuth = true
param easyAuthRequireAuthentication = true
param easyAuthEntraClientId = '<your-app-registration-client-id>'
param easyAuthAllowedAudiences = [ 'api://<your-app-registration-client-id>' ]
```

Then redeploy:

```bash
make deploy SCENARIO=container_apps
```

### Verify Easy Auth

After redeployment, accessing the Container App endpoint without authentication will redirect to Entra ID login:

```bash
# This should return a 302 redirect to login.microsoftonline.com
curl -I https://$FQDN
```

## ACR: Pushing Custom Images

The scenario creates an ACR with admin user disabled. Use Entra ID authentication to push images:

```bash
# Get the ACR login server
ACR_LOGIN_SERVER=$(az deployment sub show \
  --name container_apps_deployment \
  --query properties.outputs.containerRegistryLoginServer.value -o tsv)

# Login to ACR with Entra ID (no admin credentials)
az acr login --name ${ACR_LOGIN_SERVER%%.*}

# Tag and push your image
docker tag myapp:latest ${ACR_LOGIN_SERVER}/myapp:latest
docker push ${ACR_LOGIN_SERVER}/myapp:latest
```

### Deploying a Custom Image

Update `main.bicepparam` to use your custom image:

```bicep
param containerImage = '<acr-login-server>/myapp:latest'
```

Then redeploy:

```bash
make deploy SCENARIO=container_apps
```

The Container App will pull the image using the UAMI with AcrPull access.

## RBAC Role Assignment Notes

To grant roles at Container App scope, you need the principal object IDs.

| Principal | Lookup | Notes |
| --- | --- | --- |
| Signed-in user | `az ad signed-in-user show --query id -o tsv` | Use this for `existingUserObjectIds`. |
| Service principal | `az ad sp show --id <appId> --query id -o tsv` | Use the app registration's client ID (`appId`) to look up its object ID. |
| Managed identity (UAMI) | `az identity show -g <rg> -n <name> --query principalId -o tsv` | Use this for `existingUserAssignedIdentities`. |

## Important Notes

* **ACR admin user is disabled**: The scenario enforces Entra ID authentication for ACR. Use `az acr login` with your Entra ID credentials.
* **Log Analytics is always created**: Container Apps Environment requires Log Analytics for application logs.
* **Easy Auth requires App Registration**: You must create an Entra ID App Registration before enabling Easy Auth.
* **No RBAC granted by default**: The scenario does not grant Container App access to any principals by default. Use the `existing*` parameters to grant roles as needed.
