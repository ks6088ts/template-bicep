---
title: Container Apps Scenario
description: A Bicep scenario that provisions a minimal Azure Container Apps workload with ACR, UAMI, Log Analytics-backed environment, external HTTPS ingress, and optional Easy Auth (Entra ID)
ms.date: 2026-05-17
---

# Container Apps Scenario

A Bicep scenario that provisions a minimal Azure Container Apps workload: a dedicated resource group, Log Analytics workspace, Azure Container Registry (ACR), scenario-managed User Assigned Managed Identity (UAMI), Container Apps Environment, and a public Azure Container App running `nginx:latest` by default. The scenario follows an Entra ID-first design (ACR admin user disabled, ACR pull via managed identity) and can optionally enable Easy Auth (built-in authentication with Entra ID provider) for the app endpoint.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates the Log Analytics workspace required by Container Apps Environment.
3. [`container_registry` module](../../modules/container_registry/main.bicep) — creates ACR with Entra ID-first defaults (`adminUserEnabled = false`, `anonymousPullEnabled = false`).
4. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates a dedicated UAMI used for ACR pull.
5. [`container_app_environment` module](../../modules/container_app_environment/main.bicep) — creates Container Apps Environment connected to Log Analytics.
6. [`container_app` module](../../modules/container_app/main.bicep) — creates the Azure Container App with ingress/scale/identity/registry settings and optional Easy Auth.
7. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants mandatory `AcrPull` to the scenario-managed UAMI at ACR scope, plus optional RBAC at Container App scope for provided principal arrays.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for all resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `containerImage` | `string` | `'nginx:latest'` | Container image for Azure Container App. |
| `containerCommand` | `string[]` | `[]` | Optional startup command override. |
| `containerArgs` | `string[]` | `[]` | Optional startup argument override. |
| `cpu` | `string` | `'0.5'` | CPU allocation for the container. |
| `memory` | `string` | `'1Gi'` | Memory allocation for the container. |
| `minReplicas` | `int` | `0` | Minimum replicas (`scale.minReplicas`). |
| `maxReplicas` | `int` | `3` | Maximum replicas (`scale.maxReplicas`). |
| `targetPort` | `int` | `80` | Ingress target port (nginx default). |
| `ingressExternal` | `bool` | `true` | Enable external HTTPS ingress. |
| `acrSkuName` | `string` | `'Basic'` | ACR SKU (`Basic`/`Standard`/`Premium`). |
| `enableEasyAuth` | `bool` | `false` | Enable Easy Auth (Entra ID provider) for the app endpoint. |
| `easyAuthRequireAuthentication` | `bool` | `true` | When Easy Auth is enabled, unauthenticated users are redirected to login (`true`) or allowed (`false`). |
| `easyAuthEntraClientId` | `string` | `''` | App Registration client ID used by Easy Auth (required when `enableEasyAuth = true`). |
| `easyAuthAllowedAudiences` | `string[]` | `[]` | Allowed audiences for Easy Auth validation. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional existing UAMIs to attach to the app and grant Container App scoped roles. Each entry: `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Optional Entra service principal object IDs to grant Container App scoped roles. |
| `existingUserObjectIds` | `string[]` | `[]` | Optional Entra user object IDs to grant Container App scoped roles. |
| `roleDefinitionIds` | `string[]` | `[]` | Role definition GUIDs assigned to every principal in `existing*` arrays at Container App scope. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | RG resource ID. |
| `resourceGroupName` | `string` | RG name. |
| `containerRegistryId` | `string` | ACR resource ID. |
| `containerRegistryLoginServer` | `string` | ACR login server. |
| `userAssignedIdentityId` | `string` | Scenario-managed UAMI resource ID. |
| `userAssignedIdentityPrincipalId` | `string` | Scenario-managed UAMI principal ID. |
| `userAssignedIdentityClientId` | `string` | Scenario-managed UAMI client ID. |
| `logAnalyticsWorkspaceId` | `string` | Log Analytics resource ID. |
| `containerAppEnvironmentId` | `string` | Container Apps Environment resource ID. |
| `containerAppId` | `string` | Container App resource ID. |
| `containerAppName` | `string` | Container App name. |
| `containerAppFqdn` | `string` | Container App FQDN (`*.azurecontainerapps.io`). |
| `containerAppUrl` | `string` | Convenience URL (`https://<fqdn>`). |
| `acrPullRoleAssignmentId` | `string` | Mandatory AcrPull role assignment ID for scenario-managed UAMI. |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs for `existingUserAssignedIdentities × roleDefinitionIds`. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs for `existingServicePrincipalObjectIds × roleDefinitionIds`. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs for `existingUserObjectIds × roleDefinitionIds`. |

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

## Verification

1. Deploy the scenario.
2. Retrieve the FQDN and call it:

```bash
curl "https://$(make output SCENARIO=container_apps | jq -r '.containerAppFqdn.value')"
```

You should receive the nginx welcome HTML.

If `enableEasyAuth = true`, unauthenticated access should be redirected to Entra ID login:

```bash
curl -I "https://$(make output SCENARIO=container_apps | jq -r '.containerAppFqdn.value')"
```

Expect `302` with a `Location` header under `login.microsoftonline.com`.

## Easy Auth (Entra ID) setup

1. Create an app registration and service principal:

```bash
APP=$(az ad app create --display-name "template-bicep-container-app-easyauth" --query appId -o tsv)
az ad sp create --id "$APP"
```

2. Deploy once to get `containerAppFqdn`.
3. Add redirect URI to the app registration:

```bash
FQDN=$(make output SCENARIO=container_apps | jq -r '.containerAppFqdn.value')
az ad app update --id "$APP" --web-redirect-uris "https://${FQDN}/.auth/login/aad/callback"
```

4. Set in `main.bicepparam` and redeploy:

```bicep
param enableEasyAuth = true
param easyAuthEntraClientId = '<APP_CLIENT_ID>'
```

## Push your own image to ACR (Entra ID auth, admin disabled)

```bash
LOGIN_SERVER=$(make output SCENARIO=container_apps | jq -r '.containerRegistryLoginServer.value')
ACR_NAME="${LOGIN_SERVER%%.*}"

az acr login --name "$ACR_NAME"
docker tag myapp:tag "${LOGIN_SERVER}/myapp:tag"
docker push "${LOGIN_SERVER}/myapp:tag"
```

Then set:

```bicep
param containerImage = '<loginServer>/myapp:tag'
```

and redeploy.

## RBAC role assignment notes

This scenario always creates one UAMI and always grants that UAMI the `AcrPull` role on the scenario-created ACR. Additional role assignments at Container App scope are opt-in and only created when both identity arrays and `roleDefinitionIds` are non-empty.

For object ID lookup examples, follow the same commands used in other scenarios (`az ad sp show`, `az ad signed-in-user show`, `az identity show`). Ensure IDs are passed to the correct `existing*` parameter type to avoid `UnmatchedPrincipalType` deployment errors.
