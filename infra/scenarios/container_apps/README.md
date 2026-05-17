---
title: Container Apps Scenario
description: Deploy a minimal Azure Container Apps workload (default: nginx) with a dedicated UAMI, ACR (Entra ID auth, admin disabled), Log Analytics-backed environment, external HTTPS ingress, and optional Easy Auth (Entra ID)
ms.date: 2026-05-17
---

# Container Apps Scenario

A Bicep scenario that deploys a minimal Azure Container Apps workload (default image: `nginx:latest`) behind an external HTTPS endpoint. The scenario is designed for Microsoft Entra ID-first operation: it always creates a dedicated User Assigned Managed Identity (UAMI), an Azure Container Registry (ACR) with admin credentials disabled, and grants the UAMI `AcrPull` at the registry scope. It also creates a Log Analytics-backed Container Apps environment (required for environments) and can optionally enable built-in authentication (Easy Auth) with an Entra ID provider on the Container App endpoint.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace (always on).
3. [`container_registry` module](../../modules/container_registry/main.bicep) — creates ACR (admin user disabled, anonymous pull disabled).
4. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates a dedicated UAMI used for ACR pulls.
5. [`container_app_environment` module](../../modules/container_app_environment/main.bicep) — creates a Container Apps environment connected to Log Analytics.
6. [`container_app` module](../../modules/container_app/main.bicep) — creates the Container App with external ingress and optional Easy Auth.
7. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants `AcrPull` to the created UAMI at ACR scope (always), and optionally grants additional roles at Container App scope to any supplied principals.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Creating the required Log Analytics workspace for the environment and retrieving the workspace shared key at deployment time.
* Always granting `AcrPull` to the created UAMI at the created ACR scope.
* Optionally enabling Easy Auth on the Container App endpoint (`enableEasyAuth`).
* Optionally granting RBAC roles at Container App scope via the three `existing*` principal arrays × `roleDefinitionIds`. **By default, no additional role assignments are created** (`roleDefinitionIds = []`).

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and Container Apps resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `containerImage` | `string` | `'nginx:latest'` | Container image for the Container App. |
| `containerCommand` | `string[]` | `[]` | Optional container command override. |
| `containerArgs` | `string[]` | `[]` | Optional container args override. |
| `cpu` | `string` | `'0.5'` | CPU allocation (vCPU). |
| `memory` | `string` | `'1Gi'` | Memory allocation. |
| `minReplicas` | `int` | `0` | Scale minimum replicas. |
| `maxReplicas` | `int` | `3` | Scale maximum replicas. |
| `targetPort` | `int` | `80` | Ingress target port. |
| `ingressExternal` | `bool` | `true` | When `true`, creates an external HTTPS endpoint. |
| `acrSkuName` | `string` | `'Basic'` | ACR SKU (`Basic`, `Standard`, `Premium`). |
| `enableEasyAuth` | `bool` | `false` | When `true`, enables built-in authentication (Easy Auth) with Entra ID on the Container App endpoint. |
| `easyAuthRequireAuthentication` | `bool` | `true` | When Easy Auth is enabled, redirects unauthenticated clients to Entra ID login. |
| `easyAuthEntraClientId` | `string` | `''` | App registration client ID used by Easy Auth. Required when `enableEasyAuth = true`. |
| `easyAuthAllowedAudiences` | `string[]` | `[]` | Allowed audiences for Easy Auth token validation. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to attach to the Container App and grant roles at Container App scope. Each item is `{ name: string, resourceGroup: string }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Optional. Entra service principal object IDs to grant roles at Container App scope. |
| `existingUserObjectIds` | `string[]` | `[]` | Optional. Entra user object IDs to grant roles at Container App scope. |
| `roleDefinitionIds` | `string[]` | `[]` | Role definition GUIDs to grant to every principal in the `existing*` arrays (Container App scope). Defaults to empty (no extra role assignments). |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | RG resource ID. |
| `resourceGroupName` | `string` | RG name. |
| `containerRegistryId` | `string` | ACR resource ID. |
| `containerRegistryLoginServer` | `string` | ACR login server (e.g. `myacr.azurecr.io`). |
| `userAssignedIdentityId` | `string` | Resource ID of the created UAMI. |
| `userAssignedIdentityPrincipalId` | `string` | Principal ID of the created UAMI. |
| `userAssignedIdentityClientId` | `string` | Client ID of the created UAMI. |
| `logAnalyticsWorkspaceId` | `string` | Log Analytics workspace resource ID. |
| `containerAppEnvironmentId` | `string` | Container Apps environment resource ID. |
| `containerAppId` | `string` | Container App resource ID. |
| `containerAppName` | `string` | Container App name. |
| `containerAppFqdn` | `string` | Container App host name (`*.azurecontainerapps.io`). |
| `containerAppUrl` | `string` | `https://<containerAppFqdn>` convenience URL. |
| `acrPullRoleAssignmentId` | `string` | Role assignment ID of `AcrPull` granted to the created UAMI at ACR scope. |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs created for `existingUserAssignedIdentities` × `roleDefinitionIds` at Container App scope. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs created for `existingServicePrincipalObjectIds` × `roleDefinitionIds` at Container App scope. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs created for `existingUserObjectIds` × `roleDefinitionIds` at Container App scope. |

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
│   │   └── main.bicep                         # Reusable Container Apps environment module (Log Analytics-backed)
│   ├── container_registry/
│   │   └── main.bicep                         # Reusable ACR module (admin disabled by default)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics workspace module (always created here)
│   ├── resource_group/
│   │   └── main.bicep                         # Reusable resource group module
│   ├── role_assignment/
│   │   └── main.bicep                         # Reusable role assignment module
│   └── user_assigned_managed_identity/
│       └── main.bicep                         # Reusable UAMI module
└── scenarios/
    └── container_apps/
        ├── main.bicep                         # Scenario entry point (this scenario)
        ├── main.bicepparam                    # Parameter file
        ├── main.json                          # Compiled ARM template
        └── README.md                          # This file
