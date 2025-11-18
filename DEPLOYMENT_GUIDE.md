# 🚀 Complete Deployment & Teardown Guide

## Overview
This guide provides complete automation for deploying and destroying the entire e-commerce microservices infrastructure on AWS.

## 📋 Prerequisites

### Required Tools
```bash
# macOS installation
brew install terraform
brew install awscli
brew install kubectl
brew install docker

# Verify installations
terraform --version   # Should be >= 1.5.0
aws --version
kubectl version --client
docker --version
```

### AWS Credentials
```bash
# Configure AWS credentials
aws configure

# Required information:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json

# Verify credentials
aws sts get-caller-identity
```

### Docker Setup
```bash
# Start Docker Desktop (macOS)
open -a Docker

# Wait for Docker to start, then verify
docker ps
```

---

## 🎯 Quick Start Deployment

### Option 1: Automated Deployment (Recommended)
```bash
# Make scripts executable
chmod +x deploy.sh teardown.sh

# Deploy everything
./deploy.sh

# Expected time: 30-45 minutes
```

### Option 2: Manual Step-by-Step Deployment
See "Manual Deployment Steps" section below.

---

## 🤖 Automated Deployment (deploy.sh)

The `deploy.sh` script automates the entire deployment process:

### What It Does:
1. ✅ **Checks prerequisites** (terraform, aws, kubectl, docker)
2. ✅ **Deploys AWS infrastructure** (VPC, EKS, RDS, DynamoDB, MSK, S3, Lambda)
3. ✅ **Configures kubectl** for EKS cluster
4. ✅ **Initializes RDS database** (creates tables)
5. ✅ **Updates ConfigMap** with actual AWS resource endpoints
6. ✅ **Builds & pushes Docker images** to ECR (linux/amd64)
7. ✅ **Updates Kubernetes deployments** with ECR image URIs
8. ✅ **Deploys all services** to Kubernetes
9. ✅ **Configures IAM permissions** for DynamoDB
10. ✅ **Displays public endpoints** and next steps

### Usage:
```bash
./deploy.sh
```

### Expected Output:
```
╔═══════════════════════════════════════════════════════════╗
║     E-Commerce Microservices - Full Deployment Script     ║
╚═══════════════════════════════════════════════════════════╝

[HH:MM:SS] Checking prerequisites...
[HH:MM:SS] All prerequisites met ✓

[HH:MM:SS] STEP 1/8: Deploying AWS Infrastructure with Terraform...
[HH:MM:SS] AWS Infrastructure deployed ✓

... (continues through all 8 steps) ...

╔═══════════════════════════════════════════════════════════╗
║            DEPLOYMENT COMPLETED SUCCESSFULLY!              ║
╚═══════════════════════════════════════════════════════════╝

Public Endpoints:
  🌐 Frontend: http://a1b2c3d4...elb.amazonaws.com
  🔧 API:      http://e5f6g7h8...elb.amazonaws.com
```

### Timing:
- Infrastructure deployment: 15-20 minutes
- Docker builds & pushes: 10-15 minutes
- Kubernetes deployment: 5-10 minutes
- **Total: ~30-45 minutes**

---

## 🧹 Automated Teardown (teardown.sh)

The `teardown.sh` script safely destroys all resources:

### What It Does:
1. ⚠️ **Confirms destruction** (requires typing "yes")
2. 🗑️ **Deletes Kubernetes resources** (pods, services, deployments)
3. 🗑️ **Removes IAM policies** (DynamoDB access)
4. 🗑️ **Deletes ECR images** (Docker images)
5. 🗑️ **Destroys AWS infrastructure** (Terraform destroy)
6. 🗑️ **Cleans local artifacts** (Terraform state, kubectl context)
7. ✅ **Verifies cleanup** (checks for remaining resources)

### Usage:
```bash
./teardown.sh

# You will be prompted:
# ⚠️  WARNING: This will destroy ALL infrastructure and data!
# Are you sure you want to continue? (yes/no): yes
```

### Safety Features:
- Requires explicit "yes" confirmation
- Shows clear warnings before destruction
- Verifies no remaining tagged resources
- Provides AWS billing console link for verification

