---
title: Storage Account Scenario
description: A Bicep scenario that provisions a general-purpose Azure Storage Account with Entra ID-first authentication, pre-created data-plane containers/services, and optional Azure Monitor observability
ms.date: 2026-05-16
---

# Storage Account Scenario

A Bicep scenario that provisions an Azure Storage Account (`Microsoft.Storage/storageAccounts`) with Entra ID-first defaults (Shared Key disabled by default), pre-created Blob containers / Queues / Tables / File Shares, optional RBAC role assignments for existing identities, and optional Azure Monitor observability.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`storage_account` module](../../modules/storage_account/main.bicep) — creates the storage account and data-plane boxes (Blob containers / Queues / Tables / File Shares).
3. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when observability is enabled.
4. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes storage sub-service logs/metrics (`blob`, `queue`, `table`, `file`) to Log Analytics when observability is enabled.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Storage Data roles to any combination of existing UAMIs, service principals, and users.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Enforcing secure storage defaults (Entra ID-first, no anonymous blob, HTTPS only).
* Expanding identity arrays × `roleDefinitionIds` cross-products into role assignments.
* Optionally deploying observability when `enableObservability` is `true`.
* Surfacing module outputs to deployment consumers.

> [!NOTE]
> Service availability depends on `kind`:
>
> * `StorageV2`: Blob/Queue/Table/File are available.
> * `BlockBlobStorage`: Queue/Table/File are unavailable.
> * `FileStorage`: Blob/Queue/Table are unavailable.
>
> For unsupported services, this scenario/module emits no corresponding child resources.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and storage resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `skuName` | `string` | `'Standard_LRS'` | Storage SKU (`Standard_LRS`, `Standard_GRS`, `Standard_RAGRS`, `Standard_ZRS`, `Standard_GZRS`, `Standard_RAGZRS`, `Premium_LRS`). |
| `kind` | `string` | `'StorageV2'` | Storage kind (`StorageV2`, `BlockBlobStorage`, `FileStorage`). |
| `accessTier` | `string` | `'Hot'` | Access tier (`Hot`, `Cool`). |
| `enableHierarchicalNamespace` | `bool` | `false` | Enables Data Lake Gen2 (HNS). |
| `publicNetworkAccess` | `string` | `'Enabled'` | Public network access (`Enabled` or `Disabled`). |
| `allowSharedKeyAccess` | `bool` | `false` | Escape hatch to re-enable Shared Key authorization when required by legacy clients. |
| `blobContainers` | `array` | `[{ name: 'default' }]` | Blob containers to create. Element: `{ name, publicAccess? }`. |
| `queues` | `array` | `[{ name: 'default' }]` | Queues to create. Element: `{ name, metadata? }`. |
| `tables` | `array` | `[{ name: 'default' }]` | Tables to create. Element: `{ name }`. |
| `fileShares` | `array` | `[{ name: 'default' }]` | File shares to create. Element: `{ name, shareQuota?, accessTier? }`. |
| `existingUserAssignedIdentities` | `array` | `[]` | Existing UAMIs to grant Storage Data roles. Each item is `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Existing service principal object IDs to grant Storage Data roles. |
| `existingUserObjectIds` | `array` | `[]` | Existing user object IDs to grant Storage Data roles. |
| `roleDefinitionIds` | `array` | `['ba92f5b4-2d11-453d-a403-e96b0029c9fe','974c5e8b-45b9-4653-ba55-5f855dd0fb88','0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3','69566ab7-960f-475b-8e7c-b3118f30c6bd']` | Role definition GUIDs assigned at storage account scope (Blob/Queue/Table/File Data Contributor defaults). |
| `enableObservability` | `bool` | `false` | When `true`, deploys Log Analytics + diagnostic settings for storage sub-services. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `storageAccountId` | `string` | Resource ID of the created storage account. |
| `storageAccountName` | `string` | Name of the created storage account. |
| `blobEndpoint` | `string` | Blob endpoint URL. |
| `queueEndpoint` | `string` | Queue endpoint URL. |
| `tableEndpoint` | `string` | Table endpoint URL. |
| `fileEndpoint` | `string` | File endpoint URL. |
| `dfsEndpoint` | `string` | DFS endpoint URL (meaningful when HNS is enabled). |
| `blobContainerNames` | `array` | Names of created blob containers. |
| `queueNames` | `array` | Names of created queues. |
| `tableNames` | `array` | Names of created tables. |
| `fileShareNames` | `array` | Names of created file shares. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of created Log Analytics workspace (empty when `enableObservability = false`). |
| `uamiRoleAssignmentIds` | `array` | Role assignment IDs for supplied UAMIs. |
| `servicePrincipalRoleAssignmentIds` | `array` | Role assignment IDs for supplied service principals. |
| `userRoleAssignmentIds` | `array` | Role assignment IDs for supplied users. |

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

The bundled `main.bicepparam` is ready-to-deploy as-is. By default, role assignment arrays are empty, so **no data-plane RBAC is granted automatically**. Add your UAMI/SP/User IDs in `main.bicepparam` (or run `az role assignment create`) before testing data access.

Because storage account names must be globally unique, 3-24 chars, lowercase alphanumeric, this scenario derives:

```bicep
storageAccountName = take(toLower(replace(replace('st${name}', '_', ''), '-', '')), 24)
```

If name collisions occur, use a unique suffix in `name` (for example append part of `uniqueString(subscription().id, name)`).

### Entra ID authentication examples

Python (Blob):

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

account_url = "https://<storage-account-name>.blob.core.windows.net"
client = BlobServiceClient(account_url=account_url, credential=DefaultAzureCredential())
container_client = client.get_container_client("default")
container_client.upload_blob(name="hello.txt", data=b"hello", overwrite=True)
```

