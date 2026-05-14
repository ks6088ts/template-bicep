---
title: Concierge Scenario
description: A Bicep scenario that provisions Azure AI Foundry, Application Insights tracing, and optional Azure Database for PostgreSQL Flexible Server (pgvector)
ms.date: 2026-05-14
---

# Concierge Scenario

A Bicep scenario that provisions the full stack used by [ks6088ts-labs/concierge](https://github.com/ks6088ts-labs/concierge): Azure AI Foundry account/project/model deployments, Application Insights tracing integration, and optional Azure Database for PostgreSQL Flexible Server with Entra ID-only authentication and pgvector.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep) — creates the Azure AI Foundry account.
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep) — creates the Foundry project.
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep) — creates model deployments (`@batchSize(1)`).
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Foundry inference roles for existing UAMIs, service principals, and users.
6. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates Log Analytics when `enableApplicationInsights = true`.
7. [`application_insights` module](../../modules/application_insights/main.bicep) — creates workspace-based Application Insights when `enableApplicationInsights = true`.
8. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes Foundry diagnostics to Log Analytics when `enableApplicationInsights = true`.
9. [`microsoft_foundry_connection` module](../../modules/microsoft_foundry_connection/main.bicep) — connects Application Insights to the Foundry project for tracing when `enableApplicationInsights = true`.
10. [`postgresql_flexible_server` module](../../modules/postgresql_flexible_server/main.bicep) — creates PostgreSQL Flexible Server when `enablePostgresql = true`.
11. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes PostgreSQL diagnostics to the same Log Analytics workspace when `enablePostgresql && enableApplicationInsights`.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for all resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `enableApplicationInsights` | `bool` | `true` | Enables Log Analytics + Application Insights + Foundry tracing integration. |
| `enablePostgresql` | `bool` | `true` | Enables PostgreSQL Flexible Server resources. |
| `models` | `array` | See `main.bicep` | Foundry model deployments to create. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs assigned at Foundry account scope. |
| `existingUserAssignedIdentities` | `array` | `[]` | Existing UAMIs to receive Foundry role assignments. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Existing service principal object IDs to receive Foundry role assignments. |
| `existingUserObjectIds` | `array` | `[]` | Existing user object IDs to receive Foundry role assignments. |
| `disableLocalAuth` | `bool` | `true` | Disables Foundry API key auth and requires Entra ID auth. |
| `entraAdministrator` | `object?` | _(deployer())_ | PostgreSQL Entra administrator (falls back to `deployer()` when omitted). |
| `postgresVersion` | `string` | `'18'` | PostgreSQL major version. |
| `postgresSkuName` | `string` | `'Standard_B1ms'` | PostgreSQL compute SKU name. |
| `postgresSkuTier` | `string` | `'Burstable'` | PostgreSQL SKU tier. |
| `postgresStorageSizeGB` | `int` | `32` | PostgreSQL storage size in GB. |
| `enablePgvector` | `bool` | `true` | Enables pgvector (`azure.extensions = VECTOR`). |
| `firewallRules` | `array` | `[{ name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }]` | PostgreSQL firewall rules. |
| `databases` | `array` | `[{ name: 'appdb' }]` | PostgreSQL databases to create. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `foundryAccountId` | `string` | Resource ID of the created Foundry account. |
| `foundryAccountName` | `string` | Name of the created Foundry account. |
| `foundryEndpoint` | `string` | Endpoint of the created Foundry account. |
| `foundryProjectId` | `string` | Resource ID of the created Foundry project. |
| `foundryProjectName` | `string` | Name of the created Foundry project. |
| `deployedModelNames` | `array` | Names of requested model deployments. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the created Log Analytics workspace (empty when `enableApplicationInsights = false`). |
| `applicationInsightsId` | `string` | Resource ID of the created Application Insights component (empty when `enableApplicationInsights = false`). |
| `applicationInsightsConnectionString` | `string` | Application Insights connection string (empty when `enableApplicationInsights = false`). |
| `postgresServerId` | `string` | Resource ID of the created PostgreSQL Flexible Server (empty when `enablePostgresql = false`). |
| `postgresServerName` | `string` | Name of the created PostgreSQL Flexible Server (empty when `enablePostgresql = false`). |
| `postgresServerFqdn` | `string` | PostgreSQL server FQDN (empty when `enablePostgresql = false`). |
| `databaseNames` | `array` | Names of created databases (empty when `enablePostgresql = false`). |
| `uamiRoleAssignmentIds` | `array` | Foundry role assignment IDs for supplied UAMIs. |
| `servicePrincipalRoleAssignmentIds` | `array` | Foundry role assignment IDs for supplied service principals. |
| `userRoleAssignmentIds` | `array` | Foundry role assignment IDs for supplied users. |

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

