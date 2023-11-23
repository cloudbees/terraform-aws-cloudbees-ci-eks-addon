.DEFAULT_GOAL   	:= help
SHELL           	:= /bin/bash
MAKEFLAGS       	+= --no-print-directory
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))

define confirmation
	@echo -n "Are OK with $(1) [yes/No] " && read ans && [ $${ans:-No} = yes ]
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
define tfDeploy
	@echo ">> Deploying CloudBees CI Blueprint $(1)..."
	$(call confirmation,Deploy $(1))
	terraform -chdir=blueprints/$(1) init -upgrade
	terraform -chdir=blueprints/$(1) apply -target="module.vpc" -auto-approve
	terraform -chdir=blueprints/$(1) apply -target="module.eks" -auto-approve
	terraform -chdir=blueprints/$(1) apply -auto-approve
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
define tfDestroy
	@echo ">> Destroying CloudBees CI Blueprint $(1)..."
	$(call confirmation,Destroy $(1))
	kubectl delete --all pods --grace-period=0 --force --namespace $(shell cd blueprints/$(1) && terraform output -raw eks_blueprints_addon_cbci_namepace) || echo "There are no pods to delete in $(shell cd blueprints/$(1) && terraform output -raw eks_blueprints_addon_cbci_namepace)" 
	terraform -chdir=blueprints/$(1) destroy -target=module.eks_blueprints_addon_cbci -auto-approve
	kubectl delete --all pvc --grace-period=0 --force --namespace $(shell cd blueprints/$(1) && terraform output -raw eks_blueprints_addon_cbci_namepace) || echo "There are no pvc to delete in $(shell cd blueprints/$(1) && terraform output -raw eks_blueprints_addon_cbci_namepace)"
	terraform -chdir=blueprints/$(1) destroy -target=module.eks_blueprints_addons -auto-approve
	terraform -chdir=blueprints/$(1) destroy -target=module.eks -auto-approve
	terraform -chdir=blueprints/$(1) destroy -auto-approve
endef

define validate
	@echo ">> Checking CloudBees CI Operation Center availability"
	cd blueprints/$(1) && eval `terraform output --raw configure_kubectl`
	until kubectl get pod -n $(2) cjoc-0; do sleep 2 && echo "Waiting for Pod to get ready"; done
	@echo "OC Pod is Ready"
	until kubectl get ing -n $(2) cjoc; do sleep 2 && echo "Waiting for Ingress to get ready"; done
	@echo "Ingress Ready"
	until curl -s $(3)/whoAmI/api/json  > /dev/null; do sleep 10 && echo "Waiting for Operation Center at $(1)"; done
	@echo "Operation Center Ready at $(3)"
	@echo "Initial Admin Password: $(shell kubectl exec -n $(2) -ti cjoc-0 -- cat /var/jenkins_home/secrets/initialAdminPassword)"
endef

define testBlueprint
	@echo ">> Testing Blueprint $(1)..."
	$(call tfDeploy,$(1))
	$(call validate,$(1),\
		$(shell cd blueprints/$(1) && terraform output -raw eks_blueprints_addon_cbci_namepace),\
		$(shell cd blueprints/$(1) && terraform output -raw cjoc_url))
	$(call tfDestroy,$(1))
endef

.PHONY: dBuildAndRun
dBuildAndRun: ## Docker Build and Run locally 
dBuildAndRun:
	docker build . --file .docker/Dockerfile \
		--tag local.cloudbees/bp-agent:latest
	docker run -it --name bp-agent_$(shell echo $$RANDOM) \
		-v $(MKFILEDIR):/root/cloudbees-ci-addons -v $(HOME)/.aws:/root/.aws \
		local.cloudbees/bp-agent:latest

.PHONY: tfDeploy
tfDeploy: ## Deploy Terraform Blueprint passed as parameter. ROOT=getting-started/v4 make tfRun 
tfDeploy: guard-ROOT
	$(call tfDeploy,$(ROOT))

.PHONY: tfDestroy
tfDestroy: ## Destroy Terraform Blueprint passed as parameter. ROOT=getting-started/v4 make tfDestroy 
tfDestroy: guard-ROOT
	$(call tfDestroy,$(ROOT))

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. ROOT=getting-started/v4 make validate
validate: guard-ROOT
	$(call validate,$(ROOT),\
		$(shell cd blueprints/$(ROOT) && terraform output -raw eks_blueprints_addon_cbci_namepace),\
		$(shell cd blueprints/$(ROOT) && terraform output -raw cjoc_url))

.PHONY: tfTestAll
tfTestAll: ## Test all Terraform Blueprints
tfTestAll:
	$(call testBlueprint,getting-started/v4)
	$(call testBlueprint,getting-started/v5)

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then echo "Environment variable $* not set"; exit 1; fi