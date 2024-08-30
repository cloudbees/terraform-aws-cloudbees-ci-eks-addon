#!/bin/bash

set -x

# Constants
TAG_KEY1="ingress.k8s.aws/stack"
TAG_VALUE1="observability/kube-prometheus-stack-grafana"
TAG_KEY2="elbv2.k8s.aws/cluster"
#Paranmeters cluster name
TAG_VALUE2="cbci-bp02-carlos4-eks" 
REGION="us-east-1"

# List all ALBs
load_balancers=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text --region "$REGION")

# Loop through all load balancers to find the one with the desired tag
for lb_arn in $load_balancers; do
    # Describe tags for the current load balancer
    tags=$(aws elbv2 describe-tags --resource-arns "$lb_arn" --region "$REGION")
    if echo "$tags" | jq -e --arg key1 "$TAG_KEY1" --arg value1 "$TAG_VALUE1" --arg key2 "$TAG_KEY2" --arg value2 "$TAG_VALUE2" '
        .TagDescriptions[].Tags | 
        any(.[]; .Key == $key1 and .Value == $value1) and 
        any(.[]; .Key == $key2 and .Value == $value2)
    ' > /dev/null; then
        echo "Deleting Load Balancer with ARN: $lb_arn"
        # Delete the load balancer
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION"
    fi
done