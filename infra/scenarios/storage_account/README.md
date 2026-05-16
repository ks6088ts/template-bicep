---
title: Storage Account Scenario
description: A Bicep scenario that provisions a general-purpose Azure Storage Account with Entra ID-only authentication, pre-created containers/queues/tables/shares, and optional Azure Monitor observability
ms.date: 2026-05-16
---

# Storage Account Scenario

A Bicep scenario that provisions an Azure Storage Account (`Microsoft.Storage/storageAccounts`) with Microsoft Entra ID-first security defaults (Shared Key disabled by default), optional pre-created Blob containers / Queues / Tables / File shares, and optional Azure Monitor-based observability (Log Analytics workspace and diagnostic settings for the blob/queue/table/file sub-services).

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`storage_account` module](../../modules/storage_account/main.bicep) — creates the Storage Account, configures Entra ID-first defaults, and optionally creates containers/queues/tables/shares.
3. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when observability is enabled.
4. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes Storage sub-service diagnostics (blob/queue/table/file) to Log Analytics when observability is enabled.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Storage data roles at Storage Account scope when principal arrays are provided.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Forwarding storage configuration parameters to the reusable module.
* Optionally deploying Azure Monitor based observability when `enableObservability` is `true`.
* Optionally granting RBAC roles when identity/principal arrays are non-empty.
* Surfacing module outputs to deployment consumers.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and Storage Account resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `skuName` | `string` | `'Standard_LRS'` | Storage SKU (`Standard_LRS`, `Standard_GRS`, `Standard_RAGRS`, `Standard_ZRS`, `Standard_GZRS`, `Standard_RAGZRS`, `Premium_LRS`). |
| `kind` | `string` | `'StorageV2'` | Storage kind (`StorageV2`, `BlockBlobStorage`, `FileStorage`). |
| `accessTier` | `string` | `'Hot'` | Access tier (`Hot`, `Cool`). StorageV2 only. |
| `enableHierarchicalNamespace` | `bool` | `false` | When `true`, enables hierarchical namespace (Data Lake Storage Gen2). StorageV2 only. |
| `publicNetworkAccess` | `string` | `'Enabled'` | Public network access (`Enabled`/`Disabled`). |
| `allowSharedKeyAccess` | `bool` | `false` | Escape hatch to re-enable Shared Key authorization. Defaults to `false` (Entra ID-only access). |
| `blobContainers` | `array` | `[{ name: 'default' }]` | Blob containers to create. Each element: `{ name, publicAccess? }` (`publicAccess` defaults to `None`). |
| `queues` | `array` | `[{ name: 'default' }]` | Queues to create. Each element: `{ name, metadata? }`. |
| `tables` | `array` | `[{ name: 'default' }]` | Tables to create. Each element: `{ name }`. |
| `fileShares` | `array` | `[{ name: 'default' }]` | File shares to create. Each element: `{ name, shareQuota?, accessTier? }`. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to grant roles to. Each element: `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Optional. Entra service principal object IDs to grant roles to. |
| `existingUserObjectIds` | `string[]` | `[]` | Optional. Entra user object IDs to grant roles to. |
| `roleDefinitionIds` | `string[]` | _(see main.bicep)_ | Role definition GUIDs to grant to every principal (defaults to Blob/Queue/Table/File data contributor roles). |
| `enableObservability` | `bool` | `false` | When `true`, deploys Log Analytics workspace and routes Storage diagnostics to it. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `storageAccountId` | `string` | Resource ID of the created Storage Account. |
| `storageAccountName` | `string` | Name of the created Storage Account. |
| `blobEndpoint` | `string` | Blob endpoint URL. |
| `queueEndpoint` | `string` | Queue endpoint URL. |
| `tableEndpoint` | `string` | Table endpoint URL. |
| `fileEndpoint` | `string` | File endpoint URL. |
| `dfsEndpoint` | `string` | DFS endpoint URL (meaningful when `enableHierarchicalNamespace = true`). |
| `blobContainerNames` | `array` | Names of created blob containers. |
| `queueNames` | `array` | Names of created queues. |
| `tableNames` | `array` | Names of created tables. |
| `fileShareNames` | `array` | Names of created file shares. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the created Log Analytics workspace (empty when `enableObservability = false`). |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs created for UAMIs. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs created for service principals. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs created for users. |

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
make deploy SCENARIO=storage_account
```

