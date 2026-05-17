---
title: User Assigned Managed Identity Scenario
description: A Bicep scenario that provisions multiple User Assigned Managed Identities inside a dedicated resource group via reusable modules
ms.date: 2026-05-14
---

# User Assigned Managed Identity Scenario

A Bicep scenario that provisions one or more User Assigned Managed Identities (UAMIs) inside a dedicated resource group. It demonstrates the recommended layout for scenarios that compose multiple reusable modules under `infra/modules/`.

## Overview

This scenario targets the subscription scope and composes two reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates each UAMI inside that resource group (called once per entry in `userAssignedIdentities`).

The scenario layer is responsible for:

* Deriving the resource group name from a single `name` parameter.
* Composing inputs (UAMI names, default tags).
* Calling the modules with explicit parameters and correct dependency ordering.
* Surfacing the module outputs to deployment consumers.

## Parameters

| Parameter                  | Type                          | Default                                  | Description                                                                                              |
| -------------------------- | ----------------------------- | ---------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `name`                     | `string`                      | _required_                               | Scenario name used to derive the resource group name (`rg-templatebicep-{name}`) and the default `scenario` tag. |
| `location`                 | `string`                      | _required_                               | Azure region where the resource group and all UAMIs are created.                                         |
| `tags`                     | `object`                      | `{ scenario: name, managedBy: 'bicep' }` | Tags applied to all resources.                                                                           |
| `userAssignedIdentities`   | `userAssignedIdentitySpec[]`  | _required_                               | Array of UAMIs to create. Each entry must have a `name` field (full UAMI resource name).                 |

Resource names are derived as:

* Resource group: `rg-templatebicep-{name}`
* User Assigned Managed Identity: as specified by each `userAssignedIdentities[].name` entry

## Outputs

| Output                        | Type     | Description                                                                      |
| ----------------------------- | -------- | -------------------------------------------------------------------------------- |
| `resourceGroupId`             | `string` | Resource ID of the created resource group.                                       |
| `resourceGroupName`           | `string` | Name of the created resource group.                                              |
| `resourceGroupLocation`       | `string` | Location of the created resource group.                                          |
| `userAssignedIdentities`      | `array`  | Array of objects (same order as input), each with `id`, `name`, `principalId`, `clientId`, and `tenantId`. |

## Usage

Deploy with the bundled `bicepparam` file:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Using the repository `Makefile`:

```bash
make deploy SCENARIO=user_assigned_managed_identity
```

## Architecture

```text
infra/
├── modules/
│   ├── resource_group/
│   │   └── main.bicep       # Reusable resource group module
│   └── user_assigned_managed_identity/
│       └── main.bicep       # Reusable UAMI module
└── scenarios/
    └── user_assigned_managed_identity/
        ├── main.bicep       # Scenario entry point (this scenario)
        ├── main.bicepparam  # Parameter file
        ├── main.json        # Compiled ARM template
        └── README.md        # This file
```

The scenario targets `subscription` scope and first creates the resource group, then deploys all UAMIs into it using `dependsOn` to ensure correct ordering. Each UAMI in `userAssignedIdentities` is deployed as a separate module instance via a `for` loop.
