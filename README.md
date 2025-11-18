# Cloud Computing Assignment - E-Commerce Microservices Platform

## 🎯 Project Overview

A comprehensive cloud-native e-commerce application with 6 microservices deployed across AWS and GCP, demonstrating:
- Infrastructure as Code (Terraform)
- Kubernetes orchestration (EKS)
- GitOps deployment (ArgoCD)
- Real-time stream processing (Flink on GCP)
- Serverless computing (Lambda)
- Comprehensive monitoring (Prometheus + Grafana)

## 🏗️ Architecture

### Microservices (5 on AWS EKS + 1 on GCP)
1. **API Gateway** - Public REST API (with HPA)
2. **User Service** - User management (RDS MySQL)
3. **Product Service** - Product catalog (DynamoDB + S3)
4. **Order Service** - Order processing (RDS MySQL, with HPA)
5. **Notification Service** - Notifications via Kafka
6. **Analytics Service** - Real-time analytics (Flink on GCP Dataproc)

### Infrastructure
- **AWS**: EKS, RDS MySQL, DynamoDB, S3, MSK (Kafka), Lambda, VPC
- **GCP**: Dataproc (Flink), Cloud Storage
- **IaC**: 100% Terraform provisioned
- **GitOps**: ArgoCD for deployment
- **Monitoring**: Prometheus + Grafana + EFK Stack
- **Testing**: k6 load testing

## 📁 Project Structure

```
Cloud_A15/
├── terraform/              # Infrastructure as Code
│   ├── aws/               # AWS resources
│   ├── gcp/               # GCP resources
│   └── modules/           # Reusable modules
├── microservices/         # Application code
│   ├── api-gateway/
│   ├── user-service/
│   ├── product-service/
│   ├── order-service/
│   └── notification-service/
├── analytics/             # GCP Flink job
├── lambda/                # Serverless function
├── kubernetes/            # K8s manifests
│   ├── base/
│   └── argocd/
├── monitoring/            # Observability
│   ├── prometheus/
│   ├── grafana/
│   └── logging/
├── load-testing/          # k6 scripts
├── docs/                  # Documentation & diagrams
└── scripts/              # Helper scripts
```

## 🚀 Quick Start

**Prerequisites:**
- AWS CLI configured with $100 credits
- Terraform >= 1.5
- kubectl >= 1.27
- Docker
- Git

**Setup Time:** ~45-60 minutes

```bash
# 1. Set up GCP account (free tier)
# Follow: docs/GCP_SETUP.md

# 2. Deploy infrastructure
cd terraform/aws
terraform init && terraform apply -auto-approve

cd ../gcp
terraform init && terraform apply -auto-approve

# 3. Configure kubectl
aws eks update-kubeconfig --name ecommerce-cluster --region us-east-1

# 4. Deploy ArgoCD and applications
./scripts/deploy-all.sh

# 5. Run load tests
./scripts/run-tests.sh
```

**Detailed instructions:** See [SETUP.md](./SETUP.md)

## 📊 Key Features

✅ **Multi-cloud**: AWS (primary) + GCP (analytics)
✅ **GitOps**: ArgoCD manages all deployments
✅ **Auto-scaling**: HPA on API Gateway & Order Service
✅ **Stream Processing**: Kafka → Flink → Real-time analytics
✅ **Event-driven**: Lambda triggered by S3 uploads
✅ **Observability**: Full metrics, logs, and traces
✅ **Load Tested**: k6 scripts validate scalability

## 💰 Cost Estimate

- **Development/Testing**: ~$5-10 (mostly MSK Kafka)
- **After submission**: Delete all resources with `terraform destroy`
- **Free tier eligible**: RDS t3.micro, EKS control plane free first 30 days

## 📹 Demonstration

- Individual code walkthrough: See `<idno>_video.txt`
- Full demo: See `demo_video.txt`

## 📚 Documentation

- [Complete Setup Guide](./SETUP.md)
- [Architecture Design](./docs/DESIGN.md)
- [API Documentation](./docs/API.md)
- [Troubleshooting](./docs/TROUBLESHOOTING.md)

## 🎓 Student Information

- **Course**: CS/SS G527 - Cloud Computing
- **Institution**: BITS Pilani
- **Semester**: I Semester 2025-2026

---
**Note**: This project meets all assignment requirements. Destroy resources after submission to avoid charges.