### Important: no RBAC granted by default

This scenario intentionally does **not** grant Storage data roles to the deployment principal by default (the `existing*` arrays default to empty). After deployment, add yourself (or your app identity) to `existingUserAssignedIdentities` / `existingServicePrincipalObjectIds` / `existingUserObjectIds`, or create role assignments out-of-band.

## Architecture

```text
infra/
├── modules/
│   ├── diagnostic_settings/
│   │   └── main.bicep                         # Reusable Diagnostic Settings module (CognitiveServices + PostgreSQL + Storage sub-services)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics Workspace module
│   ├── resource_group/
│   │   └── main.bicep                         # Reusable resource group module
│   ├── role_assignment/
│   │   └── main.bicep                         # Reusable role assignment module (CognitiveServices + Storage)
│   └── storage_account/
│       └── main.bicep                         # Reusable Storage Account module (this scenario uses this module)
└── scenarios/
    └── storage_account/
        ├── main.bicep                         # Scenario entry point (this scenario)
        ├── main.bicepparam                    # Parameter file
        ├── main.json                          # Compiled ARM template
        └── README.md                          # This file
```

The scenario targets `subscription` scope, creates the resource group, then provisions the Storage Account with Entra ID-first defaults. When `enableObservability = true`, it additionally creates a Log Analytics workspace and configures diagnostic settings for the blob/queue/table/file sub-services to route all logs and metrics to Log Analytics.

### Notes on `kind` vs sub-services

The default `kind = 'StorageV2'` supports Blob/Queue/Table/File. If you change `kind`, ensure you also adjust the arrays:

* `kind = 'BlockBlobStorage'`: Blob only (set `queues`, `tables`, `fileShares` to `[]`).
* `kind = 'FileStorage'`: File only (set `blobContainers`, `queues`, `tables` to `[]`).

## Connecting with Entra ID (no Shared Key)

The Storage Account module defaults to `allowSharedKeyAccess = false` and `defaultToOAuthAuthentication = true`. Use Entra ID-based auth flows (managed identity or user login).

### Azure CLI example

```bash
az storage blob upload \
  --account-name <storageAccountName> \
  --container-name default \
  --name hello.txt \
  --file ./hello.txt \
  --auth-mode login
```

### Python examples (Blob + Queue)

Blob:

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

credential = DefaultAzureCredential()
client = BlobServiceClient(account_url="https://<storageAccountName>.blob.core.windows.net", credential=credential)

container = client.get_container_client("default")
container.upload_blob("hello.txt", b"hello", overwrite=True)
```

Queue:

```python
from azure.identity import DefaultAzureCredential
from azure.storage.queue import QueueClient

credential = DefaultAzureCredential()
queue = QueueClient(account_url="https://<storageAccountName>.queue.core.windows.net", queue_name="default", credential=credential)

queue.send_message("hello")
```

## RBAC role assignment notes

To grant roles via this scenario, you need the principal object IDs.

| Principal | Lookup | Notes |
| --- | --- | --- |
| Signed-in user | `az ad signed-in-user show --query id -o tsv` | Use this for `existingUserObjectIds`. |
| Service principal | `az ad sp show --id <appId> --query id -o tsv` | Use the app registration's client ID (`appId`) to look up its object ID. |
| Managed identity (UAMI) | `az identity show -g <rg> -n <name> --query principalId -o tsv` | Use this for `existingUserAssignedIdentities`. |

## Re-enabling Shared Key (`allowSharedKeyAccess = true`)

Only enable Shared Key authorization when you fully understand the implications (account keys and SAS tokens are bearer credentials). Prefer Entra ID with managed identities for application access.

