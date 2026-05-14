---
title: PostgreSQL Flexible Server Scenario
description: A Bicep scenario that provisions an Azure Database for PostgreSQL Flexible Server with Entra ID-only authentication, optional pgvector extension, and optional Azure Monitor observability
ms.date: 2026-05-13
---

# PostgreSQL Flexible Server Scenario

> **⚠️ DEPRECATION NOTICE**
>
> This scenario is deprecated and will be removed in a future release. Please migrate to the [**`concierge`**](../concierge/README.md) scenario, which consolidates this scenario with Azure AI Foundry support and provides a unified infrastructure deployment for the [ks6088ts-labs/concierge](https://github.com/ks6088ts-labs/concierge) application.
>
> See the [Migration to `concierge`](#migration-to-concierge) section below for parameter mapping.

A Bicep scenario that provisions an Azure Database for PostgreSQL Flexible Server (`Microsoft.DBforPostgreSQL/flexibleServers`) with Microsoft Entra ID-only authentication (password authentication disabled), an optional pgvector extension for vector similarity search, configurable firewall rules, initial databases, and optionally Azure Monitor-based observability (Log Analytics workspace and diagnostic settings).

By default this scenario provisions a managed environment equivalent to the [`pgvector/pgvector:pg18`](https://hub.docker.com/r/pgvector/pgvector) Docker image: PostgreSQL major version `18` with the `pgvector` extension allow-listed (`azure.extensions = VECTOR`) so it can be enabled with `CREATE EXTENSION vector;` against any database created on the server.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`postgresql_flexible_server` module](../../modules/postgresql_flexible_server/main.bicep) — creates the Azure Database for PostgreSQL Flexible Server, Entra ID administrator, firewall rules, databases, and optional pgvector configuration.
3. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when observability is enabled.
4. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes PostgreSQL server logs and metrics to Log Analytics when observability is enabled.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Composing inputs (default tags, firewall rules, initial databases).
* Forwarding the `entraAdministrator` object to the module unchanged.
* Optionally deploying Azure Monitor based observability when `enableObservability` is `true`.
* Surfacing module outputs to deployment consumers.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and PostgreSQL resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `entraAdministrator` | `object?` | _(deployer())_ | Microsoft Entra ID administrator. When omitted, the principal executing the deployment (returned by the Bicep [`deployer()`](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-deployment#deployer) function) is registered as the administrator. Fields when overriding: `objectId`, `principalName`, `principalType` (`'User'`\|`'Group'`\|`'ServicePrincipal'`), `tenantId`. |
| `version` | `string` | `'18'` | PostgreSQL major version. Defaults to `18` to match the [`pgvector/pgvector:pg18`](https://hub.docker.com/r/pgvector/pgvector) reference container image. |
| `skuName` | `string` | `'Standard_B1ms'` | Compute SKU name. |
| `skuTier` | `string` | `'Burstable'` | SKU tier (`'Burstable'`, `'GeneralPurpose'`, `'MemoryOptimized'`). |
| `storageSizeGB` | `int` | `32` | Storage size in GB. |
| `enablePgvector` | `bool` | `true` | When `true`, sets `azure.extensions` configuration to `VECTOR` to enable pgvector. |
| `firewallRules` | `array` | `[{ name: 'AllowAllAzureServices', startIpAddress: '0.0.0.0', endIpAddress: '0.0.0.0' }]` | Firewall rules. The default allows all Azure services to connect. |
| `databases` | `array` | `[{ name: 'appdb' }]` | Initial databases to create. Each element: `{ name, charset?, collation? }`. |
| `enableObservability` | `bool` | `false` | When `true`, deploys Log Analytics workspace and routes PostgreSQL diagnostics (all logs and metrics) to it. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `postgresServerId` | `string` | Resource ID of the created PostgreSQL Flexible Server. |
| `postgresServerName` | `string` | Name of the created PostgreSQL Flexible Server. |
| `postgresServerFqdn` | `string` | Fully qualified domain name (FQDN) of the server; use this as the connection host. |
| `databaseNames` | `array` | Names of databases created on the server. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the created Log Analytics workspace (empty when `enableObservability = false`). |

## Usage

The bundled `main.bicepparam` is ready to deploy as-is: by default the scenario registers the principal executing the deployment (obtained via the Bicep [`deployer()`](https://learn.microsoft.com/azure/azure-resource-manager/bicep/bicep-functions-deployment#deployer) function) as the Microsoft Entra administrator, so no manual edits are required.

Deploy with the bundled `bicepparam` file:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Or with the repository `Makefile`:

```bash
make deploy SCENARIO=postgresql_flexible_server
```

To register a different administrator (for example a security group or a service principal), uncomment and edit the `param entraAdministrator = { ... }` block in `main.bicepparam`. To look up the signed-in user's values, run:

```bash
az ad signed-in-user show --query "{objectId:id, principalName:userPrincipalName, tenantId:tenantId}" -o json
```

To enable observability, set `param enableObservability = true` in `main.bicepparam` (already the default in the bundled file). This deploys a Log Analytics workspace and configures diagnostic settings to send all PostgreSQL server logs and metrics to it.

After deployment, enable and use pgvector in the database:

```sql
-- Connect to your database, then run:
CREATE EXTENSION IF NOT EXISTS vector;

-- Create a table with a vector column (example: 1536-dimension embeddings)
CREATE TABLE embeddings (id SERIAL PRIMARY KEY, content TEXT, embedding VECTOR(1536));

-- Insert a vector
INSERT INTO embeddings (content, embedding) VALUES ('hello world', ARRAY[...]::VECTOR(1536));

-- Query nearest neighbors
SELECT id, content, embedding <=> '[...]'::VECTOR AS distance
FROM embeddings
ORDER BY distance LIMIT 5;
```

### Connecting with Entra ID (token-based, no password)

Since password authentication is disabled, clients must obtain a token for `https://ossrdbms-aad.database.windows.net/.default`:

```bash
# Get an access token for psql
TOKEN=$(az account get-access-token --resource "https://ossrdbms-aad.database.windows.net" --query accessToken -o tsv)

# Connect (replace <fqdn> and <principalName> with your values)
PGPASSWORD="$TOKEN" psql "host=<fqdn> user=<principalName> dbname=appdb sslmode=require"
```

Python example using `psycopg` and `azure-identity`:

```python
from azure.identity import DefaultAzureCredential
import psycopg

cred = DefaultAzureCredential()
token = cred.get_token("https://ossrdbms-aad.database.windows.net/.default").token

conn = psycopg.connect(
    host="<postgresServerFqdn>",
    user="<entraAdministrator.principalName>",
    dbname="appdb",
    password=token,
    sslmode="require",
)

with conn.cursor() as cur:
    cur.execute("SELECT version();")
    print(cur.fetchone())
```

## Architecture

```text
infra/
├── modules/
│   ├── diagnostic_settings/
│   │   └── main.bicep                         # Reusable Diagnostic Settings module (CognitiveServices + PostgreSQL)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics Workspace module
│   ├── postgresql_flexible_server/
│   │   └── main.bicep                         # Reusable PostgreSQL Flexible Server module (this module)
│   └── resource_group/
│       └── main.bicep                         # Reusable resource group module
└── scenarios/
    └── postgresql_flexible_server/
        ├── main.bicep                         # Scenario entry point (this scenario)
        ├── main.bicepparam                    # Parameter file
        ├── main.json                          # Compiled ARM template
        └── README.md                          # This file
```

The scenario targets `subscription` scope, creates the resource group, then provisions the PostgreSQL Flexible Server with Entra ID-only authentication. When `enableObservability = true`, it additionally creates a Log Analytics workspace and routes all server logs and metrics to it via diagnostic settings.

The `postgresql_flexible_server` module handles all child resources inline:

| Child resource | Purpose |
| --- | --- |
| `flexibleServers/administrators` | Registers the Entra ID principal as server administrator |
| `flexibleServers/firewallRules` | Creates 0-N firewall rules from the `firewallRules` array |
| `flexibleServers/databases` | Creates 0-N databases from the `databases` array |
| `flexibleServers/configurations` | Sets `azure.extensions = VECTOR` when `enablePgvector = true` |

## Migration to `concierge`

The [`concierge` scenario](../concierge/README.md) consolidates this scenario with [Azure AI Foundry](../microsoft_foundry/README.md) support, providing a unified infrastructure deployment for the [ks6088ts-labs/concierge](https://github.com/ks6088ts-labs/concierge) application stack.

### Parameter Mapping

| `postgresql_flexible_server` Parameter | `concierge` Parameter | Notes |
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

### Migration Steps

1. **Update parameter file**: Rename PostgreSQL-specific parameters:
   - `version` → `postgresVersion`
   - `skuName` → `postgresSkuName`
   - `skuTier` → `postgresSkuTier`
   - `storageSizeGB` → `postgresStorageSizeGB`
   - `enableObservability` → `enableApplicationInsights`

2. **Add Foundry control** (optional): Set `enableApplicationInsights = false` in `main.bicepparam` if you don't need Application Insights observability (matches the behavior of this scenario with `enableObservability = false`).

3. **Update deployment commands**: Replace `SCENARIO=postgresql_flexible_server` with `SCENARIO=concierge` in `make deploy` commands, or update `azure.yaml` to point to `infra/scenarios/concierge`.

Example migration:

```bash
# Old deployment
make deploy SCENARIO=postgresql_flexible_server

# New deployment (PostgreSQL + Foundry full stack)
make deploy SCENARIO=concierge

# Or deploy PostgreSQL only without Foundry models (not recommended; use concierge for the full stack)
# The concierge scenario always includes Foundry; to deploy PostgreSQL standalone, continue using this scenario
```

### Benefits of Migrating to `concierge`

- **Unified stack**: Single scenario for Foundry + observability + PostgreSQL pgvector, matching the [concierge application](https://github.com/ks6088ts-labs/concierge) architecture
- **Feature flags**: Independent control of Application Insights (`enableApplicationInsights`) and PostgreSQL (`enablePostgresql`)
- **Maintained**: The `concierge` scenario will receive updates and improvements; this scenario is frozen
- **Same modules**: Uses identical underlying modules, so PostgreSQL behavior is consistent

For full documentation, see the [concierge scenario README](../concierge/README.md).

