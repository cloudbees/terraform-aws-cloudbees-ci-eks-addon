.DEFAULT_GOAL   	:= help
SHELL           	:= /usr/bin/env bash
MAKEFLAGS       	+= --no-print-directory
BP_AGENT_USER		:= bp-agent
MKFILEDIR 			:= $(abspath $(dir $(lastword $(MAKEFILE_LIST))))
MSG_INFO 			:= "\033[36m[INFO] %s\033[0m\n"
MSG_WARN 			:= "\033[0;33m[WARN] %s\033[0m\n"
MSG_ERROR 			:= "\033[0;31m[ERROR] %s\033[0m\n"

define confirmation
	@echo -n "Asking for your confirmation to $(1) [yes/No]" && read ans && [ $${ans:-No} = yes ]
endef

define tfOutput
	$(shell cd blueprints/$(1) && terraform output -raw $(2) 2> /dev/null)
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
define deploy
	@printf $(MSG_INFO) "Deploying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Deploy $(1))
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) init -upgrade
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.vpc" -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -target="module.eks" -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) apply -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) output > $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
define destroy
	@printf $(MSG_INFO) "Destroying CloudBees CI Blueprint $(1) ..."
	$(call confirmation,Destroy $(1))
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addon_cbci -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks_blueprints_addons -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -target=module.eks -auto-approve
	@terraform -chdir=$(MKFILEDIR)/blueprints/$(1) destroy -auto-approve
	@rm -f $(MKFILEDIR)/blueprints/$(1)/.deployed
endef

define validate
	@printf $(MSG_INFO) "Validating CloudBees CI Operation Center availability for $(1) ..."
	$(call confirmation,Validate $(1))
	$(eval $(call tfOutput,$(1),kubeconfig_export))
	$(eval OC_URL := $(call tfOutput,$(1),cbci_oc_url))
	@until $(call tfOutput,$(1),cbci_oc_pod); do sleep 2 && echo "Waiting for Operation Center Pod to get ready"; done
	@printf $(MSG_INFO) "OC Pod is Ready."
	@until $(call tfOutput,$(1),cbci_liveness_probe_int); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster"; done
	@printf $(MSG_INFO) "Operation Center Service passed Health Check inside the cluster."
	@until $(call tfOutput,$(1),cbci_oc_ing); do sleep 2 && echo "Waiting for Operation Center Ingress to get ready"; done
	@printf $(MSG_INFO) "Operation Center Ingress Ready."
	@until $(call tfOutput,$(1),cbci_liveness_probe_ext); do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from outside the cluster"; done
	@printf $(MSG_INFO) "Operation Center Service passed Health Check outside the cluster. It is available at $(OC_URL)."
	@if [ "$(1)" == "01-getting-started" ]; then \
		echo "Initial Admin Password: `$(call tfOutput,$(1),cbci_initial_admin_password)`" ; fi
	@if [ "$(1)" == "02-at-scale" ]; then \
		echo "General Password all users: `$(call tfOutput,$(1),cbci_general_password)`"; \
		until $(call tfOutput,$(1),team_c_hpa); do sleep 10 && echo "Waiting for Team C Horizontal Pod Autoscaling"; done; \
		printf $(MSG_INFO) "Configuration as Code is applied for OC and Controllers and Team C has HA enabled." ; \
		$(call tfOutput,$(1),velero_backup_schedule_team_a) > /tmp/backup.txt && \
			printf $(MSG_INFO) "Velero backups schedule configured for Team A"; \
		$(call tfOutput,$(1),velero_backup_on_demand_team_a) > /tmp/backup.txt && \
			cat /tmp/backup.txt | grep "Backup completed with status: Completed" && \
			printf $(MSG_INFO) "Velero on demand backup for Team A was successful"; \
		$(call tfOutput,$(1),prometheus_active_targets) | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") \
			| {job: .labels.job, instance: .labels.instance, status: .health}' && \
			printf $(MSG_INFO) "Prometheus CloudBees CI Targets are OK"; fi
endef

.PHONY: dRun
dRun: ## Build (if not locally present) and Run the Blueprint Agent using Bash as Entrypoint. It is ideal starting point for all targets. Example: make dRun
dRun:
	$(eval IMAGE := $(shell docker image ls | grep -c local.cloudbees/bp-agent))
	@if [ "$(IMAGE)" == "0" ]; then \
		echo "Building Docker Image local.cloudbees/bp-agent:latest" && \
		docker build . --file $(MKFILEDIR)/blueprints/Dockerfile --tag local.cloudbees/bp-agent:latest; \
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
ifneq ("$(wildcard blueprints/$(ROOT)/.deployed)","")
	$(call destroy,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target. It is not Ready for Destroy target but it is possible to destroy manually https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy"
endif

.PHONY: clean
clean: ## Clean Blueprint passed as parameter. Example: ROOT=02-at-scale make clean
clean: guard-ROOT tfpreFlightChecks
	@cd blueprints/$(ROOT) && find -name ".terraform" -type d | xargs rm -rf
	@cd blueprints/$(ROOT) && find -name ".terraform.lock.hcl" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && find -name "kubeconfig_*.yaml" -type f | xargs rm -f
	@cd blueprints/$(ROOT) && find -name terraform.log -type f | xargs rm -f

.PHONY: tfAction
tfAction: ## Any Terraform Action for Blueprint passed as parameters. Usage: ROOT=02-at-scale ACTION="status list" make tf_action
tfAction: guard-ROOT guard-ACTION tfpreFlightChecks
	terraform -chdir=blueprints/$(ROOT) $(ACTION)

.PHONY: validate
validate: ## Validate CloudBees CI Blueprint deployment passed as parameter. Example: ROOT=02-at-scale make validate
validate: guard-ROOT tfpreFlightChecks
ifneq ("$(wildcard blueprints/$(ROOT)/.deployed)","")
	$(call validate,$(ROOT))
else
	@printf $(MSG_ERROR) "Blueprint $(ROOT) did not complete the Deployment target thus it is not Ready to be validated."
endif

.PHONY: test
test: ## Runs a smoke test for all blueprints throughout their Terraform Lifecycle. Example: make test
test:
	@printf $(MSG_INFO) "Running Smoke Test for all blueprints ..."
	bash $(MKFILEDIR)/blueprints/test-all.sh

.PHONY: help
help: ## Makefile Help Page
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n\nTargets:\n"} /^[\/\%a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-21s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST) 2>/dev/null
	@printf "\nDebug: Use -d flag with targets. Example: ROOT=02-at-scale make -d validate \n\n"

.PHONY: guard-%
guard-%:
	@if [[ "${${*}}" == "" ]]; then printf "\033[0;31m[ERROR]\033[0m %s\n" "Environment variable $* not set."; exit 1; fi
