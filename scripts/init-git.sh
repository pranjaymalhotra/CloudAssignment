#!/bin/bash

# Initialize Git Repository and Setup
# This helps you push your project to GitHub

set -e

echo "📦 Initializing Git repository..."

# Check if already initialized
if [ -d ".git" ]; then
    echo "⚠️  Git already initialized"
    exit 0
fi

# Initialize git
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: E-Commerce Cloud Assignment

- 6 microservices (API Gateway, User, Product, Order, Notification)
- Terraform IaC for AWS and GCP
- Kubernetes manifests with HPA
- ArgoCD for GitOps
- Flink analytics on GCP
- Lambda serverless function
- Prometheus + Grafana monitoring
- k6 load testing
- Complete documentation"

echo ""
echo "✅ Git repository initialized!"
echo ""
echo "Next steps:"
echo "1. Create a new repository on GitHub"
echo "2. Run these commands:"
echo ""
echo "   git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git"
echo "   git branch -M main"
echo "   git push -u origin main"
echo ""
echo "3. Update ArgoCD application files with your repo URL:"
echo "   - kubernetes/argocd/applications/microservices-app.yaml"
echo ""
