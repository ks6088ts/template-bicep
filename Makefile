# Git
GIT_REVISION ?= $(shell git rev-parse --short HEAD)
GIT_TAG ?= $(shell git describe --tags --abbrev=0 | sed -e s/v//g)

# Azure
APPLICATION_ID ?= $(shell az ad sp list --display-name $(APPLICATION_NAME) --query "[0].appId" --output tsv)
APPLICATION_NAME ?= "template-bicep_dev"
SUBSCRIPTION_ID ?= $(shell az account show --query id --output tsv)
SUBSCRIPTION_NAME ?= $(shell az account show --query name --output tsv)
TENANT_ID ?= $(shell az account show --query tenantId --output tsv)

# Bicep
SCENARIO ?= hello_world
SCENARIO_DIR ?= infra/scenarios/$(SCENARIO)
SCENARIO_DIR_LIST ?= $(shell find infra/scenarios -maxdepth 1 -mindepth 1 -type d -print)
RESOURCE_GROUP ?= rg-$(SCENARIO)
LOCATION ?= japaneast
DEPLOYMENT_NAME ?= $(SCENARIO)_deployment

.PHONY: help
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
.DEFAULT_GOAL := help

.PHONY: info
info: ## show information
	@echo "SUBSCRIPTION_ID: $(SUBSCRIPTION_ID)"
	@echo "SUBSCRIPTION_NAME: $(SUBSCRIPTION_NAME)"
	@echo "TENANT_ID: $(TENANT_ID)"
	@echo "GIT_REVISION: $(GIT_REVISION)"
	@echo "GIT_TAG: $(GIT_TAG)"

.PHONY: install-deps-dev
install-deps-dev: ## install dependencies for development
	@which az > /dev/null || echo "Please install Azure CLI: https://docs.microsoft.com/cli/azure/install-azure-cli"
	@which gh > /dev/null || echo "Please install GitHub CLI: https://cli.github.com/"
	@which trivy > /dev/null || echo "Please install Trivy: https://aquasecurity.github.io/trivy/v0.57/getting-started/installation/"

.PHONY: lint
lint: ## lint bicep files
	@find $(SCENARIO_DIR) \
		-name '*.bicep' \
		-type f \
		| xargs -I {} sh -c ' \
			echo "Linting: {}" && \
			az bicep lint --file {} || exit 255 \
		'

.PHONY: trivy
trivy: ## run trivy security scan
	trivy config $(SCENARIO_DIR)

.PHONY: fix
fix: ## fix formatting
	@find $(SCENARIO_DIR) \
		-name '*.bicep' \
		-type f \
		-exec az bicep format \
			--file {} \
			--insert-final-newline \;

.PHONY: build
build: ## build bicep files
	az bicep build --file $(SCENARIO_DIR)/main.bicep

.PHONY: git-diff
git-diff: ## check git diff (if there are changes, it means the bicep files are not synced with the built files)
	@if [ -n "$$(git status --porcelain)" ]; then \
		echo "Error: Bicep files are not synced with built files. Please commit your changes." ; \
		exit 1 ; \
	fi

.PHONY: test
test: ## test bicep files (what-if deployment)
	az deployment sub what-if \
		--name $(DEPLOYMENT_NAME) \
		--location $(LOCATION) \
		--template-file $(SCENARIO_DIR)/main.bicep \
		--parameters $(SCENARIO_DIR)/main.bicepparam

.PHONY: _ci-test-base
_ci-test-base: install-deps-dev lint build git-diff test

.PHONY: ci-test
ci-test: trivy ## ci test
	@for dir in $(SCENARIO_DIR_LIST) ; do \
		echo "Test: $$dir" ; \
		make _ci-test-base SCENARIO=$$(basename $$dir) || exit 1 ; \
	done

.PHONY: deploy
deploy: ## deploy resources
	az deployment sub create \
		--name $(DEPLOYMENT_NAME) \
		--location $(LOCATION) \
		--template-file $(SCENARIO_DIR)/main.bicep \
		--parameters $(SCENARIO_DIR)/main.bicepparam

.PHONY: destroy
destroy: ## destroy resources (delete resource group)
	az deployment sub delete \
		--name $(DEPLOYMENT_NAME)

.PHONY: output
output: ## show output values
	@az deployment sub show \
		--name $(DEPLOYMENT_NAME) \
		--query properties.outputs
