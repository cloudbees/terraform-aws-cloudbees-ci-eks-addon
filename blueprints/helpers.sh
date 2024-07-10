#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -euox pipefail

SCRIPTDIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

#https://developer.hashicorp.com/terraform/internals/debugging
export TF_LOG=DEBUG

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
  local msg="$1"
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
  local root="$1"
  local output="$2"
  terraform -chdir="$SCRIPTDIR/$root" output -raw "$output" 2> /dev/null
}

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#deploy
tf-apply () {
  local root="$1"
  export TF_LOG_PATH="$SCRIPTDIR/$root/terraform.log"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -target=module.vpc -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -target=module.eks -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root apply -auto-approve"
  terraform -chdir="$SCRIPTDIR/$root" output > "$SCRIPTDIR/$root/terraform.output"
}

#https://aws-ia.github.io/terraform-aws-eks-blueprints/getting-started/#destroy
tf-destroy () {
  local root="$1"
  export TF_LOG_PATH="$SCRIPTDIR/$root/terraform.log"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks_blueprints_addon_cbci -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks_blueprints_addons -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -target=module.eks -auto-approve"
  retry 3 "terraform -chdir=$SCRIPTDIR/$root destroy -auto-approve"
  rm -f "$SCRIPTDIR/$root/terraform.output"
}

probes () {
  local root="$1"
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
    until [ "$(eval "$(tf-output "$root" cbci_controllers_pods)" | awk '{ print $3 }' | grep -v STATUS | grep -v -c Running)" == 0 ]; do sleep $wait && echo "Waiting for Controllers Pod to get into Ready State..."; done ;\
      eval "$(tf-output "$root" cbci_controllers_pods)" && INFO "All Controllers Pods are Ready."
    GLOBAL_PASS=$(eval "$(tf-output "$root" global_password)") && \
      if [ -n "$GLOBAL_PASS" ]; then
        INFO "Password for admin_cbci_a: $GLOBAL_PASS."
      else
        ERROR "Problem while getting Global Pass."
      fi
    until { eval "$(tf-output "$root" cbci_oc_export_admin_crumb)" && eval "$(tf-output "$root" cbci_oc_export_admin_api_token)" && [ -n "$CBCI_ADMIN_TOKEN" ]; }; do sleep $wait && echo "Waiting for Admin Token..."; done && INFO "Admin Token: $CBCI_ADMIN_TOKEN"
    eval "$(tf-output "$root" cbci_controller_b_ws_cache_build)" > /tmp/controller-b-hibernation &&
      if grep "201\|202" /tmp/controller-b-hibernation; then
        INFO "Hibernation Post Queue Controller B OK."
      else
        ERROR "Hibernation Post Queue Controller B KO."
      fi
    eval "$(tf-output "$root" cbci_controller_c_windows_node_build)" > /tmp/controller-c-hibernation &&
      if grep "201\|202" /tmp/controller-c-hibernation; then
        INFO "Hibernation Post Queue Controller C OK."
      else
        ERROR "Hibernation Post Queue Controller C KO."
      fi
    until eval "$(tf-output "$root" cbci_controller_c_hpa)"; do sleep $wait && echo "Waiting for Team C HPA to get Ready..."; done ;\
      INFO "Team C HPA is Ready."
    until [ "$(eval "$(tf-output "$root" cbci_agent_windowstempl_events)" | grep -c 'Allocated Resource vpc.amazonaws.com')" -ge 1 ]; do sleep $wait && echo "Waiting for Windows Template Pod to allocate resource vpc.amazonaws.com"; done ;\
      eval "$(tf-output "$root" cbci_agent_windowstempl_events)" && INFO "Windows Template Example is OK."
    until [ "$(eval "$(tf-output "$root" cbci_agent_linuxtempl_events)" | grep -c 'Created container maven')" -ge 1 ]; do sleep $wait && echo "Waiting for Linux Template Pod to create maven container"; done ;\
      eval "$(tf-output "$root" cbci_agent_linuxtempl_events)" && INFO "Linux Template Example is OK."
    until [ "$(eval "$(tf-output "$root" s3_list_objects)" | grep -c 'cbci/')" -ge 1 ]; do sleep $wait && echo "Waiting for WS Cache to be uploaded into s3 cbci"; done ;\
      eval "$(tf-output "$root" s3_list_objects)" | grep 'cbci/' && INFO "CBCI s3 Permissions are configured correctly."
    eval "$(tf-output "$root" velero_backup_schedule)" && eval "$(tf-output "$root" velero_backup_on_demand)" > /tmp/velero-backup.txt && \
      if grep 'Backup completed with status: Completed' /tmp/velero-backup.txt; then
        INFO "Velero Backups are OK."
      else
        ERROR "Velero Backups are K0."
      fi
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
  local root="$1"
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

set-casc-location () {
  local endpoint="$1"
  local branch="$2"
  #Endpoint
  sed -i "s|scmRepo: .*|scmRepo: \"$endpoint\"|g" "$SCRIPTDIR/02-at-scale/k8s/cbci-values.yml"
  sed -i "s|scmCascMmStore: .*|scmCascMmStore: \"$endpoint\"|g" "$SCRIPTDIR/02-at-scale/casc/oc/variables/variables.yaml"
  #Branch
  sed -i "s|scmBranch: .*|scmBranch: $branch|g" "$SCRIPTDIR/02-at-scale/k8s/cbci-values.yml"
  sed -i "s|cascBranch: .*|cascBranch: $branch|g" "$SCRIPTDIR/02-at-scale/casc/oc/variables/variables.yaml"
  sed -i "s|bundle: \".*/none-ha\"|bundle: \"$branch/none-ha\"|g" "$SCRIPTDIR/02-at-scale/casc/oc/items/root.yaml"
  sed -i "s|bundle: \".*/ha\"|bundle: \"$branch/ha\"|g" "$SCRIPTDIR/02-at-scale/casc/oc/items/root.yaml"
}

run-aws-nuke () {
  local dry_run="$1"
  local aws_nuke_file="$SCRIPTDIR/../.cloudbees/aws-nuke/bp-tf-ci-nuke.yaml"
  local aws_nuke_file_log="$SCRIPTDIR/../.cloudbees/aws-nuke/aws-nuke.log"
  if [ "$dry_run" == "true" ]; then
    INFO "Running AWS Nuke in Dry Run Mode..."
    rm "$aws_nuke_file_log" || INFO "No log file to remove."
    aws-nuke -c "$aws_nuke_file" | tee "$aws_nuke_file_log"
    INFO "Listing candidated resources to be deleted by using $aws_nuke_file"
    grep "remove" "$aws_nuke_file_log" ||  INFO "No candidates to delete."
  else
    WARN "Running AWS Nuke in Not Dry Run Mode..."
    aws-nuke -c "$aws_nuke_file" --no-dry-run
  fi
}
