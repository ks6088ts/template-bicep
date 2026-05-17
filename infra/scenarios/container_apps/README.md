---
title: Container Apps Scenario
description: A Bicep scenario that provisions a minimal Azure Container Apps workload with dedicated UAMI, ACR (Entra ID-first), Log Analytics-backed environment, optional Container App RBAC, and optional Easy Auth
ms.date: 2026-05-17
---

# Container Apps Scenario

A Bicep scenario that provisions a minimal Azure Container Apps stack (`Microsoft.App/containerApps`) that is ready to serve a default `nginx:latest` workload over external HTTPS. The scenario is Entra ID-first: it creates a dedicated UAMI, creates ACR with admin user disabled, grants only `AcrPull`, and supports optional Easy Auth (built-in authentication) with Microsoft Entra ID.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace (always required for Container Apps Environment creation).
3. [`container_registry` module](../../modules/container_registry/main.bicep) — creates Azure Container Registry with Entra ID-first defaults (`adminUserEnabled = false`, `anonymousPullEnabled = false`).
4. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates a dedicated UAMI used for ACR pull authentication.
5. [`container_app_environment` module](../../modules/container_app_environment/main.bicep) — creates Container Apps Environment with direct Log Analytics integration.
6. [`container_app` module](../../modules/container_app/main.bicep) — creates Container App with ingress/scale/registries settings and optional Easy Auth.
7. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants mandatory `AcrPull` to the scenario-created UAMI at ACR scope, and optional role assignments at Container App scope for existing UAMIs/service principals/users.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Ensuring the scenario-created UAMI is always attached to the Container App and always receives `AcrPull` on ACR.
* Allowing additional existing UAMIs to be attached to Container App and optionally granted Container App-scope RBAC.
* Exposing Container App FQDN and URL outputs for quick verification.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for all resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `containerImage` | `string` | `'nginx:latest'` | Container image for the Container App. |
| `containerCommand` | `string[]` | `[]` | Optional startup command override. |
| `containerArgs` | `string[]` | `[]` | Optional startup arguments override. |
| `cpu` | `string` | `'0.5'` | CPU allocation for the app container. |
| `memory` | `string` | `'1Gi'` | Memory allocation for the app container. |
| `minReplicas` | `int` | `0` | `scale.minReplicas`. |
| `maxReplicas` | `int` | `3` | `scale.maxReplicas`. |
| `targetPort` | `int` | `80` | Ingress target port (default nginx port). |
| `ingressExternal` | `bool` | `true` | Enable external ingress (public HTTPS endpoint). |
| `acrSkuName` | `string` | `'Basic'` | ACR SKU (`Basic`, `Standard`, `Premium`). |
| `enableEasyAuth` | `bool` | `false` | Enable built-in authentication (Easy Auth) for Container App endpoint. |
| `easyAuthRequireAuthentication` | `bool` | `true` | When Easy Auth is enabled, require authentication (`RedirectToLoginPage`) or allow anonymous (`AllowAnonymous`). |
| `easyAuthEntraClientId` | `string` | `''` | App registration client ID for Easy Auth. Required when `enableEasyAuth = true`. |
| `easyAuthAllowedAudiences` | `string[]` | `[]` | Allowed audiences for Easy Auth token validation. |
| `existingUserAssignedIdentities` | `array` | `[]` | Existing UAMIs to attach to Container App and optionally grant roles at Container App scope. Each item: `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Existing service principal object IDs to grant roles at Container App scope. |
| `existingUserObjectIds` | `string[]` | `[]` | Existing user object IDs to grant roles at Container App scope. |
| `roleDefinitionIds` | `string[]` | `[]` | Role definition GUIDs for all principals in `existing*` arrays at Container App scope. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `containerRegistryId` | `string` | Resource ID of the created ACR. |
| `containerRegistryLoginServer` | `string` | Login server of the created ACR. |
| `userAssignedIdentityId` | `string` | Resource ID of the scenario-created UAMI. |
| `userAssignedIdentityPrincipalId` | `string` | Principal ID of the scenario-created UAMI. |
| `userAssignedIdentityClientId` | `string` | Client ID of the scenario-created UAMI. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the created Log Analytics workspace. |
| `containerAppEnvironmentId` | `string` | Resource ID of the created Container Apps Environment. |
| `containerAppId` | `string` | Resource ID of the created Container App. |
| `containerAppName` | `string` | Name of the created Container App. |
| `containerAppFqdn` | `string` | Public FQDN of the created Container App. |
| `containerAppUrl` | `string` | `https://<containerAppFqdn>` convenience URL. |
| `acrPullRoleAssignmentId` | `string` | Role assignment ID for mandatory `AcrPull` granted to the scenario-created UAMI on ACR. |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs for existing UAMIs at Container App scope. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs for existing service principals at Container App scope. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs for existing users at Container App scope. |

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

