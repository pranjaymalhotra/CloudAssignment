# 🚀 Complete Deployment & Teardown Guide - Multi-Cloud E-Commerce Platform

## Overview
This guide provides complete step-by-step instructions for deploying and managing a production-ready multi-cloud e-commerce microservices platform spanning AWS and GCP. Based on real deployment experience, this guide includes all commands, common errors, and their solutions.

## Architecture Overview
- **AWS**: EKS (Kubernetes), RDS MySQL, MSK Kafka, DynamoDB, S3, Lambda, ECR
- **GCP**: Dataproc (Apache Flink), Cloud Functions, Cloud Storage
- **Monitoring**: Prometheus, Grafana, ArgoCD (GitOps)
- **Services**: 6 microservices (API Gateway, User, Product, Order, Notification, Analytics) + Frontend
- **Real-Time Processing**: Kafka → Flink → Analytics pipeline

## 📋 Prerequisites

### Required Tools
```bash
# macOS installation
brew install terraform
brew install awscli
brew install kubectl
brew install docker
brew install k6  # For load testing

# GCP CLI (for Dataproc and Cloud Functions)
brew install --cask google-cloud-sdk

# Verify installations
terraform --version   # Tested with v1.5.0+
aws --version        # Tested with v2.x
kubectl version --client
docker --version
gcloud --version
```

### AWS Credentials Setup
```bash
# Configure AWS credentials
aws configure

# Required information:
# - AWS Access Key ID: Your IAM user access key
# - AWS Secret Access Key: Your IAM user secret key
# - Default region: us-east-1
# - Default output format: json

# Verify credentials and get Account ID
aws sts get-caller-identity

# Expected output:
# {
#     "UserId": "AIDAXXXXXXXXXX",
#     "Account": "123456789012",
#     "Arn": "arn:aws:iam::123456789012:user/your-username"
# }

# Save your Account ID for later use
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo $AWS_ACCOUNT_ID
```

### GCP Project Setup
```bash
# Login to GCP
gcloud auth login

# Create or select project
gcloud projects create PROJECT_ID --name="E-Commerce Platform"
# OR use existing project
gcloud config set project PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable dataproc.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Set default region
gcloud config set compute/region us-central1
gcloud config set compute/zone us-central1-c

# Verify configuration
gcloud config list
```

### Docker Setup
```bash
# Start Docker Desktop (macOS)
open -a Docker

# Wait for Docker to start (30-60 seconds)
# Verify Docker is running
docker ps

# Enable BuildKit for multi-platform builds
docker buildx create --use --name multiarch

# Verify buildx
docker buildx ls
```

---

## 🎯 Complete Deployment Guide (Step-by-Step)

### Phase 1: AWS Infrastructure Deployment

#### Step 1.1: Deploy Core AWS Infrastructure
```bash
cd terraform/aws

# Initialize Terraform
terraform init

# Review what will be created (48 resources)
terraform plan -out=tfplan

# Apply infrastructure
terraform apply tfplan

# Expected time: 15-20 minutes
# Resources created:
# - VPC with public/private subnets
# - EKS cluster (Kubernetes 1.28)
# - RDS MySQL (t3.micro)
# - MSK Kafka (2 brokers)
# - DynamoDB tables
# - S3 bucket
# - Lambda function
# - ECR repositories (6)
# - IAM roles and policies
# - Security groups
# - NAT gateways

# Save important outputs
terraform output > outputs.txt

# Get specific values
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export MSK_BOOTSTRAP=$(terraform output -raw msk_bootstrap_servers)
export DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
export S3_BUCKET=$(terraform output -raw s3_bucket_name)

cd ../..
```

**Common Error 1: Terraform Backend Already Exists**
```bash
# Error: Error configuring the backend "s3": Error creating S3 bucket

# Solution: Check if bucket exists
aws s3 ls | grep terraform

# If exists, either:
# 1. Use existing bucket (comment out backend config)
# 2. Or delete and recreate
aws s3 rb s3://YOUR-BUCKET-NAME --force
```

**Common Error 2: EKS Cluster Creation Timeout**
```bash
# Error: timeout while waiting for state to become 'ACTIVE'

# Solution: Increase timeout or check IAM permissions
# Edit terraform/aws/modules/eks/main.tf
# Add: timeouts { create = "30m" }

# Or check AWS console for actual error:
aws eks describe-cluster --name ecommerce-cluster --region us-east-1
```

#### Step 1.2: Configure kubectl for EKS
```bash
# Update kubeconfig to connect to EKS
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Verify connection
kubectl get nodes

# Expected output:
# NAME                         STATUS   ROLES    AGE   VERSION
# ip-10-0-10-176.ec2.internal  Ready    <none>   5m    v1.28.x
# ip-10-0-11-107.ec2.internal  Ready    <none>   5m    v1.28.x

# Check node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"
```

**Common Error 3: kubectl Connection Failed**
```bash
# Error: Unable to connect to the server

# Solution 1: Verify AWS credentials
aws sts get-caller-identity

# Solution 2: Update kubeconfig with correct region
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Solution 3: Check cluster status
aws eks describe-cluster --name ecommerce-cluster --region us-east-1 | grep status
```

#### Step 1.3: Initialize RDS Database
```bash
# Get RDS endpoint
export DB_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)
echo $DB_ENDPOINT

# Create database and tables
kubectl run mysql-init --image=mysql:8.0 --rm -it --restart=Never -- mysql \
  -h $DB_ENDPOINT \
  -u admin \
  -p'Admin123456!' \
  -e "CREATE DATABASE IF NOT EXISTS ecommercedb; \
      USE ecommercedb; \
      CREATE TABLE IF NOT EXISTS users ( \
        id INT AUTO_INCREMENT PRIMARY KEY, \
        name VARCHAR(255) NOT NULL, \
        email VARCHAR(255) UNIQUE NOT NULL, \
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP \
      ); \
      CREATE TABLE IF NOT EXISTS orders ( \
        id INT AUTO_INCREMENT PRIMARY KEY, \
        user_id INT NOT NULL, \
        product_id VARCHAR(255) NOT NULL, \
        quantity INT NOT NULL DEFAULT 1, \
        total_price DECIMAL(10,2) DEFAULT 0.00, \
        status VARCHAR(50) DEFAULT 'pending', \
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE \
      );"

# Verify tables created
kubectl run mysql-verify --image=mysql:8.0 --rm -it --restart=Never -- mysql \
  -h $DB_ENDPOINT \
  -u admin \
  -p'Admin123456!' \
  -D ecommercedb \
  -e "SHOW TABLES; DESCRIBE users; DESCRIBE orders;"
```

**Common Error 4: RDS Connection Timeout**
```bash
# Error: ERROR 2003 (HY000): Can't connect to MySQL server

# Solution: Check security group allows connections from EKS nodes
# Get EKS node security group
kubectl get nodes -o jsonpath='{.items[0].spec.providerID}' | cut -d'/' -f5
aws ec2 describe-instances --instance-ids i-xxxxx --query 'Reservations[0].Instances[0].SecurityGroups[*]'

# Add ingress rule to RDS security group
aws ec2 authorize-security-group-ingress \
  --group-id sg-xxxxx \
  --protocol tcp \
  --port 3306 \
  --source-group sg-eks-node-group
```

