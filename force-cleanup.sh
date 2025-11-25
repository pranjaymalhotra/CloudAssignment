#!/bin/bash
set -e

echo "🔥 FORCE CLEANUP - Destroying all remaining resources"
echo ""

# 1. Delete all ECR repositories with images
echo "▶ Deleting ECR repositories..."
for repo in $(aws ecr describe-repositories --region us-east-1 --query 'repositories[?starts_with(repositoryName, `ecommerce`)].repositoryName' --output text); do
  echo "  🗑️  Deleting $repo..."
  aws ecr delete-repository --repository-name $repo --region us-east-1 --force 2>/dev/null || echo "    Already deleted"
done

# 2. Delete S3 buckets
echo ""
echo "▶ Deleting S3 buckets..."
for bucket in $(aws s3 ls | grep ecommerce | awk '{print $3}'); do
  echo "  🗑️  Emptying and deleting $bucket..."
  aws s3 rm s3://$bucket --recursive 2>/dev/null || echo "    Already empty"
  aws s3 rb s3://$bucket --force 2>/dev/null || echo "    Already deleted"
done

# 3. Clean up VPC and dependencies
echo ""
echo "▶ Cleaning up VPC dependencies..."
VPC_ID=$(aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=ECommerce-Cloud-Assignment" --query 'Vpcs[0].VpcId' --output text)

if [ "$VPC_ID" != "None" ] && [ ! -z "$VPC_ID" ]; then
  echo "  Found VPC: $VPC_ID"
  
  # Delete NAT Gateways
  echo "  🗑️  Deleting NAT Gateways..."
  for nat in $(aws ec2 describe-nat-gateways --region us-east-1 --filter "Name=vpc-id,Values=$VPC_ID" "Name=state,Values=available" --query 'NatGateways[].NatGatewayId' --output text); do
    echo "    Deleting NAT Gateway: $nat"
    aws ec2 delete-nat-gateway --nat-gateway-id $nat --region us-east-1 2>/dev/null || echo "    Failed to delete"
  done
  
  echo "  ⏳ Waiting 60s for NAT gateways to delete..."
  sleep 60
  
  # Release Elastic IPs
  echo "  🗑️  Releasing Elastic IPs..."
  for eip in $(aws ec2 describe-addresses --region us-east-1 --filters "Name=domain,Values=vpc" --query 'Addresses[?AssociationId==`null`].AllocationId' --output text); do
    echo "    Releasing EIP: $eip"
    aws ec2 release-address --allocation-id $eip --region us-east-1 2>/dev/null || echo "    Failed to release"
  done
  
  # Delete Internet Gateway
  echo "  🗑️  Deleting Internet Gateway..."
  for igw in $(aws ec2 describe-internet-gateways --region us-east-1 --filters "Name=attachment.vpc-id,Values=$VPC_ID" --query 'InternetGateways[].InternetGatewayId' --output text); do
    echo "    Detaching and deleting IGW: $igw"
    aws ec2 detach-internet-gateway --internet-gateway-id $igw --vpc-id $VPC_ID --region us-east-1 2>/dev/null || echo "    Already detached"
    aws ec2 delete-internet-gateway --internet-gateway-id $igw --region us-east-1 2>/dev/null || echo "    Failed to delete"
  done
  
  # Delete Subnets
  echo "  🗑️  Deleting Subnets..."
  for subnet in $(aws ec2 describe-subnets --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'Subnets[].SubnetId' --output text); do
    echo "    Deleting Subnet: $subnet"
    aws ec2 delete-subnet --subnet-id $subnet --region us-east-1 2>/dev/null || echo "    Failed to delete"
  done
  
  # Delete Security Groups (except default)
  echo "  🗑️  Deleting Security Groups..."
  for sg in $(aws ec2 describe-security-groups --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text); do
    echo "    Deleting Security Group: $sg"
    aws ec2 delete-security-group --group-id $sg --region us-east-1 2>/dev/null || echo "    Failed to delete (may have dependencies)"
  done
  
  # Delete Route Tables (except main)
  echo "  🗑️  Deleting Route Tables..."
  for rt in $(aws ec2 describe-route-tables --region us-east-1 --filters "Name=vpc-id,Values=$VPC_ID" --query 'RouteTables[?Associations[0].Main!=`true`].RouteTableId' --output text); do
    echo "    Deleting Route Table: $rt"
    aws ec2 delete-route-table --route-table-id $rt --region us-east-1 2>/dev/null || echo "    Failed to delete"
  done
  
  # Delete VPC
  echo "  🗑️  Deleting VPC..."
  aws ec2 delete-vpc --vpc-id $VPC_ID --region us-east-1 2>/dev/null && echo "    ✅ VPC deleted!" || echo "    ⚠️  VPC deletion failed - may have remaining dependencies"
else
  echo "  ✅ No VPC found"
fi

# 4. Clean up terraform state
echo ""
echo "▶ Cleaning terraform state..."
cd terraform/aws
rm -f terraform.tfstate terraform.tfstate.backup terraform.tfstate.*.backup tfplan .terraform.lock.hcl
rm -rf .terraform/
cd ../..

echo ""
echo "✅ FORCE CLEANUP COMPLETE!"
echo ""
echo "Run verify-destruction.sh to confirm everything is deleted"
