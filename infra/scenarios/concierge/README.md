---
title: Concierge Scenario
description: A Bicep scenario that provisions a full-stack Azure infrastructure for the ks6088ts-labs/concierge application - Azure AI Foundry + Application Insights + PostgreSQL Flexible Server with pgvector
ms.date: 2026-05-14
---

# Concierge Scenario

A Bicep scenario that provisions the complete Azure infrastructure for the [ks6088ts-labs/concierge](https://github.com/ks6088ts-labs/concierge) application. This scenario integrates Azure AI Foundry (account, project, model deployments, role assignments), Application Insights for observability, and PostgreSQL Flexible Server with pgvector extension into a single, cohesive deployment.

The `concierge` application is a LangChain / LangGraph hands-on Python repository hosted on Microsoft Foundry, covering:

1. Foundry-hosted chat / agent / embedding / vector store calls
2. Azure Monitor / Foundry trace observability
3. PostgreSQL (pgvector) vector store (local Docker Compose or Azure Database for PostgreSQL Flexible Server + Entra authentication)

This scenario replaces and consolidates the previous `microsoft_foundry` and `postgresql_flexible_server` scenarios, providing a unified infrastructure deployment with feature flags to enable/disable Application Insights and PostgreSQL independently.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep) — creates the Azure AI Foundry account.
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep) — creates the Foundry project under the account.
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep) — creates model deployments under the account.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Foundry inference permissions to any combination of existing UAMIs, service principals, and users at account scope (all opt-in via array parameters).
6. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when Application Insights is enabled.
7. [`application_insights` module](../../modules/application_insights/main.bicep) — creates workspace-based Application Insights when enabled.
8. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes Foundry account logs/metrics and PostgreSQL logs/metrics to Log Analytics when Application Insights is enabled.
9. [`microsoft_foundry_connection` module](../../modules/microsoft_foundry_connection/main.bicep) — registers Application Insights as a Foundry project connection for tracing when Application Insights is enabled.
10. [`postgresql_flexible_server` module](../../modules/postgresql_flexible_server/main.bicep) — creates PostgreSQL Flexible Server with Entra ID-only authentication, pgvector extension, firewall rules, and databases when PostgreSQL is enabled.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Composing inputs (default tags, model list, role definition IDs, firewall rules, databases).
* Accepting three independent array parameters — UAMIs, service principal object IDs, and user object IDs — each defaulting to `[]`. **By default, no role assignments are created**, and supplying any non-empty array opts that category in.
* Deploying models sequentially with `@batchSize(1)` to avoid concurrent deployment conflicts.
* Optionally deploying Application Insights / Log Analytics when `enableApplicationInsights` is `true`.
* Optionally deploying PostgreSQL Flexible Server when `enablePostgresql` is `true`.
* Surfacing module outputs to deployment consumers.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and all resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `enableApplicationInsights` | `bool` | `true` | Enable Application Insights and Log Analytics workspace for observability. When true, creates workspace, Application Insights, Foundry diagnostic settings, and Foundry tracing connection. |
| `enablePostgresql` | `bool` | `true` | Enable PostgreSQL Flexible Server with pgvector support. When true, creates PostgreSQL server with Entra ID-only authentication. |
| `models` | `array` | See `main.bicep` | Model deployments to create under the Foundry account. Defaults: `gpt-4o`, `gpt-5`, `text-embedding-3-large`, `text-embedding-3-small`. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs to assign at Foundry account scope. For each role, one role assignment is emitted per supplied identity in each of the three identity arrays. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to grant Foundry call permissions. Each item is `{ name: string, resourceGroup: string }`. Leave empty to skip the role assignment. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Optional. Object (principal) IDs of existing Microsoft Entra service principals to grant Foundry call permissions. Use service principal object IDs (Enterprise Application), not the application/client IDs. Leave empty to skip the role assignment. |
| `existingUserObjectIds` | `array` | `[]` | Optional. Object IDs of existing Microsoft Entra users to grant Foundry call permissions. Leave empty to skip the role assignment. |
| `disableLocalAuth` | `bool` | `true` | Disable local authentication (API keys) on the Foundry account. Set to `false` to enable API key based authentication. |
| `entraAdministrator` | `object?` | _(deployer())_ | Microsoft Entra ID administrator for PostgreSQL (used when `enablePostgresql = true`). When omitted, the principal executing the deployment (returned by the Bicep [`deployer()`](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-deployment#deployer) function) is registered as the administrator. Fields when overriding: `objectId`, `principalName`, `principalType` (`'User'`\|`'Group'`\|`'ServicePrincipal'`), `tenantId`. |
| `postgresVersion` | `string` | `'18'` | PostgreSQL major version. Defaults to `18` to match the [`pgvector/pgvector:pg18`](https://hub.docker.com/r/pgvector/pgvector) reference container image. |
| `postgresSkuName` | `string` | `'Standard_B1ms'` | Compute SKU name for PostgreSQL. |
| `postgresSkuTier` | `string` | `'Burstable'` | SKU tier for PostgreSQL (`'Burstable'`, `'GeneralPurpose'`, `'MemoryOptimized'`). |
| `postgresStorageSizeGB` | `int` | `32` | Storage size in GB for PostgreSQL. |
| `enablePgvector` | `bool` | `true` | When `true`, sets `azure.extensions` configuration to `VECTOR` to enable pgvector on PostgreSQL. |
| `firewallRules` | `array` | `[{ name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }]` | Firewall rules for PostgreSQL. The default allows all Azure services to connect. |
| `databases` | `array` | `[{ name: 'appdb' }]` | Initial databases to create on PostgreSQL. Each element: `{ name, charset?, collation? }`. |

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
| `applicationInsightsConnectionString` | `string` | Application Insights connection string used for Foundry tracing (empty when `enableApplicationInsights = false`). |
| `postgresServerId` | `string` | Resource ID of the created PostgreSQL Flexible Server (empty when `enablePostgresql = false`). |
| `postgresServerName` | `string` | Name of the created PostgreSQL Flexible Server (empty when `enablePostgresql = false`). |
| `postgresServerFqdn` | `string` | Fully qualified domain name (FQDN) of the PostgreSQL server (empty when `enablePostgresql = false`); use this as the connection host. |
| `databaseNames` | `array` | Names of databases created on the PostgreSQL server (empty when `enablePostgresql = false`). |
| `uamiRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to the supplied UAMIs (empty when no UAMI is attached). One entry per (UAMI, roleDefinitionId) pair. |
| `servicePrincipalRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to the supplied service principals (empty when no service principal is attached). One entry per (servicePrincipal, roleDefinitionId) pair. |
| `userRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to the supplied users (empty when no user is attached). One entry per (user, roleDefinitionId) pair. |

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

The bundled `main.bicepparam` enables both Application Insights and PostgreSQL by default (`enableApplicationInsights = true`, `enablePostgresql = true`), providing the full concierge stack. The PostgreSQL Entra administrator defaults to the principal executing the deployment (obtained via the Bicep [`deployer()`](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-deployment#deployer) function), so no manual edits are required.

If target region does not support one of the default models (`gpt-4o`, `gpt-5`, `text-embedding-3-large`, `text-embedding-3-small`), edit `main.bicepparam` and remove/replace unsupported entries in `models` to match what is available in your region/quota. For example, `gpt-5` (version `2025-08-07`, GlobalStandard) is not available in `japaneast`; deploy in regions such as `eastus2` or `swedencentral`, or remove the entry from `models`.

### Feature Flag Combinations

The scenario supports four deployment configurations via the `enableApplicationInsights` and `enablePostgresql` feature flags:

| `enableApplicationInsights` | `enablePostgresql` | Resources Deployed |
| --- | --- | --- |
| `true` (default) | `true` (default) | **Concierge full stack**: Foundry + models + Application Insights + Log Analytics + Foundry tracing + PostgreSQL + pgvector + diagnostic settings for both Foundry and PostgreSQL |
| `false` | `true` | Foundry + models + PostgreSQL + pgvector (no observability) |
| `true` | `false` | Foundry + models + Application Insights + Log Analytics + Foundry tracing + Foundry diagnostic settings (no PostgreSQL) |
| `false` | `false` | **Foundry minimal**: Foundry + models only (no observability, no PostgreSQL) |

To deploy without Application Insights:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters enableApplicationInsights=false
```

To deploy without PostgreSQL:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam \
  --parameters enablePostgresql=false
```

### Using with the concierge Application

After deployment, configure the [ks6088ts-labs/concierge](https://github.com/ks6088ts-labs/concierge) application with the following output values (retrieve with `make output SCENARIO=concierge` or `az deployment sub show --name concierge_deployment --query properties.outputs`):

| Output | Environment Variable / Config | Description |
| --- | --- | --- |
| `foundryEndpoint` | `AZURE_OPENAI_ENDPOINT` | Foundry account endpoint for Azure OpenAI SDK |
| `foundryProjectName` | `FOUNDRY_PROJECT_NAME` | Project name for AI Foundry portal operations |
| `postgresServerFqdn` | `POSTGRES_HOST` | PostgreSQL connection host |
| `databaseNames[0]` | `POSTGRES_DB` | Database name (default: `appdb`) |
| `applicationInsightsConnectionString` | `APPLICATIONINSIGHTS_CONNECTION_STRING` | Connection string for OpenTelemetry tracing |

Example `.env` file for concierge:

```bash
# Foundry
AZURE_OPENAI_ENDPOINT=<foundryEndpoint>
FOUNDRY_PROJECT_NAME=<foundryProjectName>

# PostgreSQL
POSTGRES_HOST=<postgresServerFqdn>
POSTGRES_DB=appdb
POSTGRES_USER=<entraAdministrator.principalName>
# No POSTGRES_PASSWORD needed; use Entra token authentication

# Application Insights
APPLICATIONINSIGHTS_CONNECTION_STRING=<applicationInsightsConnectionString>
```

Python example using Entra ID authentication for Foundry and PostgreSQL:

```python
from azure.identity import DefaultAzureCredential
from openai import AzureOpenAI
import psycopg

# Foundry client (Entra ID)
credential = DefaultAzureCredential()
token = credential.get_token("https://cognitiveservices.azure.com/.default")

client = AzureOpenAI(
    azure_endpoint="<foundryEndpoint>",
    azure_ad_token=token.token,
    api_version="2024-10-21"
)

response = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "Hello from concierge"}]
)
print(response.choices[0].message.content)

