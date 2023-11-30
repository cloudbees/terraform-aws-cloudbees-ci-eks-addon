.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

define confirmation
	@echo -n "Asking for your confirmation to $(1) [yes/No] " && read ans && [ $${ans:-No} = yes ]
endef

define getTFOutput
	$(shell cd blueprints/$(1) && terraform output -raw $(2))
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
define tfDeploy
	@printf "\033[36mDeploying CloudBees CI Blueprint %s...\033[0m\n\n" "$(1)"
	$(call confirmation,Deploy $(1))
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) init -upgrade
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.vpc" -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.eks" -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -auto-approve
	@touch $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
define tfDestroy
	@printf "\033[36mDestroying CloudBees CI Blueprint %s...\033[0m\n\n" "$(1)"
	$(call confirmation,Destroy $(1))
	$(eval $(call getTFOutput,$(1),export_kubeconfig))
	$(eval CBCI_NAMESPACE := $(call getTFOutput,$(1),eks_bp_addon_cbci_namepace))
	kubectl delete --all pods --grace-period=0 --force --namespace $(CBCI_NAMESPACE) || echo "There are no pods to delete in $(CBCI_NAMESPACE)" 
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addon_cbci -auto-approve
	kubectl delete --all pvc --grace-period=0 --force --namespace $(CBCI_NAMESPACE) || echo "There are no pvc to delete in $(CBCI_NAMESPACE)"
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addons -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks -auto-approve
	terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -auto-approve
	@rm -f $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

define validate
	@printf "\033[36mValidating CloudBees CI Operation Center availability for %s...\033[0m\n\n" "$(1)"
	$(call confirmation,Validate $(1))
	$(eval $(call getTFOutput,$(1),export_kubeconfig))
	$(eval CBCI_NAMESPACE := $(call getTFOutput,$(1),eks_bp_addon_cbci_namepace))
	$(eval OC_URL := $(call getTFOutput,$(1),cjoc_url))
	until $(call getTFOutput,$(1),eks_bp_addon_cbci_oc_pod); do sleep 2 && echo "Waiting for Operation Center Pod to get ready"; done
	@printf "\033[36m✔\033[0m OC Pod is Ready.\n"
	until $(call getTFOutput,$(1),eks_bp_addon_cbci_liveness_probe_int); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster"; done
	@printf "\033[36m✔\033[0m Operation Center Service passed Health Check inside the cluster.\n"
	until $(call getTFOutput,$(1),eks_bp_addon_cbci_oc_ing); do sleep 2 && echo "Waiting for Operation Center Ingress to get ready"; done
	@printf "\033[36m✔\033[0m Operation Center Ingress Ready.\n"
	until $(call getTFOutput,$(1),eks_bp_addon_cbci_liveness_probe_ext); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from outside the cluster"; done
	@printf "\033[36m✔\033[0m Operation Center Service passed Health Check outside the cluster. It is available at %s.\n" "$(OC_URL)"
	@echo "Initial Admin Password: `$(call getTFOutput,$(1),eks_bp_addon_cbci_initial_admin_password)`"
endef

.PHONY: dBuildAndRun
dBuildAndRun: ## Docker Build and Run locally. Example: make dBuildAndRun 
dBuildAndRun:
	docker build . --file $(MKFILEDIR)/.docker/Dockerfile \
		--tag local.cloudbees/bp-agent:latest
	docker run -it --name bp-agent_$(shell echo $$RANDOM) \
		-v $(MKFILEDIR):/root/cloudbees-ci-addons -v $(HOME)/.aws:/root/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: tfpreFlightChecks
tfpreFlightChecks: ## Run preflight checks for terraform according to getting-started/README.md . Example: ROOT=getting-started/v4 make tfpreFlightChecks 
tfpreFlightChecks: guard-ROOT
	@if [ ! -f blueprints/$(ROOT)/.auto.tfvars ]; then echo ERROR: blueprints/$(ROOT)/.auto.tfvars file does not exist and it is required that contains your own values for required variables; exit 1; fi
	$(eval USER_ID := $(shell aws sts get-caller-identity | grep UserId | cut -d"," -f 1 | xargs ))
	@if [ "$(USER_ID)" == "" ]; then echo "ERROR: AWS Authention for CLI is not configured" && exit 1; fi
	@printf "\033[36m✔\033[0m Preflight Checks OK for %s\n" "$(USER_ID)"

.PHONY: tfDeploy
tfDeploy: ## Deploy Terraform Blueprint passed as parameter. Example: ROOT=getting-started/v4 make tfDeploy 
tfDeploy: guard-ROOT tfpreFlightChecks
	$(call tfDeploy,$(ROOT))

.PHONY: tfDestroy
tfDestroy: ## Destroy Terraform Blueprint passed as parameter. Example: ROOT=getting-started/v4 make tfDestroy 
tfDestroy: guard-ROOT tfpreFlightChecks
ifeq (,$(wildcard blueprints/$(ROOT)/.deployed))
	@echo "WARN: Blueprint $(ROOT) did not complete the Deployment target"
endif
	$(call tfDestroy,$(ROOT))

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=getting-started/v4 make validate
validate: guard-ROOT
ifneq (,$(wildcard blueprints/$(ROOT)/.deployed))
	$(call validate,$(ROOT))
else
	@echo "ERROR: Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated."
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
	@if [[ "${${*}}" == "" ]]; then echo "Environment variable $* not set"; exit 1; fi