Python (Queue):

```python
from azure.identity import DefaultAzureCredential
from azure.storage.queue import QueueClient

client = QueueClient(
    account_url="https://<storage-account-name>.queue.core.windows.net",
    queue_name="default",
    credential=DefaultAzureCredential(),
)
client.send_message("hello from Entra ID")
```

Azure CLI (`--auth-mode login`):

```bash
az storage blob upload \
  --account-name <storage-account-name> \
  --container-name default \
  --name hello.txt \
  --file ./hello.txt \
  --auth-mode login
```

### RBAC role assignment notes

Each optional identity array expects IDs whose Entra type matches the scenario's `principalType` used for assignment.

| Parameter | Expected Entra type | Retrieval example |
| --- | --- | --- |
| `existingServicePrincipalObjectIds` | `ServicePrincipal` (Enterprise Application object ID, not application/client ID) | `az ad sp show --id <application-id-or-name> --query id --output tsv` |
| `existingUserObjectIds` | `User` | `az ad signed-in-user show --query id --output tsv` or `az ad user show --id <upn-or-objectid> --query id --output tsv` |
| `existingUserAssignedIdentities` | `ServicePrincipal` (managed identity) | `az identity show --name <uami-name> --resource-group <rg-name> --query principalId --output tsv` |

Default `roleDefinitionIds`:

* `ba92f5b4-2d11-453d-a403-e96b0029c9fe` — Storage Blob Data Contributor
* `974c5e8b-45b9-4653-ba55-5f855dd0fb88` — Storage Queue Data Contributor
* `0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3` — Storage Table Data Contributor
* `69566ab7-960f-475b-8e7c-b3118f30c6bd` — Storage File Data SMB Share Contributor

> [!WARNING]
> Keep `allowSharedKeyAccess = false` unless strictly required for compatibility with clients/tools that cannot use Entra ID. Re-enabling Shared Key broadens credential attack surface and enables account-key based access paths.

## Architecture

```text
infra/
├── modules/
│   ├── diagnostic_settings/
│   │   └── main.bicep                       # Reusable Diagnostic Settings module (Foundry + PostgreSQL + Storage services)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                       # Reusable Log Analytics Workspace module
│   ├── resource_group/
│   │   └── main.bicep                       # Reusable resource group module
│   ├── role_assignment/
│   │   └── main.bicep                       # Reusable role assignment module (Foundry + Storage scopes)
│   └── storage_account/
│       └── main.bicep                       # Reusable storage account module
└── scenarios/
    └── storage_account/
        ├── main.bicep                       # Scenario entry point (this scenario)
        ├── main.bicepparam                  # Parameter file
        ├── main.json                        # Compiled ARM template
        └── README.md                        # This file
```

The scenario targets `subscription` scope, creates the resource group, then provisions the storage account and requested data-plane boxes. When `enableObservability = true`, it also creates a Log Analytics workspace and applies diagnostic settings to selected storage services (`blob`, `queue`, `table`, `file`). RBAC role assignments are emitted as cross-products of each identity array and `roleDefinitionIds`.