# PostgreSQL client (Entra ID)
pg_token = credential.get_token("https://ossrdbms-aad.database.windows.net/.default").token

conn = psycopg.connect(
    host="<postgresServerFqdn>",
    user="<entraAdministrator.principalName>",
    dbname="appdb",
    password=pg_token,
    sslmode="require",
)

with conn.cursor() as cur:
    cur.execute("CREATE EXTENSION IF NOT EXISTS vector;")
    cur.execute("SELECT version();")
    print(cur.fetchone())
```

### Connecting with psql

Since password authentication is disabled on PostgreSQL, clients must obtain a token for `https://ossrdbms-aad.database.windows.net/.default`:

```bash
# Get an access token for psql
TOKEN=$(az account get-access-token --resource "https://ossrdbms-aad.database.windows.net" --query accessToken -o tsv)

# Connect (replace <fqdn> and <principalName> with your values)
PGPASSWORD="$TOKEN" psql "host=<fqdn> user=<principalName> dbname=appdb sslmode=require"

# Enable pgvector
CREATE EXTENSION IF NOT EXISTS vector;

# Create a table with a vector column (example: 1536-dimension embeddings)
CREATE TABLE embeddings (id SERIAL PRIMARY KEY, content TEXT, embedding VECTOR(1536));
```

