# Complete Deployment Guide

## Prerequisites

### Required Tools
- AWS CLI (v2.x) - [Install](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html)
- kubectl (v1.28+) - [Install](https://kubernetes.io/docs/tasks/tools/)
- Terraform (v1.0+) - [Install](https://www.terraform.io/downloads)
- Docker (v20+) - [Install](https://docs.docker.com/get-docker/)
- Helm (v3.x) - [Install](https://helm.sh/docs/intro/install/)
- k6 (latest) - [Install](https://k6.io/docs/getting-started/installation/)
- gcloud CLI - [Install](https://cloud.google.com/sdk/docs/install)

### AWS Configuration
```bash
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json
```

### GCP Configuration
```bash
gcloud auth login
gcloud config set project YOUR_PROJECT_ID
gcloud auth application-default login
```

---

## Step 1: Clone Repository

```bash
git clone https://github.com/pranjaymalhotra/CloudAssignment.git
cd CloudAssignment
export PS1="2024H1030072P "  # Set custom prompt for recording
```

---

## Step 2: Deploy AWS Infrastructure

### 2.1 Initialize and Apply Terraform
```bash
cd terraform/aws
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected Output:**
- VPC with 2 public + 2 private subnets
- EKS cluster (ecommerce-cluster)
- RDS MySQL instance
- MSK Kafka cluster (2 brokers)
- DynamoDB tables (products, analytics)
- S3 bucket + Lambda function
- ECR repositories (6 repos)

**Save these outputs:**
```bash
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export MSK_BOOTSTRAP_SERVERS=$(terraform output -raw msk_bootstrap_servers)
export ECR_REGISTRY=$(terraform output -raw ecr_registry)
```

### 2.2 Configure kubectl
```bash
aws eks update-kubeconfig --name ecommerce-cluster --region us-east-1
kubectl get nodes  # Should show 2 nodes
```

---

## Step 3: Deploy GCP Infrastructure

```bash
cd ../gcp
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Expected Output:**
- Dataproc cluster (analytics-cluster)
- Cloud Storage bucket
- VPC and firewall rules

---

## Step 4: Build and Push Docker Images

### 4.1 Login to ECR
```bash
cd ../..
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY
```

### 4.2 Build All Images
```bash
# Important: Use --platform linux/amd64 for AMD64 nodes
services=("api-gateway" "user-service" "product-service" "order-service" "notification-service" "frontend")

for service in "${services[@]}"; do
  echo "Building $service..."
  if [ "$service" = "frontend" ]; then
    cd frontend
  else
    cd microservices/$service
  fi
  
  docker buildx build --platform linux/amd64 \
    -t $ECR_REGISTRY/ecommerce-$service:latest \
    --push .
  
  cd ../..
done
```

---

## Step 5: Fix Common Issues Before Deployment

### 5.1 Fix RDS Security Group (CRITICAL)
**Problem:** EKS pods can't connect to RDS

**Solution:**
```bash
# Get security group IDs
EKS_SG=$(aws eks describe-cluster --name ecommerce-cluster --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
RDS_SG=$(aws rds describe-db-instances --db-instance-identifier ecommercedb --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

# Allow EKS cluster SG
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --source-group $EKS_SG

# Allow EKS node subnets (get CIDR blocks)
aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --cidr 10.0.10.0/24

aws ec2 authorize-security-group-ingress \
  --group-id $RDS_SG \
  --protocol tcp \
  --port 3306 \
  --cidr 10.0.11.0/24
```

### 5.2 Create Database Tables (CRITICAL)
**Problem:** Tables don't exist, causing 500 errors

**Solution:**
```bash
# Connect to RDS via a pod
kubectl run mysql-client --rm -it --image=mysql:8.0 -- bash

# Inside the pod:
mysql -h $RDS_ENDPOINT -u admin -p

# Enter password (from terraform output or AWS console)

# Create tables:
USE ecommercedb;

CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE IF NOT EXISTS orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);

# Verify
SHOW TABLES;
exit;
exit  # Exit pod
```

---

## Step 6: Deploy Kubernetes Resources

### 6.1 Create ConfigMap with Endpoints
```bash
kubectl create configmap app-config \
  --from-literal=DB_HOST=$RDS_ENDPOINT \
  --from-literal=KAFKA_BOOTSTRAP_SERVERS=$MSK_BOOTSTRAP_SERVERS \
  --from-literal=USER_SERVICE_URL=http://user-service:5001 \
  --from-literal=PRODUCT_SERVICE_URL=http://product-service:5002 \
  --from-literal=ORDER_SERVICE_URL=http://order-service:5003
```

### 6.2 Create Secrets
```bash
# Get DB password from Terraform output or AWS Secrets Manager
DB_PASSWORD=$(terraform output -raw db_password)

kubectl create secret generic app-secrets \
  --from-literal=DB_PASSWORD=$DB_PASSWORD \
  --from-literal=DB_USER=admin \
  --from-literal=DB_NAME=ecommercedb
```

### 6.3 Deploy All Services
```bash
kubectl apply -f kubernetes/base/
```

### 6.4 Wait for Pods
```bash
kubectl get pods -w
# Wait until all pods are Running (Ctrl+C to exit)
```

### 6.5 Get Service URLs
```bash
echo "API Gateway: http://$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Frontend: http://$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

---

## Step 7: Deploy Flink Analytics Job

### 7.1 Build Flink JAR
```bash
cd analytics
mvn clean package
```

### 7.2 Upload to GCS
```bash
gsutil cp target/flink-analytics-1.0.0.jar gs://YOUR_PROJECT_ID-flink-jobs/
```

### 7.3 Submit to Dataproc
```bash
gcloud dataproc jobs submit flink \
  --cluster=analytics-cluster \
  --region=us-central1 \
  --jar=gs://YOUR_PROJECT_ID-flink-jobs/flink-analytics-1.0.0.jar \
  --properties=^#^dataproc:dataproc.logging.stackdriver.enable=true
```

**Save Job ID** from output for monitoring

---

## Step 8: Deploy Monitoring Stack

### 8.1 Install Prometheus + Grafana
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

kubectl create namespace monitoring

helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.service.type=LoadBalancer \
  --set grafana.service.type=LoadBalancer \
  --set grafana.adminPassword=admin123
```

### 8.2 Get Grafana URL
```bash
echo "Grafana: http://$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
echo "Username: admin"
echo "Password: admin123"
```

### 8.3 Import Custom Dashboard
1. Open Grafana URL
2. Login with admin/admin123
3. Go to Dashboards → Import
4. Upload `monitoring/grafana-dashboard-microservices.json`

---

## Step 9: Deploy ArgoCD (GitOps)

### 9.1 Install ArgoCD
```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
```

### 9.2 Expose ArgoCD Server
```bash
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'
```

### 9.3 Get Admin Password
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""
```

### 9.4 Get ArgoCD URL
```bash
echo "ArgoCD: http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
```

### 9.5 Create ArgoCD Applications
```bash
kubectl apply -f kubernetes/argocd/ecommerce-project.yaml
kubectl apply -f kubernetes/argocd/applications/
```

---

## Step 10: Run Load Tests

### 10.1 Install k6
```bash
# macOS
brew install k6

# Linux
sudo apt-get install k6
```

### 10.2 Update Load Test URL
```bash
export API_URL="http://$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/api"

# Edit load-test.js to use your API_URL if needed
```

### 10.3 Run Load Test
```bash
k6 run load-test.js
```

### 10.4 Watch HPA Scaling
```bash
# In another terminal:
watch kubectl get hpa
# You should see replicas increase from 2 to 8-10 during load
```

---

## Step 11: Verify All Requirements

### (a) Multi-Cloud Architecture ✅
```bash
# AWS Resources
aws eks describe-cluster --name ecommerce-cluster
aws rds describe-db-instances --db-instance-identifier ecommercedb
aws kafka list-clusters

# GCP Resources
gcloud dataproc clusters describe analytics-cluster --region=us-central1
```

### (b) Serverless Function ✅
```bash
# Test Lambda
aws lambda invoke --function-name s3-event-processor --payload '{"test": "data"}' response.json
cat response.json
```

### (c) HPA ✅
```bash
kubectl get hpa
# Should show api-gateway-hpa and order-service-hpa
```

### (d) GitOps (ArgoCD) ✅
```bash
kubectl get applications -n argocd
# Should show microservices and monitoring-stack apps
```

### (e) Stream Processing (Flink) ✅
```bash
gcloud dataproc jobs describe YOUR_JOB_ID --region=us-central1
```

### (f) Cross-Cloud Communication ✅
```bash
# Create order to test Kafka → Flink flow
curl -X POST $API_URL/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": "test-123", "quantity": 1}'

# Check Flink job logs
gcloud dataproc jobs wait YOUR_JOB_ID --region=us-central1
```

### (g) Monitoring ✅
- Prometheus: Metrics collection
- Grafana: Visualization
- Check dashboard at Grafana URL

### (h) Load Testing ✅
```bash
k6 run load-test.js
# Verify HPA scaling during test
```

---

## Troubleshooting

### Issue: Pods Can't Pull Images
**Error:** `ErrImagePull` or `ImagePullBackOff`

**Solution:**
```bash
# Verify ECR login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $ECR_REGISTRY

# Check if image exists
aws ecr describe-images --repository-name ecommerce-api-gateway --region us-east-1

# Rebuild with correct platform
docker buildx build --platform linux/amd64 -t $ECR_REGISTRY/ecommerce-api-gateway:latest --push .
```

### Issue: Database Connection Failed
**Error:** `Can't connect to MySQL server`

**Solution:** See Step 5.1 - Fix RDS Security Group

### Issue: Table Doesn't Exist
**Error:** `Table 'ecommercedb.users' doesn't exist`

**Solution:** See Step 5.2 - Create Database Tables

### Issue: HPA Not Scaling
**Error:** HPA shows `<unknown>` for metrics

**Solution:**
```bash
# Install metrics-server
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml

# Wait for it to start
kubectl get deployment metrics-server -n kube-system

# Verify metrics
kubectl top nodes
kubectl top pods
```

### Issue: Kafka Connection Timeout
**Error:** `Failed to connect to Kafka broker`

**Solution:**
```bash
# Check MSK cluster status
aws kafka describe-cluster --cluster-arn $(terraform output -raw msk_cluster_arn)

# Verify bootstrap servers in ConfigMap
kubectl get configmap app-config -o yaml
```

### Issue: Flink Job Failed
**Error:** Job submission failed

**Solution:**
```bash
# Check Dataproc cluster
gcloud dataproc clusters describe analytics-cluster --region=us-central1

# View job logs
gcloud dataproc jobs describe YOUR_JOB_ID --region=us-central1

# Resubmit with proper dependencies
```

---

## Cleanup

### Delete Kubernetes Resources
```bash
kubectl delete -f kubernetes/base/
kubectl delete namespace argocd
kubectl delete namespace monitoring
```

### Destroy GCP Infrastructure
```bash
cd terraform/gcp
terraform destroy -auto-approve
```

### Destroy AWS Infrastructure
```bash
cd ../aws
terraform destroy -auto-approve
```

---

## Access URLs Summary

Save these after deployment:

```bash
# Application
export FRONTEND_URL="http://$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
export API_URL="http://$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')/api"

# Monitoring
export GRAFANA_URL="http://$(kubectl get svc -n monitoring prometheus-grafana -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"
export ARGOCD_URL="http://$(kubectl get svc -n argocd argocd-server -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')"

# Print all
echo "Frontend: $FRONTEND_URL"
echo "API Gateway: $API_URL"
echo "Grafana: $GRAFANA_URL (admin/admin123)"
echo "ArgoCD: $ARGOCD_URL (admin/$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d))"
```

---

## Demo Script for Recording

```bash
# 1. Show infrastructure
kubectl get nodes
kubectl get pods --all-namespaces

# 2. Open frontend
open $FRONTEND_URL

# 3. Demonstrate features
# - Create users
# - Create orders (triggers Kafka)
# - Show real-time processing section
# - Click Kafka button (shows pipeline)
# - Click Flink analytics button

# 4. Show monitoring
open $GRAFANA_URL
# Navigate to imported dashboard

# 5. Show GitOps
open $ARGOCD_URL
# Show synced applications

# 6. Run load test
k6 run load-test.js

# 7. Watch HPA scale
watch kubectl get hpa
```
