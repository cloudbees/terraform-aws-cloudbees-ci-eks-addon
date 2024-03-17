.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
CI 					?= false
BP_AGENT_USER       := bp-agent
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

#https://developer.hashicorp.com/terraform/internals/debugging
export TF_LOG=INFO

define helpers
	source blueprints/helpers.sh && $(1)
endef

##########################
# Blueprint User
##########################

.PHONY: tfChecks
tfChecks: ## Run required terraform checks according to getting-started/README.md . Example: ROOT=02-at-scale make tfChecks
tfChecks: guard-ROOT
	@if [ ! -f blueprints/$(ROOT)/.auto.tfvars ]; then $(call helpers,ERROR "blueprints/$(ROOT)/.auto.tfvars file does not exist and it is required to store your own values"); fi
	@if ([ ! -f blueprints/$(ROOT)/k8s/secrets-values.yml ] && [ $(ROOT) == "02-at-scale" ]); then $(call helpers,ERROR "blueprints/$(ROOT)/secrets-values.yml file does not exist and it is required to store your secrets"); fi
	$(eval USER_ID := $(shell aws sts get-caller-identity | grep UserId | cut -d"," -f 1 | xargs ))
	@if [ "$(USER_ID)" == "" ]; then $(call helpers,ERROR "AWS Authention for CLI is not configured"); fi
	@$(call helpers,INFO "Terraform Preflight Checks OK for $(USER_ID)")

.PHONY: agentCheck
agentCheck: ## Run agent check providing a warning message in case it is not used. Example:  make agentCheck
	@if [ "$(shell whoami)" != "$(BP_AGENT_USER)" ]; then $(call helpers,WARN "$(BP_AGENT_USER) user is not detected. Blueprint Docker Agent available via: make bpAgent-dRun"); fi

.PHONY: bpAgent-dRun
bpAgent-dRun: ## Build (if not locally present) and Run the Blueprint Agent using Bash as Entrypoint. It is ideal starting point for all targets. Example: make bpAgent-dRun
	@$(call helpers,bpAgent-dRun)

.PHONY: deploy
deploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make deploy
deploy: tfChecks agentCheck
	terraform -chdir=$(MKFILEDIR)/blueprints/$(ROOT) init
	terraform -chdir=$(MKFILEDIR)/blueprints/$(ROOT) plan -no-color > $(MKFILEDIR)/blueprints/$(ROOT)/tfplan.txt
ifeq ($(CI),false)
	@$(call helpers,ask-confirmation "Deploy $(ROOT). Check plan at blueprints/$(ROOT)/tfplan.txt")
endif
	@$(call helpers,tf-apply $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Deploy target finished succesfully.")

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: tfChecks agentCheck
ifeq ($(CI),false)
ifeq ($(wildcard $(MKFILEDIR)/blueprints/$(ROOT)/terraform.output),)
	@$(call helpers,WARN "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated.")
endif
	@$(call helpers,ask-confirmation "Validate $(ROOT)")
endif
	@$(call helpers,probes $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Validation target finished succesfully.")

.PHONY: destroy
destroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make destroy
destroy: tfChecks agentCheck
ifeq ($(CI),false)
	@$(call helpers,ask-confirmation "Destroy $(ROOT) in mode CBCI_ONLY=$(CBCI_ONLY)")
endif
	@$(call helpers,tf-destroy $(ROOT) $(CBCI_ONLY))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Destroy target finished succesfully.")

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT agentCheck
	@$(call helpers,clean $(ROOT))
	@$(call helpers,INFO "CloudBees CI Blueprint $(ROOT) Clean target finished succesfully.")

##########################
# Blueprint Admin
##########################

.PHONY: test
test: ## Runs a test for blueprint passed as parameters throughout their Terraform Lifecycle. Example: ROOT=02-at-scale make test
test: deploy validate destroy clean
	@$(call helpers,INFO "Test target for $(ROOT) passed succesfully.")

.PHONY: test-all
test-all: ## Runs test for all blueprints throughout their Terraform Lifecycle. Example: make test-all
	@$(call helpers,test-all)
	@$(call helpers,INFO "All Tests target passed succesfully.")

.PHONY: set-kube-env
set-kube-env: ## Set K8s version according to file .k8.env. Example: make set-kube-env
set-kube-env: agentCheck
	@$(call helpers,set-kube-env)
	@$(call helpers,INFO "Setting Kube environment finished succesfully.")

.PHONY: set-casc-branch
set-casc-branch: ## Update Casc bundle repository to the branch passed as parameter. Example: BRANCH=main make set-casc-branch
set-casc-branch: agentCheck guard-BRANCH
	@$(call helpers,set-casc-branch $(BRANCH))
	@$(call helpers,INFO "Setting Casc Branch finished succesfully.")

#https://github.com/kyounger/casc-plugin-dependency-calculation/blob/master/README.md#using-the-docker-image
.PHONY: cascCal-dRun
cascCal-dRun: ## Run Docker Container for Casc Plugin Dependency Calculations. Example: make cascCal-dRun
	@$(call helpers,casc-docker-run)

#https://github.com/kyounger/casc-plugin-dependency-calculation/blob/master/README.md#using-the-docker-image
.PHONY: cascCal-script
cascCal-script: ## Run Casc Plugin Dependency Calculations Script passing a version, type and source as parameters. Example: VERSION=2.440.1.3 TYPE=oc SOURCE="./blueprints/02-at-scale/casc/oc/plugins/plugins.2.426.3.3.minimal.yaml" make cascCal-script
cascCal-script: guard-VERSION guard-SOURCE guard-TYPE
	@$(call helpers,casc-script-exec $(VERSION) $(TYPE) $(SOURCE))

##########################
# Global
##########################

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