#### Step 1.4: Update Kubernetes ConfigMap
```bash
# Get all AWS resource values
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export RDS_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)
export MSK_BOOTSTRAP=$(cd terraform/aws && terraform output -raw msk_bootstrap_servers)
export DYNAMODB_TABLE=$(cd terraform/aws && terraform output -raw dynamodb_table_name)
export S3_BUCKET=$(cd terraform/aws && terraform output -raw s3_bucket_name)

# Display values
echo "Account ID: $AWS_ACCOUNT_ID"
echo "RDS: $RDS_ENDPOINT"
echo "MSK: $MSK_BOOTSTRAP"
echo "DynamoDB: $DYNAMODB_TABLE"
echo "S3: $S3_BUCKET"

# Update ConfigMap file
sed -i.bak "s|DB_HOST:.*|DB_HOST: \"$RDS_ENDPOINT\"|g" kubernetes/base/configmap.yaml
sed -i.bak "s|KAFKA_BOOTSTRAP_SERVERS:.*|KAFKA_BOOTSTRAP_SERVERS: \"$MSK_BOOTSTRAP\"|g" kubernetes/base/configmap.yaml
sed -i.bak "s|DYNAMODB_TABLE:.*|DYNAMODB_TABLE: \"$DYNAMODB_TABLE\"|g" kubernetes/base/configmap.yaml
sed -i.bak "s|S3_BUCKET:.*|S3_BUCKET: \"$S3_BUCKET\"|g" kubernetes/base/configmap.yaml

# Verify changes
cat kubernetes/base/configmap.yaml | grep -E "DB_HOST|KAFKA_BOOTSTRAP|DYNAMODB_TABLE|S3_BUCKET"

# Apply ConfigMap
kubectl apply -f kubernetes/base/configmap.yaml
kubectl get configmap app-config -o yaml
```

### Phase 2: Docker Images - Build and Push to ECR

#### Step 2.1: Login to Amazon ECR
```bash
# Get AWS Account ID
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION="us-east-1"

# Authenticate Docker to ECR
aws ecr get-login-password --region $AWS_REGION | \
  docker login --username AWS --password-stdin \
  $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Expected: "Login Succeeded"
```

**Common Error 5: ECR Login Failed**
```bash
# Error: Error saving credentials: error storing credentials

# Solution: Check Docker is running
docker ps

# If Docker not running
open -a Docker
# Wait 30-60 seconds, then retry login
```

#### Step 2.2: Build and Push All Microservices
```bash
# List of services to build
SERVICES="api-gateway user-service product-service order-service notification-service analytics-service"

# Build and push each service
for SERVICE in $SERVICES; do
  echo "Building $SERVICE..."
  cd microservices/$SERVICE
  
  # Build for AMD64 architecture (EKS runs on x86_64)
  docker buildx build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest \
    --push .
  
  # Verify push succeeded
  if [ $? -eq 0 ]; then
    echo "✓ $SERVICE pushed successfully"
  else
    echo "✗ $SERVICE push failed"
    exit 1
  fi
  
  cd ../..
done

# Build and push frontend
echo "Building frontend..."
cd frontend
docker buildx build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest \
  --push .
cd ..

# Verify all images in ECR
aws ecr list-images --repository-name ecommerce-api-gateway
aws ecr list-images --repository-name ecommerce-user-service
aws ecr list-images --repository-name ecommerce-product-service
aws ecr list-images --repository-name ecommerce-order-service
aws ecr list-images --repository-name ecommerce-notification-service
aws ecr list-images --repository-name ecommerce-frontend
```

**Common Error 6: Docker Build Platform Mismatch**
```bash
# Error: exec /app/app: exec format error (in pod logs)

# Cause: Built for wrong architecture (ARM64 on M1/M2 Mac)
# Solution: Always use --platform linux/amd64

# Check current platform
docker buildx ls

# Create multi-platform builder if needed
docker buildx create --use --name multiarch

# Rebuild with correct platform
docker buildx build --platform linux/amd64 -t IMAGE --push .
```

**Common Error 7: Docker BuildKit Not Enabled**
```bash
# Error: unknown flag: --platform

# Solution: Enable BuildKit
export DOCKER_BUILDKIT=1

# Or use buildx (recommended)
docker buildx create --use
docker buildx build --platform linux/amd64 ...
```

#### Step 2.3: Update Kubernetes Deployment Files with ECR URIs
```bash
# Update all deployment YAML files with actual ECR image URIs
for SERVICE in api-gateway user-service product-service order-service notification-service; do
  sed -i.bak "s|image:.*ecommerce-$SERVICE.*|image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest|g" \
    kubernetes/base/$SERVICE.yaml
done

# Update frontend
sed -i.bak "s|image:.*ecommerce-frontend.*|image: $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest|g" \
  kubernetes/base/frontend.yaml

# Verify changes
grep "image:" kubernetes/base/*.yaml
```

### Phase 3: Kubernetes Deployment

#### Step 3.1: Create Kubernetes Secrets
```bash
# Create secret for database password
kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD='Admin123456!' \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify secret created
kubectl get secrets
kubectl describe secret app-secrets
```

#### Step 3.2: Deploy All Services to Kubernetes
```bash
# Apply ConfigMap first
kubectl apply -f kubernetes/base/configmap.yaml

# Deploy services in order (databases first, then apps)
kubectl apply -f kubernetes/base/user-service.yaml
kubectl apply -f kubernetes/base/product-service.yaml
kubectl apply -f kubernetes/base/order-service.yaml
kubectl apply -f kubernetes/base/notification-service.yaml
kubectl apply -f kubernetes/base/api-gateway.yaml
kubectl apply -f kubernetes/base/frontend.yaml

# Apply HPAs (Horizontal Pod Autoscalers)
kubectl apply -f kubernetes/base/api-gateway-hpa.yaml
kubectl apply -f kubernetes/base/order-service-hpa.yaml

# Wait for all deployments to be ready
kubectl wait --for=condition=available --timeout=600s deployment --all

# Check pod status
kubectl get pods

# Expected output (may vary based on replicas):
# NAME                                  READY   STATUS    RESTARTS   AGE
# api-gateway-xxxxx                     1/1     Running   0          2m
# user-service-xxxxx                    1/1     Running   0          2m
# product-service-xxxxx                 1/1     Running   0          2m
# order-service-xxxxx                   1/1     Running   0          2m
# notification-service-xxxxx            1/1     Running   0          2m
# frontend-xxxxx                        1/1     Running   0          2m
```

**Common Error 8: ImagePullBackOff**
```bash
# Error: Pod status shows "ImagePullBackOff"

# Check error details
kubectl describe pod POD_NAME

# Common causes:
# 1. ECR authentication expired (12 hours)
# Solution: Recreate ECR secret or use IAM roles

# 2. Image doesn't exist
aws ecr list-images --repository-name ecommerce-SERVICE-NAME

# 3. Wrong image URI
kubectl get deployment SERVICE -o yaml | grep image:

# Fix: Update deployment with correct image
kubectl set image deployment/SERVICE SERVICE=CORRECT_IMAGE_URI
```

