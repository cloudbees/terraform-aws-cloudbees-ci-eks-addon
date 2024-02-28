.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
BP_AGENT_USER		:= bp-agent
CI 					?= false
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

#https://developer.hashicorp.com/terraform/internals/debugging
export TF_LOG=INFO

define helpers
	source blueprints/helpers.sh && $(1)
endef

.PHONY: dRun
dRun: ## Build (if not locally present) and Run the Blueprint Agent using Bash as Entrypoint. It is ideal starting point for all targets. Example: make dRun
dRun:
	$(eval IMAGE := $(shell docker image ls | grep -c local.cloudbees/bp-agent))
	@if [ "$(IMAGE)" == "0" ]; then \
		$(call helpers,INFO "Building Docker Image local.cloudbees/bp-agent:latest") && \
		docker build . --file $(MKFILEDIR)/.docker/Dockerfile.rootless --tag local.cloudbees/bp-agent:latest; \
		fi
	docker run --rm -it --name bp-agent \
		-v $(MKFILEDIR):/$(BP_AGENT_USER)/cbci-eks-addon -v $(HOME)/.aws:/$(BP_AGENT_USER)/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: preFlightChecks
preFlightChecks: ## Run preflight checks for terraform according to getting-started/README.md . Example: ROOT=02-at-scale make preFlightChecks
preFlightChecks: guard-ROOT
	@if [ "$(shell whoami)" != "$(BP_AGENT_USER)" ]; then $(call helpers,WARN "$(BP_AGENT_USER) user is not detected. Note that blueprints validations use the companion Blueprint Docker Agent available via: make dRun"); fi
	@if [ ! -f blueprints/$(ROOT)/.auto.tfvars ]; then $(call helpers,ERROR "blueprints/$(ROOT)/.auto.tfvars file does not exist and it is required to store your own values"); fi
	@if ([ ! -f blueprints/$(ROOT)/k8s/secrets-values.yml ] && [ $(ROOT) == "02-at-scale" ]); then $(call helpers,ERROR "blueprints/$(ROOT)/secrets-values.yml file does not exist and it is required to store your secrets"); fi
	$(eval USER_ID := $(shell aws sts get-caller-identity | grep UserId | cut -d"," -f 1 | xargs ))
	@if [ "$(USER_ID)" == "" ]; then $(call helpers,ERROR "AWS Authention for CLI is not configured"); fi
	@$(call helpers,INFO "Preflight Checks OK for $(USER_ID)")

.PHONY: deploy
deploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make deploy
deploy: guard-ROOT preFlightChecks
	terraform -chdir=$(MKFILEDIR)/blueprints/$(ROOT) init
	terraform -chdir=$(MKFILEDIR)/blueprints/$(ROOT) plan -no-color >> $(MKFILEDIR)/blueprints/$(ROOT)/tfplan.txt
ifeq ($(CI),false)
	@$(call helpers,ask-confirmation "Deploy $(ROOT). Check plan at blueprints/$(ROOT)/tfplan.txt")
endif
	@$(call helpers,tf-apply $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Deploy target finished succesfully.")

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: guard-ROOT preFlightChecks
ifeq ($(CI),false)
ifneq ("$(wildcard $(MKFILEDIR)/blueprints/$(ROOT)/terraform.output)","")
	@$(call confirmation,Validate $(ROOT))
else
	@$(call helpers,ERROR "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated.")
endif
endif
	@$(call helpers,probes $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Validation target finished succesfully.")

.PHONY: destroy
destroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make destroy
destroy: guard-ROOT preFlightChecks
ifeq ($(CI),false)
	@$(call confirmation,Destroy $(ROOT))
endif
	@$(call helpers,tf-destroy $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Destroy target finished succesfully.")

.PHONY: test
test: ## Runs a test for blueprint passed as parameters throughout their Terraform Lifecycle. Example: ROOT=02-at-scale make test
test: guard-ROOT deploy validate destroy clean
	@$(call helpers,INFO "Test target for $(ROOT) passed succesfully.")

.PHONY: test-all
test-all: ## Runs test for all blueprints throughout their Terraform Lifecycle. Example: make test-all
test-all:
	$(call helpers,test-all)
	@$(call helpers,INFO "All Tests target passed succesfully.")

.PHONY: set-k8s-env
set-k8s-env: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
set-k8s-env:
	@$(call helpers,set-k8s-env)
	@$(call helpers,INFO "Set K8s Environment target was completed.")

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name ".terraform" -type d | xargs rm -rf
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name ".terraform.lock.hcl" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name "kubeconfig_*.yaml" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name "terraform.output" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name terraform.log -type f | xargs rm -f
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Clean target finished succesfully.")

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
