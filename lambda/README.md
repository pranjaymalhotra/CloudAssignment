# Lambda Function - S3 File Processor

This Lambda function is triggered when files are uploaded to the S3 bucket.

## Function Details

- **Runtime**: Python 3.11
- **Trigger**: S3 ObjectCreated events
- **Purpose**: Process uploaded files and save processed versions

## What It Does

1. Triggered when file uploaded to `s3://bucket/uploads/`
2. Reads file content
3. Processes it (example: converts to uppercase)
4. Saves processed file to `s3://bucket/processed/`

## Local Testing

```python
# test_lambda.py
import json
from index import handler

event = {
    "Records": [{
        "s3": {
            "bucket": {"name": "test-bucket"},
            "object": {"key": "uploads/test.txt"}
        }
    }]
}

result = handler(event, None)
print(result)
```

## Deployment

Lambda is automatically deployed by Terraform. To update code manually:

```bash
cd lambda/s3-processor

# Package
zip -r function.zip index.py

# Deploy
aws lambda update-function-code \
    --function-name s3-file-processor \
    --zip-file fileb://function.zip \
    --region us-east-1
```

## Testing

```bash
# Upload a file to trigger Lambda
echo "test content" > test.txt
aws s3 cp test.txt s3://YOUR_BUCKET_NAME/uploads/test.txt

# Check Lambda logs
aws logs tail /aws/lambda/s3-file-processor --follow

# Check processed file
aws s3 ls s3://YOUR_BUCKET_NAME/processed/
aws s3 cp s3://YOUR_BUCKET_NAME/processed/test.txt -
```

## CloudWatch Logs

View logs in AWS Console:
1. Go to CloudWatch → Log Groups
2. Find `/aws/lambda/s3-file-processor`
3. View log streams
