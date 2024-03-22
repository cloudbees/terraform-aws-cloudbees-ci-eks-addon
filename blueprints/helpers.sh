#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -euox pipefail

SCRIPTDIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

declare -a BLUEPRINTS=(
    "01-getting-started"
    "02-at-scale"
  )

INFO () {
  printf "\033[36m[INFO] %s\033[0m\n" "$1"
}

WARN () {
  printf "\033[0;33m[WARN] %s\033[0m\n" "$1"
}

ERROR () {
  printf "\033[0;31m[ERROR] %s\033[0m\n" "$1"
  exit 1
}

bpAgent-dRun (){
  local bpAgentUser="bp-agent"
  local bpAgentLocalImage="local.cloudbees/bp-agent"
	if [ "$(docker image ls | grep -c "$bpAgentLocalImage")" -eq 0 ]; then \
		INFO "Building Docker Image local.cloudbees/bp-agent:latest" && \
		docker build . --file "$SCRIPTDIR/../.docker/agent/agent.rootless.Dockerfile" --tag "$bpAgentLocalImage"; \
		fi
	docker run --rm -it --name "$bpAgentUser" \
		-v "$SCRIPTDIR/..":"/$bpAgentUser/cbci-eks-addon" -v "$HOME/.aws":"/$bpAgentUser/.aws" \
		"$bpAgentLocalImage"
}

ask-confirmation () {
  local msg=$1
  INFO "Asking for your confirmation to $msg. [yes/No]"
	read -r ans && [ "$ans" = "yes" ]
}

retry () {
  local retries="$1"
  local command="$2"
  local options="$-"
  local wait=150

  if [[ $options == *e* ]]; then
    set +e
  fi

  $command
  local exit_code=$?

  if [[ $options == *e* ]]; then
    set -e
  fi

  if [[ $exit_code -ne 0 && $retries -gt 0 ]]; then
    WARN "$command failed. Retrying in $wait seconds..."
    sleep $wait
    retry $((retries - 1)) "$command"
  else
    return $exit_code
  fi
}

tf-output () {
  local root=$1
  local output=$2
  terraform -chdir="$SCRIPTDIR/$root" output -raw "$output" 2> /dev/null
}

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
tf-apply () {
  local root=$1
  export TF_LOG_PATH="$SCRIPTDIR/$root/terraform.log"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -target=module.vpc -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -target=module.eks -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -auto-approve"
  terraform -chdir="$SCRIPTDIR/$root" output > "$SCRIPTDIR/$root/terraform.output"
}

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
tf-destroy () {
  local root=$1
  export TF_LOG_PATH="$SCRIPTDIR/$root/terraform.log"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks_blueprints_addon_cbci -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks_blueprints_addons -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -auto-approve"
  rm -f "$SCRIPTDIR/$root/terraform.output"
}

probes () {
  local root=$1
  local wait=5
  eval "$(tf-output "$root" kubeconfig_export)"
  until [ "$(eval "$(tf-output "$root" cbci_oc_pod)" | awk '{ print $3 }' | grep -v STATUS | grep -v -c Running)" == 0 ]; do sleep 10 && echo "Waiting for Operation Center Pod to get ready..."; done ;\
    eval "$(tf-output "$root" cbci_oc_pod)" && INFO "OC Pod is Ready."
  until eval "$(tf-output "$root" cbci_liveness_probe_int)"; do sleep $wait && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster..."; done
    INFO "Operation Center Service passed Health Check inside the cluster." ;\
  until eval "$(tf-output "$root" cbci_oc_ing)"; do sleep $wait && echo "Waiting for Operation Center Ingress to get ready..."; done ;\
    INFO "Operation Center Ingress Ready."
  OC_URL=$(tf-output "$root" cbci_oc_url)
  until eval "$(tf-output "$root" cbci_liveness_probe_ext)"; do sleep $wait && echo "Waiting for Operation Center Service to pass Health Check from outside the clustery..."; done ;\
    INFO "Operation Center Service passed Health Check outside the cluster. It is available at $OC_URL."
  if [ "$root" == "01-getting-started" ]; then
    INITIAL_PASS=$(eval "$(tf-output "$root" cbci_initial_admin_password)"); \
      INFO "Initial Admin Password: $INITIAL_PASS."
  fi
  if [ "$root" == "02-at-scale" ]; then
    ADMIN_CBCI_A_PASS=$(eval "$(tf-output "$root" ldap_admin_password)") && \
      if [ -n "$ADMIN_CBCI_A_PASS" ]; then
        INFO "Password for admin_cbci_a: $ADMIN_CBCI_A_PASS."
      else
        ERROR "Problem while getting Password for admin_cbci_a."
      fi
    until [ "$(eval "$(tf-output "$root" cbci_controllers_pods)" | awk '{ print $3 }' | grep -v STATUS | grep -v -c Running)" == 0 ]; do sleep $wait && echo "Waiting for Controllers Pod to get into Ready State..."; done ;\
      eval "$(tf-output "$root" cbci_controllers_pods)" && INFO "All Controllers Pods are Ready."
    until eval "$(tf-output "$root" cbci_controller_c_hpa)"; do sleep $wait && echo "Waiting for Team C HPA to get Ready..."; done ;\
      INFO "Team C HPA is Ready."
    eval "$(tf-output "$root" cbci_oc_export_admin_crumb)" && eval "$(tf-output "$root" cbci_oc_export_admin_api_token)" && \
      if [ -n "$CBCI_ADMIN_TOKEN" ]; then 
        INFO "Admin Token: $CBCI_ADMIN_TOKEN"
      else 
        ERROR "Problem while getting Admin Token"
      fi
    eval "$(tf-output "$root" cbci_controller_b_hibernation_post_queue_ws_cache)" > /tmp/ws-cache-build-trigger && \
      grep "HTTP/2 201" /tmp/ws-cache-build-trigger && \
      INFO "Hibernation Post Queue WS Cache is working."
    until [ "$(eval "$(tf-output "$root" cbci_agents_events_stopping)" | wc -l)" -ge 3 ]; do sleep $wait && echo "Waiting for Agent Pod to complete to run a job"; done ;\
      eval "$(tf-output "$root" cbci_agents_events_stopping)" && INFO "Agent Pods are Ready."
    eval "$(tf-output "$root" velero_backup_schedule_team_a)" && eval "$(tf-output "$root" velero_backup_on_demand_team_a)" > "/tmp/backup.txt" && \
      grep "Backup completed with status: Completed" "/tmp/backup.txt" && \
      INFO "Velero backups are working"
    until eval "$(tf-output "$root" prometheus_active_targets)" | jq '.data.activeTargets[] | select(.labels.container=="jenkins") | {job: .labels.job, instance: .labels.instance, status: .health}'; do sleep $wait && echo "Waiting for CloudBees CI Prometheus Targets..."; done ;\
      INFO "CloudBees CI Targets are loaded in Prometheus."
    until eval "$(tf-output "$root" aws_logstreams_fluentbit)" | jq '.[] '; do sleep $wait && echo "Waiting for CloudBees CI Log streams in CloudWatch..."; done ;\
      INFO "CloudBees CI Log Streams are already in Cloud Watch."
  fi
}

