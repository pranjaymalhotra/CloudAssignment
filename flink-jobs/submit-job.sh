#!/bin/bash

# Submit Flink job to GCP Dataproc with AWS MSK configuration
# Use single broker to avoid comma parsing issues

gcloud dataproc jobs submit pyflink \
  --cluster=analytics-cluster \
  --region=us-central1 \
  --project=adept-lead-479014-r0 \
  --properties='env.KAFKA_BOOTSTRAP_SERVERS=b-1.ecommercekafka.f372ak.c6.kafka.us-east-1.amazonaws.com:9094,env.KAFKA_INPUT_TOPIC=orders-events,env.KAFKA_OUTPUT_TOPIC=analytics-results' \
  --py-requirements=gs://adept-lead-479014-r0-flink-jobs/requirements.txt \
  gs://adept-lead-479014-r0-flink-jobs/analytics_job.py
