#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║          COMPLETE INFRASTRUCTURE DESTRUCTION                      ║${NC}"
echo -e "${RED}║                  ⚠️  WARNING ⚠️                                    ║${NC}"
echo -e "${RED}║   This will DELETE ALL resources and cannot be undone!           ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Confirmation
read -p "Are you absolutely sure you want to destroy everything? (type 'YES' to confirm): " CONFIRM
if [ "$CONFIRM" != "YES" ]; then
    echo -e "${YELLOW}Destruction cancelled.${NC}"
    exit 0
fi

echo ""
echo -e "${CYAN}Starting complete infrastructure destruction...${NC}"
echo ""

# =============================================================================
# STEP 1: Delete Kubernetes Resources
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 1: Deleting Kubernetes Resources${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if kubectl is connected
if kubectl cluster-info &>/dev/null; then
    echo -e "${YELLOW}Deleting ArgoCD applications...${NC}"
    kubectl delete applications --all -n argocd --timeout=60s 2>/dev/null || true
    sleep 5
    
    echo -e "${YELLOW}Deleting ArgoCD namespace...${NC}"
    kubectl delete namespace argocd --timeout=120s 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting monitoring namespace...${NC}"
    kubectl delete namespace monitoring --timeout=120s 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting all services (to release LoadBalancers)...${NC}"
    kubectl delete svc --all --timeout=60s 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting all deployments...${NC}"
    kubectl delete deployments --all --timeout=60s 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting all HPAs...${NC}"
    kubectl delete hpa --all --timeout=30s 2>/dev/null || true
    
    echo -e "${YELLOW}Deleting all pods...${NC}"
    kubectl delete pods --all --force --grace-period=0 --timeout=60s 2>/dev/null || true
    
    echo -e "${GREEN}✓ Kubernetes resources deleted${NC}"
else
    echo -e "${YELLOW}⚠ Kubectl not connected, skipping Kubernetes cleanup${NC}"
fi

echo ""

# Wait for LoadBalancers to be released
echo -e "${YELLOW}Waiting 30 seconds for LoadBalancers to be released...${NC}"
sleep 30

# =============================================================================
# STEP 2: Delete Helm Releases
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 2: Deleting Helm Releases${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if command -v helm &> /dev/null; then
    echo -e "${YELLOW}Uninstalling Helm releases...${NC}"
    helm uninstall argocd -n argocd 2>/dev/null || true
    helm uninstall prometheus -n monitoring 2>/dev/null || true
    echo -e "${GREEN}✓ Helm releases uninstalled${NC}"
else
    echo -e "${YELLOW}⚠ Helm not found, skipping${NC}"
fi

echo ""

# =============================================================================
# STEP 3: Run Terraform Destroy
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 3: Destroying Terraform Infrastructure${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

cd terraform/aws

echo -e "${YELLOW}Running terraform destroy...${NC}"
echo -e "${CYAN}This may take 10-15 minutes...${NC}"
echo ""

# Run terraform destroy with auto-approve
terraform destroy -auto-approve

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Terraform destroy completed successfully${NC}"
else
    echo -e "${RED}✗ Terraform destroy encountered errors${NC}"
    echo -e "${YELLOW}Attempting to continue with verification...${NC}"
fi

cd ../..

echo ""

# Wait for resources to be fully deleted
echo -e "${YELLOW}Waiting 30 seconds for AWS resources to be fully deleted...${NC}"
sleep 30

# =============================================================================
# STEP 4: Manual Cleanup of Stuck Resources
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 4: Cleaning Up Any Remaining Resources${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Clean up LoadBalancers
echo -e "${YELLOW}Checking for remaining LoadBalancers...${NC}"
LB_ARNS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `ecommerce`) || contains(LoadBalancerName, `argocd`) || contains(LoadBalancerName, `prometheus`)].LoadBalancerArn' --output text 2>/dev/null || echo "")
if [ -n "$LB_ARNS" ]; then
    for LB_ARN in $LB_ARNS; do
        echo -e "${YELLOW}  Deleting LoadBalancer: $LB_ARN${NC}"
        aws elbv2 delete-load-balancer --load-balancer-arn "$LB_ARN" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ LoadBalancers cleanup initiated${NC}"
    sleep 10
else
    echo -e "${GREEN}✓ No LoadBalancers found${NC}"
fi

# Clean up Target Groups
echo -e "${YELLOW}Checking for remaining Target Groups...${NC}"
TG_ARNS=$(aws elbv2 describe-target-groups --query 'TargetGroups[?contains(TargetGroupName, `ecommerce`) || contains(TargetGroupName, `k8s`)].TargetGroupArn' --output text 2>/dev/null || echo "")
if [ -n "$TG_ARNS" ]; then
    for TG_ARN in $TG_ARNS; do
        echo -e "${YELLOW}  Deleting Target Group: $TG_ARN${NC}"
        aws elbv2 delete-target-group --target-group-arn "$TG_ARN" 2>/dev/null || true
    done
    echo -e "${GREEN}✓ Target Groups cleanup initiated${NC}"
else
    echo -e "${GREEN}✓ No Target Groups found${NC}"
fi

# Clean up Security Groups (wait a bit for dependencies)
sleep 15
echo -e "${YELLOW}Checking for remaining Security Groups...${NC}"
SG_IDS=$(aws ec2 describe-security-groups --query 'SecurityGroups[?contains(GroupName, `ecommerce`) && GroupName!=`default`].GroupId' --output text 2>/dev/null || echo "")
if [ -n "$SG_IDS" ]; then
    for SG_ID in $SG_IDS; do
        echo -e "${YELLOW}  Attempting to delete Security Group: $SG_ID${NC}"
        aws ec2 delete-security-group --group-id "$SG_ID" 2>/dev/null || echo -e "${YELLOW}    (May be in use, will be deleted with VPC)${NC}"
    done
    echo -e "${GREEN}✓ Security Groups cleanup attempted${NC}"
else
    echo -e "${GREEN}✓ No Security Groups found${NC}"
fi

echo ""

# =============================================================================
# STEP 5: Verification
# =============================================================================
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}STEP 5: Verifying Complete Destruction${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

ISSUES_FOUND=0

# Check EKS Clusters
echo -e "${YELLOW}Checking EKS clusters...${NC}"
EKS_CLUSTERS=$(aws eks list-clusters --query 'clusters[?contains(@, `ecommerce`)]' --output text 2>/dev/null || echo "")
if [ -n "$EKS_CLUSTERS" ]; then
    echo -e "${RED}  ✗ Found EKS clusters: $EKS_CLUSTERS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No EKS clusters found${NC}"
fi

# Check RDS Instances
echo -e "${YELLOW}Checking RDS instances...${NC}"
RDS_INSTANCES=$(aws rds describe-db-instances --query 'DBInstances[?contains(DBInstanceIdentifier, `ecommerce`)].DBInstanceIdentifier' --output text 2>/dev/null || echo "")
if [ -n "$RDS_INSTANCES" ]; then
    echo -e "${RED}  ✗ Found RDS instances: $RDS_INSTANCES${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No RDS instances found${NC}"
fi

# Check DynamoDB Tables
echo -e "${YELLOW}Checking DynamoDB tables...${NC}"
DYNAMODB_TABLES=$(aws dynamodb list-tables --query 'TableNames[?contains(@, `ecommerce`)]' --output text 2>/dev/null || echo "")
if [ -n "$DYNAMODB_TABLES" ]; then
    echo -e "${RED}  ✗ Found DynamoDB tables: $DYNAMODB_TABLES${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No DynamoDB tables found${NC}"
fi

# Check MSK Clusters
echo -e "${YELLOW}Checking MSK Kafka clusters...${NC}"
MSK_CLUSTERS=$(aws kafka list-clusters --query 'ClusterInfoList[?contains(ClusterName, `ecommerce`)].ClusterName' --output text 2>/dev/null || echo "")
if [ -n "$MSK_CLUSTERS" ]; then
    echo -e "${RED}  ✗ Found MSK clusters: $MSK_CLUSTERS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No MSK clusters found${NC}"
fi

# Check S3 Buckets
echo -e "${YELLOW}Checking S3 buckets...${NC}"
S3_BUCKETS=$(aws s3 ls | grep ecommerce | awk '{print $3}' || echo "")
if [ -n "$S3_BUCKETS" ]; then
    echo -e "${RED}  ✗ Found S3 buckets: $S3_BUCKETS${NC}"
    echo -e "${YELLOW}  Note: S3 buckets may need manual deletion if not empty${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No S3 buckets found${NC}"
fi

# Check Lambda Functions
echo -e "${YELLOW}Checking Lambda functions...${NC}"
LAMBDA_FUNCTIONS=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `s3-file-processor`)].FunctionName' --output text 2>/dev/null || echo "")
if [ -n "$LAMBDA_FUNCTIONS" ]; then
    echo -e "${RED}  ✗ Found Lambda functions: $LAMBDA_FUNCTIONS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No Lambda functions found${NC}"