**Common Error 9: CrashLoopBackOff**
```bash
# Error: Pod repeatedly crashing

# Check logs
kubectl logs POD_NAME
kubectl logs POD_NAME --previous  # Previous instance

# Common causes:
# 1. Environment variables missing
kubectl exec POD_NAME -- env | grep DB_HOST

# 2. Database connection failed
kubectl exec POD_NAME -- nc -zv RDS_ENDPOINT 3306

# 3. Application error
kubectl logs POD_NAME | tail -50
```

**Common Error 10: Pods Stuck in Pending**
```bash
# Error: Pods remain in "Pending" state

# Check events
kubectl describe pod POD_NAME

# Common causes:
# 1. Insufficient node capacity
kubectl describe nodes | grep -A 5 "Allocated resources"

# Solution: Scale down some deployments
kubectl scale deployment product-service --replicas=1
kubectl scale deployment user-service --replicas=1

# 2. Resource limits too high
kubectl describe pod POD_NAME | grep -A 10 "Limits"

# Solution: Reduce resource requests in deployment YAML
```

#### Step 3.3: Configure IAM Permissions for DynamoDB
```bash
# Get EKS node IAM role
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name ecommerce-cluster \
  --nodegroup-name ecommerce-node-group \
  --query 'nodegroup.nodeRole' \
  --output text | cut -d'/' -f2)

echo "Node Role: $NODE_ROLE"

# Attach DynamoDB policy to node role
aws iam put-role-policy \
  --role-name $NODE_ROLE \
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
      "Resource": "arn:aws:dynamodb:us-east-1:*:table/ecommerce-*"
    }]
  }'

# Remove incorrect service account annotation (if exists)
kubectl annotate serviceaccount product-service-sa eks.amazonaws.com/role-arn- 2>/dev/null || true

# Restart product service to pick up new permissions
kubectl rollout restart deployment/product-service

# Wait for rollout
kubectl rollout status deployment/product-service

# Verify DynamoDB access
kubectl logs -l app=product-service --tail=20 | grep -i dynamodb
```

**Common Error 11: DynamoDB Access Denied**
```bash
# Error: AccessDeniedException when accessing DynamoDB

# Check pod logs
kubectl logs -l app=product-service | grep DynamoDB

# Verify IAM policy attached
aws iam get-role-policy --role-name $NODE_ROLE --policy-name DynamoDBAccess

# Test DynamoDB access from pod
kubectl exec -it PRODUCT_POD -- sh
# Inside pod:
aws dynamodb list-tables --region us-east-1
```

#### Step 3.4: Wait for LoadBalancers and Get Public Endpoints
```bash
# Wait for LoadBalancers to provision (2-3 minutes)
echo "Waiting for LoadBalancers to be ready..."
sleep 120

# Get API Gateway URL
export API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "API Gateway: http://$API_URL"

# Get Frontend URL
export FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Frontend: http://$FRONTEND_URL"

# Test endpoints
curl -s http://$API_URL/health | jq .
curl -s http://$FRONTEND_URL | grep -o "<title>.*</title>"
```

### Phase 4: GCP Infrastructure - Flink Analytics

#### Step 4.1: Deploy GCP Dataproc Cluster for Flink
```bash
cd terraform/gcp

# Initialize Terraform
terraform init

# Set GCP project
export GCP_PROJECT_ID="your-project-id"
export GCP_REGION="us-central1"

# Create terraform.tfvars
cat > terraform.tfvars <<EOF
project_id = "$GCP_PROJECT_ID"
region = "$GCP_REGION"
EOF

# Deploy Dataproc cluster
terraform plan
terraform apply -auto-approve

# Expected time: 5-7 minutes
# Resources created:
# - Dataproc cluster (1 master + 2 workers)
# - Cloud Storage bucket for Flink jobs
# - IAM service account

# Get cluster name
export DATAPROC_CLUSTER=$(terraform output -raw cluster_name)
echo "Dataproc Cluster: $DATAPROC_CLUSTER"

cd ../..
```

#### Step 4.2: Build and Upload Flink Job JAR
```bash
cd analytics

# Build Flink job (requires Maven)
mvn clean package

# Verify JAR created
ls -lh target/*.jar

# Upload to GCP Cloud Storage
export GCS_BUCKET=$(cd ../terraform/gcp && terraform output -raw gcs_bucket_name)
gsutil cp target/flink-analytics-1.0.0.jar gs://$GCS_BUCKET/flink-jobs/

# Verify upload
gsutil ls gs://$GCS_BUCKET/flink-jobs/

cd ..
```

**Common Error 12: Maven Build Failed**
```bash
# Error: BUILD FAILURE - missing dependencies

# Solution 1: Update dependencies
cd analytics
mvn dependency:resolve
mvn clean install

# Solution 2: Use pre-built JAR (if available)
# Download from releases or use provided JAR

# Error: Java version mismatch
# Solution: Use Java 11
java -version
export JAVA_HOME=$(/usr/libexec/java_home -v 11)
```

#### Step 4.3: Configure Flink Job to Connect to MSK Kafka
```bash
# Update Flink job configuration with MSK bootstrap servers
export MSK_BOOTSTRAP=$(cd terraform/aws && terraform output -raw msk_bootstrap_servers)

# Edit analytics/src/main/resources/application.properties
cat > analytics/src/main/resources/application.properties <<EOF
kafka.bootstrap.servers=$MSK_BOOTSTRAP
kafka.topic.orders=order-events
kafka.topic.analytics=analytics-results
kafka.group.id=flink-analytics-group
EOF

# Rebuild JAR with updated config
cd analytics
mvn clean package
gsutil cp target/flink-analytics-1.0.0.jar gs://$GCS_BUCKET/flink-jobs/
cd ..
```

**Common Error 13: Flink Can't Connect to MSK**
```bash
# Error: org.apache.kafka.common.errors.TimeoutException

# Cause: MSK is in AWS private subnet, Flink in GCP
# Solution: Use MSK public endpoint or VPN/VPC peering

# Check MSK connectivity settings
aws kafka describe-cluster --cluster-arn CLUSTER_ARN

# Enable public access (if needed)
aws kafka update-connectivity \
  --cluster-arn CLUSTER_ARN \
  --connectivity-info PublicAccess={Type=SERVICE_PROVIDED_EIPS}
```

#### Step 4.4: Submit Flink Job to Dataproc
```bash
# Submit Flink job
gcloud dataproc jobs submit flink \
  --cluster=$DATAPROC_CLUSTER \
  --region=$GCP_REGION \
  --jar=gs://$GCS_BUCKET/flink-jobs/flink-analytics-1.0.0.jar \
  --properties=flink.execution.mode=detached

# Get job ID
export FLINK_JOB_ID=$(gcloud dataproc jobs list \
  --cluster=$DATAPROC_CLUSTER \
  --region=$GCP_REGION \
  --filter="status.state=RUNNING" \
  --format="value(reference.jobId)" \
  --limit=1)

echo "Flink Job ID: $FLINK_JOB_ID"

# Check job status
gcloud dataproc jobs describe $FLINK_JOB_ID \
  --cluster=$DATAPROC_CLUSTER \
  --region=$GCP_REGION

# View job logs
gcloud dataproc jobs wait $FLINK_JOB_ID \
  --cluster=$DATAPROC_CLUSTER \
  --region=$GCP_REGION
```

