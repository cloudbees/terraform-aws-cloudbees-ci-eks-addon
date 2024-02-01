#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -euox pipefail

SCRIPTDIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RETRY_SECONDS=10
MSG_INFO="\033[36m[INFO] %s\033[0m\n"

test-all () {
  declare -a bluePrints=(
    "01-getting-started"
    "02-at-scale"
  )
  for bp in "${bluePrints[@]}"
  do
    export ROOT="$bp"
    cd "$SCRIPTDIR"/.. && make test
  done
}

get-tf-output () {
  local ROOT=$1
  local OUTPUT=$2
  cd "$SCRIPTDIR/$ROOT" && terraform output -raw "$OUTPUT" 2> /dev/null
}

probes-common () {
  local ROOT=$1
  eval "$(get-tf-output "$ROOT" kubeconfig_export)"
  until [ "$(eval "$(get-tf-output "$ROOT" cbci_oc_pod)" | awk '{ print $3 }' | grep -v STATUS | grep -v -c Running)" == 0 ]; do sleep 10 && echo "Waiting for Operation Center Pod to get ready..."; done ;\
    eval "$(get-tf-output "$ROOT" cbci_oc_pod)" && printf "$MSG_INFO" "OC Pod is Ready."
  until eval "$(get-tf-output "$ROOT" cbci_liveness_probe_int)"; do sleep $RETRY_SECONDS && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster..."; done
    printf "$MSG_INFO" "Operation Center Service passed Health Check inside the cluster." ;\
  until eval "$(get-tf-output "$ROOT" cbci_oc_ing)"; do sleep $RETRY_SECONDS && echo "Waiting for Operation Center Ingress to get ready..."; done ;\
    printf "$MSG_INFO" "Operation Center Ingress Ready."
  OC_URL=$(get-tf-output "$ROOT" cbci_oc_url)
  until eval "$(get-tf-output "$ROOT" cbci_liveness_probe_ext)"; do sleep $RETRY_SECONDS && echo "Waiting for Operation Center Service to pass Health Check from outside the clustery..."; done ;\
    printf "$MSG_INFO" "Operation Center Service passed Health Check outside the cluster. It is available at $OC_URL."
}

probes-bp01 () {
  local ROOT="01-getting-started"
  eval "$(get-tf-output "$ROOT" kubeconfig_export)"
  INITIAL_PASS=$(eval "$(get-tf-output "$ROOT" cbci_initial_admin_password)"); \
    printf "$MSG_INFO" "Initial Admin Password: $INITIAL_PASS."
}

probes-bp02 () {
  local ROOT="02-at-scale"
  eval "$(get-tf-output "$ROOT" kubeconfig_export)"
  GENERAL_PASS=$(eval "$(get-tf-output "$ROOT" cbci_general_password)"); \
    printf "$MSG_INFO" "General Password all users: $GENERAL_PASS."
  until [ "$(eval "$(get-tf-output "$ROOT" cbci_controllers_pods)" | awk '{ print $3 }' | grep -v STATUS | grep -v -c Running)" == 0 ]; do sleep $RETRY_SECONDS && echo "Waiting for Controllers Pod to get into Ready State..."; done ;\
    eval "$(get-tf-output "$ROOT" cbci_controllers_pods)" && printf "$MSG_INFO" "All Controllers Pods are Ready..."
  until eval "$(get-tf-output "$ROOT" cbci_controller_c_hpa)"; do sleep $RETRY_SECONDS && echo "Waiting for Team C HPA to get Ready..."; done ;\
    printf "$MSG_INFO" "Team C HPA is Ready."
  eval "$(get-tf-output "$ROOT" velero_backup_schedule_team_a)" && eval "$(get-tf-output "$ROOT" velero_backup_on_demand_team_a)" > "/tmp/backup.txt" && \
		cat "/tmp/backup.txt" | grep "Backup completed with status: Completed" && \
		printf "$MSG_INFO" "Velero backups are working"
  until eval "$(get-tf-output "$ROOT" prometheus_active_targets)" | jq '.data.activeTargets[] | select(.labels.container=="jenkins" or .labels.job=="cjoc") | {job: .labels.job, instance: .labels.instance, status: .health}'; do sleep $RETRY_SECONDS && echo "Waiting for CloudBees CI Prometheus Targets..."; done ;\
    printf "$MSG_INFO" "CloudBees CI Targets are loaded in Prometheus."
  until eval "$(get-tf-output "$ROOT" aws_logstreams_fluentbit)" | jq '.[] | select(.logStreamName | contains("jenkins"))'; do sleep $RETRY_SECONDS && echo "Waiting for CloudBees CI Log streams in CloudWatch..."; done ;\
    printf "$MSG_INFO" "CloudBees CI Log Streams are already in Cloud Watch."
}
