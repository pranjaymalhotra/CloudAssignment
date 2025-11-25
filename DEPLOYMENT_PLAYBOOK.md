# Complete End-to-End Deployment Playbook

**Last Updated**: 23 November 2025  
**Project**: Cloud-Native E-Commerce Platform (Multi-Cloud AWS + GCP)

---

## Table of Contents
1. [Prerequisites](#prerequisites)
2. [AWS Setup](#aws-setup)
3. [GCP Setup](#gcp-setup)
4. [Infrastructure Deployment](#infrastructure-deployment)
5. [Application Deployment](#application-deployment)
6. [Verification](#verification)
7. [Teardown](#teardown)
8. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Tools
```bash
# Verify all tools are installed
aws --version          # AWS CLI 2.x
gcloud --version       # Google Cloud SDK 548.0.0+
terraform --version    # Terraform 1.5.0+
kubectl version        # kubectl 1.28+
docker --version       # Docker 20.x+
```

### Environment Variables
```bash
# AWS Configuration
export AWS_REGION=us-east-1
export AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export ECR_REGISTRY=${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

# GCP Configuration
export GCP_PROJECT_ID=adept-lead-479014-r0  # Replace with your project
export GCP_REGION=us-central1
export GCP_ZONE=us-central1-a

# Database Credentials (CHANGE THESE!)
export TF_VAR_db_username=admin
export TF_VAR_db_password=YourSecurePassword123!  # CHANGE THIS!
```

---

## AWS Setup

### Step 1: Configure AWS Credentials
```bash
# Login to AWS
aws configure
# Enter:
# - AWS Access Key ID
# - AWS Secret Access Key
# - Default region: us-east-1
# - Default output format: json

# Verify authentication
aws sts get-caller-identity
```

### Step 2: Create ECR Repositories
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Create repositories for all microservices
aws ecr create-repository --repository-name ecommerce-api-gateway --region us-east-1
aws ecr create-repository --repository-name ecommerce-user-service --region us-east-1
aws ecr create-repository --repository-name ecommerce-product-service --region us-east-1
aws ecr create-repository --repository-name ecommerce-order-service --region us-east-1
aws ecr create-repository --repository-name ecommerce-notification-service --region us-east-1
aws ecr create-repository --repository-name ecommerce-analytics-service --region us-east-1
```

---

## GCP Setup

### Step 1: Configure GCP Authentication
```bash
# Login to GCP
gcloud auth login

# Set project
gcloud config set project ${GCP_PROJECT_ID}

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable dataproc.googleapis.com
gcloud services enable storage.googleapis.com
gcloud services enable container.googleapis.com

# Verify authentication
gcloud auth list
gcloud config list
```

### Step 2: Create GCS Buckets (if needed)
```bash
# Create bucket for Flink checkpoints
gsutil mb -p ${GCP_PROJECT_ID} -l ${GCP_REGION} gs://ecommerce-flink-checkpoints/

# Create bucket for analytics results
gsutil mb -p ${GCP_PROJECT_ID} -l ${GCP_REGION} gs://ecommerce-analytics-data/
```

---

## Infrastructure Deployment

### Step 1: Deploy AWS Infrastructure
```bash
cd terraform/aws

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure (takes 15-20 minutes)
terraform apply -auto-approve

# Save important outputs
export KAFKA_BOOTSTRAP_SERVERS=$(terraform output -raw kafka_bootstrap_servers)
export RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
export EKS_CLUSTER_NAME=$(terraform output -raw eks_cluster_name)

# Configure kubectl for EKS
aws eks update-kubeconfig --region us-east-1 --name ${EKS_CLUSTER_NAME}

# Verify cluster access
kubectl get nodes
kubectl get namespaces
```

### Step 2: Deploy GCP Infrastructure (Optional - if using Dataproc)
```bash
cd ../gcp

# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Apply infrastructure (takes 10-15 minutes)
terraform apply -auto-approve

# Save outputs
export DATAPROC_CLUSTER_NAME=$(terraform output -raw dataproc_cluster_name)
```

### Step 3: Create Kubernetes Secrets
```bash
cd ../../

# Create namespace (if not exists)
kubectl create namespace default --dry-run=client -o yaml | kubectl apply -f -

# Create database secrets
kubectl create secret generic app-secrets \
  --from-literal=DB_HOST=${RDS_ENDPOINT} \
  --from-literal=DB_NAME=ecommercedb \
  --from-literal=DB_USER=${TF_VAR_db_username} \
  --from-literal=DB_PASSWORD=${TF_VAR_db_password} \
  --from-literal=KAFKA_BOOTSTRAP_SERVERS=${KAFKA_BOOTSTRAP_SERVERS} \
  --namespace=default \
  --dry-run=client -o yaml | kubectl apply -f -

# Verify secret creation
kubectl get secrets -n default
```

### Step 4: Create ConfigMap
```bash
# Create ConfigMap with service URLs
kubectl apply -f - <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  AWS_REGION: "us-east-1"
  USER_SERVICE_URL: "http://user-service:5001"
  PRODUCT_SERVICE_URL: "http://product-service:5002"
  ORDER_SERVICE_URL: "http://order-service:5003"
  ANALYTICS_SERVICE_URL: "http://analytics-service:5000"
  S3_BUCKET_NAME: "ecommerce-data-bucket-${AWS_ACCOUNT_ID}"
  KAFKA_BOOTSTRAP_SERVERS: "${KAFKA_BOOTSTRAP_SERVERS}"
  KAFKA_SECURITY_PROTOCOL: "SSL"
  KAFKA_SSL_CAFILE: "/etc/ssl/certs/ca-certificates.crt"
  KAFKA_API_VERSION: "2.8.1"
EOF

# Verify ConfigMap
kubectl get configmap app-config -n default -o yaml
```

---

## Application Deployment

### Step 1: Build and Push Docker Images
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin ${ECR_REGISTRY}

# Build and push all microservices
services=("api-gateway" "user-service" "product-service" "order-service" "notification-service" "analytics-service")

for service in "${services[@]}"; do
  echo "Building ${service}..."
  cd microservices/${service}
  
  docker build -t ecommerce-${service}:latest .
  docker tag ecommerce-${service}:latest ${ECR_REGISTRY}/ecommerce-${service}:latest
  docker push ${ECR_REGISTRY}/ecommerce-${service}:latest
  
  cd ../..
done

echo "All images pushed successfully!"
```

### Step 2: Deploy Microservices to Kubernetes
```bash
# Apply all Kubernetes manifests
kubectl apply -f kubernetes/base/

# Wait for deployments to be ready
kubectl wait --for=condition=available --timeout=300s deployment --all -n default

# Check deployment status
kubectl get deployments -n default
kubectl get pods -n default
kubectl get services -n default
kubectl get hpa -n default
```

### Step 3: Initialize Databases
```bash
# Get RDS endpoint
RDS_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)

# Connect to RDS and create tables (using port-forward through a pod or bastion)
# Option 1: Use user-service pod
USER_POD=$(kubectl get pod -l app=user-service -n default -o jsonpath="{.items[0].metadata.name}")

kubectl exec -it ${USER_POD} -n default -- python3 -c "
from app import db
db.create_all()
print('User database initialized!')
"

# Option 2: Direct connection (if RDS is publicly accessible - NOT RECOMMENDED)
# psql -h ${RDS_ENDPOINT} -U admin -d ecommercedb -c "CREATE TABLE IF NOT EXISTS users (...)"
```

### Step 4: Initialize DynamoDB Tables
```bash
# Tables are created by Terraform, verify they exist
aws dynamodb list-tables --region us-east-1

# Optionally, load sample product data
aws dynamodb put-item \
  --table-name ecommerce-products \
  --item '{"product_id": {"S": "1"}, "name": {"S": "Laptop"}, "price": {"N": "999.99"}, "category": {"S": "Electronics"}, "stock_quantity": {"N": "50"}}' \
  --region us-east-1
```

### Step 5: Deploy Flink Analytics Job (Optional - GCP)
```bash
# Package Flink job
cd analytics
mvn clean package

# Submit to Dataproc
gcloud dataproc jobs submit flink \
  --cluster=${DATAPROC_CLUSTER_NAME} \
  --region=${GCP_REGION} \
  --jar=target/flink-analytics-1.0.0.jar \
  --properties=kafka.bootstrap.servers=${KAFKA_BOOTSTRAP_SERVERS}
```

---

## Verification

### Step 1: Check Infrastructure
```bash
# AWS Resources
echo "=== EKS Cluster ==="
kubectl get nodes

echo "=== RDS Database ==="
aws rds describe-db-instances --region us-east-1 --query 'DBInstances[].DBInstanceIdentifier'

echo "=== MSK Kafka ==="
aws kafka list-clusters --region us-east-1 --query 'ClusterInfoList[].ClusterName'

echo "=== DynamoDB Tables ==="
aws dynamodb list-tables --region us-east-1

# GCP Resources (if deployed)
echo "=== GCP Dataproc ==="
gcloud dataproc clusters list --region=${GCP_REGION}
```

### Step 2: Check Application Health
```bash
# Get LoadBalancer URL
GATEWAY_URL=$(kubectl get svc api-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "API Gateway URL: http://${GATEWAY_URL}"

# Test health endpoints
curl http://${GATEWAY_URL}/health
curl http://${GATEWAY_URL}/api/products
curl http://${GATEWAY_URL}/api/users

# Check all pod health
kubectl get pods -n default
kubectl top pods -n default  # Resource usage
```

### Step 3: Check HPA Status
```bash
# View HPA metrics
kubectl get hpa -n default
kubectl describe hpa api-gateway-hpa -n default
kubectl describe hpa order-service-hpa -n default
```

### Step 4: View Logs
```bash
# View logs for each service
kubectl logs -l app=api-gateway -n default --tail=50
kubectl logs -l app=user-service -n default --tail=50
kubectl logs -l app=order-service -n default --tail=50
kubectl logs -l app=notification-service -n default --tail=50

# Follow logs in real-time
kubectl logs -f deployment/api-gateway -n default
```

### Step 5: Test End-to-End Flow
```bash
GATEWAY_URL=$(kubectl get svc api-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# 1. Create a user
curl -X POST http://${GATEWAY_URL}/api/users/register \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","email":"test@example.com","password":"test123"}'

# 2. Login
TOKEN=$(curl -X POST http://${GATEWAY_URL}/api/users/login \
  -H "Content-Type: application/json" \
  -d '{"username":"testuser","password":"test123"}' | jq -r '.token')

# 3. Get products
curl http://${GATEWAY_URL}/api/products

# 4. Create an order
curl -X POST http://${GATEWAY_URL}/api/orders \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{"user_id":1,"items":[{"product_id":"1","quantity":2}],"total_amount":1999.98}'

# 5. Check Kafka messages (from a pod)
kubectl exec -it $(kubectl get pod -l app=order-service -n default -o jsonpath="{.items[0].metadata.name}") -n default -- \
  python3 -c "from kafka import KafkaConsumer; consumer = KafkaConsumer('orders', bootstrap_servers='${KAFKA_BOOTSTRAP_SERVERS}'); print(next(consumer))"
```

---

## Teardown

### Complete Infrastructure Destruction

```bash
#!/bin/bash
# destroy-everything.sh - Complete teardown script

set -e

echo "╔════════════════════════════════════════════════════════════╗"
echo "║     COMPLETE INFRASTRUCTURE TEARDOWN                       ║"
echo "╚════════════════════════════════════════════════════════════╝"

# Step 1: Delete Kubernetes Resources
echo ""
echo "▶ Step 1: Deleting Kubernetes resources..."
kubectl delete -f kubernetes/base/ --ignore-not-found=true
kubectl delete secrets app-secrets -n default --ignore-not-found=true
kubectl delete configmap app-config -n default --ignore-not-found=true

# Wait for LoadBalancer cleanup
echo "⏳ Waiting 60 seconds for LoadBalancer cleanup..."
sleep 60

# Step 2: Destroy AWS Infrastructure
echo ""
echo "▶ Step 2: Destroying AWS infrastructure..."
cd terraform/aws

# Destroy Terraform resources
terraform destroy -auto-approve

cd ../..

# Step 3: Clean up ECR Images
echo ""
echo "▶ Step 3: Cleaning up ECR repositories..."
services=("api-gateway" "user-service" "product-service" "order-service" "notification-service" "analytics-service")

for service in "${services[@]}"; do
  echo "  Deleting ecommerce-${service}..."
  aws ecr delete-repository \
    --repository-name ecommerce-${service} \
    --region us-east-1 \
    --force 2>/dev/null || echo "  Repository ecommerce-${service} not found, skipping..."
done

# Step 4: Destroy GCP Infrastructure (if exists)
echo ""
echo "▶ Step 4: Destroying GCP infrastructure..."
if [ -d "terraform/gcp" ]; then
  cd terraform/gcp
  terraform destroy -auto-approve || echo "No GCP infrastructure to destroy"
  cd ../..
fi

# Step 5: Delete GCS Buckets
echo ""
echo "▶ Step 5: Cleaning up GCS buckets..."
gsutil -m rm -r gs://ecommerce-flink-checkpoints/ 2>/dev/null || echo "  Bucket not found, skipping..."
gsutil -m rm -r gs://ecommerce-analytics-data/ 2>/dev/null || echo "  Bucket not found, skipping..."

# Step 6: Clean up local Docker images
echo ""
echo "▶ Step 6: Cleaning up local Docker images..."
docker rmi $(docker images | grep ecommerce | awk '{print $3}') 2>/dev/null || echo "  No local images to clean"

echo ""
echo "✅ TEARDOWN COMPLETE!"
echo ""
```

### Manual Verification Commands

```bash
# Verify AWS cleanup
echo "=== Checking AWS Resources ==="
aws eks list-clusters --region us-east-1
aws rds describe-db-instances --region us-east-1 --query 'DBInstances[].DBInstanceIdentifier'
aws kafka list-clusters --region us-east-1
aws dynamodb list-tables --region us-east-1
aws ec2 describe-vpcs --region us-east-1 --filters "Name=tag:Project,Values=ECommerce-Cloud-Assignment"
aws ecr describe-repositories --region us-east-1 --query 'repositories[?starts_with(repositoryName, `ecommerce`)].repositoryName'
aws s3 ls | grep ecommerce

# Verify GCP cleanup
echo "=== Checking GCP Resources ==="
gcloud dataproc clusters list --region=us-central1
gcloud compute instances list
gsutil ls
gcloud container clusters list

# Check for running costs
echo "=== Cost Check ==="
aws ce get-cost-and-usage \
  --time-period Start=$(date -u -d '1 day ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
  --granularity DAILY \
  --metrics UnblendedCost \
  --region us-east-1
```

---

## Troubleshooting

### Common Issues

#### 1. EKS Nodes Not Ready
```bash
# Check node status
kubectl get nodes

# Describe node for issues
kubectl describe node <node-name>

# Check node group in AWS
aws eks describe-nodegroup \
  --cluster-name ${EKS_CLUSTER_NAME} \
  --nodegroup-name <nodegroup-name> \
  --region us-east-1
```

#### 2. Pods in CrashLoopBackOff
```bash
# Check pod logs
kubectl logs <pod-name> -n default --previous

# Describe pod for events
kubectl describe pod <pod-name> -n default

# Check resource limits
kubectl top pod <pod-name> -n default
```

#### 3. Database Connection Issues
```bash
# Test RDS connectivity from a pod
kubectl run test-db --image=postgres:15 --rm -it -- \
  psql -h ${RDS_ENDPOINT} -U admin -d ecommercedb -c "SELECT 1;"

# Check security group rules
aws ec2 describe-security-groups \
  --filters "Name=tag:Name,Values=*rds*" \
  --region us-east-1
```

#### 4. Kafka Connection Issues
```bash
# Get MSK bootstrap servers
aws kafka get-bootstrap-brokers \
  --cluster-arn <cluster-arn> \
  --region us-east-1

# Test Kafka from a pod
kubectl run kafka-test --image=confluentinc/cp-kafka:7.4.0 --rm -it -- \
  kafka-console-consumer \
  --bootstrap-server ${KAFKA_BOOTSTRAP_SERVERS} \
  --topic orders \
  --from-beginning
```

#### 5. LoadBalancer Not Getting External IP
```bash
# Check LoadBalancer service
kubectl get svc api-gateway -n default -o yaml

# Check AWS Load Balancer Controller
kubectl get pods -n kube-system | grep aws-load-balancer-controller

# Check service events
kubectl describe svc api-gateway -n default
```

#### 6. HPA Not Scaling
```bash
# Check metrics-server
kubectl get deployment metrics-server -n kube-system

# Check HPA status
kubectl describe hpa api-gateway-hpa -n default

# Generate load to test scaling
kubectl run load-generator --image=busybox --rm -it -- \
  /bin/sh -c "while true; do wget -q -O- http://api-gateway/health; done"
```

---

## Cost Optimization

### Estimated Monthly Costs
```
EKS Control Plane:    $73
EC2 Instances:        $120 (4x t3.medium)
RDS:                  $15 (db.t3.micro)
MSK:                  $300 (kafka.t3.small x3)
DynamoDB:             $25 (on-demand)
Data Transfer:        $20
NAT Gateway:          $90
Load Balancer:        $20
------------------------------------
Total:                ~$663/month
```

### Cost Saving Tips
1. **Use Spot Instances** for EKS worker nodes (70% savings)
2. **Stop dev environments** outside working hours
3. **Use Reserved Instances** for predictable workloads (40% savings)
4. **Enable S3 lifecycle policies** for old data
5. **Use Auto Scaling** to match actual demand
6. **Delete unused resources** immediately after testing

---

## Important URLs & Endpoints

### AWS Console Links
- EKS: https://console.aws.amazon.com/eks/home?region=us-east-1
- RDS: https://console.aws.amazon.com/rds/home?region=us-east-1
- MSK: https://console.aws.amazon.com/msk/home?region=us-east-1
- DynamoDB: https://console.aws.amazon.com/dynamodb/home?region=us-east-1
- ECR: https://console.aws.amazon.com/ecr/repositories?region=us-east-1

### GCP Console Links
- Dataproc: https://console.cloud.google.com/dataproc/clusters
- GCS: https://console.cloud.google.com/storage/browser

### API Endpoints (After Deployment)
```bash
# Get LoadBalancer URL
GATEWAY_URL=$(kubectl get svc api-gateway -n default -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo "Health Check:  http://${GATEWAY_URL}/health"
echo "Users API:     http://${GATEWAY_URL}/api/users"
echo "Products API:  http://${GATEWAY_URL}/api/products"
echo "Orders API:    http://${GATEWAY_URL}/api/orders"
echo "Analytics API: http://${GATEWAY_URL}/api/analytics"
```

---

## Quick Reference Commands

### Cluster Access
```bash
# Update kubeconfig
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Switch context
kubectl config use-context arn:aws:eks:us-east-1:*:cluster/ecommerce-cluster
```

### Monitoring
```bash
# Watch pods
watch kubectl get pods -n default

# Stream logs
kubectl logs -f deployment/api-gateway -n default

# Port forward for local testing
kubectl port-forward svc/api-gateway 8080:80 -n default
```

### Scaling
```bash
# Manual scale
kubectl scale deployment api-gateway --replicas=5 -n default

# Update HPA
kubectl patch hpa api-gateway-hpa -n default --patch '{"spec":{"maxReplicas":15}}'
```

---

## Emergency Contacts & Support

- **AWS Support**: https://console.aws.amazon.com/support/
- **GCP Support**: https://cloud.google.com/support
- **Kubernetes Docs**: https://kubernetes.io/docs/
- **Terraform Registry**: https://registry.terraform.io/

---

## Change Log

| Date | Change | Author |
|------|--------|--------|
| 2025-11-23 | Initial deployment playbook created | System |

---

**End of Deployment Playbook**
