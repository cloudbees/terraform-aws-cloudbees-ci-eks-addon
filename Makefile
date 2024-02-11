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

define confirmation
	echo -n "Asking for your confirmation to $(1) [yes/No]" && read ans && [ $${ans:-No} = yes ]
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
	@$(call helpers,INFO "Deploying CloudBees CI Blueprint $(ROOT) ...")
ifeq ($(CI),false)
	@$(call confirmation,Deploy $(ROOT))
endif
	@$(call helpers,tf-deploy $(ROOT))

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: guard-ROOT preFlightChecks
	@$(call helpers,INFO "Validating CloudBees CI Operation Center availability for $(ROOT) ...")
ifeq ($(CI),false)
ifneq ("$(wildcard $(MKFILEDIR)/blueprints/$(ROOT)/terraform.output)","")
	@$(call confirmation,Validate $(ROOT))
else
	@$(call helpers,ERROR "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated.")
endif
endif
	@$(call helpers,probes-common $(1))
	@if [ "$(1)" == "01-getting-started" ]; then \
		$(call helpers,probes-bp01) ; fi
	@if [ "$(1)" == "02-at-scale" ]; then \
		$(call helpers,probes-bp02) ; fi

.PHONY: destroy
destroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make destroy
destroy: guard-ROOT preFlightChecks
	@$(call helpers,INFO "Destroying CloudBees CI Blueprint $(1) ...")
ifeq ($(CI),false)
ifneq ("$(wildcard $(MKFILEDIR)/blueprints/$(ROOT)/terraform.output)","")
	@$(call confirmation,Destroy $(ROOT))
else
	@$(call helpers,ERROR "Blueprint $(ROOT) did not complete the Deployment target. It is not Ready for Destroy target but it is possible to destroy manually https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy")
endif
endif
	@$(call helpers,tf-destroy $(ROOT))

.PHONY: test
test: ## Runs a test for blueprint passed as parameters throughout their Terraform Lifecycle. Example: ROOT=02-at-scale make test
test: guard-ROOT deploy validate destroy clean

.PHONY: test-all
test-all: ## Runs test for all blueprints throughout their Terraform Lifecycle. Example: make test-all
test-all:
	@$(call helpers,INFO "Running Test for all blueprints ...")
	$(call helpers,test-all)

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT preFlightChecks
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name ".terraform" -type d | xargs rm -rf
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name ".terraform.lock.hcl" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name "kubeconfig_*.yaml" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name "terraform.output" -type f | xargs rm -f
	@cd $(MKFILEDIR)/blueprints/$(ROOT) && find -name terraform.log -type f | xargs rm -f

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