## Architecture

```text
infra/
├── modules/
│   ├── application_insights/
│   │   └── main.bicep                       # Reusable Application Insights module
│   ├── diagnostic_settings/
│   │   └── main.bicep                       # Reusable Diagnostic Settings module (CognitiveServices + PostgreSQL)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                       # Reusable Log Analytics Workspace module
│   ├── microsoft_foundry/
│   │   └── main.bicep                       # Reusable Azure AI Foundry account module
│   ├── microsoft_foundry_connection/
│   │   └── main.bicep                       # Reusable Foundry project connection module
│   ├── microsoft_foundry_model_deployment/
│   │   └── main.bicep                       # Reusable model deployment module
│   ├── microsoft_foundry_project/
│   │   └── main.bicep                       # Reusable Foundry project module
│   ├── postgresql_flexible_server/
│   │   └── main.bicep                       # Reusable PostgreSQL Flexible Server module
│   ├── resource_group/
│   │   └── main.bicep                       # Reusable resource group module
│   └── role_assignment/
│       └── main.bicep                       # Reusable role assignment module
└── scenarios/
    └── concierge/
        ├── main.bicep                       # Scenario entry point (this scenario)
        ├── main.bicepparam                  # Parameter file
        ├── main.json                        # Compiled ARM template
        └── README.md                        # This file
```

