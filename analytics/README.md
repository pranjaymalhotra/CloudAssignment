# Flink Analytics Service

This service runs on GCP Dataproc and performs real-time analytics on order data.

## Building

```bash
cd analytics
mvn clean package
```

## Deploying to GCP Dataproc

```bash
# Upload JAR to GCS
gsutil cp target/flink-analytics-1.0.0.jar gs://YOUR_PROJECT_ID-flink-jobs/

# Submit Flink job
gcloud dataproc jobs submit flink \
    --cluster=analytics-cluster \
    --region=us-central1 \
    --jar=gs://YOUR_PROJECT_ID-flink-jobs/flink-analytics-1.0.0.jar \
    -- \
    --kafka-brokers YOUR_MSK_BROKERS
```

## What it does

1. Consumes order events from Kafka topic `orders`
2. Performs 1-minute tumbling window aggregation
3. Counts orders per user
4. Publishes results to `analytics-results` topic
