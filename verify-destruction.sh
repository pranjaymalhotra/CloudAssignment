#!/bin/bash

echo "╔════════════════════════════════════════════════════════════╗"
echo "║         INFRASTRUCTURE DESTRUCTION VERIFICATION            ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

echo "▶ AWS RESOURCES CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "1. EKS Clusters:"
aws eks list-clusters --region us-east-1 --query 'clusters' --output table 2>/dev/null || echo "   ✅ No EKS clusters"

echo ""
echo "2. RDS Instances:"
aws rds describe-db-instances --region us-east-1 --query 'DBInstances[].DBInstanceIdentifier' --output table 2>/dev/null || echo "   ✅ No RDS instances"

echo ""
echo "3. MSK Kafka Clusters:"
aws kafka list-clusters --region us-east-1 --query 'ClusterInfoList[].ClusterName' --output table 2>/dev/null || echo "   ✅ No Kafka clusters"

echo ""
echo "4. DynamoDB Tables:"
aws dynamodb list-tables --region us-east-1 --query "TableNames[?starts_with(@, 'ecommerce')]" --output table 2>/dev/null || echo "   ✅ No ecommerce tables"

echo ""
echo "5. VPCs (Project-tagged):"
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=ECommerce-Cloud-Assignment" --query 'Vpcs[].VpcId' --output table 2>/dev/null || echo "   ✅ No project VPCs"

echo ""
echo "6. ECR Repositories:"
aws ecr describe-repositories --region us-east-1 --query 'repositories[?starts_with(repositoryName, `ecommerce`)].repositoryName' --output table 2>/dev/null || echo "   ✅ No ecommerce repositories"

echo ""
echo "7. S3 Buckets:"
aws s3 ls 2>/dev/null | grep ecommerce || echo "   ✅ No ecommerce buckets"

echo ""
echo "8. Lambda Functions:"
aws lambda list-functions --region us-east-1 --query 'Functions[?starts_with(FunctionName, `s3-file-processor`)].FunctionName' --output table 2>/dev/null || echo "   ✅ No s3-file-processor functions"

echo ""
echo "9. NAT Gateways:"
aws ec2 describe-nat-gateways --region us-east-1 --filter "Name=tag:Project,Values=ECommerce-Cloud-Assignment" "Name=state,Values=available" --query 'NatGateways[].NatGatewayId' --output table 2>/dev/null || echo "   ✅ No project NAT gateways"

echo ""
echo "10. Elastic IPs (unassociated):"
aws ec2 describe-addresses --region us-east-1 --filters "Name=tag:Project,Values=ECommerce-Cloud-Assignment" --query 'Addresses[].PublicIp' --output table 2>/dev/null || echo "   ✅ No project Elastic IPs"

echo ""
echo "▶ GCP RESOURCES CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "11. GCP Dataproc Clusters:"
gcloud dataproc clusters list --region=us-central1 2>/dev/null || echo "   ✅ No Dataproc clusters"

echo ""
echo "12. GCP Compute Instances:"
gcloud compute instances list 2>/dev/null || echo "   ✅ No compute instances"

echo ""
echo "13. GCS Buckets:"
gsutil ls 2>/dev/null | grep -E "(ecommerce|flink)" || echo "   ✅ No ecommerce/flink buckets"

echo ""
echo "▶ COST CHECK"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo ""
echo "14. AWS Cost (Last 24 hours):"
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 day ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --region us-east-1 2>/dev/null | jq '.ResultsByTime[].Total.UnblendedCost' || echo "   Unable to fetch cost data"

echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║               VERIFICATION COMPLETE                        ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
