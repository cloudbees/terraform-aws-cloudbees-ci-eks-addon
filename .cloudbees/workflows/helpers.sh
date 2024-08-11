#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -euox pipefail

s3-create-bucket() {
    local bucket_name=$1
    local region=$2
    aws s3api create-bucket \
          --bucket "$bucket_name" \
          --region "$region" || echo "$bucket_name already exists"
}