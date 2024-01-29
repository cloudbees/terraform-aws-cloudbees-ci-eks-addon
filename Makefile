.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
BP_AGENT_USER		:= bp-agent
CI 					?= false
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MSG_INFO     		:= "\033[36m[INFO] %s\033[0m\n"
MSG_WARN 			:= "\033[0;33m[WARN] %s\033[0m\n"
MSG_ERROR 			:= "\033[0;31m[ERROR] %s\033[0m\n"

#https://developer.hashicorp.com/terraform/internals/debugging
ifeq ($(CI),false)
	export TF_LOG=INFO
	export TF_LOG_PATH=$(MKFILEDIR)/blueprints/terraform.log
endif

define confirmation
	@if [ $(CI) == false ]; then \
		echo -n "Asking for your confirmation to $(1) [yes/No]" && read ans && [ $${ans:-No} = yes ] ; fi
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
define deploy
	@printf $(MSG_INFO) "Deploying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Deploy $(1))
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) init
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.vpc" -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.eks" -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) output > $(MKFILEDIR)/blueprints/$(1)/terraform.output
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
define destroy
	@printf $(MSG_INFO) "Destroying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Destroy $(1))
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addon_cbci -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addons -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -auto-approve
	@rm -f $(MKFILEDIR)/blueprints/$(1)/terraform.output
endef

define validate
	@printf $(MSG_INFO) "Validating CloudBees CI Operation Center availability for $(1) ..."
	$(call confirmation,Validate $(1))
	@source blueprints/helpers.sh && probes-common $(1)
	@if [ "$(1)" == "01-getting-started" ]; then \
		source blueprints/helpers.sh && probes-bp01 ; fi
	@if [ "$(1)" == "02-at-scale" ]; then \
		source blueprints/helpers.sh && probes-bp02 ; fi
endef

define clean
	@cd blueprints/$(ROOT) && find -name ".terraform" -type d | xargs rm -rf
	@cd blueprints/$(ROOT) && find -name ".terraform.lock.hcl" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && find -name "kubeconfig_*.yaml" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && find -name "terraform.output" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && find -name terraform.log -type f | xargs rm -f
endef

.PHONY: dRun
dRun: ## Build (if not locally present) and Run the Blueprint Agent using Bash as Entrypoint. It is ideal starting point for all targets. Example: make dRun
dRun:
	$(eval IMAGE := $(shell docker image ls | grep -c local.cloudbees/bp-agent))
	@if [ "$(IMAGE)" == "0" ]; then \
		printf $(MSG_INFO) "Building Docker Image local.cloudbees/bp-agent:latest" && \
		docker build . --file $(MKFILEDIR)/.docker/Dockerfile --tag local.cloudbees/bp-agent:latest; \
		fi
	docker run --rm -it --name bp-agent \
		-v $(MKFILEDIR):/$(BP_AGENT_USER)/cbci-eks-addon -v $(HOME)/.aws:/$(BP_AGENT_USER)/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: tfpreFlightChecks
tfpreFlightChecks: ## Run preflight checks for terraform according to getting-started/README.md . Example: ROOT=02-at-scale make tfpreFlightChecks
tfpreFlightChecks: guard-ROOT
	@if [ "$(shell whoami)" != "$(BP_AGENT_USER)" ]; then printf $(MSG_WARN) "$(BP_AGENT_USER) user is not detected. Note that blueprints validations use the companion Blueprint Docker Agent available via: make dRun"; fi
	@if [ ! -f blueprints/$(ROOT)/.auto.tfvars ]; then printf $(MSG_ERROR) "blueprints/$(ROOT)/.auto.tfvars file does not exist and it is required to store your own values"; exit 1; fi
	@if ([ ! -f blueprints/$(ROOT)/k8s/secrets-values.yml ] && [ $(ROOT) == "02-at-scale" ]); then printf $(MSG_ERROR) "blueprints/$(ROOT)/secrets-values.yml file does not exist and it is required to store your secrets"; exit 1; fi
	$(eval USER_ID := $(shell aws sts get-caller-identity | grep UserId | cut -d"," -f 1 | xargs ))
	@if [ "$(USER_ID)" == "" ]; then printf $(MSG_ERROR) "AWS Authention for CLI is not configured" && exit 1; fi
	@printf $(MSG_INFO) "Preflight Checks OK for $(USER_ID)"

.PHONY: deploy
deploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make deploy
deploy: guard-ROOT tfpreFlightChecks
	$(call deploy,$(ROOT))

.PHONY: destroy
destroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=02-at-scale make destroy
destroy: guard-ROOT tfpreFlightChecks
ifneq ("$(wildcard blueprints/$(ROOT)/terraform.output)","")
	$(call destroy,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target. It is not Ready for Destroy target but it is possible to destroy manually https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy"
endif

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT tfpreFlightChecks
	$(call clean,$(ROOT))

.PHONY: tfAction
tfAction: ## Any Terraform Action for Blueprint passed as parameters. Usage: ROOT=02-at-scale ACTION="status list" make tf_action
tfAction: guard-ROOT guard-ACTION tfpreFlightChecks
	terraform -chdir=blueprints/$(ROOT) $(ACTION)

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: guard-ROOT tfpreFlightChecks
ifneq ("$(wildcard blueprints/$(ROOT)/terraform.output)","")
	$(call validate,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated."
endif

.PHONY: test
test: ## Runs a test for blueprint passed as parameters throughout their Terraform Lifecycle. Example: ROOT=02-at-scale make test
	@printf $(MSG_INFO) "Running Test for $(ROOT) blueprint ..."
	$(call deploy,$(ROOT))
	until ls blueprints/$(ROOT)/terraform.output; do sleep 3 && echo "Waiting for output file..."; done ;
ifneq ("$(wildcard blueprints/$(ROOT)/terraform.output)","")
	$(call validate,$(ROOT))
	$(call destroy,$(ROOT))
	$(call clean,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready for the following phases."
endif

.PHONY: test-all
test-all: ## Runs test for all blueprints throughout their Terraform Lifecycle. Example: make test
test-all:
	@printf $(MSG_INFO) "Running Test for all blueprints ..."
	@source $(MKFILEDIR)/blueprints/helpers.sh && test-all

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null
	@printf "\nDebug: Use -d flag with targets. Example: ROOT=02-at-scale make -d validate \n\n"

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
