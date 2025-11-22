#!/bin/bash

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           DESTRUCTION VERIFICATION SCRIPT                         ║${NC}"
echo -e "${CYAN}║     Checking if all AWS resources have been deleted              ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

ISSUES_FOUND=0
TOTAL_CHECKS=0

check_resource() {
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    if [ -n "$2" ]; then
        echo -e "${RED}  ✗ Found: $2${NC}"
        ISSUES_FOUND=$((ISSUES_FOUND + 1))
        return 1
    else
        echo -e "${GREEN}  ✓ None found${NC}"
        return 0
    fi
}

echo -e "${BLUE}Checking AWS Resources...${NC}"
echo ""

# EKS Clusters
echo -e "${YELLOW}1. EKS Clusters:${NC}"
EKS_CLUSTERS=$(aws eks list-clusters --query 'clusters[?contains(@, `ecommerce`)]' --output text 2>/dev/null || echo "")
check_resource "EKS" "$EKS_CLUSTERS"

# RDS Instances
echo -e "${YELLOW}2. RDS Instances:${NC}"
RDS_INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `ecommerce`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
check_resource "RDS" "$RDS_INSTANCES"

# DynamoDB Tables
echo -e "${YELLOW}3. DynamoDB Tables:${NC}"
DYNAMODB_TABLES=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `ecommerce`)]' --output text 2>/dev/null || echo "")
check_resource "DynamoDB" "$DYNAMODB_TABLES"

# MSK Clusters
echo -e "${YELLOW}4. MSK Kafka Clusters:${NC}"
MSK_CLUSTERS=$(aws kafka list-clusters --query 'ClusterInfoList[?contains(ClusterName, `ecommerce`)].ClusterName' --output text 2>/dev/null || echo "")
check_resource "MSK" "$MSK_CLUSTERS"

# S3 Buckets
echo -e "${YELLOW}5. S3 Buckets:${NC}"
S3_BUCKETS=$(aws s3 ls | grep ecommerce | awk '{print $3}' || echo "")
check_resource "S3" "$S3_BUCKETS"

# Lambda Functions
echo -e "${YELLOW}6. Lambda Functions:${NC}"
LAMBDA_FUNCTIONS=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `s3-file-processor`) || contains(FunctionName, `ecommerce`)].FunctionName' --output text 2>/dev/null || echo "")
check_resource "Lambda" "$LAMBDA_FUNCTIONS"

# VPCs
echo -e "${YELLOW}7. VPCs (tagged with ecommerce):${NC}"
VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*ecommerce*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
check_resource "VPC" "$VPCS"

# LoadBalancers
echo -e "${YELLOW}8. LoadBalancers:${NC}"
LOAD_BALANCERS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `ecommerce`) || contains(LoadBalancerName, `k8s`)].LoadBalancerName' --output text 2>/dev/null || echo "")
check_resource "LoadBalancer" "$LOAD_BALANCERS"

# Target Groups
echo -e "${YELLOW}9. Target Groups:${NC}"
TARGET_GROUPS=$(aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `ecommerce`) || contains(TargetGroupName, `k8s`)].TargetGroupName' --output text 2>/dev/null || echo "")
check_resource "TargetGroup" "$TARGET_GROUPS"

# ECR Repositories
echo -e "${YELLOW}10. ECR Repositories:${NC}"
ECR_REPOS=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `ecommerce`)].repositoryName' --output text 2>/dev/null || echo "")
check_resource "ECR" "$ECR_REPOS"

# NAT Gateways
echo -e "${YELLOW}11. NAT Gateways:${NC}"
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available,pending" --query 'NatGateways[?contains(to_string(Tags), `ecommerce`)].NatGatewayId' --output text 2>/dev/null || echo "")
check_resource "NAT Gateway" "$NAT_GATEWAYS"

# Elastic IPs
echo -e "${YELLOW}12. Elastic IPs:${NC}"
ELASTIC_IPS=$(aws ec2 describe-addresses --query 'Addresses[?contains(to_string(Tags), `ecommerce`)].AllocationId' --output text 2>/dev/null || echo "")
check_resource "Elastic IP" "$ELASTIC_IPS"

# Internet Gateways
echo -e "${YELLOW}13. Internet Gateways:${NC}"
INTERNET_GATEWAYS=$(aws ec2 describe-internet-gateways --filters "Name=tag:Name,Values=*ecommerce*" --query 'InternetGateways[].InternetGatewayId' --output text 2>/dev/null || echo "")
check_resource "Internet Gateway" "$INTERNET_GATEWAYS"

