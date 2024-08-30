#!/bin/bash

set -x

#!/bin/bash

VPC_ID="vpc-085708123cabfb7a2"
REGION="us-east-1"

# Delete Subnets
subnets=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[*].SubnetId' --output text --region "$REGION")
for subnet in $subnets; do
    echo "Deleting Subnet: $subnet"
    aws ec2 delete-subnet --subnet-id $subnet --region "$REGION"
done

# Detach and Delete Internet Gateways
igws=$(aws ec2 describe-internet-gateways --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[*].InternetGatewayId' --output text --region "$REGION")
for igw in $igws; do
    echo "Detaching and Deleting Internet Gateway: $igw"
    aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VPC_ID --region "$REGION"
    aws ec2 delete-internet-gateway --internet-gateway-id $igw --region "$REGION"
done

# Delete Route Tables
route_tables=$(aws ec2 describe-route-tables --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[*].RouteTableId' --output text --region "$REGION")
for rt in $route_tables; do
    echo "Deleting Route Table: $rt"
    aws ec2 delete-route-table --route-table-id $rt --region "$REGION"
done

# Delete Network ACLs
network_acls=$(aws ec2 describe-network-acls --filters "Name=vpc-id,Values=$VPC_ID" --query 'NetworkAcls[*].NetworkAclId' --output text --region "$REGION")
for acl in $network_acls; do
    echo "Deleting Network ACL: $acl"
    aws ec2 delete-network-acl --network-acl-id $acl
done

# Delete Security Groups
security_groups=$(aws ec2 describe-security-groups --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[*].GroupId' --output text --region "$REGION")
for sg in $security_groups; do
    echo "Deleting Security Group: $sg"
    aws ec2 delete-security-group --group-id $sg --region "$REGION"
done

# Delete VPC Endpoints
vpc_endpoints=$(aws ec2 describe-vpc-endpoints --filters "Name=vpc-id,Values=$VPC_ID" --query 'VpcEndpoints[*].VpcEndpointId' --output text --region "$REGION")
for vpc_endpoint in $vpc_endpoints; do
    echo "Deleting VPC Endpoint: $vpc_endpoint"
    aws ec2 delete-vpc-endpoint --vpc-endpoint-id $vpc_endpoint --region "$REGION"
done

# Delete the VPC
echo "Deleting VPC: $VPC_ID"
aws ec2 delete-vpc --vpc-id $VPC_ID --region "$REGION"