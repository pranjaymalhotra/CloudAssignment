#!/bin/bash
set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     E-Commerce Microservices - Full Deployment Script     ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

# Function to print status
print_status() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check prerequisites
print_status "Checking prerequisites..."

if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it first."
    exit 1
fi

if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed. Please install it first."
    exit 1
fi

if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed. Please install it first."
    exit 1
fi

if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please install it first."
    exit 1
fi

print_status "All prerequisites met ✓"
echo ""

# Step 1: Deploy AWS Infrastructure
print_status "STEP 1/8: Deploying AWS Infrastructure with Terraform..."
cd terraform/aws

if [ ! -d ".terraform" ]; then
    print_status "Initializing Terraform..."
    terraform init
fi

print_status "Planning infrastructure..."
terraform plan -out=tfplan

print_status "Applying infrastructure..."
terraform apply -auto-approve tfplan

print_status "Getting AWS outputs..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
AWS_REGION="us-east-1"
DB_ENDPOINT=$(terraform output -raw rds_endpoint)
DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name)
MSK_BOOTSTRAP=$(terraform output -raw msk_bootstrap_servers)
S3_BUCKET=$(terraform output -raw s3_bucket_name)

print_status "AWS Infrastructure deployed ✓"
echo "  - Account: $AWS_ACCOUNT_ID"
echo "  - Region: $AWS_REGION"
echo "  - RDS: $DB_ENDPOINT"
echo "  - DynamoDB: $DYNAMODB_TABLE"
echo ""

cd ../..

# Step 2: Configure kubectl for EKS
print_status "STEP 2/8: Configuring kubectl for EKS..."
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

print_status "Waiting for EKS nodes to be ready..."
kubectl wait --for=condition=Ready nodes --all --timeout=600s

print_status "EKS cluster configured ✓"
kubectl get nodes
echo ""

# Step 3: Setup RDS Database
print_status "STEP 3/8: Initializing RDS MySQL Database..."

# Get DB password from Kubernetes secret (will be created in step 4)
DB_PASSWORD="Admin123456!"

print_status "Creating database tables..."
kubectl run mysql-init --image=mysql:8.0 --rm -it --restart=Never -- mysql \
  -h $DB_ENDPOINT \
  -u admin \
  -p"$DB_PASSWORD" \
  -e "CREATE DATABASE IF NOT EXISTS ecommercedb; USE ecommercedb; \
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
        quantity INT NOT NULL, \
        status VARCHAR(50) DEFAULT 'pending', \
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP, \
        total_price DECIMAL(10,2) DEFAULT 0.00 \
      );" 2>/dev/null || print_warning "Database tables may already exist"

print_status "RDS Database initialized ✓"
echo ""

# Step 4: Update Kubernetes ConfigMap with actual values
print_status "STEP 4/8: Updating Kubernetes ConfigMap..."

cat > kubernetes/base/configmap.yaml <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: default
data:
  # AWS Configuration
  AWS_REGION: "${AWS_REGION}"
  AWS_ACCOUNT_ID: "${AWS_ACCOUNT_ID}"
  
  # Database Configuration
  DB_HOST: "${DB_ENDPOINT}"
  DB_NAME: "ecommercedb"
  DB_USER: "admin"
  DB_PORT: "3306"
  
  # DynamoDB Configuration
  DYNAMODB_TABLE: "${DYNAMODB_TABLE}"
  DYNAMODB_REGION: "${AWS_REGION}"
  
  # Kafka Configuration
  KAFKA_BOOTSTRAP_SERVERS: "${MSK_BOOTSTRAP}"
  KAFKA_TOPIC: "notifications"
  
  # S3 Configuration
  S3_BUCKET: "${S3_BUCKET}"
  
  # Service URLs (will be updated after deployment)
  USER_SERVICE_URL: "http://user-service:5000"
  PRODUCT_SERVICE_URL: "http://product-service:5000"
  ORDER_SERVICE_URL: "http://order-service:5000"
  NOTIFICATION_SERVICE_URL: "http://notification-service:5000"
EOF

kubectl apply -f kubernetes/base/configmap.yaml
print_status "ConfigMap updated ✓"
echo ""

# Step 5: Build and Push Docker Images
print_status "STEP 5/8: Building and pushing Docker images to ECR..."

# Login to ECR
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Build and push each microservice
SERVICES=("api-gateway" "user-service" "product-service" "order-service" "notification-service")