#### Step 4.5: Deploy GCP Cloud Function for Order Analytics
```bash
cd gcp-function

# Enable required APIs (if not already done)
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudbuild.googleapis.com

# Deploy Cloud Function
gcloud functions deploy order-analytics \
  --runtime python311 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point process_order_analytics \
  --region=$GCP_REGION \
  --memory=256MB \
  --timeout=60s

# Get function URL
export GCP_FUNCTION_URL=$(gcloud functions describe order-analytics \
  --region=$GCP_REGION \
  --format="value(serviceConfig.uri)")

echo "GCP Function URL: $GCP_FUNCTION_URL"

# Test function
curl -X POST $GCP_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"order_id": 123, "user_id": 1, "total": 299.99}'

cd ..
```

### Phase 5: Monitoring Stack Deployment

#### Step 5.1: Deploy Prometheus
```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/prometheus \
  --set server.service.type=LoadBalancer \
  --set server.persistentVolume.enabled=false \
  --set alertmanager.enabled=false

# Wait for LoadBalancer
kubectl get svc prometheus-server -w

# Get Prometheus URL
export PROMETHEUS_URL=$(kubectl get svc prometheus-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Prometheus: http://$PROMETHEUS_URL"
```

#### Step 5.2: Deploy Grafana
```bash
# Add Grafana Helm repo
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Install Grafana
helm install grafana grafana/grafana \
  --set service.type=LoadBalancer \
  --set persistence.enabled=false \
  --set adminPassword='admin123'

# Wait for LoadBalancer
kubectl get svc grafana -w

# Get Grafana URL and credentials
export GRAFANA_URL=$(kubectl get svc grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Grafana: http://$GRAFANA_URL"
echo "Username: admin"
echo "Password: admin123"

# Configure Prometheus as data source in Grafana
# Login to Grafana → Configuration → Data Sources → Add Prometheus
# URL: http://prometheus-server
```

#### Step 5.3: Deploy ArgoCD for GitOps
```bash
# Create ArgoCD namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods
kubectl wait --for=condition=available --timeout=600s deployment --all -n argocd

# Expose ArgoCD server
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get ArgoCD URL
export ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "ArgoCD: http://$ARGOCD_URL"

# Get admin password
export ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"

# Login via CLI
argocd login $ARGOCD_URL --username admin --password $ARGOCD_PASSWORD --insecure

# Create ArgoCD applications
kubectl apply -f kubernetes/argocd/applications/
```

---

## 🧪 Complete Testing Guide

### Test 1: Health Checks
```bash
# API Gateway health
curl http://$API_URL/health

# Expected: {"service":"api-gateway","status":"healthy"}

# Test all services via API Gateway
curl http://$API_URL/api/users
curl http://$API_URL/api/products
curl http://$API_URL/api/orders
```

### Test 2: Create and Retrieve Data
```bash
# Create a user
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# Get all users
curl http://$API_URL/api/users | jq .

# Create a product
curl -X POST http://$API_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name":"Laptop","description":"High-performance laptop","price":1299.99,"stock":10}'

# Create an order (triggers Kafka → Flink pipeline)
curl -X POST http://$API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id":1,"product_id":"laptop-001","quantity":2,"total_price":2599.98}'
```

### Test 3: Lambda S3 Processing
```bash
# Create test file
echo "Test file uploaded at $(date)" > test.txt

# Upload to S3 (triggers Lambda)
aws s3 cp test.txt s3://$S3_BUCKET/uploads/test.txt

# Wait 2-3 seconds for Lambda processing

# Check Lambda processed the file
aws s3 ls s3://$S3_BUCKET/processed/

# Download processed file
aws s3 cp s3://$S3_BUCKET/processed/test.txt processed-test.txt

# Verify uppercase conversion
cat processed-test.txt

# Check Lambda logs
aws logs tail /aws/lambda/s3-file-processor --follow
```

### Test 4: Flink Real-Time Analytics
```bash
# Create multiple orders to test Flink aggregation
for i in {1..10}; do
  curl -X POST http://$API_URL/api/orders \
    -H "Content-Type: application/json" \
    -d "{\"user_id\":1,\"product_id\":\"product-$i\",\"quantity\":$((RANDOM % 5 + 1)),\"total_price\":$((RANDOM % 500 + 50)).99}"
  sleep 0.5
done

# Check Flink job is processing
gcloud dataproc jobs describe $FLINK_JOB_ID --region=$GCP_REGION

# View Flink output (analytics-results topic in Kafka)
# This requires Kafka consumer tool or checking service logs
kubectl logs -l app=notification-service --tail=50 | grep analytics
```

### Test 5: GCP Cloud Function
```bash
# Test with user ID 1 (should have orders from previous tests)
curl -X POST $GCP_FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1}' | jq .

# Expected response with analytics:
# {
#   "user_id": 1,
#   "total_orders": 10,
#   "lifetime_value": "5249.90",
#   "customer_segment": "VIP Customer",
#   "recommendation": "Offer exclusive 20% discount"
# }
```

### Test 6: Load Testing with k6
```bash
# Install k6 (if not already)
brew install k6

# Run load test
k6 run load-testing/scripts/load-test.js

# Expected output:
# - Test creates users and orders
# - Measures response times
# - Shows success rate
# - Duration: ~5-10 minutes

# Monitor HPA during load test
watch kubectl get hpa
```

### Test 7: Frontend End-to-End
```bash
# Open frontend in browser
open http://$FRONTEND_URL

# Test these features:
# 1. Overview tab - should show all services status
# 2. Users tab - create user, view all users
# 3. Orders tab - create order (sends to Kafka → Flink)
# 4. Products tab - create product (saves to DynamoDB)
# 5. Cloud Services tab:
#    - Lambda: Upload text file, see uppercase output
#    - GCP Function: Enter user ID, see analytics
#    - Flink: View top 10 VIP users
# 6. Monitoring tab - links to Grafana and ArgoCD
```

### Test 8: Verify Data in Databases
```bash
# Check RDS MySQL
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h $RDS_ENDPOINT -u admin -p'Admin123456!' -D ecommercedb \
  -e "SELECT COUNT(*) as user_count FROM users; SELECT COUNT(*) as order_count FROM orders; SELECT * FROM orders LIMIT 5;"

# Check DynamoDB
aws dynamodb scan --table-name ecommerce-products --limit 5

# Check S3
aws s3 ls s3://$S3_BUCKET/uploads/
aws s3 ls s3://$S3_BUCKET/processed/
```

---

## 🚨 Common Errors and Solutions

### Error 14: LoadBalancer Stuck in Pending
```bash
# Issue: Service remains in "pending" state for LoadBalancer

# Check service events
kubectl describe svc api-gateway

# Check AWS ELB creation
aws elbv2 describe-load-balancers

# Common cause: Insufficient EIPs
# Solution: Delete unused elastic IPs or request limit increase

# Workaround: Use NodePort instead
kubectl patch svc api-gateway -p '{"spec":{"type":"NodePort"}}'
```