# Subnets
echo -e "${YELLOW}14. Subnets:${NC}"
SUBNETS=$(aws ec2 describe-subnets --filters "Name=tag:Name,Values=*ecommerce*" --query 'Subnets[].SubnetId' --output text 2>/dev/null || echo "")
check_resource "Subnet" "$SUBNETS"

# Security Groups
echo -e "${YELLOW}15. Security Groups:${NC}"
SECURITY_GROUPS=$(aws ec2 describe-security-groups --query 'SecurityGroups[?contains(GroupName, `ecommerce`) && GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
check_resource "Security Group" "$SECURITY_GROUPS"

# Route Tables
echo -e "${YELLOW}16. Route Tables:${NC}"
ROUTE_TABLES=$(aws ec2 describe-route-tables --filters "Name=tag:Name,Values=*ecommerce*" --query 'RouteTables[].RouteTableId' --output text 2>/dev/null || echo "")
check_resource "Route Table" "$ROUTE_TABLES"

# CloudWatch Log Groups
echo -e "${YELLOW}17. CloudWatch Log Groups:${NC}"
LOG_GROUPS=$(aws logs describe-log-groups --query 'logGroups[?contains(logGroupName, `ecommerce`) || contains(logGroupName, `/aws/eks`)].logGroupName' --output text 2>/dev/null || echo "")
check_resource "Log Group" "$LOG_GROUPS"

# IAM Roles (with ecommerce prefix)
echo -e "${YELLOW}18. IAM Roles:${NC}"
IAM_ROLES=$(aws iam list-roles --query 'Roles[?contains(RoleName, `ecommerce`)].RoleName' --output text 2>/dev/null || echo "")
check_resource "IAM Role" "$IAM_ROLES"

# EC2 Instances
echo -e "${YELLOW}19. EC2 Instances:${NC}"
EC2_INSTANCES=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=*ecommerce*" "Name=instance-state-name,Values=running,pending,stopping,stopped" --query 'Reservations[].Instances[].InstanceId' --output text 2>/dev/null || echo "")
check_resource "EC2 Instance" "$EC2_INSTANCES"

# Auto Scaling Groups
echo -e "${YELLOW}20. Auto Scaling Groups:${NC}"
ASG_GROUPS=$(aws autoscaling describe-auto-scaling-groups --query 'AutoScalingGroups[?contains(AutoScalingGroupName, `ecommerce`)].AutoScalingGroupName' --output text 2>/dev/null || echo "")
check_resource "Auto Scaling Group" "$ASG_GROUPS"

# Terraform State
echo -e "${YELLOW}21. Terraform State:${NC}"
cd terraform/aws 2>/dev/null
TERRAFORM_RESOURCES=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
if [ "$TERRAFORM_RESOURCES" -gt 0 ]; then
    echo -e "${RED}  ✗ Terraform state has $TERRAFORM_RESOURCES resources${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ Terraform state is clean${NC}"
fi
cd - >/dev/null 2>&1

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}VERIFICATION SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Total Checks:     $TOTAL_CHECKS${NC}"
echo -e "${GREEN}Clean:            $((TOTAL_CHECKS - ISSUES_FOUND))${NC}"
echo -e "${RED}Issues Found:     $ISSUES_FOUND${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              ✓✓✓ VERIFICATION PASSED! ✓✓✓                        ║${NC}"
    echo -e "${GREEN}║                                                                   ║${NC}"
    echo -e "${GREEN}║        ALL resources have been successfully destroyed!           ║${NC}"
    echo -e "${GREEN}║        Your AWS account is completely clean.                     ║${NC}"
    echo -e "${GREEN}║        No ongoing costs. ✓                                        ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    exit 0
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║                ⚠  RESOURCES STILL EXIST ⚠                        ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  $ISSUES_FOUND resource type(s) still exist in your account.              ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  NEXT STEPS:                                                      ║${NC}"
    echo -e "${YELLOW}║  1. Wait 5-10 minutes for AWS to finish deletion                 ║${NC}"
    echo -e "${YELLOW}║  2. Run this script again: ./verify-destruction.sh               ║${NC}"
    echo -e "${YELLOW}║  3. If issues persist, manually delete from AWS Console          ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    exit 1
fi
