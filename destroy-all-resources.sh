#!/bin/bash
set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     COMPLETE INFRASTRUCTURE TEARDOWN                       ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Delete Kubernetes Resources
echo "▶ Step 1: Deleting Kubernetes resources..."
kubectl delete -f kubernetes/base/ --ignore-not-found=true 2>/dev/null || echo "  No k8s resources or cluster not accessible"
kubectl delete secrets app-secrets -n default --ignore-not-found=true 2>/dev/null || echo "  No secrets to delete"
kubectl delete configmap app-config -n default --ignore-not-found=true 2>/dev/null || echo "  No configmap to delete"

echo "⏳ Waiting 60 seconds for LoadBalancer cleanup..."
sleep 60

# Step 2: Destroy AWS Infrastructure
echo ""
echo "▶ Step 2: Destroying AWS infrastructure..."
cd terraform/aws
terraform destroy -auto-approve
cd ../..

# Step 3: Clean up ECR Images
echo ""
echo "▶ Step 3: Cleaning up ECR repositories..."
services=("api-gateway" "user-service" "product-service" "order-service" "notification-service" "analytics-service")
for service in "${services[@]}"; do
  echo "  Deleting ecommerce-${service}..."
  aws ecr delete-repository --repository-name ecommerce-${service} --region us-east-1 --force 2>/dev/null || echo "  Repository not found, skipping..."
done

# Step 4: Destroy GCP Infrastructure
echo ""
echo "▶ Step 4: Destroying GCP infrastructure (if exists)..."
if [ -d "terraform/gcp" ]; then
  cd terraform/gcp
  terraform destroy -auto-approve 2>/dev/null || echo "  No GCP infrastructure found"
  cd ../..
fi

# Step 5: Delete GCS Buckets
echo ""
echo "▶ Step 5: Cleaning up GCS buckets..."
gsutil -m rm -r gs://ecommerce-flink-checkpoints/ 2>/dev/null || echo "  Bucket not found, skipping..."
gsutil -m rm -r gs://ecommerce-analytics-data/ 2>/dev/null || echo "  Bucket not found, skipping..."

echo ""
echo "✅ TEARDOWN COMPLETE!"
echo ""