### Timing:
- Kubernetes cleanup: 3-5 minutes
- Terraform destroy: 10-15 minutes
- **Total: ~15-20 minutes**

---

## 📝 Manual Deployment Steps

If you prefer manual control, follow these steps:

### Step 1: Deploy AWS Infrastructure
```bash
cd terraform/aws
terraform init
terraform plan -out=tfplan
terraform apply -auto-approve tfplan

# Get outputs
terraform output
cd ../..
```

### Step 2: Configure kubectl
```bash
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster
kubectl get nodes
```

### Step 3: Initialize RDS Database
```bash
# Get DB endpoint from Terraform output
DB_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)

# Create tables
kubectl run mysql-init --image=mysql:8.0 --rm -it --restart=Never -- mysql \
  -h $DB_ENDPOINT \
  -u admin \
  -p'Admin123456!' \
  -e "CREATE DATABASE IF NOT EXISTS ecommercedb; \
      USE ecommercedb; \
      CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(255), email VARCHAR(255) UNIQUE, created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP); \
      CREATE TABLE orders (id INT AUTO_INCREMENT PRIMARY KEY, user_id INT, product_id VARCHAR(255), quantity INT, status VARCHAR(50) DEFAULT 'pending', created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, total_price DECIMAL(10,2) DEFAULT 0.00);"
```

### Step 4: Update ConfigMap
```bash
# Get AWS values
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
DB_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)
DYNAMODB_TABLE=$(cd terraform/aws && terraform output -raw dynamodb_table_name)
MSK_BOOTSTRAP=$(cd terraform/aws && terraform output -raw msk_bootstrap_servers)

# Edit kubernetes/base/configmap.yaml with actual values
# Replace placeholders with actual endpoints
```

### Step 5: Build & Push Docker Images
```bash
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push each service
for SERVICE in api-gateway user-service product-service order-service notification-service; do
  cd microservices/$SERVICE
  docker buildx build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest \
    --push .
  cd ../..
done

# Build and push frontend
cd frontend
docker buildx build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest \
  --push .
cd ..
```

### Step 6: Update Kubernetes Deployments
```bash
# Update image URIs in all kubernetes/base/*.yaml files
# Replace image: lines with actual ECR URIs
```

### Step 7: Deploy to Kubernetes
```bash
# Create secret
kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD='Admin123456!'

# Deploy all services
kubectl apply -f kubernetes/base/configmap.yaml
kubectl apply -f kubernetes/base/user-service.yaml
kubectl apply -f kubernetes/base/product-service.yaml
kubectl apply -f kubernetes/base/order-service.yaml
kubectl apply -f kubernetes/base/notification-service.yaml
kubectl apply -f kubernetes/base/api-gateway.yaml
kubectl apply -f kubernetes/base/frontend.yaml

# Wait for deployments
kubectl wait --for=condition=available --timeout=600s deployment --all
```

### Step 8: Configure IAM Permissions
```bash
# Add DynamoDB permissions
aws iam put-role-policy \
  --role-name ecommerce-cluster-node-role \
  --policy-name DynamoDBAccess \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:UpdateItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/ecommerce-products"
    }]
  }'

# Remove invalid annotation
kubectl annotate serviceaccount product-service-sa eks.amazonaws.com/role-arn-

# Restart product service
kubectl rollout restart deployment/product-service
```

### Step 9: Get Endpoints
```bash
# Wait for LoadBalancers
sleep 120

# Get URLs
kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 🧪 Testing After Deployment

### Run Automated Tests
```bash
./test-api.sh

# Expected: 17/17 tests passed
```

### Access Frontend
```bash
# Get frontend URL
FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Open in browser
open http://$FRONTEND_URL
```

### Manual API Testing
```bash
# Get API URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test health
curl http://$API_URL/health

# Create user
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Test User","email":"test@example.com"}'

# Get all users
curl http://$API_URL/api/users
```

---

## 🔍 Verification Commands

### Check Infrastructure
```bash
# AWS Resources
cd terraform/aws && terraform state list

# EKS Nodes
kubectl get nodes

# All Pods
kubectl get pods

