# E-Commerce Cloud Platform - Multi-Cloud Microservices

[![AWS](https://img.shields.io/badge/AWS-EKS%20%7C%20RDS%20%7C%20DynamoDB%20%7C%20MSK-orange)](https://aws.amazon.com)
[![GCP](https://img.shields.io/badge/GCP-Dataproc%20%7C%20Flink-blue)](https://cloud.google.com)
[![Terraform](https://img.shields.io/badge/IaC-Terraform-purple)](https://terraform.io)
[![Kubernetes](https://img.shields.io/badge/K8s-EKS%20%7C%20ArgoCD-326CE5)](https://kubernetes.io)
[![Status](https://img.shields.io/badge/Status-Production%20Ready-success)](https://github.com)

> **Enterprise-grade cloud-native e-commerce platform** with 6 microservices, serverless functions, real-time stream processing, GitOps deployment, and hybrid multi-cloud architecture.

---

## 🎯 Project Overview

A complete cloud-native e-commerce platform demonstrating **modern cloud architecture patterns**:
- **6 microservices** on AWS EKS with auto-scaling
- **Real-time analytics** with Apache Flink on GCP Dataproc
- **Event-driven architecture** using Kafka (AWS MSK)
- **GitOps deployments** via ArgoCD
- **100% Infrastructure as Code** with Terraform
- **Full observability** with Prometheus & Grafana

---

## 🏗️ Architecture

### **Multi-Cloud Setup**

```
┌─────────────────────── AWS (Provider A) ───────────────────────┐
│                                                                  │
│  ┌─────────────┐   ┌──────────────┐   ┌──────────────┐        │
│  │ EKS Cluster │──▶│   Services   │──▶│   Storage    │        │
│  │ (K8s 1.28)  │   │ 6 Microservices│   │ RDS/DynamoDB │        │
│  └─────────────┘   └──────┬───────┘   └──────────────┘        │
│                            │                                     │
│                            ▼                                     │
│                    ┌──────────────┐                            │
│                    │  MSK Kafka   │                            │
│                    │  (Messaging) │                            │
│                    └──────┬───────┘                            │
└───────────────────────────┼────────────────────────────────────┘
                            │
              Cross-Cloud Event Stream
                            │
┌───────────────────────────┼──── GCP (Provider B) ──────────────┐
│                           ▼                                      │
│                   ┌───────────────┐                            │
│                   │   Dataproc    │                            │
│                   │ Apache Flink  │                            │
│                   │ Stream Process│                            │
│                   └───────────────┘                            │
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

### **Microservices Architecture**

1. **API Gateway** (`/api`)
   - Public REST API with CORS
   - Request routing and orchestration
   - **HPA:** 2-10 pods (CPU/Memory)

2. **User Service** (`/api/users`)
   - User management and authentication
   - Storage: RDS MySQL

3. **Product Service** (`/api/products`)
   - Product catalog management
   - Storage: DynamoDB (NoSQL)

4. **Order Service** (`/api/orders`)
   - Order processing and tracking
   - Publishes events to Kafka
   - Storage: RDS MySQL
   - **HPA:** 2-8 pods (CPU/Memory)

5. **Notification Service**
   - Event-driven notifications
   - Consumes Kafka events
   - Sends alerts via SNS/Email

6. **Analytics Service** (`/api/analytics`)
   - Analytics aggregation
   - Real-time metrics
   - Storage: DynamoDB

7. **Lambda Function** (Serverless)
   - S3-triggered file processing
   - Event-driven compute

### **Stream Processing (GCP)**

- **Apache Flink** on Dataproc
- Consumes order events from AWS MSK
- 1-minute tumbling window aggregations
- Publishes results back to Kafka

---

## 📁 Project Structure

```
Cloud_A15/
├── microservices/              # 6 Flask microservices
│   ├── api-gateway/           # Public API (Port 5000)
│   ├── user-service/          # User mgmt (Port 5001)
│   ├── product-service/       # Products (Port 5002)
│   ├── order-service/         # Orders (Port 5003)
│   ├── notification-service/  # Events (Port 5004)
│   └── analytics-service/     # Analytics (Port 5005)
│
├── terraform/                  # Infrastructure as Code
│   ├── aws/                   # AWS resources (EKS, RDS, etc.)
│   │   ├── main.tf           # 48+ resources
│   │   └── modules/          # Reusable modules
│   └── gcp/                   # GCP resources (Dataproc)
│       └── main.tf
│
├── kubernetes/                 # K8s manifests
│   ├── base/                  # Deployments, Services, HPAs
│   └── argocd/                # GitOps applications
│       └── applications/
│
├── analytics/                  # Flink job (Java/Maven)
│   ├── src/main/java/
│   └── pom.xml
│
├── lambda/                     # Serverless functions
│   └── s3-processor.py
│
├── frontend/                   # Web UI
│   ├── index.html             # Original UI
│   └── app.html               # Enhanced UI
│
├── load-testing/              # k6 load tests
│   └── load-test.js
│
├── docs/                       # Documentation
│   ├── DESIGN.md             # Architecture design
│   └── API.md                # API documentation
│
├── DEPLOYMENT_GUIDE.md        # Full deployment steps
├── GCP_SETUP_GUIDE.md         # GCP integration guide
├── REQUIREMENTS_VERIFICATION.md # Assignment checklist
├── VIDEO_DEMO_GUIDE.md        # Demo script
└── README.md                  # This file
```

---

## 🚀 Quick Start

### Prerequisites

```bash
# Required tools
- AWS CLI (configured)
- kubectl
- Terraform >= 1.5
- Docker
- Helm 3
- k6 (for load testing)
- gcloud CLI (for GCP)

# Install on macOS
brew install awscli kubectl terraform docker helm k6 google-cloud-sdk
```

### 1. Deploy AWS Infrastructure

```bash
# Clone repository
git clone https://github.com/pranjaymalhotra/CloudAssignment.git
cd CloudAssignment

# Deploy AWS resources (20-30 minutes)
cd terraform/aws
terraform init
terraform apply -auto-approve

# Save outputs
terraform output > ../../aws-outputs.txt
```

### 2. Deploy Microservices to EKS

```bash
# Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name ecommerce-cluster

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Deploy microservices via ArgoCD
kubectl apply -f kubernetes/argocd/applications/

# Wait for services
kubectl get pods --watch
```

### 3. Deploy GCP Flink Processing

```bash
# Configure GCP
gcloud auth login
gcloud config set project YOUR_PROJECT_ID

# Deploy GCP infrastructure
cd terraform/gcp
terraform init
terraform apply -auto-approve

# Build and deploy Flink job
cd ../../analytics
mvn clean package
gsutil cp target/flink-analytics-1.0.0.jar gs://YOUR_BUCKET/

# Submit Flink job (see GCP_SETUP_GUIDE.md)
gcloud dataproc jobs submit flink --cluster=analytics-cluster ...
```

### 4. Install Observability Stack

```bash
# Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack

# Access Grafana
kubectl port-forward svc/prometheus-grafana 3000:80
# Open http://localhost:3000 (admin/prom-operator)
```

### 5. Run Load Tests

```bash
# Get API Gateway URL
export API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Run k6 load test
cd load-testing
k6 run load-test.js

# Watch HPA scaling
kubectl get hpa --watch
```

---

## 🎨 Frontend

### **Enhanced Web UI**

Open `frontend/app.html` in your browser:

**Features:**
- 🛍️ Product catalog with search
- 🛒 Shopping cart management
- 📦 Order history
- 👤 User profiles
- 📱 Mobile responsive design
- ⚡ Real-time API status

**Original Demo UI:** `frontend/index.html`

---

## 📊 Monitoring & Observability

### Prometheus Metrics
```bash
kubectl port-forward svc/prometheus-kube-prometheus-prometheus 9090:9090
# Open http://localhost:9090
```

### Grafana Dashboards
```bash
kubectl port-forward svc/prometheus-grafana 3000:80
# Open http://localhost:3000
```

**Pre-configured Dashboards:**
- Kubernetes cluster health
- Pod CPU/Memory usage
- Request rate (RPS)
- Error rate
- Response latency (p50, p95, p99)

### Application Logs
```bash
# View service logs
kubectl logs -l app=api-gateway --tail=50 -f
kubectl logs -l app=order-service --tail=50 -f

# View all pods
kubectl logs --all-containers=true --tail=50 -f
```

---

## 🧪 Testing

### Automated Tests
```bash
# Run API tests
./test-api.sh

# Expected: 17+ passing tests
```

### Load Testing
```bash
# Run sustained load (5 minutes)
k6 run load-testing/load-test.js

# Observe HPA scaling
kubectl get hpa --watch
```

### Manual Testing
```bash
# Get API URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Health check
curl http://$API_URL/health

# Create user
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"John Doe","email":"john@example.com"}'

# Get all users
curl http://$API_URL/api/users
```

---

## 📚 Documentation

| Document | Description |
|----------|-------------|
| [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) | Complete deployment instructions |
| [GCP_SETUP_GUIDE.md](GCP_SETUP_GUIDE.md) | GCP Dataproc + Flink setup |
| [REQUIREMENTS_VERIFICATION.md](REQUIREMENTS_VERIFICATION.md) | Requirements checklist |
| [VIDEO_DEMO_GUIDE.md](VIDEO_DEMO_GUIDE.md) | Demo script for recording |
| [TESTING_GUIDE.md](TESTING_GUIDE.md) | Testing procedures |
| [docs/DESIGN.md](docs/DESIGN.md) | Architecture design document |
| [docs/API.md](docs/API.md) | API documentation |

---

## 🔄 GitOps with ArgoCD

**All deployments managed via Git:**

```bash
# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Open https://localhost:8080
# Username: admin
```

**Application Configuration:**
- Source: GitHub repository
- Path: `kubernetes/base/`
- Sync: Automated with self-heal
- No manual `kubectl apply` needed!

---

## 💰 Cost Estimation

### AWS Resources (per hour):
- EKS cluster: $0.10
- EC2 nodes (2 × t3.medium): $0.08
- RDS MySQL (db.t3.micro): $0.017
- DynamoDB: On-demand (~$0.01)
- MSK (kafka.t3.small): $0.12
- NAT Gateways: $0.09
- Load Balancers: $0.05
- **Total AWS:** ~$0.47/hour (~$11/day)

### GCP Resources (per hour):
- Dataproc (1 master + 2 workers): $0.31
- Cloud Storage: ~$0.01
- **Total GCP:** ~$0.32/hour (~$7.68/day)

**Combined:** ~$0.79/hour or **~$19/day**

### 💡 Cost Savings:
- Stop Dataproc when not testing
- Use spot/preemptible instances
- Delete after demo
- Free tier credits available

---

## 🧹 Cleanup

### Destroy AWS Resources
```bash
cd terraform/aws
terraform destroy -auto-approve
```

### Destroy GCP Resources
```bash
cd terraform/gcp
terraform destroy -auto-approve
```

### Quick Teardown
```bash
./teardown.sh  # Automated cleanup script
```

---

## ✅ Requirements Verification

All 8 assignment requirements fully implemented:

| Requirement | Status | Details |
|-------------|--------|---------|
| a. Infrastructure as Code | ✅ 100% | Terraform for all resources |
| b. 6 Microservices + Serverless | ✅ 100% | 6 services + Lambda |
| c. Kubernetes + HPA | ✅ 100% | EKS with 2 HPAs |
| d. GitOps (ArgoCD) | ✅ 100% | Automated deployments |
| e. Flink Stream Processing | ✅ 100% | GCP Dataproc with Kafka |
| f. 3 Storage Types | ✅ 100% | S3 + RDS + DynamoDB |
| g. Observability | ✅ 100% | Prometheus + Grafana + Logs |
| h. Load Testing | ✅ 100% | k6 with HPA validation |

**See [REQUIREMENTS_VERIFICATION.md](REQUIREMENTS_VERIFICATION.md) for detailed proof.**

---

## 📹 Video Demos

### Individual Video (`<idno>_video.txt`)
- Code walkthrough for each microservice
- Terraform configurations explained
- Your contributions highlighted

### Demo Video (`demo_video.txt`)
- End-to-end system demonstration
- Load testing with HPA scaling
- Cross-cloud Flink processing
- Observability dashboards
- GitOps deployments

---

## 🤝 Contributing

This is an academic project. For questions or improvements:

1. Fork the repository
2. Create a feature branch
3. Submit a pull request

---

## 📄 License

Educational project for Cloud Computing assignment.

---

## 🙏 Acknowledgments

- AWS for EKS, RDS, DynamoDB, MSK, Lambda
- Google Cloud for Dataproc and Flink
- Apache Flink for stream processing
- ArgoCD for GitOps
- Prometheus & Grafana for observability
- k6 for load testing

---

## 📞 Support

For issues or questions:
- Check documentation in `/docs`
- Review deployment guides
- See troubleshooting in guides

---

**Project Status:** ✅ Production Ready | 📝 All Requirements Met | 🎯 Ready for Submission

Made with ☁️ by Pranjay Malhotra
