#!/usr/bin/env bash

set -e

SCRIPTDIR="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MSG_INFO="\033[36m[INFO] %s\033[0m\n"

export TF_LOG=DEBUG

test () {
  local ROOT=$1
  export TF_LOG_PATH="$SCRIPTDIR/$ROOT/terraform.log"
  cd "$SCRIPTDIR"/.. && make deploy
  cd "$SCRIPTDIR"/.. && make validate
  cd "$SCRIPTDIR"/.. && make destroy
  cd "$SCRIPTDIR"/.. && make clean
}

test-all () {
  declare -a bluePrints=(
    "01-getting-started"
    "02-at-scale"
  )
  for var in "${bluePrints[@]}"
  do
    test "${var}"
  done
}

get-tf-output () {
  local ROOT=$1
  local OUTPUT=$2
  cd "$SCRIPTDIR/$ROOT" && terraform output -raw "$OUTPUT" 2> /dev/null
}

rules-general () {
  local ROOT=$1
  eval "$(get-tf-output "$ROOT" kubeconfig_export)"
  until eval "$(get-tf-output "$ROOT" cbci_oc_pod)"; do sleep 10 && echo "Waiting for Operation Center Pod to get ready..."; done ;\
    printf "$MSG_INFO" "OC Pod is Ready."
  until eval "$(get-tf-output "$ROOT" cbci_liveness_probe_int)"; do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from inside the cluster..."; done
    printf "$MSG_INFO" "Operation Center Service passed Health Check inside the cluster." ;\
  until eval "$(get-tf-output "$ROOT" cbci_oc_ing)"; do sleep 10 && echo "Waiting for Operation Center Ingress to get ready..."; done ;\
    printf "$MSG_INFO" "Operation Center Ingress Ready."
  OC_URL=$(get-tf-output "$ROOT" cbci_oc_url)
  until eval "$(get-tf-output "$ROOT" cbci_liveness_probe_ext)"; do sleep 10 && echo "Waiting for Operation Center Service to pass Health Check from outside the clustery..."; done ;\
    printf "$MSG_INFO" "Operation Center Service passed Health Check outside the cluster. It is available at $OC_URL."
}

rules-bp01 () {
  local ROOT="01-getting-started"
  INITIAL_PASS=$(eval "$(get-tf-output "$ROOT" cbci_initial_admin_password)"); \
    printf "$MSG_INFO" "Initial Admin Password: $INITIAL_PASS."
}

rules-bp02 () {
  local ROOT="02-at-scale"
  GENERAL_PASS=$(eval "$(get-tf-output "$ROOT" cbci_general_password)"); \
    printf "$MSG_INFO" "General Password all users: $GENERAL_PASS."
}