# Services & LoadBalancers
kubectl get svc

# HPAs
kubectl get hpa
```

### Check Databases
```bash
# RDS MySQL
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h $(cd terraform/aws && terraform output -raw rds_endpoint) \
  -u admin -p'Admin123456!' -D ecommercedb \
  -e "SELECT COUNT(*) as user_count FROM users; SELECT COUNT(*) as order_count FROM orders;"

# DynamoDB
aws dynamodb scan --table-name ecommerce-products --select COUNT
```

### Check Logs
```bash
# Service logs
kubectl logs -l app=user-service --tail=50
kubectl logs -l app=product-service --tail=50
kubectl logs -l app=order-service --tail=50
kubectl logs -l app=api-gateway --tail=50
```

---

## 📊 Cost Monitoring

### Current Hourly Costs
```
EKS Control Plane:  $0.10/hour
EC2 Nodes (2x):     $0.08/hour
RDS t3.micro:       $0.00/hour (free tier)
DynamoDB:           $0.00/hour (free tier)
MSK (2 brokers):    $0.04/hour
NAT Gateways:       $0.09/hour
LoadBalancers:      $0.05/hour
---------------------------------
Total:              ~$0.36/hour
                    ~$8.64/day
```

### Check AWS Costs
```bash
# View current month charges
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity MONTHLY \
  --metrics BlendedCost

# Or visit AWS Console
open https://console.aws.amazon.com/billing/home
```

---

## 🚨 Troubleshooting

### Deploy Script Fails

**Issue:** Terraform apply fails
```bash
# Check Terraform logs
cd terraform/aws
terraform plan
# Fix any configuration issues
```

**Issue:** Docker build fails
```bash
# Ensure Docker is running
docker ps

# Check architecture
docker buildx ls

# Rebuild with correct platform
docker buildx build --platform linux/amd64 ...
```

**Issue:** Kubectl can't connect
```bash
# Reconfigure kubectl
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Verify
kubectl get nodes
```

### Teardown Script Fails

**Issue:** Resources won't delete
```bash
# Force delete Kubernetes resources
kubectl delete all --all -n default --force --grace-period=0

# Check remaining resources
kubectl get all

# Manually delete stuck resources
kubectl delete deployment <name> --force --grace-period=0
```

**Issue:** Terraform destroy fails
```bash
cd terraform/aws

# Identify stuck resources
terraform state list

# Manually delete problematic resources in AWS Console
# Then retry
terraform destroy -auto-approve
```

**Issue:** ECR repositories not empty
```bash
# Manually delete images
aws ecr list-images --repository-name ecommerce-api-gateway
aws ecr batch-delete-image --repository-name ecommerce-api-gateway \
  --image-ids imageTag=latest
```

---

## 📁 File Structure

```
Cloud_A15/
├── deploy.sh                    # ⭐ Automated deployment script
├── teardown.sh                  # ⭐ Automated teardown script
├── test-api.sh                  # Automated test suite
├── DEPLOYMENT_GUIDE.md          # ⭐ This file
├── TESTING_GUIDE.md             # Testing documentation
├── REQUIREMENTS_STATUS.md       # Requirements verification
├── terraform/
│   └── aws/
│       ├── main.tf              # Root Terraform config
│       ├── variables.tf         # Variables
│       └── modules/             # Terraform modules
├── kubernetes/
│   └── base/
│       ├── configmap.yaml       # Environment configuration
│       ├── *.yaml               # Service deployments
│       └── frontend.yaml        # Frontend deployment
├── microservices/
│   ├── api-gateway/
│   ├── user-service/
│   ├── product-service/
│   ├── order-service/
│   └── notification-service/
└── frontend/
    ├── index.html
    └── Dockerfile
```

---

## 🎯 Common Workflows

### Deploy → Test → Teardown
```bash
# 1. Deploy everything
./deploy.sh

# 2. Wait for completion (~40 minutes)

# 3. Run tests
./test-api.sh

# 4. Access frontend
open http://$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 5. When done, teardown
./teardown.sh
```

### Deploy → Modify Code → Redeploy Service
```bash
# 1. Initial deployment
./deploy.sh