fi

# Check VPCs
echo -e "${YELLOW}Checking VPCs...${NC}"
VPCS=$(aws ec2 describe-vpcs --filters "Name=tag:Name,Values=*ecommerce*" --query 'Vpcs[].VpcId' --output text 2>/dev/null || echo "")
if [ -n "$VPCS" ]; then
    echo -e "${RED}  ✗ Found VPCs: $VPCS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No VPCs found${NC}"
fi

# Check LoadBalancers
echo -e "${YELLOW}Checking LoadBalancers...${NC}"
LOAD_BALANCERS=$(aws elbv2 describe-load-balancers --query 'LoadBalancers[?contains(LoadBalancerName, `ecommerce`) || contains(LoadBalancerName, `k8s`)].LoadBalancerName' --output text 2>/dev/null || echo "")
if [ -n "$LOAD_BALANCERS" ]; then
    echo -e "${RED}  ✗ Found LoadBalancers: $LOAD_BALANCERS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No LoadBalancers found${NC}"
fi

# Check ECR Repositories
echo -e "${YELLOW}Checking ECR repositories...${NC}"
ECR_REPOS=$(aws ecr describe-repositories --query 'repositories[?contains(repositoryName, `ecommerce`)].repositoryName' --output text 2>/dev/null || echo "")
if [ -n "$ECR_REPOS" ]; then
    echo -e "${RED}  ✗ Found ECR repositories: $ECR_REPOS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No ECR repositories found${NC}"