```

## Verification

After `make deploy SCENARIO=container_apps`, confirm the nginx welcome page is reachable:

```bash
curl -fsSL "https://$(make output | jq -r '.containerAppFqdn.value')" | head
```

When `enableEasyAuth = true`, unauthenticated requests should redirect to the Entra ID login endpoint:

```bash
curl -I "https://$(make output | jq -r '.containerAppFqdn.value')" | head
```

Expect `HTTP/2 302` (or `HTTP/1.1 302`) with a `Location: https://login.microsoftonline.com/...` header.

## Easy Auth (Microsoft Entra ID)

To enable Easy Auth, you need an Entra ID app registration and must register a redirect URI for the Container App:

* Redirect URI: `https://<containerAppFqdn>/.auth/login/aad/callback`

Example (Azure CLI):

```bash
APP_NAME="template-bicep-ca-auth"
APP_ID="$(az ad app create --display-name "$APP_NAME" --query appId -o tsv)"

# Optional: create a service principal so it shows up as an enterprise app
az ad sp create --id "$APP_ID" >/dev/null

echo "clientId: $APP_ID"
```

Add the redirect URI in the app registration (Portal: **Authentication**), then set the scenario parameters:

```bicep
param enableEasyAuth = true
param easyAuthEntraClientId = '<clientId>'
```

If you use custom audiences, set `easyAuthAllowedAudiences` (otherwise leave it empty).

## Pushing your own image to ACR (Entra ID, no admin user)

The scenario always creates an ACR with `adminUserEnabled = false`. Use Entra ID authentication for `az acr login`, then push an image and update `containerImage`.

```bash
ACR_SERVER="$(make output | jq -r '.containerRegistryLoginServer.value')"
ACR_NAME="${ACR_SERVER%%.azurecr.io}"

az acr login --name "$ACR_NAME"

docker tag nginx:latest "$ACR_SERVER/myapp:dev"
docker push "$ACR_SERVER/myapp:dev"
```

Then update `main.bicepparam`:

```bicep
param containerImage = '<containerRegistryLoginServer>/myapp:dev'
```

## RBAC role assignment notes

This scenario intentionally does **not** grant any roles at Container App scope by default (`roleDefinitionIds = []`). To grant roles, populate one or more of the `existing*` principal arrays and set `roleDefinitionIds` to the desired role definition GUIDs.

Each array expects IDs whose Entra type matches the `principalType` used for that category: `'ServicePrincipal'` for managed identities and service principals, `'User'` for users. Placing an ID under the wrong category results in a deployment-time `UnmatchedPrincipalType` error from Azure RBAC.

