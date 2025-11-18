# Complete Setup Guide - E-Commerce Cloud Application

## 📋 Table of Contents
1. [Prerequisites](#prerequisites)
2. [GCP Account Setup](#gcp-account-setup)
3. [AWS Infrastructure Deployment](#aws-infrastructure-deployment)
4. [GCP Infrastructure Deployment](#gcp-infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Monitoring Setup](#monitoring-setup)
7. [Load Testing](#load-testing)
8. [Video Recording](#video-recording)
9. [Cleanup](#cleanup)

---

## Prerequisites

### Install Required Tools

```bash
# 1. Install Terraform
brew install terraform

# 2. Install kubectl
brew install kubectl

# 3. Install AWS CLI (already configured with your credentials)
aws --version

# 4. Install gcloud CLI
brew install --cask google-cloud-sdk

# 5. Install k6 (load testing)
brew install k6

# 6. Install ArgoCD CLI
brew install argocd

# 7. Install Docker (if not already)
brew install --cask docker
```

### Verify AWS Configuration

```bash
aws sts get-caller-identity
# Should show your AWS account details
```

---

## GCP Account Setup

### 1. Create Free GCP Account

1. Go to: https://console.cloud.google.com/freetrial
2. Sign up with Google account
3. Get **$300 free credits** (valid 90 days)
4. Enable billing (required but won't charge unless you exceed free tier)

### 2. Create GCP Project

```bash
# Login to GCP
gcloud auth login

# Create project
gcloud projects create ecommerce-analytics-2025 --name="E-Commerce Analytics"

# Set as default
gcloud config set project ecommerce-analytics-2025

# Enable billing (use your billing account ID)
# Get billing account: gcloud billing accounts list
gcloud billing projects link ecommerce-analytics-2025 --billing-account=YOUR_BILLING_ACCOUNT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable dataproc.googleapis.com
gcloud services enable storage.googleapis.com
```

### 3. Create GCP Service Account

```bash
# Create service account
gcloud iam service-accounts create terraform-sa \
    --display-name="Terraform Service Account"

# Grant necessary roles
gcloud projects add-iam-policy-binding ecommerce-analytics-2025 \
    --member="serviceAccount:terraform-sa@ecommerce-analytics-2025.iam.gserviceaccount.com" \
    --role="roles/editor"

# Create and download key
gcloud iam service-accounts keys create ~/gcp-key.json \
    --iam-account=terraform-sa@ecommerce-analytics-2025.iam.gserviceaccount.com

# Set environment variable
export GOOGLE_APPLICATION_CREDENTIALS=~/gcp-key.json
```

---

## AWS Infrastructure Deployment

### 1. Initialize and Deploy AWS Infrastructure

```bash
cd /Users/pranjaymalhotra/Downloads/Cloud_A15/terraform/aws

# Initialize Terraform
terraform init

# Review plan (optional)
terraform plan

# Deploy (takes ~20-25 minutes)
terraform apply -auto-approve

# Save outputs
terraform output > ../../aws-outputs.txt
```

**What gets created:**
- VPC with public/private subnets
- EKS cluster (1.28)
- RDS MySQL (t3.micro - free tier)
- DynamoDB table
- S3 bucket
- MSK Kafka cluster (kafka.t3.small - minimal cost)
- Lambda function with S3 trigger
- IAM roles and security groups

### 2. Configure kubectl

```bash
# Update kubeconfig
aws eks update-kubeconfig --name ecommerce-cluster --region us-east-1

# Verify connection
kubectl get nodes
# Should show 2-3 nodes ready
```

---

## GCP Infrastructure Deployment

### 1. Deploy GCP Resources

```bash
cd /Users/pranjaymalhotra/Downloads/Cloud_A15/terraform/gcp

# Set project ID in terraform.tfvars
echo 'project_id = "ecommerce-analytics-2025"' > terraform.tfvars

# Initialize and deploy
terraform init
terraform apply -auto-approve

# Save outputs
terraform output > ../../gcp-outputs.txt
```

**What gets created:**
- Cloud Storage bucket
- Dataproc cluster (for Flink job)
- VPC network
- Firewall rules

---

## Application Deployment

### 1. Build and Push Docker Images

```bash
cd /Users/pranjaymalhotra/Downloads/Cloud_A15

# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-1.amazonaws.com

# Build and push all microservices
./scripts/build-and-push.sh
```

### 2. Install ArgoCD

```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for pods to be ready
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Expose ArgoCD server
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# Save this password!

# Get ArgoCD URL
kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 3. Deploy Applications via ArgoCD

```bash
# Login to ArgoCD CLI
ARGOCD_SERVER=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd login $ARGOCD_SERVER --username admin --password $ARGOCD_PASSWORD --insecure

# Create applications
kubectl apply -f kubernetes/argocd/applications/

# Wait for sync
argocd app wait api-gateway user-service product-service order-service notification-service --sync
```

### 4. Deploy Flink Analytics Job

```bash
# Upload Flink job to GCS
gsutil cp analytics/flink-analytics.jar gs://ecommerce-analytics-bucket-2025/jobs/

# Submit job to Dataproc
gcloud dataproc jobs submit flink \
    --cluster=analytics-cluster \
    --region=us-central1 \
    --jar=gs://ecommerce-analytics-bucket-2025/jobs/flink-analytics.jar
```

### 5. Deploy Lambda Function

```bash
cd lambda/s3-processor

# Package function
zip -r function.zip index.py

# Deploy (already created by Terraform, just update code)
aws lambda update-function-code \
    --function-name s3-file-processor \
    --zip-file fileb://function.zip \
    --region us-east-1
```

---

## Monitoring Setup

### 1. Deploy Prometheus

```bash
# Add Prometheus Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus
helm install prometheus prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    -f monitoring/prometheus/values.yaml

# Wait for pods
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s
```

### 2. Deploy Grafana

```bash
# Grafana is included in kube-prometheus-stack
# Get Grafana password
kubectl get secret -n monitoring prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d

# Port forward to access (or expose via LoadBalancer)
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80

# Access at http://localhost:3000
# Username: admin
# Import dashboards from monitoring/grafana/dashboards/
```

### 3. Deploy EFK Stack (Logging)

```bash
# Deploy Elasticsearch
kubectl apply -f monitoring/logging/elasticsearch.yaml

# Deploy Fluentd
kubectl apply -f monitoring/logging/fluentd.yaml

# Deploy Kibana
kubectl apply -f monitoring/logging/kibana.yaml

# Access Kibana
kubectl port-forward -n logging svc/kibana 5601:5601
# Visit http://localhost:5601
```

---

## Load Testing

### 1. Get API Gateway URL

```bash
kubectl get svc api-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

### 2. Update k6 Script

```bash
# Edit load-testing/scripts/load-test.js
# Replace API_URL with your actual API Gateway URL
```

### 3. Run Load Tests

```bash
# Basic load test
k6 run load-testing/scripts/load-test.js

# Stress test (validates HPA)
k6 run load-testing/scripts/stress-test.js

# Watch HPA scale
kubectl get hpa -w
# You should see order-service and api-gateway scale up
```

---

## Video Recording

### Individual Code Walkthrough Video

Record yourself explaining your code contributions:

1. **Open terminal with ID visible**:
   ```bash
   # Add your ID to PS1
   export PS1="[YOUR_ID_HERE] \w $ "
   ```

2. **What to cover** (10-12 minutes):
   - Show project structure
   - Explain Terraform configurations you wrote
   - Walk through microservice code (1-2 services)
   - Explain Kubernetes manifests
   - Show ArgoCD configurations
   - Explain monitoring setup
   - Your design decisions

3. **Tools for recording**:
   - macOS: QuickTime Player (File → New Screen Recording)
   - OBS Studio (free, powerful)
   - Loom (easy, cloud-based)

4. **Save link**:
   ```bash
   echo "YOUR_VIDEO_LINK_HERE" > YOUR_ID_video.txt
   ```

### Demo Video

Record complete system demonstration:

1. **Show infrastructure** (5 min):
   - AWS Console: EKS, RDS, DynamoDB, S3, MSK
   - GCP Console: Dataproc cluster running
   - Terraform state

2. **Show applications** (10 min):
   - ArgoCD dashboard with all apps synced
   - Access API Gateway (public URL)
   - Make API calls (create user, product, order)
   - Show Lambda triggered by S3 upload
   - Show Kafka messages flowing

3. **Show monitoring** (5 min):
   - Grafana dashboards with metrics
   - Kibana with application logs
   - Prometheus alerts

4. **Show load testing** (5 min):
   - Run k6 tests
   - Show HPA scaling pods up
   - Show increased metrics in Grafana

5. **Save link**:
   ```bash
   echo "YOUR_DEMO_VIDEO_LINK_HERE" > demo_video.txt
   ```

---

## Testing the Application

### 1. Create a User

```bash
API_URL=$(kubectl get svc api-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'
```

### 2. Create a Product

```bash
curl -X POST http://$API_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Laptop", "price": 999.99, "stock": 10}'
```

### 3. Create an Order

```bash
curl -X POST http://$API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": 1, "quantity": 2}'
```

### 4. Test Lambda Function

```bash
# Upload a file to S3 (triggers Lambda)
echo "test data" > test.txt
aws s3 cp test.txt s3://ecommerce-data-bucket-2025/uploads/test.txt

# Check Lambda logs
aws logs tail /aws/lambda/s3-file-processor --follow
```

### 5. Verify Analytics

```bash
# Check Flink job on GCP
gcloud dataproc jobs list --cluster=analytics-cluster --region=us-central1

# View analytics results (written back to Kafka or GCS)
```

---

## Cleanup (After Submission)

**IMPORTANT**: Run this after your assignment is graded to avoid costs!

```bash
# 1. Delete Kubernetes resources
kubectl delete -f kubernetes/argocd/applications/
helm uninstall prometheus -n monitoring
kubectl delete namespace argocd monitoring logging

# 2. Destroy GCP infrastructure
cd terraform/gcp
terraform destroy -auto-approve

# 3. Destroy AWS infrastructure
cd ../aws
terraform destroy -auto-approve

# This will delete EVERYTHING and stop all charges
```

---

## Troubleshooting

### EKS Nodes Not Ready
```bash
kubectl get nodes
kubectl describe node <node-name>
# Check IAM roles and security groups in AWS Console
```

### ArgoCD Apps Not Syncing
```bash
argocd app get <app-name>
argocd app sync <app-name> --force
```

### RDS Connection Issues
```bash
# Check security group allows traffic from EKS
# Update connection string in ConfigMap
kubectl edit configmap app-config
```

### Kafka Connection Issues
```bash
# Get MSK bootstrap servers
aws kafka get-bootstrap-brokers --cluster-arn <arn>
# Update in ConfigMap
```

### Flink Job Fails
```bash
# Check Dataproc logs
gcloud dataproc jobs describe <job-id> --cluster=analytics-cluster --region=us-central1
# Check GCS bucket permissions
```

---

## Cost Monitoring

```bash
# Check AWS costs
aws ce get-cost-and-usage \
    --time-period Start=2025-11-18,End=2025-11-19 \
    --granularity DAILY \
    --metrics UnblendedCost

# Check GCP costs
gcloud billing accounts list
# View in GCP Console: Billing → Reports
```

---

## Support

If you encounter issues:
1. Check logs: `kubectl logs <pod-name>`
2. Check events: `kubectl get events --sort-by='.lastTimestamp'`
3. Verify Terraform state: `terraform show`
4. Check AWS CloudWatch logs
5. Check GCP Cloud Logging

---

**Estimated Total Setup Time**: 1-2 hours
**Estimated Cost**: $5-10 for testing
**Remember**: Destroy everything after submission!
