#!/usr/bin/env bash

# Copyright (c) CloudBees, Inc.

set -euox pipefail

AWS_REGION_TF_BUCKET="us-east-1"
NAME_TF_BUCKET="cbci-eks-addon-tf-state-cd"

s3-create-bucket() {
    aws s3api create-bucket \
        --bucket "$NAME_TF_BUCKET" \
        --region "$AWS_REGION_TF_BUCKET" || echo "$NAME_TF_BUCKET already exists"
}

s3-put-object() {
    #origin
    local body=$2
    #target
    local key=$1
    aws s3api put-object \
        --bucket "$NAME_TF_BUCKET" \
        --region "$AWS_REGION_TF_BUCKET" \
        --body "$body" \
        --key "$key" || echo "Failed to put $body object in $NAME_TF_BUCKET"
}
