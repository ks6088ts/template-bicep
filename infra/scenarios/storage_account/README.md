---
title: Storage Account Scenario
description: A Bicep scenario that provisions an Azure Storage Account with Entra ID-only authentication, pre-created blob containers / queues / tables / file shares, and optional Azure Monitor observability
ms.date: 2026-05-16
---

# Storage Account Scenario

A Bicep scenario that provisions a general-purpose Azure Storage Account (`Microsoft.Storage/storageAccounts`) with Microsoft Entra ID-only authentication (shared key access disabled by default), pre-created blob containers, queues, tables, and file shares, optional role assignments for existing identities, and optionally Azure Monitor-based observability (Log Analytics workspace and diagnostic settings).

By default this scenario provisions a secure Storage Account with:
- Entra ID authentication required (shared key disabled)
- HTTPS-only traffic
- TLS 1.2 minimum
- Blob/queue/table/file soft delete enabled (7-day retention)
- A single default container/queue/table/share in each service

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`storage_account` module](../../modules/storage_account/main.bicep) — creates the Storage Account with blob/queue/table/file services and containers.
3. [`log_analytics_workspace` module](../../modules/log_analytics_workspace/main.bicep) — creates a Log Analytics workspace when observability is enabled.
4. [`diagnostic_settings` module](../../modules/diagnostic_settings/main.bicep) — routes Storage Account subservice (blob/queue/table/file) logs and metrics to Log Analytics when observability is enabled.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Storage Data roles to existing User Assigned Managed Identities, service principals, and users.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter (with Storage Account 24-character alphanumeric limit handling).
* Composing inputs (default tags, containers/queues/tables/shares).
* Optionally deploying Azure Monitor based observability when `enableObservability` is `true`.
* Optionally granting Storage Data Contributor roles to existing identities when `existingUserAssignedIdentities`, `existingServicePrincipalObjectIds`, or `existingUserObjectIds` are provided.
* Surfacing module outputs to deployment consumers.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and Storage Account. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `skuName` | `string` | `'Standard_LRS'` | Storage SKU (`Standard_LRS`, `Standard_GRS`, `Standard_ZRS`, `Premium_LRS`, etc.). |
| `kind` | `string` | `'StorageV2'` | Storage Account kind (`StorageV2`, `BlockBlobStorage`, `FileStorage`). |
| `accessTier` | `string` | `'Hot'` | Access tier (`'Hot'` or `'Cool'`). |
| `enableHierarchicalNamespace` | `bool` | `false` | Enable Data Lake Gen2 (hierarchical namespace). |
| `publicNetworkAccess` | `string` | `'Enabled'` | Public network access (`'Enabled'` or `'Disabled'`). |
| `allowSharedKeyAccess` | `bool` | `false` | Allow shared key (account key) access. When `false`, Entra ID-only authentication is enforced. |
| `blobContainers` | `array` | `[{ name: 'default' }]` | Blob containers to create. Each element: `{ name, publicAccess? }`. |
| `queues` | `array` | `[{ name: 'default' }]` | Queues to create. Each element: `{ name, metadata? }`. |
| `tables` | `array` | `[{ name: 'default' }]` | Tables to create. Each element: `{ name }`. |
| `fileShares` | `array` | `[{ name: 'default' }]` | File shares to create. Each element: `{ name, shareQuota?, accessTier? }`. |
| `existingUserAssignedIdentities` | `array` | `[]` | Existing User Assigned Managed Identities to grant Storage Data roles. Each element: `{ name, resourceGroup }`. |
| `existingServicePrincipalObjectIds` | `string[]` | `[]` | Existing service principal object IDs to grant Storage Data roles. |
| `existingUserObjectIds` | `string[]` | `[]` | Existing user object IDs to grant Storage Data roles. |
| `roleDefinitionIds` | `string[]` | `['ba92f5b4-2d11-453d-a403-e96b0029c9fe', ...]` | Role definition GUIDs to grant. Default: Storage Blob/Queue/Table/File Data Contributor. |
| `enableObservability` | `bool` | `false` | When `true`, deploys Log Analytics workspace and routes Storage diagnostics to it. |

## Outputs

