---
title: Concierge Scenario
description: A Bicep scenario that provisions the concierge full stack (Azure AI Foundry + Application Insights tracing + PostgreSQL Flexible Server with pgvector) behind two independent feature flags
ms.date: 2026-05-14
---

# Concierge Scenario

A Bicep scenario that provisions the infrastructure used by [`ks6088ts-labs/concierge`](https://github.com/ks6088ts-labs/concierge): Azure AI Foundry (one or more account + project + model deployment sets), optional Azure Monitor / Application Insights based observability (Log Analytics + workspace-based Application Insights + Foundry tracing/diagnostics), and optional Azure Database for PostgreSQL Flexible Server (Entra ID-only authentication + optional pgvector + firewall rules + initial databases).

This scenario composes the existing `microsoft_foundry` and `postgresql_flexible_server` building blocks into a single deployable stack:

```bash
make deploy SCENARIO=concierge
```

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep) — creates one Azure AI Foundry account per `foundries` entry.
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep) — creates one Foundry project under each account.
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep) — creates model deployments under each account (sequential with `@batchSize(1)` across the flattened account×model list).
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Foundry inference permissions to any combination of existing UAMIs, service principals, and users at account scope (all opt-in via array parameters).
6. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when `enableApplicationInsights = true`.
7. [`application_insights` module](../../modules/application_insights/main.bicep) — creates workspace-based Application Insights when `enableApplicationInsights = true`.
8. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes Foundry account diagnostics to Log Analytics when `enableApplicationInsights = true`, and PostgreSQL diagnostics when both `enableApplicationInsights = true` and `enablePostgresql = true`.
9. [`microsoft_foundry_connection` module](../../modules/microsoft_foundry_connection/main.bicep) — registers Application Insights as a Foundry project connection for tracing when `enableApplicationInsights = true`.
10. [`postgresql_flexible_server` module](../../modules/postgresql_flexible_server/main.bicep) — creates PostgreSQL Flexible Server (Entra ID-only), firewall rules, databases, and optional pgvector when `enablePostgresql = true`.

The scenario layer is responsible for:

* Deriving per-Foundry resource names from `name` + Foundry location.
* Composing inputs (default tags, default model list, role definition IDs, default firewall rules/databases).
* Feature-flagging observability via `enableApplicationInsights` and PostgreSQL via `enablePostgresql` (independent).
* Surfacing module outputs (with empty values for disabled features).

## Feature flags

| `enableApplicationInsights` | `enablePostgresql` | Result |
| --- | --- | --- |
| `true` | `true` | **Default full stack**: Foundry + Log Analytics + Application Insights (tracing) + PostgreSQL + diagnostic settings for both Foundry and PostgreSQL. |
| `false` | `true` | Foundry + PostgreSQL. No Log Analytics / Application Insights / diagnostic settings / Foundry tracing connection. |
| `true` | `false` | Foundry + Log Analytics + Application Insights (tracing). No PostgreSQL. |
| `false` | `false` | Minimal: Foundry only (account + project + models). |

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `enableApplicationInsights` | `bool` | `true` | When `true`, deploys Log Analytics + Application Insights, enables Foundry diagnostic settings, and registers App Insights as a Foundry tracing connection. |
| `enablePostgresql` | `bool` | `true` | When `true`, deploys PostgreSQL Flexible Server with Entra ID-only authentication and optional pgvector. |
| `foundries` | `array` | `[{}]` | Foundry deployments. Each item supports `{ location?, name?, models? }`. If omitted, one Foundry is deployed to scenario `location` with the default model list. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs to assign at Foundry account scope. For each role, one role assignment is emitted per supplied identity in each identity array. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to grant Foundry call permissions. Each item is `{ name: string, resourceGroup: string }`. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Optional. Object (principal) IDs of existing Microsoft Entra service principals to grant Foundry call permissions. Use service principal object IDs (Enterprise Application), not application/client IDs. |
| `existingUserObjectIds` | `array` | `[]` | Optional. Object IDs of existing Microsoft Entra users to grant Foundry call permissions. |
| `disableLocalAuth` | `bool` | `true` | Disable local authentication (API keys) on the Foundry account. Set to `false` to enable API key based authentication. |
| `entraAdministrator` | `object?` | _(deployer())_ | Microsoft Entra ID administrator for PostgreSQL. When omitted, the principal executing the deployment (via `deployer()`) is registered as the administrator. |
| `postgresVersion` | `string` | `'18'` | PostgreSQL major version. |
| `postgresSkuName` | `string` | `'Standard_B1ms'` | Compute SKU name. |
| `postgresSkuTier` | `string` | `'Burstable'` | SKU tier (`'Burstable'`, `'GeneralPurpose'`, `'MemoryOptimized'`). |
| `postgresStorageSizeGB` | `int` | `32` | Storage size in GB. |
| `enablePgvector` | `bool` | `true` | When `true`, sets `azure.extensions` configuration to `VECTOR` to enable pgvector. |
| `firewallRules` | `array` | `[{ name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }]` | Firewall rules. The default allows all Azure services to connect. |
| `databases` | `array` | `[{ name: 'appdb' }]` | Initial databases to create. Each element: `{ name, charset?, collation? }`. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `foundryAccountIds` | `array` | Resource IDs of created Foundry accounts. |
| `foundryAccountNames` | `array` | Names of created Foundry accounts. |
| `foundryEndpoints` | `array` | Foundry endpoints (`https://<account>.cognitiveservices.azure.com/`). |
| `foundryProjectIds` | `array` | Resource IDs of created Foundry projects. |
| `foundryProjectNames` | `array` | Names of created Foundry projects. |
| `deployedModelNames` | `array` | Model deployment names grouped per Foundry: `[{ foundryAccountName, models[] }, ...]`. |
| `logAnalyticsWorkspaceId` | `string` | Log Analytics workspace resource ID (empty when `enableApplicationInsights = false`). |
| `applicationInsightsId` | `string` | Application Insights resource ID (empty when `enableApplicationInsights = false`). |
| `applicationInsightsConnectionString` | `string` | Application Insights connection string for tracing (empty when `enableApplicationInsights = false`). |
| `postgresServerId` | `string` | PostgreSQL server resource ID (empty when `enablePostgresql = false`). |
| `postgresServerName` | `string` | PostgreSQL server name (empty when `enablePostgresql = false`). |
| `postgresServerFqdn` | `string` | PostgreSQL server FQDN (empty when `enablePostgresql = false`). |
| `databaseNames` | `array` | Database names created on PostgreSQL (empty when `enablePostgresql = false`). |
| `uamiRoleAssignmentIds` | `array` | Role assignment resource IDs for supplied UAMIs (empty when none supplied). |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment resource IDs for supplied service principals (empty when none supplied). |
| `userRoleAssignmentIds` | `array` | Role assignment resource IDs for supplied users (empty when none supplied). |

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
make deploy SCENARIO=concierge
```

### Using outputs in the concierge app

The `ks6088ts-labs/concierge` repo typically expects these values in `.env` (or equivalent):

| Scenario output | Typical usage |
| --- | --- |
| `foundryEndpoints[0]` | Azure OpenAI / Foundry endpoint (e.g. `AZURE_OPENAI_ENDPOINT`) |
| `applicationInsightsConnectionString` | Application Insights connection string (e.g. `APPLICATIONINSIGHTS_CONNECTION_STRING`) |
| `postgresServerFqdn` | PostgreSQL host (e.g. `POSTGRES_HOST`) |
| `databaseNames[0]` | Database name (default: `appdb`) |

### Multi-region Foundry example

```bicep
param foundries = [
  {
    location: 'japaneast'
    models: [
      { name: 'gpt-4o', modelName: 'gpt-4o', modelFormat: 'OpenAI', skuName: 'GlobalStandard', skuCapacity: 50 }
    ]
  }
  {
    location: 'eastus2'
    models: [
      { name: 'gpt-5', modelName: 'gpt-5', modelVersion: '2025-08-07', modelFormat: 'OpenAI', skuName: 'GlobalStandard', skuCapacity: 50 }
    ]
  }
]
```

## Authentication examples

### Foundry: Entra ID auth (no API key)

Python example using `AzureOpenAI` and `DefaultAzureCredential`:

```python
from azure.identity import DefaultAzureCredential
from openai import AzureOpenAI