# 2. Modify code (e.g., microservices/user-service/app.py)

# 3. Rebuild and push specific service
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
cd microservices/user-service
docker buildx build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecommerce-user-service:latest \
  --push .

# 4. Restart deployment
kubectl rollout restart deployment/user-service

# 5. Verify
kubectl get pods -w
```

### Preserve Infrastructure, Update Services Only
```bash
# Don't run teardown.sh
# Just rebuild and redeploy specific services

# Update code, rebuild image, restart deployment
# Infrastructure (EKS, RDS, etc.) remains intact
```

---

## ✅ Success Criteria

After running `./deploy.sh`, you should have:

- ✅ All Terraform resources created (48 resources)
- ✅ EKS cluster with 2 nodes running
- ✅ 11 pods running (2x5 services + 1 frontend)
- ✅ 2 LoadBalancers provisioned with public DNS
- ✅ RDS MySQL initialized with tables
- ✅ DynamoDB accessible with IAM permissions
- ✅ All 17 automated tests passing
- ✅ Frontend accessible in browser
- ✅ API endpoints responding

---

## 📞 Quick Reference

### Essential Commands
```bash
# Deploy everything
./deploy.sh

# Destroy everything
./teardown.sh

# Run tests
./test-api.sh

# Check status
kubectl get pods
kubectl get svc
kubectl get hpa

# View logs
kubectl logs -l app=<service-name> --tail=50

# Get endpoints
kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### Useful kubectl Commands
```bash
# Watch pod status
kubectl get pods -w

# Describe pod for troubleshooting
kubectl describe pod <pod-name>

# Execute command in pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward for local access
kubectl port-forward svc/api-gateway 8080:80

# Scale deployment manually
kubectl scale deployment user-service --replicas=5
```

---

## 🎓 What Gets Deployed

### AWS Resources (48 total)
- **VPC**: Custom VPC with public/private subnets, NAT gateways, route tables
- **EKS**: Managed Kubernetes cluster (v1.28) with 2 t3.medium nodes
- **RDS**: MySQL 8.0 database (t3.micro) with Multi-AZ
- **DynamoDB**: NoSQL table for products (pay-per-request)
- **MSK**: Managed Kafka cluster (2 t3.small brokers)
- **S3**: Object storage bucket with lifecycle policies
- **Lambda**: Serverless function for S3 event processing
- **ECR**: 6 Docker repositories
- **IAM**: Roles and policies for EKS, Lambda, and services
- **Security Groups**: Network rules for all services
- **LoadBalancers**: 2 Application Load Balancers

### Kubernetes Resources (30+ total)
- **Deployments**: 6 deployments (5 services + frontend)
- **Services**: 6 LoadBalancer/ClusterIP services
- **HPAs**: 2 Horizontal Pod Autoscalers
- **ConfigMaps**: 1 shared configuration
- **Secrets**: 1 for sensitive data (DB password)
- **ServiceAccounts**: 1 for product-service

### Docker Images (6 total)
- ecommerce-api-gateway:latest
- ecommerce-user-service:latest
- ecommerce-product-service:latest
- ecommerce-order-service:latest
- ecommerce-notification-service:latest
- ecommerce-frontend:latest

---

## 💡 Pro Tips

1. **Save Costs**: Run `./teardown.sh` immediately after testing
2. **Monitor Costs**: Check AWS billing daily during development
3. **Use Free Tier**: RDS and DynamoDB are within free tier limits
4. **DNS Propagation**: Wait 2-3 minutes after deployment for LoadBalancer DNS
5. **Logs Are Key**: Always check `kubectl logs` for troubleshooting
6. **Test Locally First**: Use `LOCAL_MODE` patches for cost-free testing
7. **Backup Data**: Export database data before teardown if needed
8. **Version Control**: Commit working configurations to Git
9. **Document Changes**: Update this guide if you modify scripts
10. **Stay Informed**: Read REQUIREMENTS_STATUS.md for missing features

---

**Last Updated:** 2025-11-19  
**Version:** 1.0  
**Tested On:** macOS with Apple Silicon (M1/M2)