| Output | Type | Description |
| --- | --- | --- |
| `resourceGroupId` | `string` | Resource ID of the created resource group. |
| `resourceGroupName` | `string` | Name of the created resource group. |
| `resourceGroupLocation` | `string` | Location of the created resource group. |
| `storageAccountId` | `string` | Resource ID of the created Storage Account. |
| `storageAccountName` | `string` | Name of the created Storage Account. |
| `blobEndpoint` | `string` | Blob service endpoint URL. |
| `queueEndpoint` | `string` | Queue service endpoint URL. |
| `tableEndpoint` | `string` | Table service endpoint URL. |
| `fileEndpoint` | `string` | File service endpoint URL. |
| `dfsEndpoint` | `string` | DFS endpoint URL (for HNS-enabled accounts). |
| `blobContainerNames` | `array` | Names of created blob containers. |
| `queueNames` | `array` | Names of created queues. |
| `tableNames` | `array` | Names of created tables. |
| `fileShareNames` | `array` | Names of created file shares. |
| `logAnalyticsWorkspaceId` | `string` | Resource ID of the created Log Analytics workspace (empty when `enableObservability = false`). |
| `uamiRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to User Assigned Managed Identities. |
| `servicePrincipalRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to service principals. |
| `userRoleAssignmentIds` | `array` | Resource IDs of role assignments granted to users. |

## Usage

The bundled `main.bicepparam` is ready to deploy as-is. By default it creates a Storage Account with Entra ID-only authentication and a single default container/queue/table/share in each service. No role assignments are granted by default—you must explicitly provide identity references to grant access.

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

To enable observability, uncomment `param enableObservability = true` in `main.bicepparam`. This deploys a Log Analytics workspace and configures diagnostic settings for all Storage subservices (blob/queue/table/file).

### Granting Storage Data Roles

To access Storage data with Entra ID, you must grant appropriate Storage Data roles. The scenario supports granting roles to:

1. **User Assigned Managed Identities (UAMI)** — recommended for application access:
   ```bicep
   param existingUserAssignedIdentities = [
     { name: 'id-myapp', resourceGroup: 'rg-identities' }
   ]
   ```

2. **Service Principals** — for CI/CD pipelines or service accounts:
   ```bash
   # Get service principal object ID (not application ID)
   az ad sp show --id <app-id> --query id --output tsv
   ```
   ```bicep
   param existingServicePrincipalObjectIds = [
     '00000000-0000-0000-0000-000000000000'
   ]
   ```

3. **Users** — for developer access:
   ```bash
   # Get your object ID
   az ad signed-in-user show --query id --output tsv
   ```
   ```bicep
   param existingUserObjectIds = [
     '00000000-0000-0000-0000-000000000000'
   ]
   ```

By default, the scenario grants four roles to each identity:
- **Storage Blob Data Contributor** (`ba92f5b4-2d11-453d-a403-e96b0029c9fe`)
- **Storage Queue Data Contributor** (`974c5e8b-45b9-4653-ba55-5f855dd0fb88`)
- **Storage Table Data Contributor** (`0a9a7e1f-b9d0-4cc4-a60d-0319b160aaa3`)
- **Storage File Data SMB Share Contributor** (`69566ab7-960f-475b-8e7c-b3118f30c6bd`)

You can override `roleDefinitionIds` in `main.bicepparam` to grant different roles (e.g., Reader roles instead of Contributor).

### Connecting with Entra ID (token-based, no account key)

Since `allowSharedKeyAccess` defaults to `false`, clients must authenticate with Entra ID tokens.

#### Azure CLI

```bash
# Upload a blob using Entra ID authentication
az storage blob upload \
  --account-name <storageAccountName> \
  --container-name default \
  --name myfile.txt \
  --file ./myfile.txt \
  --auth-mode login
```

#### Python with azure-identity

```python
from azure.identity import DefaultAzureCredential
from azure.storage.blob import BlobServiceClient

# Authenticate with DefaultAzureCredential (uses managed identity, CLI, etc.)
credential = DefaultAzureCredential()
account_url = f"https://<storageAccountName>.blob.core.windows.net"

blob_service_client = BlobServiceClient(account_url=account_url, credential=credential)

# List containers
for container in blob_service_client.list_containers():
    print(container.name)

# Upload a blob
blob_client = blob_service_client.get_blob_client(container="default", blob="myfile.txt")
with open("./myfile.txt", "rb") as data:
    blob_client.upload_blob(data, overwrite=True)
```