client = AzureOpenAI(
    azure_endpoint="https://<foundry-account-name>.cognitiveservices.azure.com/",
    azure_ad_token_provider=DefaultAzureCredential(),
    api_version="2024-10-21",
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello from concierge"}],
)
print(response.choices[0].message.content)
```

### PostgreSQL: token-based auth (no password)

Get an access token for `psql`:

```bash
TOKEN=$(az account get-access-token --resource "https://ossrdbms-aad.database.windows.net" --query accessToken -o tsv)
PGPASSWORD="$TOKEN" psql "host=<postgresServerFqdn> user=<entraAdministrator.principalName> dbname=appdb sslmode=require"
```

## Architecture

```text
infra/
├── modules/
│   ├── application_insights/
│   │   └── main.bicep                         # Reusable Application Insights module
│   ├── diagnostic_settings/
│   │   └── main.bicep                         # Reusable Diagnostic Settings module (CognitiveServices + PostgreSQL)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics Workspace module
│   ├── microsoft_foundry/
│   │   └── main.bicep                         # Reusable Azure AI Foundry account module
│   ├── microsoft_foundry_connection/
│   │   └── main.bicep                         # Reusable Foundry project connection module
│   ├── microsoft_foundry_model_deployment/
│   │   └── main.bicep                         # Reusable model deployment module
│   ├── microsoft_foundry_project/
│   │   └── main.bicep                         # Reusable Foundry project module
│   ├── postgresql_flexible_server/
│   │   └── main.bicep                         # Reusable PostgreSQL Flexible Server module
│   ├── resource_group/
│   │   └── main.bicep                         # Reusable resource group module
│   └── role_assignment/
│       └── main.bicep                         # Reusable role assignment module
└── scenarios/
    └── concierge/
        ├── main.bicep                         # Scenario entry point (this scenario)
        ├── main.bicepparam                    # Parameter file
        ├── main.json                          # Compiled ARM template
        └── README.md                          # This file
```

| Area | What it enables |
| --- | --- |
| Foundry | Account + project + model deployments + optional role assignments for UAMI/SP/user identities. |
| Observability (`enableApplicationInsights`) | Log Analytics + workspace-based App Insights + Foundry tracing connection + Foundry diagnostic settings; also enables PostgreSQL diagnostic settings when PostgreSQL is enabled. |
| PostgreSQL (`enablePostgresql`) | Entra ID-only Flexible Server + firewall rules + databases + optional pgvector configuration. |