for SERVICE in "${SERVICES[@]}"; do
    print_status "Building $SERVICE..."
    
    cd microservices/$SERVICE
    
    # Build for AMD64 architecture (EKS nodes)
    docker buildx build --platform linux/amd64 \
        -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest \
        --push .
    
    cd ../..
    
    print_status "$SERVICE built and pushed ✓"
done

# Build and push frontend
print_status "Building frontend..."
cd frontend
docker buildx build --platform linux/amd64 \
    -t $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest \
    --push .
cd ..

print_status "All Docker images pushed ✓"
echo ""

# Step 6: Update Kubernetes Deployments with ECR URIs
print_status "STEP 6/8: Updating Kubernetes deployments with ECR image URIs..."

for SERVICE in "${SERVICES[@]}"; do
    IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-$SERVICE:latest"
    
    # Update the image in deployment file
    sed -i.bak "s|image:.*ecommerce-$SERVICE.*|image: $IMAGE_URI|g" kubernetes/base/$SERVICE.yaml
    rm kubernetes/base/$SERVICE.yaml.bak 2>/dev/null || true
done

# Update frontend deployment
IMAGE_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/ecommerce-frontend:latest"
sed -i.bak "s|image:.*ecommerce-frontend.*|image: $IMAGE_URI|g" kubernetes/base/frontend.yaml
rm kubernetes/base/frontend.yaml.bak 2>/dev/null || true

print_status "Deployment files updated ✓"
echo ""

# Step 7: Deploy to Kubernetes
print_status "STEP 7/8: Deploying all services to Kubernetes..."

# Create secrets
kubectl create secret generic app-secrets \
    --from-literal=DB_PASSWORD="$DB_PASSWORD" \
    --dry-run=client -o yaml | kubectl apply -f -

# Deploy all services
kubectl apply -f kubernetes/base/configmap.yaml
kubectl apply -f kubernetes/base/user-service.yaml
kubectl apply -f kubernetes/base/product-service.yaml
kubectl apply -f kubernetes/base/order-service.yaml
kubectl apply -f kubernetes/base/notification-service.yaml
kubectl apply -f kubernetes/base/api-gateway.yaml
kubectl apply -f kubernetes/base/frontend.yaml

print_status "Waiting for deployments to be ready..."
kubectl wait --for=condition=available --timeout=600s deployment --all

print_status "All services deployed ✓"
echo ""

# Step 8: Configure DynamoDB IAM Permissions
print_status "STEP 8/8: Configuring DynamoDB IAM permissions..."

NODE_ROLE_NAME="ecommerce-cluster-node-role"

# Add DynamoDB policy to node role
aws iam put-role-policy \
    --role-name $NODE_ROLE_NAME \
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
            "Resource": "arn:aws:dynamodb:'$AWS_REGION':'$AWS_ACCOUNT_ID':table/'$DYNAMODB_TABLE'"
        }]
    }' 2>/dev/null || print_warning "IAM policy may already exist"

# Remove invalid ServiceAccount annotation if exists
kubectl annotate serviceaccount product-service-sa eks.amazonaws.com/role-arn- 2>/dev/null || true

# Restart product service to pick up IAM changes
kubectl rollout restart deployment/product-service

print_status "IAM permissions configured ✓"
echo ""

# Wait for LoadBalancers to be ready
print_status "Waiting for LoadBalancers to be provisioned..."
sleep 60

# Get LoadBalancer URLs
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Wait for DNS propagation
print_status "Waiting for DNS propagation (2 minutes)..."
sleep 120

echo ""
echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            DEPLOYMENT COMPLETED SUCCESSFULLY!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Public Endpoints:${NC}"
echo -e "  🌐 Frontend: ${GREEN}http://$FRONTEND_URL${NC}"
echo -e "  🔧 API:      ${GREEN}http://$API_URL${NC}"
echo ""
echo -e "${BLUE}Database Information:${NC}"
echo -e "  📊 RDS MySQL:  $DB_ENDPOINT"
echo -e "  📦 DynamoDB:   $DYNAMODB_TABLE"
echo -e "  📨 Kafka MSK:  $MSK_BOOTSTRAP"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo -e "  1. Open frontend: ${GREEN}open http://$FRONTEND_URL${NC}"
echo -e "  2. Run tests:     ${GREEN}./test-api.sh${NC}"
echo -e "  3. View pods:     ${GREEN}kubectl get pods${NC}"
echo ""
echo -e "${YELLOW}⚠️  Remember to destroy resources when done to avoid costs:${NC}"
echo -e "     ${RED}./teardown.sh${NC}"
echo ""
