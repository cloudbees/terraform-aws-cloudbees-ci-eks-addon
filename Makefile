.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MSG_INFO 			:= "\033[36m[INFO] %s\033[0m\n"
MSG_WARN 			:= "\033[0;33m[WARN] %s\033[0m\n"
MSG_ERROR 			:= "\033[0;31m[ERROR] %s\033[0m\n"

define confirmation
	@echo -n "Asking for your confirmation to $(1) [yes/No]" && read ans && [ $${ans:-No} = yes ]
endef

define tfOutput
	$(shell cd blueprints/$(1) && terraform output -raw $(2))
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
define tfDeploy
	@printf $(MSG_INFO) "Deploying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Deploy $(1))
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) init -upgrade
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.vpc" -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.eks" -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -auto-approve
	@touch $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
define tfDestroy
	@printf $(MSG_INFO) "Destroying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Destroy $(1))
	$(eval $(call tfOutput,$(1),export_kubeconfig))
	$(eval CBCI_NAMESPACE := $(call tfOutput,$(1),cbci_namespace))
	kubectl delete --all pods --grace-period=0 --force --namespace $(CBCI_NAMESPACE) || echo "There are no pods to delete in $(CBCI_NAMESPACE)"
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addon_cbci -auto-approve
	kubectl delete --all pvc --grace-period=0 --force --namespace $(CBCI_NAMESPACE) || echo "There are no pvc to delete in $(CBCI_NAMESPACE)"
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addons -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -auto-approve
	@rm -f $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

define validate
	@printf $(MSG_INFO) "Validating CloudBees CI Operation Center availability for $(1) ..."
	$(call confirmation,Validate $(1))
	$(eval $(call tfOutput,$(1),export_kubeconfig))
	$(eval CBCI_NAMESPACE := $(call tfOutput,$(1),cbci_namespace))
	$(eval OC_URL := $(call tfOutput,$(1),cjoc_url))
	until $(call tfOutput,$(1),cbci_oc_pod); do sleep 2 && echo "Waiting for Operation Center Pod to get ready"; done
	@printf $(MSG_INFO) "OC Pod is Ready."
	until $(call tfOutput,$(1),cbci_liveness_probe_int); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster"; done
	@printf $(MSG_INFO) "Operation Center Service passed Health Check inside the cluster."
	until $(call tfOutput,$(1),cbci_oc_ing); do sleep 2 && echo "Waiting for Operation Center Ingress to get ready"; done
	@printf $(MSG_INFO) "Operation Center Ingress Ready."
	until $(call tfOutput,$(1),cbci_liveness_probe_ext); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from outside the cluster"; done
	@printf $(MSG_INFO) "Operation Center Service passed Health Check outside the cluster. It is available at $(OC_URL)."
	@echo "Initial Admin Password: `$(call tfOutput,$(1),cbci_initial_admin_password)`"
endef

.PHONY: dRun
dRun: ## Docker Run using Bash as Entrypoint. Example: make dRunBash
dRun:
	$(eval IMAGE := $(shell docker image ls | grep -c local.cloudbees/bp-agent))
	@if [ "$(IMAGE)" == "0" ]; then \
		echo "Building Docker Image local.cloudbees/bp-agent:latest" && \
		docker build . --file $(MKFILEDIR)/blueprints/Dockerfile --tag local.cloudbees/bp-agent:latest; \
		fi
	docker run --rm -it --name bp-agent \
		-v $(MKFILEDIR):/asdf/cbci-eks-addon -v $(HOME)/.aws:/asdf/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: tfpreFlightChecks
tfpreFlightChecks: ## Run preflight checks for terraform according to getting-started/README.md . Example: ROOT=getting-started/v4 make tfpreFlightChecks
tfpreFlightChecks: guard-ROOT
	@if [ ! -f blueprints/$(ROOT)/.auto.tfvars ]; then printf $(MSG_ERROR) "blueprints/$(ROOT)/.auto.tfvars file does not exist and it is required that contains your own values for required variables"; exit 1; fi
	$(eval USER_ID := $(shell aws sts get-caller-identity | grep UserId | cut -d"," -f 1 | xargs ))
	@if [ "$(USER_ID)" == "" ]; then printf $(MSG_ERROR) "AWS Authention for CLI is not configured" && exit 1; fi
	@printf $(MSG_INFO) "Preflight Checks OK for $(USER_ID)"

.PHONY: tfDeploy
tfDeploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=getting-started/v4 make tfDeploy
tfDeploy: guard-ROOT tfpreFlightChecks
	$(call tfDeploy,$(ROOT))

.PHONY: tfDestroy
tfDestroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=getting-started/v4 make tfDestroy
tfDestroy: guard-ROOT tfpreFlightChecks
ifneq ("$(wildcard blueprints/$(ROOT)/.deployed)","")
	$(call tfDestroy,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target. It is not Ready for Destroy target but it is possible to destroy manually https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy"
endif

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=getting-started/v4 make tfClean
clean: guard-ROOT
	@cd blueprints/$(ROOT) && find -name ".terraform" -type d | xargs rm -rf
	@cd blueprints/$(ROOT) && find -name ".terraform.lock.hcl" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && rm kubeconfig_*.yaml || echo "No kubeconfig file to remove"
	@cd blueprints/$(ROOT) && rm terraform.log || echo "No terraform.log file to remove"

.PHONY: tfAction
tfAction: ## Any Terraform Action for Blueprint passed as parameters. Usage: ROOT=getting-started/v4 ACTION="status list" make tf_action
tfAction: guard-ROOT guard-ACTION tfpreFlightChecks
	terraform -chdir=blueprints/$(ROOT) $(ACTION)

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=getting-started/v4 make validate
validate: guard-ROOT
ifneq ("$(wildcard blueprints/$(ROOT)/.deployed)","")
	$(call validate,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated."
endif

.PHONY: test
test: ## Runs a smoke test for all blueprints throughout their Terraform Lifecycle. Example: make test
test:
	bash $(MKFILEDIR)/blueprints/test-all.sh

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
