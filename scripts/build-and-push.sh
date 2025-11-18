#!/bin/bash

# Build and Push Docker Images to ECR
# This script builds all microservices and pushes them to Amazon ECR

set -e

echo "🚀 Building and Pushing Microservices to ECR..."

# Get AWS account ID
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

# Login to ECR
echo "🔐 Logging into ECR..."
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# List of microservices
SERVICES=("api-gateway" "user-service" "product-service" "order-service" "notification-service")

# Build and push each service
for SERVICE in "${SERVICES[@]}"; do
    echo ""
    echo "📦 Building ${SERVICE}..."
    
    cd microservices/${SERVICE}
    
    # Build Docker image
    docker build -t ecommerce-${SERVICE}:latest .
    
    # Tag for ECR
    docker tag ecommerce-${SERVICE}:latest ${ECR_REGISTRY}/ecommerce-${SERVICE}:latest
    
    # Push to ECR
    echo "⬆️  Pushing ${SERVICE} to ECR..."
    docker push ${ECR_REGISTRY}/ecommerce-${SERVICE}:latest
    
    cd ../..
    
    echo "✅ ${SERVICE} pushed successfully!"
done

echo ""
echo "🎉 All microservices built and pushed to ECR!"
echo "Registry: ${ECR_REGISTRY}"
