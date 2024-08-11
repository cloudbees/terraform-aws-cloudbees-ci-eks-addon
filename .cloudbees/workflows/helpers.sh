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

kms-delete-alias() {
    local alias_name=$1
    local region=$2
    aws kms delete-alias \
          --alias-name "$alias_name" \
          --region "$region" || echo "$alias_name does not exist"
}

s3-put-object() {
    local bucket_name=$1
    local region=$2
    local key=$3
    local body=$4
    aws s3api put-object \
        --bucket "$bucket_name" \
        --region "$region" \
        --key "$key" \
        --body "$body" || echo "Failed to put object"
}