fi

# Check NAT Gateways
echo -e "${YELLOW}Checking NAT Gateways...${NC}"
NAT_GATEWAYS=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available,pending" --query 'NatGateways[?contains(to_string(Tags), `ecommerce`)].NatGatewayId' --output text 2>/dev/null || echo "")
if [ -n "$NAT_GATEWAYS" ]; then
    echo -e "${RED}  ✗ Found NAT Gateways: $NAT_GATEWAYS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No NAT Gateways found${NC}"
fi

# Check Elastic IPs
echo -e "${YELLOW}Checking Elastic IPs...${NC}"
ELASTIC_IPS=$(aws ec2 describe-addresses --query 'Addresses[?contains(to_string(Tags), `ecommerce`)].AllocationId' --output text 2>/dev/null || echo "")
if [ -n "$ELASTIC_IPS" ]; then
    echo -e "${RED}  ✗ Found Elastic IPs: $ELASTIC_IPS${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ No Elastic IPs found${NC}"
fi

# Check Terraform State
echo -e "${YELLOW}Checking Terraform state...${NC}"
cd terraform/aws
TERRAFORM_RESOURCES=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
if [ "$TERRAFORM_RESOURCES" -gt 0 ]; then
    echo -e "${RED}  ✗ Terraform state still has $TERRAFORM_RESOURCES resources${NC}"
    ISSUES_FOUND=$((ISSUES_FOUND + 1))
else
    echo -e "${GREEN}  ✓ Terraform state is clean${NC}"
fi
cd ../..

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}DESTRUCTION SUMMARY${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

if [ $ISSUES_FOUND -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                ✓ ALL RESOURCES DESTROYED! ✓                       ║${NC}"
    echo -e "${GREEN}║         Your AWS account is clean and no costs remain.           ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║           ⚠  SOME RESOURCES STILL EXIST ⚠                        ║${NC}"
    echo -e "${YELLOW}║                                                                   ║${NC}"
    echo -e "${YELLOW}║  Found $ISSUES_FOUND issue(s). Resources may still be deleting.        ║${NC}"
    echo -e "${YELLOW}║  Wait 5-10 minutes and run verification again:                   ║${NC}"
    echo -e "${YELLOW}║  ./verify-destruction.sh                                          ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${CYAN}Destruction process completed at $(date)${NC}"
echo ""