### Error 15: Frontend Shows "Failed to fetch"
```bash
# Issue: Frontend can't connect to API Gateway

# Check CORS configuration in API Gateway
kubectl logs -l app=api-gateway | grep CORS

# Verify API_URL in frontend code
kubectl get configmap -o yaml | grep API_URL

# Update ConfigMap if needed
kubectl edit configmap app-config

# Restart frontend
kubectl rollout restart deployment/frontend
```

### Error 16: Orders Not Flowing to Kafka
```bash
# Check order service logs
kubectl logs -l app=order-service --tail=50

# Test Kafka connectivity from pod
kubectl exec -it ORDER_POD -- nc -zv MSK_ENDPOINT 9092

# Check MSK cluster status
aws kafka describe-cluster --cluster-arn CLUSTER_ARN

# Verify Kafka topic exists
# (Requires Kafka client in pod)
kubectl exec -it ORDER_POD -- kafka-topics --list --bootstrap-server $MSK_BOOTSTRAP
```

### Error 17: High Costs / Unexpected Charges
```bash
# Check current costs
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity DAILY \
  --metrics BlendedCost

# Most expensive resources:
# 1. NAT Gateways ($0.045/hour each = $65/month)
# 2. EKS Control Plane ($0.10/hour = $72/month)
# 3. MSK Brokers ($0.21/hour = $151/month)
# 4. EC2 Nodes ($0.0416/hour each)

# Cost-saving tips:
# 1. Destroy when not in use: ./teardown.sh
# 2. Scale down nodes: kubectl scale deployment --replicas=1
# 3. Use Spot instances for non-prod
# 4. Delete NAT gateways if not needed for private subnets
```

---

## 🧹 Complete Teardown Guide

### Automated Teardown Script
```bash
# Use the automated script (recommended)
./teardown.sh

# This script will:
# 1. Confirm destruction (requires typing "yes")
# 2. Delete all Kubernetes resources
# 3. Remove IAM policies
# 4. Delete ECR images
# 5. Destroy GCP infrastructure
# 6. Destroy AWS infrastructure
# 7. Clean local artifacts
```

### Manual Teardown (Step-by-Step)

#### Step 1: Delete Monitoring Stack
```bash
# Delete ArgoCD
kubectl delete -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl delete namespace argocd

# Delete Grafana
helm uninstall grafana

# Delete Prometheus
helm uninstall prometheus
```

#### Step 2: Delete Kubernetes Resources
```bash
# Delete all deployments and services
kubectl delete deployment --all
kubectl delete service --all
kubectl delete hpa --all
kubectl delete configmap --all
kubectl delete secret --all

# Force delete if stuck
kubectl delete pods --all --force --grace-period=0

# Verify all deleted
kubectl get all
```

#### Step 3: Delete GCP Resources
```bash
# Delete Cloud Function
gcloud functions delete order-analytics --region=$GCP_REGION --quiet

# Delete Flink job
gcloud dataproc jobs kill $FLINK_JOB_ID --cluster=$DATAPROC_CLUSTER --region=$GCP_REGION

# Destroy Dataproc cluster via Terraform
cd terraform/gcp
terraform destroy -auto-approve
cd ../..

# Or manually delete cluster
gcloud dataproc clusters delete analytics-cluster --region=$GCP_REGION --quiet

# Delete Cloud Storage bucket
gsutil -m rm -r gs://$GCS_BUCKET
```

#### Step 4: Delete AWS ECR Images
```bash
# List repositories
aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text

# Delete all images in each repository
for REPO in $(aws ecr describe-repositories --query 'repositories[*].repositoryName' --output text); do
  echo "Deleting images in $REPO..."
  aws ecr batch-delete-image \
    --repository-name $REPO \
    --image-ids "$(aws ecr list-images --repository-name $REPO --query 'imageIds[*]' --output json)" || true
done
```

#### Step 5: Remove IAM Policies
```bash
# Get node role
NODE_ROLE=$(aws eks describe-nodegroup \
  --cluster-name ecommerce-cluster \
  --nodegroup-name ecommerce-node-group \
  --query 'nodegroup.nodeRole' \
  --output text | cut -d'/' -f2)

# Delete DynamoDB policy
aws iam delete-role-policy \
  --role-name $NODE_ROLE \
  --policy-name DynamoDBAccess || true
```

#### Step 6: Destroy AWS Infrastructure
```bash
cd terraform/aws

# Destroy all Terraform resources
terraform destroy -auto-approve

# If destroy fails, manually delete stuck resources:
# 1. LoadBalancers
aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerArn,LoadBalancerName]'
aws elbv2 delete-load-balancer --load-balancer-arn ARN

# 2. Security groups (delete after LBs)
aws ec2 describe-security-groups --filters "Name=tag:Project,Values=ecommerce" --query 'SecurityGroups[*].GroupId'

# 3. EKS cluster (if not deleted)
aws eks delete-cluster --name ecommerce-cluster

# Retry destroy
terraform destroy -auto-approve

cd ../..
```

#### Step 7: Clean Local Artifacts
```bash
# Remove kubectl context
kubectl config delete-context $(kubectl config current-context)

# Remove Terraform state files
rm -f terraform/aws/terraform.tfstate*
rm -f terraform/aws/.terraform.lock.hcl
rm -rf terraform/aws/.terraform/

rm -f terraform/gcp/terraform.tfstate*
rm -f terraform/gcp/.terraform.lock.hcl
rm -rf terraform/gcp/.terraform/

# Clear environment variables
unset AWS_ACCOUNT_ID RDS_ENDPOINT MSK_BOOTSTRAP DYNAMODB_TABLE S3_BUCKET
unset API_URL FRONTEND_URL PROMETHEUS_URL GRAFANA_URL ARGOCD_URL
unset GCP_PROJECT_ID DATAPROC_CLUSTER FLINK_JOB_ID GCP_FUNCTION_URL
```

#### Step 8: Verify Complete Cleanup
```bash
# Check no AWS resources remain
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=ecommerce

# Should return: "ResourceTagMappingList": []

# Check AWS billing
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-30 \
  --granularity DAILY \
  --metrics BlendedCost

# Check GCP resources
gcloud compute instances list
gcloud dataproc clusters list
gcloud functions list

# Open billing consoles to verify zero charges
open https://console.aws.amazon.com/billing/home
open https://console.cloud.google.com/billing
```

---

## 📊 Cost Summary and Monitoring

### Hourly/Monthly Cost Breakdown
```
AWS Resources:
├── EKS Control Plane       $0.10/hr  ($72/month)
├── EC2 Nodes (2x t3.medium)$0.08/hr  ($58/month)
├── RDS t3.micro            $0.00/hr  (Free Tier)
├── DynamoDB                $0.00/hr  (Pay per request)
├── MSK (2x t3.small)       $0.21/hr  ($151/month)
├── NAT Gateways (2)        $0.09/hr  ($65/month)
├── LoadBalancers (2)       $0.05/hr  ($36/month)
├── S3 Storage              ~$0.01/hr ($7/month)
└── Data Transfer           ~$0.02/hr ($14/month)
                            ─────────────────────
AWS Total:                  ~$0.56/hr (~$403/month)

GCP Resources:
├── Dataproc Master         $0.08/hr  ($58/month)
├── Dataproc Workers (2)    $0.16/hr  ($115/month)
├── Cloud Storage           ~$0.01/hr ($7/month)
├── Cloud Functions         $0.00/hr  (Minimal usage)
└── Network Egress          ~$0.01/hr ($7/month)
                            ─────────────────────
GCP Total:                  ~$0.26/hr (~$187/month)

GRAND TOTAL:                ~$0.82/hr (~$590/month)
```

