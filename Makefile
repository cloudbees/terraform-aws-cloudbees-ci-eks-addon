.DEFAULT_GOAL   	:= help
SHELL           	:= /bin/bash
MAKEFLAGS       	+= --no-print-directory
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

.PHONY: dBuildAndRun
dBuildAndRun: ## Docker Build and Run locally 
dBuildAndRun:
	docker build . --file .docker/Dockerfile \
		--tag local.cloudbees/bp-agent:latest
	docker run -it --name bp-agent_$(shell echo $$RANDOM) \
		-v $(MKFILEDIR):/root/cloudbees-ci-addons -v $(HOME)/.aws:/root/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: tfRun
tfRun: ## Run Terraform Blueprint passed as parameter. ROOT=getting-started/v4 make tfRun 
tfRun: guard-ROOT
	terraform -chdir=blueprints/$(ROOT) fmt
	terraform -chdir=blueprints/$(ROOT) init -upgrade
	terraform -chdir=blueprints/$(ROOT) plan 
	terraform -chdir=blueprints/$(ROOT) apply

.PHONY: tfDestroy
tfDestroy: ## Destroy Terraform Blueprint passed as parameter. ROOT=getting-started/v4 make tfDestroy 
tfDestroy: guard-ROOT
	terraform -chdir=blueprints/$(ROOT) destroy -target=module.eks_blueprints_addon_cbci
	terraform -chdir=blueprints/$(ROOT) destroy -target=module.eks_blueprints_addons
	terraform -chdir=blueprints/$(ROOT) destroy -target=module.eks
	terraform -chdir=blueprints/$(ROOT) destroy -target=module.vpc
	terraform -chdir=blueprints/$(ROOT) destroy

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then echo "Environment variable $* not set"; exit 1; fi