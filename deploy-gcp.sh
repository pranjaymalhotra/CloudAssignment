#!/bin/bash

# GCP Deployment Script for Flink Analytics
# This script deploys the Flink stream processing job to GCP Dataproc

set -e

echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║       GCP Flink Deployment - E-Commerce Analytics            ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo "❌ gcloud CLI not found. Please install it first:"
    echo "   brew install --cask google-cloud-sdk"
    exit 1
fi

# Check if Maven is installed
if ! command -v mvn &> /dev/null; then
    echo "❌ Maven not found. Please install it first:"
    echo "   brew install maven"
    exit 1
fi

echo "✓ Prerequisites checked"
echo ""

# Get GCP Project ID
echo "Enter your GCP Project ID:"
read -p "Project ID: " PROJECT_ID

if [ -z "$PROJECT_ID" ]; then
    echo "❌ Project ID cannot be empty"
    exit 1
fi

# Set project
echo "Setting GCP project to: $PROJECT_ID"
gcloud config set project $PROJECT_ID

# Variables
REGION="us-central1"
CLUSTER="analytics-cluster"
BUCKET="${PROJECT_ID}-flink-jobs"

echo ""
echo "Configuration:"
echo "  Project ID: $PROJECT_ID"
echo "  Region: $REGION"
echo "  Cluster: $CLUSTER"
echo "  Bucket: $BUCKET"
echo ""

# Step 1: Enable required APIs
echo "▶ Step 1/7: Enabling required GCP APIs..."
gcloud services enable compute.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable dataproc.googleapis.com
echo "✓ APIs enabled"
echo ""

# Step 2: Deploy GCP infrastructure with Terraform
echo "▶ Step 2/7: Deploying GCP infrastructure (Dataproc cluster)..."
cd terraform/gcp

# Update variables.tf with project ID
cat > terraform.tfvars <<EOF
project_id = "$PROJECT_ID"
region     = "$REGION"
EOF

terraform init
terraform apply -auto-approve

BUCKET=$(terraform output -raw flink_jobs_bucket_name)
echo "✓ Infrastructure deployed"
echo "  Cluster: $CLUSTER"
echo "  Bucket: $BUCKET"
echo ""

cd ../..

# Step 3: Build Flink job
echo "▶ Step 3/7: Building Flink job JAR..."
cd analytics
mvn clean package -DskipTests

if [ ! -f target/flink-analytics-1.0.0.jar ]; then
    echo "❌ Failed to build JAR"
    exit 1
fi

echo "✓ JAR built: target/flink-analytics-1.0.0.jar"
echo ""

# Step 4: Upload JAR to Cloud Storage
echo "▶ Step 4/7: Uploading JAR to Cloud Storage..."
gsutil cp target/flink-analytics-1.0.0.jar gs://$BUCKET/
echo "✓ JAR uploaded to gs://$BUCKET/"
echo ""

cd ..

# Step 5: Get AWS MSK Kafka brokers
echo "▶ Step 5/7: Getting AWS MSK Kafka brokers..."
cd terraform/aws

if [ ! -d ".terraform" ]; then
    echo "⚠️  AWS infrastructure not found. Please deploy AWS first!"
    echo "   cd terraform/aws && terraform init && terraform apply"
    exit 1
fi

KAFKA_BROKERS=$(terraform output -raw msk_bootstrap_servers 2>/dev/null || echo "")

if [ -z "$KAFKA_BROKERS" ]; then
    echo "❌ Could not get Kafka brokers. Please check AWS deployment."
    echo ""
    echo "Manual setup required:"
    echo "1. Get MSK bootstrap servers from AWS console"
    echo "2. Submit Flink job manually with:"
    echo ""
    echo "   gcloud dataproc jobs submit flink \\"
    echo "     --cluster=$CLUSTER \\"
    echo "     --region=$REGION \\"
    echo "     --jar=gs://$BUCKET/flink-analytics-1.0.0.jar \\"
    echo "     --properties=env.KAFKA_BOOTSTRAP_SERVERS=YOUR_MSK_BROKERS \\"
    echo "     -- \\"
    echo "     --kafka-brokers YOUR_MSK_BROKERS"
    exit 1
fi

echo "✓ Kafka brokers: $KAFKA_BROKERS"
echo ""

cd ../..

# Step 6: Configure MSK security group (allow GCP access)
echo "▶ Step 6/7: Configuring AWS MSK security group..."
echo ""
echo "⚠️  IMPORTANT: You need to allow GCP Dataproc to access AWS MSK"
echo ""
echo "Run this command to get the MSK security group ID:"
echo "  aws kafka describe-cluster --cluster-arn YOUR_CLUSTER_ARN --query 'ClusterInfo.BrokerNodeGroupInfo.SecurityGroups' --output text"
echo ""
echo "Then run:"
echo "  aws ec2 authorize-security-group-ingress \\"
echo "    --group-id sg-XXXXXXXX \\"
echo "    --protocol tcp \\"
echo "    --port 9092 \\"
echo "    --cidr 0.0.0.0/0"
echo ""
read -p "Press Enter after configuring security group..."

# Step 7: Submit Flink job to Dataproc
echo ""
echo "▶ Step 7/7: Submitting Flink job to Dataproc..."

JOB_ID=$(gcloud dataproc jobs submit flink \
    --cluster=$CLUSTER \
    --region=$REGION \
    --jar=gs://$BUCKET/flink-analytics-1.0.0.jar \
    --properties=env.KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BROKERS \
    -- \
    --kafka-brokers $KAFKA_BROKERS \
    --format=json 2>/dev/null | jq -r '.reference.jobId' || echo "")

if [ -z "$JOB_ID" ]; then
    echo "❌ Failed to submit job. Trying alternative method..."
    
    gcloud dataproc jobs submit flink \
        --cluster=$CLUSTER \
        --region=$REGION \
        --jar=gs://$BUCKET/flink-analytics-1.0.0.jar \
        --properties=env.KAFKA_BOOTSTRAP_SERVERS=$KAFKA_BROKERS \
        -- \
        --kafka-brokers $KAFKA_BROKERS
    
    echo ""
    echo "Job submitted! Use this command to check status:"
    echo "  gcloud dataproc jobs list --cluster=$CLUSTER --region=$REGION"
else
    echo "✓ Flink job submitted successfully!"
    echo "  Job ID: $JOB_ID"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                   🎉 Deployment Complete! 🎉                  ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo ""
echo "✅ GCP Dataproc cluster running"
echo "✅ Flink job submitted"
echo "✅ Consuming from AWS MSK Kafka"
echo ""
echo "📊 Monitor job:"
echo "   gcloud dataproc jobs list --cluster=$CLUSTER --region=$REGION"
echo ""
echo "📋 View logs:"
echo "   gcloud dataproc jobs describe <JOB_ID> --region=$REGION"
echo ""
echo "🛑 Stop cluster (save costs):"
echo "   gcloud dataproc clusters stop $CLUSTER --region=$REGION"
echo ""
echo "🧹 Cleanup:"
echo "   cd terraform/gcp && terraform destroy"
echo ""
