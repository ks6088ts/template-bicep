---
title: Microsoft Foundry Scenario
description: A Bicep scenario that provisions Azure AI Foundry account, project, model deployments, and optional role assignments for any number of existing User Assigned Managed Identities, service principals, or users
ms.date: 2026-05-11
---

# Microsoft Foundry Scenario

A Bicep scenario that provisions an Azure AI Foundry account (`Microsoft.CognitiveServices/accounts`), a Foundry project, model deployments, and (optionally) scope-limited role assignments for any number of existing User Assigned Managed Identities (UAMI), Microsoft Entra service principals, and Microsoft Entra users.

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep) — creates the Azure AI Foundry account.
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep) — creates the Foundry project under the account.
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep) — creates model deployments under the account.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Foundry inference permissions to any combination of existing UAMIs, service principals, and users at account scope (all opt-in via array parameters).

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Composing inputs (default tags, model list, role definition IDs).
* Accepting three independent array parameters — UAMIs, service principal object IDs, and user object IDs — each defaulting to `[]`. **By default, no role assignments are created**, and supplying any non-empty array opts that category in.
* Deploying models sequentially with `@batchSize(1)` to avoid concurrent deployment conflicts.
* Surfacing module outputs to deployment consumers.

For every supplied identity, the scenario emits one role assignment per entry in `roleDefinitionIds`. The default `roleDefinitionIds` is **Cognitive Services OpenAI User** (`5e0bd9bd-7b93-4f28-af87-19fc36ad61bd`), the stable minimal permission set for model inference calls against the Foundry account. Each category has a dedicated `principalType` (`'ServicePrincipal'` for UAMIs and service principals, `'User'` for users) — placing an ID under the wrong array will cause Azure RBAC to reject the deployment with `UnmatchedPrincipalType`.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and Foundry resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `existingUserAssignedIdentities` | `array` | `[]` | Optional. Existing UAMIs to grant Foundry call permissions. Each item is `{ name: string, resourceGroup: string }`. Leave empty to skip the role assignment. |
| `existingServicePrincipalObjectIds` | `array` | `[]` | Optional. Object (principal) IDs of existing Microsoft Entra service principals to grant Foundry call permissions. Use service principal object IDs (Enterprise Application), not the application/client IDs. Leave empty to skip the role assignment. |
| `existingUserObjectIds` | `array` | `[]` | Optional. Object IDs of existing Microsoft Entra users to grant Foundry call permissions. Leave empty to skip the role assignment. |
| `models` | `array` | See `main.bicep` | Model deployments to create under the Foundry account. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs to assign at Foundry account scope. For each role, one role assignment is emitted per supplied identity in each of the three identity arrays. |

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
make deploy SCENARIO=microsoft_foundry
```

If target region does not support one of the default models (`gpt-5.4`, `gpt-5.4-nano`, `text-embedding-3-large`, `text-embedding-3-small`), edit `main.bicepparam` and remove/replace unsupported entries in `models` (for example, use `gpt-5` or `gpt-5-mini`).

This scenario sets `disableLocalAuth: true` on the Foundry account so API keys are disabled and Entra ID (for example UAMI) is required.

```python
from azure.identity import DefaultAzureCredential
from openai import AzureOpenAI

client = AzureOpenAI(
    azure_endpoint="https://<foundry-account-name>.cognitiveservices.azure.com/",
    azure_ad_token_provider=DefaultAzureCredential(),
    api_version="2024-10-21"
)

response = client.chat.completions.create(
    model="gpt-5.4",
    messages=[{"role": "user", "content": "Hello from UAMI"}]
)
print(response.choices[0].message.content)
```

## Architecture

```text
infra/
├── modules/
│   ├── microsoft_foundry/
│   │   └── main.bicep                       # Reusable Azure AI Foundry account module
│   ├── microsoft_foundry_model_deployment/
│   │   └── main.bicep                       # Reusable model deployment module
│   ├── microsoft_foundry_project/
│   │   └── main.bicep                       # Reusable Foundry project module
│   ├── resource_group/
│   │   └── main.bicep                       # Reusable resource group module
│   └── role_assignment/
│       └── main.bicep                       # Reusable role assignment module
└── scenarios/
    └── microsoft_foundry/
        ├── main.bicep                       # Scenario entry point (this scenario)
        ├── main.bicepparam                  # Parameter file
        ├── main.json                        # Compiled ARM template
        └── README.md                        # This file
```

The scenario targets `subscription` scope, creates the resource group and Foundry resources, and deploys models sequentially. When any of the three identity arrays is non-empty, it also grants inference permissions on the Foundry account to those identities; one role assignment is emitted per (identity, roleDefinitionId) pair.

### Looking up principal object IDs

Each optional identity array expects IDs whose actual Microsoft Entra type matches the hardcoded `principalType` for that category. Placing an ID under the wrong category results in a deployment-time `UnmatchedPrincipalType` error from Azure RBAC.

| Parameter | Expected Entra type | Retrieval example |
| --- | --- | --- |
| `existingServicePrincipalObjectIds` | `ServicePrincipal` (Enterprise Application object ID, not application/client ID) | `az ad sp show --id <application-id-or-name> --query id --output tsv` |
| `existingUserObjectIds` | `User` | `az ad signed-in-user show --query id --output tsv` or `az ad user show --id <upn-or-objectid> --query id --output tsv` |
| `existingUserAssignedIdentities` | `ServicePrincipal` (managed identity) | `az identity show --name <uami-name> --resource-group <rg-name>` |