## Verification

After deployment, verify nginx is reachable:

```bash
curl https://$(make output SCENARIO=container_apps | jq -r '.containerAppFqdn.value')
```

Expected: nginx Welcome HTML.

If `enableEasyAuth = true`, unauthenticated requests should be redirected to Entra ID login:

```bash
curl -I https://$(make output SCENARIO=container_apps | jq -r '.containerAppFqdn.value')
```

Expected: `302` with Microsoft Entra ID login URL in `Location` header.

## Easy Auth (Microsoft Entra ID)

1. Create an app registration and service principal:

```bash
az ad app create --display-name template-bicep-container-app-auth
az ad sp create --id <appId>
```

2. Register redirect URI in the app registration:

* `https://<containerAppFqdn>/.auth/login/aad/callback`

3. Set parameters in `main.bicepparam`:

```bicep
param enableEasyAuth = true
param easyAuthRequireAuthentication = true
param easyAuthEntraClientId = '<app-registration-client-id>'
// param easyAuthAllowedAudiences = [ 'api://<app-registration-client-id>' ]
```

You can retrieve the client ID with:

```bash
az ad app list --display-name template-bicep-container-app-auth --query '[0].appId' -o tsv
```

## Push custom image to ACR (Entra ID auth, admin user disabled)

```bash
az acr login --name <acr-name>
docker tag myapp:tag <loginServer>/myapp:tag
docker push <loginServer>/myapp:tag
```

Then update `main.bicepparam`:

```bicep
param containerImage = '<loginServer>/myapp:tag'
```

Re-deploy with `make deploy SCENARIO=container_apps`.

## RBAC role assignment notes

The scenario always grants `AcrPull` to the scenario-created UAMI for ACR. Additional role assignments at Container App scope are opt-in via:

* `existingUserAssignedIdentities`
* `existingServicePrincipalObjectIds`
* `existingUserObjectIds`
* `roleDefinitionIds`

Each supplied principal is paired with every GUID in `roleDefinitionIds` (cross-product). Leave arrays empty to skip these optional assignments.

## Architecture

```text
infra/
├── modules/
│   ├── container_app/
│   │   └── main.bicep                       # Reusable Container App module
│   ├── container_app_environment/
│   │   └── main.bicep                       # Reusable Container Apps Environment module
│   ├── container_registry/
│   │   └── main.bicep                       # Reusable Azure Container Registry module
│   ├── log_analytics_workspace/
│   │   └── main.bicep                       # Reusable Log Analytics Workspace module
│   ├── resource_group/
│   │   └── main.bicep                       # Reusable resource group module
│   ├── role_assignment/
│   │   └── main.bicep                       # Reusable role assignment module
│   └── user_assigned_managed_identity/
│       └── main.bicep                       # Reusable UAMI module
└── scenarios/
    └── container_apps/
        ├── main.bicep                       # Scenario entry point (this scenario)
        ├── main.bicepparam                  # Parameter file
        ├── main.json                        # Compiled ARM template
        └── README.md                        # This file
```
