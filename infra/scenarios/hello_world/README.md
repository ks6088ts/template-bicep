---
title: Hello World Scenario
description: A minimal Bicep scenario demonstrating basic template structure and unique name generation
ms.date: 2026-02-17
---

# Hello World Scenario

A minimal Bicep template that demonstrates the basic structure of a Bicep scenario and generates a unique name using Azure's `uniqueString` function.

## Overview

This scenario serves as a starting point for understanding Bicep template structure. It creates a deterministic unique identifier based on the subscription ID, location, and provided name.

## Parameters

| Parameter  | Type   | Description                      |
| ---------- | ------ | -------------------------------- |
| `name`     | string | The name of the scenario         |
| `location` | string | The location for the deployment  |

## Outputs

| Output       | Type   | Description                                             |
| ------------ | ------ | ------------------------------------------------------- |
| `randomName` | string | A unique name generated from subscription and location  |

## Usage

Deploy the scenario using Azure CLI:

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
  --parameters name='hello_world' location='japaneast'
```

## Architecture

This scenario targets the subscription scope (`targetScope = 'subscription'`) and uses the `uniqueString` function to generate a deterministic hash based on:

* Subscription ID
* Location
* Provided name

The generated name follows the pattern: `{name}-{uniqueHash}`
