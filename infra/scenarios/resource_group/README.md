---
title: Resource Group Scenario
description: A Bicep scenario that provisions a single resource group via a reusable module
ms.date: 2026-05-11
---

# Resource Group Scenario

A skeleton Bicep scenario that provisions a single Azure resource group through a reusable module. It demonstrates the recommended layout for scenarios that depend on shared modules under `infra/modules/`.

## Overview

This scenario targets the subscription scope and delegates the actual resource group creation to the [`resource_group` module](../../modules/resource_group/main.bicep). The module is the single source of truth for the `Microsoft.Resources/resourceGroups` resource, and the scenario layer is responsible for:

* Composing inputs (name prefixes, default tags).
* Calling the module with explicit parameters.
* Surfacing the module outputs to deployment consumers.

## Parameters

| Parameter  | Type     | Default                                       | Description                                                |
| ---------- | -------- | --------------------------------------------- | ---------------------------------------------------------- |
| `name`     | `string` | _required_                                    | Scenario name used to derive the resource group name.      |
| `location` | `string` | _required_                                    | Azure region where the resource group is created.          |
| `tags`     | `object` | `{ scenario: name, managedBy: 'bicep' }`      | Tags applied to the resource group.                        |

The resource group name is derived as `rg-{name}`.

## Outputs

| Output                  | Type     | Description                                  |
| ----------------------- | -------- | -------------------------------------------- |
| `resourceGroupId`       | `string` | Resource ID of the created resource group.   |
| `resourceGroupName`     | `string` | Name of the created resource group.          |
| `resourceGroupLocation` | `string` | Location of the created resource group.      |

## Usage

Deploy with the bundled `bicepparam` file:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters main.bicepparam
```

Or with inline parameters:

```bash
az deployment sub create \
  --location japaneast \
  --template-file main.bicep \
  --parameters name='resource_group' location='japaneast'
```

Using the repository `Makefile`:

```bash
make deploy SCENARIO=resource_group
```

## Architecture

```text
infra/
├── modules/
│   └── resource_group/
│       └── main.bicep       # Reusable resource group module
└── scenarios/
    └── resource_group/
        ├── main.bicep       # Scenario entry point (this scenario)
        ├── main.bicepparam  # Parameter file
        └── main.json        # Compiled ARM template
```

The scenario targets `subscription` scope and invokes the module through a `module` declaration with a relative path. The module is itself subscription-scoped because resource groups are subscription-level resources.
