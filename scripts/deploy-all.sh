#!/bin/bash

# Deploy All Applications
# This script deploys the entire application stack

set -e

echo "🚀 Deploying E-Commerce Application..."

# Get outputs from Terraform
echo "📋 Fetching infrastructure details..."
cd terraform/aws
RDS_ENDPOINT=$(terraform output -raw rds_endpoint | cut -d: -f1)
MSK_BROKERS=$(terraform output -raw msk_bootstrap_brokers)
ECR_REGISTRY=$(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com
cd ../..

echo "RDS Endpoint: ${RDS_ENDPOINT}"
echo "MSK Brokers: ${MSK_BROKERS}"
echo "ECR Registry: ${ECR_REGISTRY}"

# Update ConfigMap with actual values
echo "📝 Updating Kubernetes ConfigMap..."
sed -i.bak "s|REPLACE_WITH_RDS_ENDPOINT|${RDS_ENDPOINT}|g" kubernetes/base/configmap.yaml
sed -i.bak "s|REPLACE_WITH_MSK_BROKERS|${MSK_BROKERS}|g" kubernetes/base/configmap.yaml

# Update image URIs in deployments
echo "📝 Updating deployment image URIs..."
for file in kubernetes/base/*.yaml; do
    sed -i.bak "s|REPLACE_WITH_ECR_URI|${ECR_REGISTRY}|g" "$file"
done

# Apply ConfigMap and Secrets
echo "⚙️  Applying ConfigMap and Secrets..."
kubectl apply -f kubernetes/base/configmap.yaml

# Apply all services
echo "🚢 Deploying microservices..."
kubectl apply -f kubernetes/base/user-service.yaml
kubectl apply -f kubernetes/base/product-service.yaml
kubectl apply -f kubernetes/base/order-service.yaml
kubectl apply -f kubernetes/base/notification-service.yaml
kubectl apply -f kubernetes/base/api-gateway.yaml

# Wait for deployments
echo "⏳ Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/user-service
kubectl wait --for=condition=available --timeout=300s deployment/product-service
kubectl wait --for=condition=available --timeout=300s deployment/order-service
kubectl wait --for=condition=available --timeout=300s deployment/notification-service
kubectl wait --for=condition=available --timeout=300s deployment/api-gateway

# Get API Gateway URL
echo "🌐 Getting API Gateway URL..."
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "API Gateway URL: http://${API_URL}"

echo ""
echo "✅ Deployment complete!"
echo "📊 Check status with: kubectl get pods"
echo "🔍 View services: kubectl get svc"
echo "📈 Watch HPA: kubectl get hpa -w"
