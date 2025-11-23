# GCP Cloud Function - Order Analytics

This is a serverless HTTP-triggered Cloud Function that processes order analytics.

## Deployment

Deploy this function to GCP:

```bash
gcloud functions deploy order-analytics \
  --runtime python311 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point order_analytics \
  --region us-central1 \
  --project adept-lead-479014-r0
```

## Testing

Test the function:

```bash
# Get function URL
gcloud functions describe order-analytics --region us-central1 --format='value(httpsTrigger.url)'

# Test with curl
curl -X POST https://YOUR-FUNCTION-URL \
  -H "Content-Type: application/json" \
  -d '{"order_id": 123, "user_id": 1, "total": 299.99}'
```

## Function Features

- **HTTP Trigger**: Can be called from any HTTP client
- **CORS Enabled**: Works with web frontends
- **Analytics Processing**: Simulates real-time order analytics
- **Error Handling**: Returns proper error responses
- **Demo Mode**: Returns sample data when called without parameters
