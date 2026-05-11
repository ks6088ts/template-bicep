---
title: User Assigned Managed Identity Scenario
description: A Bicep scenario that provisions a User Assigned Managed Identity inside a dedicated resource group via reusable modules
ms.date: 2026-05-11
---

# User Assigned Managed Identity Scenario

A Bicep scenario that provisions a User Assigned Managed Identity (UAMI) inside a dedicated resource group. It demonstrates the recommended layout for scenarios that compose multiple reusable modules under `infra/modules/`.

## Overview

This scenario targets the subscription scope and composes two reusable modules:

1. [`resource_group` module](../../modules/resource_group/main.bicep) — creates the resource group.
2. [`user_assigned_managed_identity` module](../../modules/user_assigned_managed_identity/main.bicep) — creates the UAMI inside that resource group.

The scenario layer is responsible for:

* Deriving resource names from a single `name` parameter.
* Composing inputs (name prefixes, default tags).
* Calling the modules with explicit parameters and correct dependency ordering.
* Surfacing the module outputs to deployment consumers.

## Parameters

| Parameter  | Type     | Default                                       | Description                                                        |
| ---------- | -------- | --------------------------------------------- | ------------------------------------------------------------------ |
| `name`     | `string` | _required_                                    | Scenario name used to derive resource group and UAMI names.        |
| `location` | `string` | _required_                                    | Azure region where the resource group and UAMI are created.        |
| `tags`     | `object` | `{ scenario: name, managedBy: 'bicep' }`      | Tags applied to all resources.                                     |

Resource names are derived as:
- Resource group: `rg-{name}`
- User Assigned Managed Identity: `id-{name}`

## Outputs

| Output                              | Type     | Description                                                    |
| ----------------------------------- | -------- | -------------------------------------------------------------- |
| `resourceGroupId`                   | `string` | Resource ID of the created resource group.                     |
| `resourceGroupName`                 | `string` | Name of the created resource group.                            |
| `resourceGroupLocation`             | `string` | Location of the created resource group.                        |
| `userAssignedIdentityId`            | `string` | Resource ID of the created User Assigned Managed Identity.     |
| `userAssignedIdentityName`          | `string` | Name of the created User Assigned Managed Identity.            |
| `userAssignedIdentityPrincipalId`   | `string` | Principal ID of the UAMI (used for role assignments).          |
| `userAssignedIdentityClientId`      | `string` | Client ID of the UAMI.                                         |
| `userAssignedIdentityTenantId`      | `string` | Tenant ID of the UAMI.                                         |

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
  --parameters name='user_assigned_managed_identity' location='japaneast'
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

The scenario targets `subscription` scope and first creates the resource group, then deploys the UAMI into it using `dependsOn` to ensure correct ordering.
