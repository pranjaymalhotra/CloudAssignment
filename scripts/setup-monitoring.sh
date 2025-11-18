#!/bin/bash

# Setup Monitoring Stack
# Installs Prometheus and Grafana

set -e

echo "📊 Setting up monitoring stack..."

# Add Helm repo
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install Prometheus + Grafana
echo "📦 Installing Prometheus and Grafana..."
helm install prometheus prometheus-community/kube-prometheus-stack \
    -n monitoring --create-namespace \
    --set grafana.adminPassword=admin123

# Wait for pods
echo "⏳ Waiting for monitoring pods..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=prometheus -n monitoring --timeout=300s

# Expose Grafana
kubectl patch svc prometheus-grafana -n monitoring -p '{"spec": {"type": "LoadBalancer"}}'

# Get Grafana URL
sleep 30
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

echo ""
echo "✅ Monitoring stack deployed!"
echo "📊 Grafana URL: http://${GRAFANA_URL}"
echo "👤 Username: admin"
echo "🔑 Password: admin123"
echo ""
echo "🎯 Import dashboards from monitoring/grafana/dashboards/"