The scenario targets `subscription` scope, creates the resource group, Foundry resources, models, and optionally Application Insights and PostgreSQL. When any of the three identity arrays is non-empty, it also grants inference permissions on the Foundry account to those identities; one role assignment is emitted per (identity, roleDefinitionId) pair.

When `enableApplicationInsights = true`, it additionally creates Log Analytics/Application Insights, routes Foundry account diagnostics to Log Analytics, registers Application Insights as a Foundry project connection for tracing, and (if `enablePostgresql = true`) routes PostgreSQL diagnostics to the same Log Analytics workspace.

When `enablePostgresql = true`, it creates a PostgreSQL Flexible Server with Entra ID-only authentication (password authentication disabled), configures the pgvector extension, creates firewall rules and databases, and (if `enableApplicationInsights = true`) routes diagnostics to Log Analytics.

### Resource Naming Convention

| Resource Type | Name Pattern | Example (`name = 'concierge'`) |
| --- | --- | --- |
| Resource Group | `rg-${name}` | `rg-concierge` |
| Foundry Account | `aif-${name}` (normalized) | `aif-concierge` |
| Foundry Project | `proj-${name}` | `proj-concierge` |
| PostgreSQL Server | `psql-${name}` (normalized) | `psql-concierge` |
| Log Analytics | `law-${name}` (normalized) | `law-concierge` |
| Application Insights | `appi-${name}` (normalized) | `appi-concierge` |

Normalized names: `toLower(replace(name, '_', '-'))` with length limits applied.

### Looking up principal object IDs

Each optional identity array expects IDs whose actual Microsoft Entra type matches the hardcoded `principalType` for that category. Placing an ID under the wrong category results in a deployment-time `UnmatchedPrincipalType` error from Azure RBAC.

| Parameter | Expected Entra type | Retrieval example |
| --- | --- | --- |
| `existingServicePrincipalObjectIds` | `ServicePrincipal` (Enterprise Application object ID, not application/client ID) | `az ad sp show --id <application-id-or-name> --query id --output tsv` |
| `existingUserObjectIds` | `User` | `az ad signed-in-user show --query id --output tsv` or `az ad user show --id <upn-or-objectid> --query id --output tsv` |
| `existingUserAssignedIdentities` | `ServicePrincipal` (managed identity) | `az identity show --name <uami-name> --resource-group <rg-name>` |

## Migration from microsoft_foundry / postgresql_flexible_server Scenarios

The `concierge` scenario replaces the previous `microsoft_foundry` and `postgresql_flexible_server` scenarios. Here's how parameters map:

### From microsoft_foundry

| Old Parameter | New Parameter | Notes |
| --- | --- | --- |
| `name` | `name` | Unchanged |
| `location` | `location` | Unchanged |
| `tags` | `tags` | Unchanged |
| `enableObservability` | `enableApplicationInsights` | Renamed for clarity; same behavior |
| `models` | `models` | Unchanged |
| `roleDefinitionIds` | `roleDefinitionIds` | Unchanged |
| `existingUserAssignedIdentities` | `existingUserAssignedIdentities` | Unchanged |
| `existingServicePrincipalObjectIds` | `existingServicePrincipalObjectIds` | Unchanged |
| `existingUserObjectIds` | `existingUserObjectIds` | Unchanged |
| `disableLocalAuth` | `disableLocalAuth` | Unchanged |

### From postgresql_flexible_server

| Old Parameter | New Parameter | Notes |
| --- | --- | --- |
| `name` | `name` | Unchanged |
| `location` | `location` | Unchanged |
| `tags` | `tags` | Unchanged |
| `entraAdministrator` | `entraAdministrator` | Unchanged |
| `version` | `postgresVersion` | Renamed to avoid collision with Foundry parameters |
| `skuName` | `postgresSkuName` | Renamed to avoid collision |
| `skuTier` | `postgresSkuTier` | Renamed to avoid collision |
| `storageSizeGB` | `postgresStorageSizeGB` | Renamed to avoid collision |
| `enablePgvector` | `enablePgvector` | Unchanged |
| `firewallRules` | `firewallRules` | Unchanged |
| `databases` | `databases` | Unchanged |
| `enableObservability` | `enableApplicationInsights` | Renamed; same Log Analytics + diagnostic settings behavior |

Set `enablePostgresql = false` if you only need Foundry resources (equivalent to the old `microsoft_foundry` scenario without PostgreSQL).

Set `enableApplicationInsights = false` if you don't need observability (equivalent to the old scenarios with `enableObservability = false`).
