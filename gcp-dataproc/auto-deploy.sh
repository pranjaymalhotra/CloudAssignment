#!/bin/bash
# Automated deployment script for GCP Dataproc analytics processor
set -e

echo "Waiting for Dataproc cluster to be ready..."
while true; do
    STATUS=$(gcloud dataproc clusters describe analytics-cluster --region=us-central1 --format="value(status.state)" 2>/dev/null || echo "NOT_FOUND")
    if [ "$STATUS" = "RUNNING" ]; then
        echo "Cluster is RUNNING"
        break
    fi
    echo "Current status: $STATUS - waiting..."
    sleep 30
done

echo "Deploying analytics processor..."
cd /Users/pranjaymalhotra/Downloads/Cloud_A15/gcp-dataproc
chmod +x deploy.sh
./deploy.sh

echo "Deployment complete!"
echo "Check job status:"
echo "  gcloud dataproc jobs list --cluster=analytics-cluster --region=us-central1"
