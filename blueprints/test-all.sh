#!/usr/bin/env bash

# This script runs the smoke test for all blueprints throughout their Terraform Lifecycle
# 1. Deploy
# 2. Validate
# 3. Destroy

set -e

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

export TF_LOG=DEBUG

declare -a bluePrints=(
  #"01-getting-started"
  "02-at-scale"
)

test () {
  printf "\033[36mRunning Smoke Test for CloudBees CI Blueprint %s...\033[0m\n\n" "$1"
  export ROOT=$1
  export TF_LOG_PATH="$HERE/$ROOT/terraform.log"
  cd "$HERE"/.. && make tfDeploy
  cd "$HERE"/.. && make validate
  cd "$HERE"/.. && make tfDestroy
  cd "$HERE"/.. && make clean
}

for var in "${bluePrints[@]}"
do
  test "${var}"
done
