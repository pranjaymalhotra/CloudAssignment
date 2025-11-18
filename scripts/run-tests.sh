#!/bin/bash

# Run Load Tests
# This script executes k6 load tests against the deployed application

set -e

echo "🧪 Running Load Tests..."

# Get API Gateway URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$API_URL" ]; then
    echo "❌ Error: Could not get API Gateway URL"
    exit 1
fi

echo "🎯 Target: http://${API_URL}"

# Run basic load test
echo ""
echo "📊 Running basic load test..."
k6 run -e API_URL=http://${API_URL} load-testing/scripts/load-test.js

# Watch HPA during stress test
echo ""
echo "⚡ Running stress test to trigger HPA..."
echo "📈 Open another terminal and run: kubectl get hpa -w"
echo "Press Enter to start stress test..."
read

k6 run -e API_URL=http://${API_URL} load-testing/scripts/stress-test.js

echo ""
echo "✅ Load tests complete!"
echo "📊 Check HPA status: kubectl get hpa"
echo "📈 Check metrics: kubectl top pods"