test-all () {
  for bp in "${BLUEPRINTS[@]}"
  do
    export ROOT="$bp"
    cd "$SCRIPTDIR"/.. && make test
  done
}

clean() {
  local root=$1
  cd "$SCRIPTDIR/$root" && \
    rm -rf ".terraform" && \
	  rm -f ".terraform.lock.hcl" "k8s/kubeconfig_*.yaml"  "terraform.output" "terraform.log" "tfplan.txt"
}

set-kube-env () {
  # shellcheck source=/dev/null
  source "$SCRIPTDIR/.k8s.env"
  # shellcheck disable=SC2154
  sed -i "/#vCBCI_Helm#/{n;s/\".*\"/\"$vCBCI_Helm\"/;}" "$SCRIPTDIR/../main.tf"
  for bp in "${BLUEPRINTS[@]}"
  do
    # shellcheck disable=SC2154
    sed -i -e "/#vK8#/{n;s/\".*\"/\"$vK8\"/;}" \
      -e "/#vEKSBpAddonsTFMod#/{n;s/\".*\"/\"$vEKSBpAddonsTFMod\"/;}" "$SCRIPTDIR/$bp/main.tf"
  done
}

set-casc-branch () {
  local branch=$1
  sed -i "s|scmBranch: .*|scmBranch: $branch|g" "$SCRIPTDIR/02-at-scale/k8s/cbci-values.yml"
  sed -i "s|casc_branch: .*|casc_branch: $branch|g" "$SCRIPTDIR/02-at-scale/casc/oc/variables/variables.yaml"
  sed -i "s|bundle: \".*/none-ha\"|bundle: \"$branch/none-ha\"|g" "$SCRIPTDIR/02-at-scale/casc/oc/items/items-root.yaml"
  sed -i "s|bundle: \".*/ha\"|bundle: \"$branch/ha\"|g" "$SCRIPTDIR/02-at-scale/casc/oc/items/items-root.yaml"
}

#https://github.com/kyounger/casc-plugin-dependency-calculation/blob/master/README.md#using-the-docker-image
#NOTE: Using --platform linux/x86_64 to avoid issues with M1 Macs
casc-docker-run () {
  docker run --platform linux/x86_64 -v "$(pwd)":"$(pwd)" -w "$(pwd)" -u "$(id -u)":"$(id -g)" --rm -it ghcr.io/kyounger/casc-plugin-dependency-calculation bash
}

casc-script-exec () {
  # shellcheck source=/dev/null
  source "$SCRIPTDIR/.k8s.env"
  # shellcheck disable=SC2154
  local version="$vCBCI_App"
  local type="$1"
  local plugins_source="$2"
  actual_plugins_folder=/tmp/tmp-plugin-calculations
  mkdir -p $actual_plugins_folder || rm -rf "$actual_plugins_folder/*.*"
  cascdeps \
		-v "$version" \
		-t "$type" \
		-f "$plugins_source" \
		-F "$actual_plugins_folder/plugins.yaml" \
		-c "$actual_plugins_folder/plugin-catalog.yaml" \
		-C "$actual_plugins_folder/plugin-catalog-offline.yaml" \
		-s \
		-g "$actual_plugins_folder/plugins-minimal-for-generation-only.yaml" \
		-G "$actual_plugins_folder/plugins-minimal.yaml"
}