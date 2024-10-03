#!/bin/bash

set -o pipefail
set -x

# Constants
TAG_KEY1="ingress.k8s.aws/stack"
TAG_VALUE1="kube-prometheus-stack-grafana"
TAG_KEY2="elbv2.k8s.aws/cluster"
OBSERVABABILITY_NS="observability"
#Paranmeters cluster name
EKS_CLUSTER_NAME="$1"
REGION="$2"

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
    echo "$command failed. Retrying in $wait seconds..."
    sleep $wait
    retry $((retries - 1)) "$command"
  else
    return $exit_code
  fi
}


#https://github.com/cloudbees/terraform-aws-cloudbees-ci-eks-addon/issues/165

# List all ALBs
load_balancers=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[*].LoadBalancerArn' --output text --region "$REGION")

# Loop through all load balancers to find the one with the desired tag
for lb_arn in $load_balancers; do
    # Describe tags for the current load balancer
    tags=$(aws elbv2 describe-tags --resource-arns "$lb_arn" --region "$REGION")
    if echo "$tags" | jq -e --arg key1 "$TAG_KEY1" --arg value1 "$OBSERVABABILITY_NS/$TAG_VALUE1" --arg key2 "$TAG_KEY2" --arg value2 "$EKS_CLUSTER_NAME" '
        .TagDescriptions[].Tags |
        any(.[]; .Key == $key1 and .Value == $value1) and
        any(.[]; .Key == $key2 and .Value == $value2)
    ' > /dev/null; then

        # Describe the load balancer to get its security groups
        lb_desc=$(aws elbv2 describe-load-balancers --load-balancer-arns "$lb_arn" --region "$REGION")
        security_groups=$(echo "$lb_desc" | jq -r '.LoadBalancers[].SecurityGroups[]')

        # Delete the load balancer
        aws elbv2 delete-load-balancer --load-balancer-arn "$lb_arn" --region "$REGION"
        echo "Load Balancer with ARN: $lb_arn deleted"

    fi
done

# Delete the security groups

if [ -n "$security_groups" ]; then
  for sg in $security_groups; do
    retry 5 "aws ec2 delete-security-group --group-id $sg --region $REGION"
    echo "Security Group: $sg deleted"
  done
else
  echo "No security groups found for Load Balancer with ARN: $lb_arn"
fi