### Cost Optimization Tips
1. **Run only when needed**: Use ./teardown.sh after demos
2. **Scale down replicas**: Reduce from 2 to 1 replica per service
3. **Use Spot instances**: Save 70% on EC2 costs
4. **Pause Dataproc**: Delete cluster when not using Flink
5. **Optimize RDS**: Use t3.micro (free tier eligible)
6. **Delete NAT Gateways**: Use public subnets only (less secure)

### Set Up Cost Alerts
```bash
# AWS Budgets
aws budgets create-budget \
  --account-id $AWS_ACCOUNT_ID \
  --budget '{
    "BudgetName": "Monthly-Spend-Limit",
    "BudgetLimit": {"Amount": "100", "Unit": "USD"},
    "TimeUnit": "MONTHLY",
    "BudgetType": "COST"
  }'

# GCP Budget Alert
gcloud billing budgets create \
  --billing-account=BILLING_ACCOUNT_ID \
  --display-name="Monthly Budget" \
  --budget-amount=100USD
```

---

## 🔍 Verification and Monitoring Commands

### Check Infrastructure Status
```bash
# AWS Resources via Terraform
cd terraform/aws && terraform state list && cd ../..

# EKS Cluster
aws eks describe-cluster --name ecommerce-cluster --query 'cluster.status'
kubectl get nodes -o wide

# All Kubernetes Resources
kubectl get all --all-namespaces

# Services with External IPs
kubectl get svc -o wide

# HPAs (Horizontal Pod Autoscalers)
kubectl get hpa

# PV and PVC
kubectl get pv,pvc

# ConfigMaps and Secrets
kubectl get configmap,secret
```

### Database Verification
```bash
# RDS MySQL - Connection test
kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h $RDS_ENDPOINT -u admin -p'Admin123456!' -D ecommercedb -e "SHOW TABLES;"

# RDS - Row counts
kubectl run mysql-test --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h $RDS_ENDPOINT -u admin -p'Admin123456!' -D ecommercedb \
  -e "SELECT 'Users:' as Table_Name, COUNT(*) as Row_Count FROM users UNION SELECT 'Orders:', COUNT(*) FROM orders;"

# DynamoDB - Item count
aws dynamodb describe-table --table-name ecommerce-products --query 'Table.ItemCount'

# DynamoDB - Scan items
aws dynamodb scan --table-name ecommerce-products --max-items 5
```

### Kafka/MSK Verification
```bash
# MSK Cluster status
aws kafka list-clusters
aws kafka describe-cluster --cluster-arn CLUSTER_ARN

# List Kafka topics (from within pod)
kubectl exec -it ORDER_SERVICE_POD -- sh
# Inside pod:
kafka-topics --list --bootstrap-server $MSK_BOOTSTRAP
```

### Flink Job Monitoring
```bash
# List all Dataproc jobs
gcloud dataproc jobs list --cluster=$DATAPROC_CLUSTER --region=$GCP_REGION

# Describe specific job
gcloud dataproc jobs describe $FLINK_JOB_ID --cluster=$DATAPROC_CLUSTER --region=$GCP_REGION

# View job output
gcloud dataproc jobs wait $FLINK_JOB_ID --cluster=$DATAPROC_CLUSTER --region=$GCP_REGION

# SSH into Dataproc master (for advanced debugging)
gcloud compute ssh analytics-cluster-m --zone=us-central1-c
```

### Application Logs
```bash
# All logs for a service
kubectl logs -l app=user-service --tail=100

# Follow logs in real-time
kubectl logs -l app=api-gateway -f

# Previous container logs (if crashed)
kubectl logs POD_NAME --previous

# Multiple pod logs
stern api-gateway  # Requires stern: brew install stern

# Lambda logs
aws logs tail /aws/lambda/s3-file-processor --follow --since 10m

# GCP Function logs
gcloud functions logs read order-analytics --region=$GCP_REGION --limit=50
```

### Performance Monitoring
```bash
# Pod resource usage
kubectl top pods
kubectl top nodes

# Detailed pod metrics
kubectl describe pod POD_NAME | grep -A 10 "Limits\|Requests"

# HPA metrics
kubectl get hpa -w

# Check Prometheus metrics
curl http://$PROMETHEUS_URL/api/v1/query?query=up

# Service latency (via Prometheus)
curl http://$PROMETHEUS_URL/api/v1/query?query=http_request_duration_seconds
```

---

## 📁 Complete File Structure
```
Cloud_A15/
├── deploy.sh                        # Automated deployment
├── teardown.sh                      # Automated cleanup
├── test-api.sh                      # API test suite
├── complete-test.sh                 # Full integration tests
├── destroy-everything.sh            # Nuclear option cleanup
├── verify-destruction.sh            # Verify all resources deleted
├── DEPLOYMENT_GUIDE.md              # This file
├── PROJECT_SUMMARY.md               # Project overview
├── REQUIREMENTS_VERIFICATION.md     # Requirements checklist
├── TESTING_GUIDE.md                 # Detailed testing guide
├── VIDEO_DEMO_GUIDE.md              # Screen recording guide
├── VIVA_GUIDE.md                    # Presentation talking points
├── terraform/
│   ├── aws/
│   │   ├── main.tf                  # Root AWS config
│   │   ├── variables.tf             # AWS variables
│   │   ├── outputs.tf               # AWS outputs
│   │   └── modules/
│   │       ├── vpc/                 # VPC module
│   │       ├── eks/                 # EKS module
│   │       ├── rds/                 # RDS module
│   │       ├── msk/                 # MSK Kafka module
│   │       └── lambda/              # Lambda module
│   └── gcp/
│       ├── main.tf                  # GCP Dataproc config
│       └── variables.tf             # GCP variables
├── kubernetes/
│   ├── base/
│   │   ├── configmap.yaml           # Environment config
│   │   ├── api-gateway.yaml         # API Gateway deployment
│   │   ├── api-gateway-hpa.yaml     # API Gateway autoscaling
│   │   ├── user-service.yaml        # User service
│   │   ├── product-service.yaml     # Product service
│   │   ├── order-service.yaml       # Order service
│   │   ├── order-service-hpa.yaml   # Order autoscaling
│   │   ├── notification-service.yaml# Notification service
│   │   ├── analytics-service.yaml   # Analytics service
│   │   └── frontend.yaml            # Frontend deployment
│   └── argocd/
│       └── applications/            # ArgoCD app definitions
├── microservices/
│   ├── api-gateway/
│   │   ├── app.py                   # Flask API gateway
│   │   ├── Dockerfile               # Container definition
│   │   └── requirements.txt         # Python dependencies
│   ├── user-service/
│   │   ├── app.py                   # User CRUD operations
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── product-service/
│   │   ├── app.py                   # Product management (DynamoDB)
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── order-service/
│   │   ├── app.py                   # Order processing (Kafka)
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   ├── notification-service/
│   │   ├── app.py                   # Kafka consumer
│   │   ├── Dockerfile
│   │   └── requirements.txt
│   └── analytics-service/
│       ├── app.py                   # Analytics REST API
│       ├── Dockerfile
│       └── requirements.txt
├── analytics/
│   ├── pom.xml                      # Maven configuration
│   ├── README.md                    # Flink job documentation
│   └── src/main/java/com/ecommerce/analytics/
│       └── OrderAnalyticsJob.java   # Flink stream processing
├── gcp-function/
│   ├── main.py                      # Cloud Function code
│   └── requirements.txt             # Python dependencies
├── lambda/
│   ├── index.py                     # Lambda handler
│   └── README.md                    # Lambda documentation
├── frontend/
│   ├── comprehensive-demo.html      # Single-page application
│   ├── Dockerfile                   # Nginx container
│   ├── app.html                     # Legacy frontend
│   └── index.html                   # Simple frontend
├── load-testing/
│   └── scripts/
│       ├── load-test.js             # k6 load test
│       └── stress-test.js           # k6 stress test
├── scripts/
│   ├── build-and-push.sh            # Docker build automation
│   ├── deploy-all.sh                # Kubernetes deployment
│   ├── setup-argocd.sh              # ArgoCD setup
│   └── setup-monitoring.sh          # Prometheus/Grafana setup
└── docs/
    ├── API.md                       # API documentation
    ├── DESIGN.md                    # Architecture design
    └── TROUBLESHOOTING.md           # Common issues
```