### Feature flag combinations

| `enableApplicationInsights` | `enablePostgresql` | Result |
| --- | --- | --- |
| `true` | `true` | Default full stack: Foundry + tracing + PostgreSQL pgvector |
| `false` | `true` | Foundry + PostgreSQL (no Log Analytics/App Insights/tracing connection) |
| `true` | `false` | Foundry + tracing only (no PostgreSQL) |
| `false` | `false` | Foundry-only minimal configuration |

### `concierge` app configuration mapping

| Scenario output | Typical usage in app `.env` / config |
| --- | --- |
| `foundryEndpoint` | `AZURE_OPENAI_ENDPOINT` |
| `foundryAccountName` | `AZURE_OPENAI_RESOURCE_NAME` |
| `applicationInsightsConnectionString` | `APPLICATIONINSIGHTS_CONNECTION_STRING` |
| `postgresServerFqdn` | `POSTGRES_HOST` |
| `databaseNames[0]` | `POSTGRES_DB` |
| `resourceGroupName` | Operational lookup / tagging |

### Authentication examples

```bash
# Get an access token for PostgreSQL (Entra auth)
az account get-access-token --resource "https://ossrdbms-aad.database.windows.net" --query accessToken -o tsv

# Connect via psql (replace <fqdn> and <principalName>)
TOKEN=$(az account get-access-token --resource "https://ossrdbms-aad.database.windows.net" --query accessToken -o tsv)
PGPASSWORD="$TOKEN" psql "host=<fqdn> user=<principalName> dbname=appdb sslmode=require"
```

```python
from azure.identity import DefaultAzureCredential
from openai import AzureOpenAI

client = AzureOpenAI(
    azure_endpoint="https://<foundry-account-name>.cognitiveservices.azure.com/",
    azure_ad_token_provider=DefaultAzureCredential(),
    api_version="2024-10-21"
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello from concierge"}]
)
print(response.choices[0].message.content)
```

## Architecture

```text
infra/
├── modules/
│   ├── application_insights/                 # App Insights module
│   ├── diagnostic_settings/                  # Diagnostic Settings module
│   ├── log_analytics_workspace/              # Log Analytics module
│   ├── microsoft_foundry/                    # Foundry account module
│   ├── microsoft_foundry_connection/         # Foundry project connection module
│   ├── microsoft_foundry_model_deployment/   # Foundry model deployment module
│   ├── microsoft_foundry_project/            # Foundry project module
│   ├── postgresql_flexible_server/           # PostgreSQL Flexible Server module
│   ├── resource_group/                       # Resource group module
│   └── role_assignment/                      # Role assignment module
└── scenarios/
    └── concierge/
        ├── main.bicep
        ├── main.bicepparam
        ├── main.json
        └── README.md
```

| Resource group | Resources |
| --- | --- |
| `rg-<name>` | Foundry account/project/model deployments, optional role assignments, optional Log Analytics + Application Insights + Foundry diagnostic/tracing connection, optional PostgreSQL server + diagnostics |
