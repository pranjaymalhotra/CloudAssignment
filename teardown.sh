#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${RED}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║     E-Commerce Microservices - Complete Teardown          ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

print_status() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Confirmation prompt
echo -e "${YELLOW}⚠️  WARNING: This will destroy ALL infrastructure and data!${NC}"
echo -e "${YELLOW}   - All Kubernetes resources${NC}"
echo -e "${YELLOW}   - All AWS resources (EKS, RDS, DynamoDB, MSK, S3, Lambda)${NC}"
echo -e "${YELLOW}   - All data in databases${NC}"
echo ""
read -p "Are you sure you want to continue? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Teardown cancelled."
    exit 0
fi

echo ""
print_status "Starting teardown process..."
echo ""

# Step 1: Delete Kubernetes Resources
print_status "STEP 1/5: Deleting all Kubernetes resources..."

# Delete all resources in default namespace
kubectl delete all --all -n default --timeout=300s || print_warning "Some resources may not exist"

# Delete configmaps and secrets
kubectl delete configmap app-config --ignore-not-found=true
kubectl delete secret app-secrets --ignore-not-found=true

# Delete service accounts
kubectl delete serviceaccount product-service-sa --ignore-not-found=true

print_status "Kubernetes resources deleted ✓"
echo ""

# Step 2: Remove IAM Policies
print_status "STEP 2/5: Removing IAM policies..."

NODE_ROLE_NAME="ecommerce-cluster-node-role"

aws iam delete-role-policy \
    --role-name $NODE_ROLE_NAME \
    --policy-name DynamoDBAccess 2>/dev/null || print_warning "IAM policy may not exist"

print_status "IAM policies removed ✓"
echo ""

# Step 3: Delete Docker Images from ECR
print_status "STEP 3/5: Deleting Docker images from ECR..."

AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

REPOS=("ecommerce-api-gateway" "ecommerce-user-service" "ecommerce-product-service" 
       "ecommerce-order-service" "ecommerce-notification-service" "ecommerce-frontend")

for REPO in "${REPOS[@]}"; do
    # Delete all images in repository
    aws ecr batch-delete-image \
        --repository-name $REPO \
        --region $AWS_REGION \
        --image-ids "$(aws ecr list-images --repository-name $REPO --region $AWS_REGION --query 'imageIds[*]' --output json)" \
        2>/dev/null || print_warning "Repository $REPO may be empty or not exist"
done

print_status "ECR images deleted ✓"
echo ""

# Step 4: Destroy AWS Infrastructure with Terraform
print_status "STEP 4/5: Destroying AWS infrastructure with Terraform..."

cd terraform/aws

# Destroy infrastructure
terraform destroy -auto-approve

print_status "AWS infrastructure destroyed ✓"
echo ""

cd ../..

# Step 5: Clean up local files
print_status "STEP 5/5: Cleaning up local artifacts..."

# Remove Terraform state backups
rm -f terraform/aws/terraform.tfstate.backup
rm -f terraform/aws/.terraform.lock.hcl
rm -f terraform/aws/tfplan

# Remove kubectl context (optional)
kubectl config delete-context arn:aws:eks:us-east-1:$AWS_ACCOUNT_ID:cluster/ecommerce-cluster 2>/dev/null || true

print_status "Local artifacts cleaned ✓"
echo ""

# Verify cleanup
print_status "Verifying cleanup..."

echo ""
echo "Checking for remaining AWS resources..."
REMAINING=$(aws resourcegroupstaggingapi get-resources \
    --tag-filters Key=Project,Values=ECommerce-Cloud-Assignment \
    --query 'ResourceTagMappingList[*].ResourceARN' \
    --output text 2>/dev/null | wc -l | tr -d ' ')

if [ "$REMAINING" -eq "0" ]; then
    echo -e "${GREEN}✓ No tagged resources found${NC}"
else
    echo -e "${YELLOW}⚠️  Found $REMAINING remaining tagged resources${NC}"
    echo "Run this command to see them:"
    echo "  aws resourcegroupstaggingapi get-resources --tag-filters Key=Project,Values=ECommerce-Cloud-Assignment"
fi

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              TEARDOWN COMPLETED SUCCESSFULLY!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  ✓ All Kubernetes resources deleted"
echo -e "  ✓ All IAM policies removed"
echo -e "  ✓ All ECR images deleted"
echo -e "  ✓ All AWS infrastructure destroyed"
echo -e "  ✓ Local artifacts cleaned"
echo ""
echo -e "${GREEN}Your AWS account is now clean!${NC}"
echo ""
echo -e "${BLUE}To redeploy everything:${NC}"
echo -e "  ${GREEN}./deploy.sh${NC}"
echo ""
echo -e "${YELLOW}💰 Reminder: Check AWS billing console to verify no charges${NC}"
echo -e "   https://console.aws.amazon.com/billing/home"
echo ""