#### Queue Example

```python
from azure.identity import DefaultAzureCredential
from azure.storage.queue import QueueServiceClient

credential = DefaultAzureCredential()
account_url = f"https://<storageAccountName>.queue.core.windows.net"

queue_service_client = QueueServiceClient(account_url=account_url, credential=credential)
queue_client = queue_service_client.get_queue_client("default")

# Send a message
queue_client.send_message("Hello from Entra ID!")

# Receive messages
messages = queue_client.receive_messages()
for message in messages:
    print(message.content)
    queue_client.delete_message(message)
```

## Architecture

```text
infra/
├── modules/
│   ├── diagnostic_settings/
│   │   └── main.bicep                         # Reusable Diagnostic Settings module (extended for Storage)
│   ├── log_analytics_workspace/
│   │   └── main.bicep                         # Reusable Log Analytics Workspace module
│   ├── resource_group/
│   │   └── main.bicep                         # Reusable Resource Group module
│   ├── role_assignment/
│   │   └── main.bicep                         # Reusable Role Assignment module (extended for Storage)
│   └── storage_account/
│       └── main.bicep                         # NEW: Reusable Storage Account module
└── scenarios/
    └── storage_account/
        ├── main.bicep                         # NEW: Storage Account scenario (subscription scope)
        ├── main.bicepparam                    # NEW: Default parameters
        ├── main.json                          # NEW: Compiled ARM template
        └── README.md                          # This file
```

The scenario orchestrates module composition at subscription scope:

1. **Resource Group** — `rg-<name>` resource group is created first.
2. **Storage Account** — `st<name>` (alphanumeric, max 24 chars) with Entra ID-only auth, soft delete, and pre-created containers/queues/tables/shares.
3. **Log Analytics Workspace** (optional) — `law-<name>` created when `enableObservability = true`.
4. **Diagnostic Settings** (optional) — routes Storage subservice logs/metrics to Log Analytics when observability is enabled.
5. **Role Assignments** (optional) — grants Storage Data roles to identities when `existing*` arrays are non-empty.

## Security Considerations

### Entra ID-Only Authentication

By default, `allowSharedKeyAccess = false` disables account key and SAS token authentication. This enforces Entra ID-only access:

- **Pros**: Centralized identity management, audit trails, no shared secrets, automatic token rotation.
- **Cons**: Requires role assignments for every identity that needs access.

To temporarily allow account key access (not recommended for production):

```bicep
param allowSharedKeyAccess = true
```

### Network Security

By default, `publicNetworkAccess = 'Enabled'` with `networkAcls.defaultAction = 'Allow'`. For production:

1. Set `publicNetworkAccess = 'Disabled'` and configure Private Endpoints (not included in this scenario).
2. Or set `networkAcls.defaultAction = 'Deny'` and add IP allowlist rules via the `storage_account` module (extend as needed).

### Data Protection

Soft delete is enabled by default with 7-day retention for:
- Blob soft delete
- Container soft delete
- File share soft delete

To extend retention or enable versioning/change feed:

```bicep
param blobSoftDeleteRetentionDays = 30
param enableBlobVersioning = true
param enableChangeFeed = true
```

## Limitations

- **Kind Constraints**:
  - `BlockBlobStorage` does not support Queue/Table/File services.
  - `FileStorage` does not support Blob/Queue/Table services.
  - The module conditionally creates subservices based on `kind`.
- **Private Endpoint**: Not included. Configure manually or extend the module.
- **Customer-Managed Keys (CMK)**: Not included. Extend the module to add Key Vault integration.

## References

- [Microsoft.Storage/storageAccounts (Bicep)](https://learn.microsoft.com/azure/templates/microsoft.storage/storageaccounts)
- [Authorize access to blobs using Microsoft Entra ID](https://learn.microsoft.com/azure/storage/blobs/authorize-access-azure-active-directory)
- [Prevent Shared Key authorization](https://learn.microsoft.com/azure/storage/common/shared-key-authorization-prevent)
- [Azure built-in roles for Storage](https://learn.microsoft.com/azure/role-based-access-control/built-in-roles/storage)
