# Quick Start Guide

## Prerequisites Checklist

- [ ] AWS CLI configured with credentials
- [ ] Terraform >= 1.5 installed
- [ ] kubectl >= 1.27 installed
- [ ] Docker installed
- [ ] k6 installed
- [ ] GCP account created (free tier)
- [ ] gcloud CLI installed

## 30-Minute Quick Deploy

### Step 1: Setup GCP (5 min)
```bash
# Login to GCP
gcloud auth login

# Create project
gcloud projects create ecommerce-analytics-2025

# Set project
gcloud config set project ecommerce-analytics-2025

# Enable APIs
gcloud services enable compute.googleapis.com dataproc.googleapis.com

# Create service account key
gcloud iam service-accounts keys create ~/gcp-key.json \
  --iam-account=terraform-sa@ecommerce-analytics-2025.iam.gserviceaccount.com

export GOOGLE_APPLICATION_CREDENTIALS=~/gcp-key.json
```

### Step 2: Deploy AWS Infrastructure (20 min)
```bash
cd Cloud_A15/terraform/aws

# Initialize
terraform init

# Deploy
terraform apply -auto-approve

# Configure kubectl
aws eks update-kubeconfig --name ecommerce-cluster --region us-east-1
```

### Step 3: Deploy GCP Infrastructure (5 min)
```bash
cd ../gcp

echo 'project_id = "ecommerce-analytics-2025"' > terraform.tfvars

terraform init
terraform apply -auto-approve
```

### Step 4: Build and Deploy Applications (10 min)
```bash
cd ../..

# Make scripts executable
chmod +x scripts/*.sh

# Build and push images
./scripts/build-and-push.sh

# Deploy applications
./scripts/deploy-all.sh
```

### Step 5: Setup ArgoCD (5 min)
```bash
./scripts/setup-argocd.sh
```

### Step 6: Setup Monitoring (5 min)
```bash
./scripts/setup-monitoring.sh
```

### Step 7: Test the Application (5 min)
```bash
# Get API URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create a user
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Test User", "email": "test@example.com"}'

# Run load tests
./scripts/run-tests.sh
```

---

## What You Get

✅ 6 microservices running on EKS
✅ Multi-cloud deployment (AWS + GCP)
✅ GitOps with ArgoCD
✅ Real-time analytics with Flink
✅ Monitoring with Prometheus + Grafana
✅ Auto-scaling with HPA
✅ Event streaming with Kafka
✅ Serverless function (Lambda)

---

## Next Steps for Assignment

1. **Push code to GitHub**
```bash
cd Cloud_A15
git init
git add .
git commit -m "Initial commit"
git remote add origin <your-repo-url>
git push -u origin main
```

2. **Update ArgoCD with your Git repo**
```bash
# Edit these files with your repo URL:
# - kubernetes/argocd/applications/microservices-app.yaml
```

3. **Record individual video** (12 min max)
   - Show project structure
   - Explain Terraform code
   - Walk through microservice code
   - Demo Kubernetes manifests
   - Show ArgoCD setup
   - Your design decisions

4. **Record demo video** (30 min max)
   - Infrastructure walkthrough
   - Application deployment
   - API testing
   - Monitoring dashboards
   - Load testing with HPA scaling
   - Analytics job running

5. **Create video links**
```bash
echo "YOUR_VIDEO_URL" > YOUR_ID_video.txt
echo "DEMO_VIDEO_URL" > demo_video.txt
```

---

## Cleanup (IMPORTANT!)

**After assignment is graded:**

```bash
# Delete Kubernetes resources
kubectl delete all --all

# Destroy GCP infrastructure
cd terraform/gcp
terraform destroy -auto-approve

# Destroy AWS infrastructure  
cd ../aws
terraform destroy -auto-approve
```

This will stop all charges!

---

## Estimated Costs

- **Development/Testing**: $5-10 total
- **After cleanup**: $0

Main costs:
- MSK Kafka: ~$2/day
- RDS: Free tier
- EKS: Free first 30 days
- GCP Dataproc: ~$1/day

**TIP**: Deploy, test, record videos, then destroy within 2-3 days to minimize costs!