---

## 💡 Pro Tips and Best Practices

### Development Workflow
```bash
# 1. Make code changes to a microservice
vim microservices/user-service/app.py

# 2. Rebuild and push only that service
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_REGION=us-east-1

docker buildx build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-user-service:latest \
  ./microservices/user-service --push

# 3. Restart deployment to pull new image
kubectl rollout restart deployment user-service

# 4. Watch rollout progress
kubectl rollout status deployment user-service

# 5. Test immediately
kubectl port-forward svc/user-service 5001:5001
curl http://localhost:5001/health
```

### Debugging Pod Issues
```bash
# Get detailed pod information
kubectl describe pod POD_NAME

# Check pod events
kubectl get events --sort-by='.lastTimestamp' | grep POD_NAME

# Shell into running pod
kubectl exec -it POD_NAME -- sh

# View environment variables
kubectl exec POD_NAME -- env

# Check if service can reach other services
kubectl exec POD_NAME -- wget -qO- http://user-service:5001/health
```

### Database Management
```bash
# Create database backup (RDS)
aws rds create-db-snapshot \
  --db-instance-identifier ecommerce-db \
  --db-snapshot-identifier ecommerce-backup-$(date +%Y%m%d)

# Restore from snapshot
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier ecommerce-db-restored \
  --db-snapshot-identifier ecommerce-backup-20250101

# Export DynamoDB table
aws dynamodb export-table-to-point-in-time \
  --table-arn arn:aws:dynamodb:us-east-1:ACCOUNT_ID:table/ecommerce-products \
  --s3-bucket ecommerce-backups \
  --export-format DYNAMODB_JSON
```

### Monitoring Best Practices
```bash
# Set up CloudWatch alarms for EKS nodes
aws cloudwatch put-metric-alarm \
  --alarm-name high-cpu-ecommerce \
  --alarm-description "CPU above 80%" \
  --metric-name CPUUtilization \
  --namespace AWS/EC2 \
  --statistic Average \
  --period 300 \
  --threshold 80 \
  --comparison-operator GreaterThanThreshold

# Create CloudWatch dashboard
aws cloudwatch put-dashboard \
  --dashboard-name ecommerce-metrics \
  --dashboard-body file://cloudwatch-dashboard.json

# Enable detailed monitoring
aws eks update-cluster-config \
  --name ecommerce-cluster \
  --logging '{"clusterLogging":[{"types":["api","audit","authenticator"],"enabled":true}]}'
```

### Performance Optimization
```bash
# Adjust HPA thresholds
kubectl patch hpa api-gateway --patch '{"spec":{"targetCPUUtilizationPercentage":70}}'

# Increase resource limits
kubectl set resources deployment user-service \
  --limits=cpu=500m,memory=512Mi \
  --requests=cpu=250m,memory=256Mi

# Scale manually for demo
kubectl scale deployment api-gateway --replicas=3

# Enable cluster autoscaler (production)
kubectl apply -f https://raw.githubusercontent.com/kubernetes/autoscaler/master/cluster-autoscaler/cloudprovider/aws/examples/cluster-autoscaler-autodiscover.yaml
```

### Cost Savings Strategies
```bash
# Use Spot instances for non-critical services
# Edit EKS node group to use spot instances
aws eks update-nodegroup-config \
  --cluster-name ecommerce-cluster \
  --nodegroup-name ecommerce-node-group \
  --capacity-type SPOT

# Delete NAT Gateways (use public subnets only - less secure)
# Modify terraform/aws/modules/vpc/main.tf:
# enable_nat_gateway = false

# Pause Dataproc cluster when not in use
gcloud dataproc clusters stop analytics-cluster --region=us-central1

# Restart when needed
gcloud dataproc clusters start analytics-cluster --region=us-central1

# Use AWS Savings Plans
aws savingsplans describe-savings-plans
```

### Security Hardening
```bash
# Enable pod security policies
kubectl apply -f - <<EOF
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: restricted
spec:
  privileged: false
  allowPrivilegeEscalation: false
  runAsUser:
    rule: MustRunAsNonRoot
  seLinux:
    rule: RunAsAny
  fsGroup:
    rule: RunAsAny
EOF

# Scan Docker images for vulnerabilities
for SERVICE in api-gateway user-service product-service order-service notification-service analytics-service frontend; do
  docker scan $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest
done

# Enable AWS GuardDuty
aws guardduty create-detector --enable

# Enable network policies in Kubernetes
kubectl apply -f - <<EOF
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress
EOF
```

---

## 🚀 Quick Reference

### Essential Commands
```bash
# Get all endpoints
kubectl get svc | grep LoadBalancer

# Restart all services
kubectl rollout restart deployment --all

# Scale down all services (save costs)
kubectl scale deployment --all --replicas=0

# Scale up all services
kubectl scale deployment --all --replicas=1

# Get pod logs for all services
for POD in $(kubectl get pods -o name); do
  echo "=== $POD ==="
  kubectl logs $POD --tail=10
done

# Port forward to service
kubectl port-forward svc/api-gateway 8080:8080

# Update ConfigMap and restart services
kubectl edit configmap ecommerce-config
kubectl rollout restart deployment --all
```

### Common Workflows

#### Deploy Code Change
```bash
# 1. Edit code
# 2. Build and push image
# 3. Restart deployment
SERVICE=user-service
docker buildx build --platform linux/amd64 -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest ./microservices/$SERVICE --push
kubectl rollout restart deployment $SERVICE
kubectl rollout status deployment $SERVICE
```

