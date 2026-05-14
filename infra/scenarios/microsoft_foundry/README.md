---
title: Microsoft Foundry Scenario
description: A Bicep scenario that provisions multiple Azure AI Foundry accounts/projects across regions with per-region model sets and optional role assignments/observability
ms.date: 2026-05-14
---

# Microsoft Foundry Scenario

A Bicep scenario that provisions Azure AI Foundry accounts/projects in one resource group, where each deployment entry can choose its own region and model list.

## Overview

This scenario targets subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep)
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep)
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep)
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep)
5. [`role_assignment` module](../../modules/role_assignment/main.bicep)
6. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep)
7. [`application_insights` module](../../modules/application_insights/main.bicep)
8. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep)
9. [`microsoft_foundry_connection` module](../../modules/microsoft_foundry_connection/main.bicep)

Scenario responsibilities:

* Accept `foundryDeployments[]` (`location + models + optional nameSuffix`) as the multi-region/multi-model interface.
* Create one Foundry account/project per `foundryDeployments` entry.
* Deploy model modules with `@batchSize(1)` to avoid concurrent Foundry conflicts.
* Keep observability resources (Log Analytics + App Insights) singleton, while creating Diagnostic Settings and App Insights Foundry connections for every account/project.
* Grant the same role definition set to every supplied identity across every Foundry account.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `foundryDeployments` | `foundryRegionDeployment[]` | _(required)_ | Region-scoped deployment list. Each entry is `{ location: string, models: modelDeployment[], nameSuffix?: string }`. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional UAMIs to grant Foundry call permissions. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Optional service principal object IDs to grant Foundry call permissions. |
| `existingUserObjectIds` | `array` | `[]` | Optional user object IDs to grant Foundry call permissions. |
| `disableLocalAuth` | `bool` | `true` | Disable local authentication (API keys). |
| `enableObservability` | `bool` | `false` | When `true`, deploys singleton Log Analytics/App Insights + per-account diagnostics/per-project App Insights connection. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs to assign at each Foundry account scope. |

### `modelDeployment` shape

```bicep
type modelDeployment = {
  name: string
  modelName: string
  modelVersion: string?
  modelFormat: string? // default OpenAI
  skuName: string?     // default GlobalStandard
  skuCapacity: int?    // default 50
  raiPolicyName: string?
}
```

### `foundryRegionDeployment` shape

```bicep
type foundryRegionDeployment = {
  location: string
  models: modelDeployment[]
  nameSuffix: string? // default: location
}
```

## Naming rules

For each `foundryDeployments` item:

* `suffix = deployment.?nameSuffix ?? deployment.location`
* `foundryAccountName = take(toLower(replace('aif-${name}-${suffix}', '_', '-')), 59)`
* `foundryProjectName = take('proj-${name}-${suffix}', 64)`

Use `nameSuffix` when same `location` appears multiple times and you need to avoid collisions.

## Location behavior

The resource group and singleton observability resources use `foundryDeployments[0].location`.
Each Foundry account/project uses its own `deployment.location`.

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group (`foundryDeployments[0].location`). |
| `foundryAccountIds` | `string[]` | Resource IDs of created Foundry accounts. |
| `foundryAccountNames` | `string[]` | Names of created Foundry accounts. |
| `foundryEndpoints` | `string[]` | Endpoints of created Foundry accounts. |
| `foundryProjectIds` | `string[]` | Resource IDs of created Foundry projects. |
| `foundryProjectNames` | `string[]` | Names of created Foundry projects. |
| `deployedModelNames` | `string[][]` | Requested model deployment names grouped per `foundryDeployments` entry. |
| `logAnalyticsWorkspaceId` | `string` | Log Analytics resource ID (empty when observability is disabled). |
| `applicationInsightsId` | `string` | Application Insights resource ID (empty when observability is disabled). |
| `applicationInsightsConnectionString` | `string` | App Insights connection string (empty when observability is disabled). |
| `uamiRoleAssignmentIds` | `string[]` | UAMI role assignment IDs across all accounts. |
| `servicePrincipalRoleAssignmentIds` | `string[]` | Service principal role assignment IDs across all accounts. |
| `userRoleAssignmentIds` | `string[]` | User role assignment IDs across all accounts. |

## Usage

```bicep
using 'main.bicep'

param name = 'templatebicepfoundry'
param foundryDeployments = [
  {
    location: 'japaneast'
    models: [
      { name: 'gpt-4o', modelName: 'gpt-4o', skuCapacity: 50 }
      { name: 'text-embedding-3-large', modelName: 'text-embedding-3-large', skuName: 'Standard' }
      { name: 'text-embedding-3-small', modelName: 'text-embedding-3-small', skuName: 'Standard' }
    ]
  }
  {
    location: 'eastus2'
    models: [
      { name: 'gpt-5', modelName: 'gpt-5', modelVersion: '2025-08-07' }
    ]
  }
]
```

## Notes

* Model availability differs by region (for example `gpt-5` may not be available in `japaneast`). Build `location + model` combinations in `foundryDeployments` based on actual regional availability.
* If you set `enableObservability = true`, all Foundry accounts emit diagnostics to the same Log Analytics workspace, and all Foundry projects connect to the same App Insights component.
