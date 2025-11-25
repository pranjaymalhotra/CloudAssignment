#!/bin/bash
set -e

CLUSTER_NAME="analytics-cluster"
REGION="us-central1"
PROJECT_ID="adept-lead-479014-r0"
BUCKET="gs://dataproc-analytics-${PROJECT_ID}"

echo "Deploying Analytics Processor to GCP Dataproc..."

# Create bucket if not exists
gsutil mb -p ${PROJECT_ID} -l ${REGION} ${BUCKET} 2>/dev/null || echo "Bucket already exists"

# Upload files
echo "Uploading files to GCS..."
gsutil cp analytics_processor.py ${BUCKET}/jobs/
gsutil cp requirements.txt ${BUCKET}/jobs/

# Submit PySpark job
echo "Submitting job to Dataproc cluster..."
gcloud dataproc jobs submit pyspark ${BUCKET}/jobs/analytics_processor.py \
  --cluster=${CLUSTER_NAME} \
  --region=${REGION} \
  --project=${PROJECT_ID} \
  --properties=spark.executor.memory=2g,spark.driver.memory=2g \
  --py-files=${BUCKET}/jobs/requirements.txt \
  --async

echo "Job submitted successfully!"
echo "Check status: gcloud dataproc jobs list --cluster=${CLUSTER_NAME} --region=${REGION}"