#### Test Lambda Changes
```bash
# 1. Update lambda/index.py
# 2. Deploy via Terraform
cd terraform/aws
terraform apply -target=module.lambda -auto-approve
cd ../..

# 3. Upload test file
echo "test content" > /tmp/test.txt
aws s3 cp /tmp/test.txt s3://ecommerce-data-bucket-$AWS_ACCOUNT_ID/uploads/test.txt

# 4. Check logs
aws logs tail /aws/lambda/s3-file-processor --follow
```

#### Update Frontend
```bash
# 1. Edit frontend/comprehensive-demo.html
# 2. Rebuild and deploy
docker buildx build --platform linux/amd64 -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest ./frontend --push
kubectl rollout restart deployment frontend
kubectl rollout status deployment frontend

# 3. Get URL and test
FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
open http://$FRONTEND_URL
```

#### Submit New Flink Job
```bash
# 1. Edit analytics/src/main/java/com/ecommerce/analytics/OrderAnalyticsJob.java
# 2. Rebuild JAR
cd analytics
mvn clean package
cd ..

# 3. Upload to GCS
gsutil cp analytics/target/flink-analytics-1.0.0.jar gs://adept-lead-479014-r0-flink-jobs/

# 4. Cancel old job
gcloud dataproc jobs kill $OLD_FLINK_JOB_ID --cluster=analytics-cluster --region=us-central1

# 5. Submit new job
gcloud dataproc jobs submit flink \
  --cluster=analytics-cluster \
  --region=us-central1 \
  --jar=gs://adept-lead-479014-r0-flink-jobs/flink-analytics-1.0.0.jar \
  --class=com.ecommerce.analytics.OrderAnalyticsJob
```

---

## 🎯 Final Checklist

Before considering deployment complete, verify:

### Infrastructure
- [ ] AWS EKS cluster running (`kubectl get nodes`)
- [ ] RDS MySQL accessible (`mysql -h $RDS_ENDPOINT -u admin -p`)
- [ ] MSK Kafka brokers healthy (`aws kafka list-clusters`)
- [ ] DynamoDB table created (`aws dynamodb describe-table --table-name ecommerce-products`)
- [ ] S3 bucket created with folders (`aws s3 ls s3://ecommerce-data-bucket-$AWS_ACCOUNT_ID/`)
- [ ] Lambda function deployed (`aws lambda list-functions`)
- [ ] GCP Dataproc cluster running (`gcloud dataproc clusters list`)
- [ ] Flink job submitted (`gcloud dataproc jobs list`)

### Kubernetes
- [ ] All 6 microservices running (`kubectl get pods`)
- [ ] Frontend deployed (`kubectl get deployment frontend`)
- [ ] ConfigMap created (`kubectl get configmap ecommerce-config`)
- [ ] Secrets created (`kubectl get secret rds-secret dynamodb-secret`)
- [ ] LoadBalancers provisioned (`kubectl get svc | grep LoadBalancer`)
- [ ] HPAs configured (`kubectl get hpa`)

### Monitoring
- [ ] Prometheus installed (`kubectl get pods -n prometheus`)
- [ ] Grafana accessible (http://GRAFANA_URL)
- [ ] ArgoCD installed (`kubectl get pods -n argocd`)

### Testing
- [ ] Health endpoints responding (`curl $API_URL/health`)
- [ ] Users API working (`curl $API_URL/users`)
- [ ] Products API working (`curl $API_URL/products`)
- [ ] Orders API working (`curl $API_URL/orders`)
- [ ] Lambda processing files (`aws s3 ls s3://ecommerce-data-bucket-$AWS_ACCOUNT_ID/processed/`)
- [ ] Frontend loading (`open http://$FRONTEND_URL`)
- [ ] Load test passing (`k6 run load-testing/scripts/load-test.js`)

### Documentation
- [ ] All endpoints documented
- [ ] Credentials stored securely
- [ ] Architecture diagrams created
- [ ] Demo script prepared
- [ ] Cost estimates calculated

---

## 📞 Support and Resources

### Documentation
- [AWS EKS Documentation](https://docs.aws.amazon.com/eks/)
- [GCP Dataproc Documentation](https://cloud.google.com/dataproc/docs)
- [Apache Flink Documentation](https://flink.apache.org/docs/stable/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### Troubleshooting
- Check `TROUBLESHOOTING.md` for common issues
- Review `docs/DESIGN.md` for architecture details
- Check CloudWatch logs: `aws logs tail /aws/containerinsights/ecommerce-cluster/application`
- Check pod events: `kubectl get events --sort-by='.lastTimestamp'`

### Cost Management
- AWS Cost Explorer: https://console.aws.amazon.com/cost-management/
- GCP Billing: https://console.cloud.google.com/billing
- Set up billing alerts immediately after deployment

---

## 🎓 Lessons Learned

### Critical Issues Faced
1. **Docker Platform Mismatch**: Apple Silicon (ARM64) builds don't work on EKS (AMD64). Always use `--platform linux/amd64`.
2. **Node Capacity**: t3.medium nodes hit capacity with 11 pods. Scale down to 1 replica per service or add more nodes.
3. **ECR Login Expiry**: ECR login tokens expire after 12 hours. Re-authenticate if builds fail.
4. **DynamoDB Permissions**: IAM policies must be attached to node role, not just service accounts.
5. **LoadBalancer Delay**: AWS LoadBalancers take 3-5 minutes to provision. Be patient.
6. **S3 Lambda Triggers**: Prefix-specific. `uploads/` triggers Lambda, `test-uploads/` does not.
7. **Flink MSK Connectivity**: Requires correct security group rules and bootstrap servers.
8. **Kafka Topic Creation**: Auto-create may fail. Manually create topics if needed.
9. **RDS Initialization**: Must manually create tables after RDS deployment.
10. **Cost Monitoring**: Enable billing alerts before deployment to avoid surprises.

### What Worked Well
- ✅ Terraform for infrastructure as code (reproducible deployments)
- ✅ Multi-platform Docker builds with BuildKit
- ✅ Kubernetes HPA for auto-scaling under load
- ✅ ArgoCD for GitOps continuous delivery
- ✅ Prometheus + Grafana for observability
- ✅ k6 for load testing and performance validation
- ✅ Lambda for serverless file processing
- ✅ Flink for real-time stream analytics
- ✅ Comprehensive frontend with multiple tabs
- ✅ Real API integration (no fake data)

### Recommendations
1. **Always test locally first**: Use Docker Compose before deploying to Kubernetes
2. **Enable verbose logging**: Helps debug issues quickly
3. **Use infrastructure as code**: Terraform makes deployments reproducible
4. **Automate everything**: Scripts save time and reduce errors
5. **Monitor costs daily**: Cloud costs can escalate quickly
6. **Document as you go**: Don't wait until the end to write documentation
7. **Version control everything**: Git commits provide audit trail
8. **Test incrementally**: Deploy one service at a time, test, then move on
9. **Use managed services**: RDS, MSK, Dataproc reduce operational overhead
10. **Plan for teardown**: Always have a cleanup strategy before deploying

---

**Deployment Guide Complete! 🎉**

*Total Deployment Time: ~45 minutes (with automated scripts)*  
*Manual Deployment Time: ~2-3 hours (following this guide step-by-step)*  
*Teardown Time: ~15 minutes*

Good luck with your deployment! 🚀

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
