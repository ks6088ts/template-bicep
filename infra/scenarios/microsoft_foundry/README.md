---
title: Microsoft Foundry Scenario
description: A Bicep scenario that provisions Azure AI Foundry account, project, model deployments, and role assignments for an existing User Assigned Managed Identity
ms.date: 2026-05-11
---

# Microsoft Foundry Scenario

A Bicep scenario that provisions an Azure AI Foundry account (`Microsoft.CognitiveServices/accounts`), a Foundry project, model deployments, and scope-limited role assignments for an existing User Assigned Managed Identity (UAMI).

## Overview

This scenario targets the subscription scope and composes reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`microsoft_foundry` module](../../modules/microsoft_foundry/main.bicep) — creates the Azure AI Foundry account.
3. [`microsoft_foundry_project` module](../../modules/microsoft_foundry_project/main.bicep) — creates the Foundry project under the account.
4. [`microsoft_foundry_model_deployment` module](../../modules/microsoft_foundry_model_deployment/main.bicep) — creates model deployments under the account.
5. [`role_assignment` module](../../modules/role_assignment/main.bicep) — grants Foundry inference permissions to the existing UAMI at account scope.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Composing inputs (default tags, model list, role definition IDs).
* Referencing an existing UAMI by name and resource group.
* Deploying models sequentially with `@batchSize(1)` to avoid concurrent deployment conflicts.
* Surfacing module outputs to deployment consumers.

By default, role assignment uses **Cognitive Services OpenAI User** (`5e0bd9bd-7b93-4f28-af87-19fc36ad61bd`) because it is the stable, minimal permission set for model inference calls against the Foundry account.

## Parameters

| Parameter | Type | Default | Description |
| --- | --- | --- | --- |
| `name` | `string` | _(required)_ | Scenario name used to derive resource names. |
| `location` | `string` | _(required)_ | Azure region for the resource group and Foundry resources. |
| `tags` | `object` | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to created resources. |
| `existingUserAssignedIdentityName` | `string` | _(required)_ | Existing UAMI name to grant Foundry call permissions. |
| `existingUserAssignedIdentityResourceGroupName` | `string` | _(required)_ | Resource group containing the existing UAMI. |
| `models` | `array` | See `main.bicep` | Model deployments to create under the Foundry account. |
| `roleDefinitionIds` | `array` | `['5e0bd9bd-7b93-4f28-af87-19fc36ad61bd']` | Role definition GUIDs to assign to the UAMI at Foundry account scope. |

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
| `roleAssignmentIds` | `array` | Resource IDs of created role assignments. |

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

The scenario targets `subscription` scope, creates the resource group and Foundry resources, deploys models sequentially, and then grants inference permissions on the Foundry account to the referenced existing UAMI.
