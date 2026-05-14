[![test](https://github.com/ks6088ts/template-bicep/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/ks6088ts/template-bicep/actions/workflows/test.yml?query=branch%3Amain)

# template-bicep

A GitHub template repository for Bicep

## Scenarios

| Scenario | Overview | Deploy To Azure |
| --- | --- | --- |
| [hello_world](./infra/scenarios/hello_world/README.md) | A simple "Hello, World!" example using Bicep. | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fhello_world%2Fmain.json) |
| [concierge](./infra/scenarios/concierge/README.md) | Provision the concierge full stack (Azure AI Foundry + Application Insights tracing + PostgreSQL Flexible Server pgvector) with independent feature flags. | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fconcierge%2Fmain.json) |
| [microsoft_foundry](./infra/scenarios/microsoft_foundry/README.md) | Provision an Azure AI Foundry account, project, model deployments, and inference role assignments for existing identities. *(deprecated → concierge)* | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fmicrosoft_foundry%2Fmain.json) |
| [resource_group](./infra/scenarios/resource_group/README.md) | Provision a single resource group via a reusable module. | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fresource_group%2Fmain.json) |
| [postgresql_flexible_server](./infra/scenarios/postgresql_flexible_server/README.md) | Provision an Azure Database for PostgreSQL Flexible Server with Entra ID-only authentication, optional pgvector extension, and optional Azure Monitor observability. *(deprecated → concierge)* | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fpostgresql_flexible_server%2Fmain.json) |
| [user_assigned_managed_identity](./infra/scenarios/user_assigned_managed_identity/README.md) | Provision a User Assigned Managed Identity inside a dedicated resource group using reusable modules. | [![Deploy to Azure](https://aka.ms/deploytoazurebutton)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2Fks6088ts%2Ftemplate-bicep%2Frefs%2Fheads%2Fmain%2Finfra%2Fscenarios%2Fuser_assigned_managed_identity%2Fmain.json) |

## Deploy with Azure Developer CLI (azd)

The repository ships with an [`azure.yaml`](./azure.yaml) so the whole repo can be deployed with `azd up`. The scenario is hardcoded via `infra.path` in `azure.yaml`. To switch scenarios, edit that line directly (search for the `FIXME:` comment).

```bash
# 1. Create a new azd environment (prompts for subscription and location)
azd env new concierge

# 2. (Optional) Edit infra.path in azure.yaml to point to a different scenario,
#    e.g. infra/scenarios/resource_group

# 3. Provision Azure resources
azd up
```

To tear down:

```bash
azd down
```

### How scenario selection works

* [`azure.yaml`](./azure.yaml) points `infra.path` at a scenario directory under [`infra/scenarios/`](./infra/scenarios/) (default: `concierge`).
* To switch scenarios with `azd`, edit `infra.path` in `azure.yaml` directly.
* Each scenario remains independently deployable via the per-scenario `Makefile` targets (`make deploy SCENARIO=concierge`).

When you add a new scenario:

1. Create `infra/scenarios/<name>/main.bicep` and `main.bicepparam`.
2. Update `infra.path` in `azure.yaml` to `infra/scenarios/<name>` and run `azd up`.
