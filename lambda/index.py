import json
import boto3
import os

s3_client = boto3.client('s3')

def handler(event, context):
    """
    Lambda function triggered by S3 upload
    Processes uploaded files and saves processed version
    """
    print("Lambda function triggered!")
    print(f"Event: {json.dumps(event)}")
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        print(f"Processing file: s3://{bucket}/{key}")
        
        try:
            # Get the object
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            
            print(f"File content length: {len(content)} bytes")
            
            # Process the file (example: convert to uppercase and add metadata)
            processed_content = f"""
=== PROCESSED FILE ===
Original: s3://{bucket}/{key}
Size: {len(content)} bytes
---
{content.upper()}
=== END ===
"""
            
            # Save processed file
            processed_key = key.replace('uploads/', 'processed/')
            s3_client.put_object(
                Bucket=bucket,
                Key=processed_key,
                Body=processed_content,
                ContentType='text/plain'
            )
            
            print(f"✅ Processed file saved to: s3://{bucket}/{processed_key}")
            
            # Optional: Publish to SNS/SQS for notifications
            # sns_client = boto3.client('sns')
            # sns_client.publish(TopicArn='...', Message='File processed')
            
        except Exception as e:
            print(f"❌ Error processing file: {str(e)}")
            raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'File processed successfully!',
            'files_processed': len(event['Records'])
        })
    }

# For local testing
if __name__ == "__main__":
    # Mock event
    test_event = {
        "Records": [{
            "s3": {
                "bucket": {"name": "test-bucket"},
                "object": {"key": "uploads/test.txt"}
            }
        }]
    }
    result = handler(test_event, None)
    print(result)
