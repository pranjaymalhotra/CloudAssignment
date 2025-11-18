#!/bin/bash

# Setup ArgoCD
# This script installs and configures ArgoCD for GitOps

set -e

echo "🎯 Setting up ArgoCD..."

# Create namespace
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

# Install ArgoCD
echo "📦 Installing ArgoCD..."
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for ArgoCD to be ready
echo "⏳ Waiting for ArgoCD pods to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

# Expose ArgoCD server
echo "🌐 Exposing ArgoCD server..."
kubectl patch svc argocd-server -n argocd -p '{"spec": {"type": "LoadBalancer"}}'

# Get admin password
echo "🔑 Getting ArgoCD admin password..."
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

# Get ArgoCD URL
echo "⏳ Waiting for LoadBalancer..."
sleep 30
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "✅ ArgoCD setup complete!"
echo "🌐 ArgoCD URL: https://${ARGOCD_URL}"
echo "👤 Username: admin"
echo "🔑 Password: ${ARGOCD_PASSWORD}"
echo ""
echo "📝 Save these credentials!"
echo ""
echo "Next steps:"
echo "1. Login to ArgoCD UI"
echo "2. Update kubernetes/argocd/applications/*.yaml with your Git repo URL"
echo "3. Apply applications: kubectl apply -f kubernetes/argocd/applications/"
