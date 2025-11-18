# IAM Role for Lambda
resource "aws_iam_role" "lambda" {
  name = "${var.function_name}-role"
  
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

# Attach basic execution policy
resource "aws_iam_role_policy_attachment" "lambda_basic" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.lambda.name
}

# S3 access policy for Lambda
resource "aws_iam_role_policy" "lambda_s3" {
  name = "${var.function_name}-s3-policy"
  role = aws_iam_role.lambda.id
  
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject"
      ]
      Resource = "${var.s3_bucket_arn}/*"
    }]
  })
}

# Lambda Function
resource "aws_lambda_function" "main" {
  filename      = "${path.module}/lambda_function.zip"
  function_name = var.function_name
  role          = aws_iam_role.lambda.arn
  handler       = "index.handler"
  runtime       = "python3.11"
  timeout       = 30
  memory_size   = 256
  
  environment {
    variables = {
      BUCKET_NAME = var.s3_bucket_name
    }
  }
  
  tags = {
    Name = var.function_name
  }
}

# Lambda permission for S3 to invoke
resource "aws_lambda_permission" "allow_s3" {
  statement_id  = "AllowExecutionFromS3"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.main.function_name
  principal     = "s3.amazonaws.com"
  source_arn    = var.s3_bucket_arn
}

# Create placeholder zip file
data "archive_file" "lambda_zip" {
  type        = "zip"
  output_path = "${path.module}/lambda_function.zip"
  
  source {
    content  = <<EOF
import json
import boto3
import os

s3_client = boto3.client('s3')

def handler(event, context):
    """
    Lambda function triggered by S3 upload
    Processes uploaded files
    """
    print("Lambda function triggered!")
    
    for record in event['Records']:
        bucket = record['s3']['bucket']['name']
        key = record['s3']['object']['key']
        
        print(f"Processing file: s3://{bucket}/{key}")
        
        try:
            # Get the object
            response = s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            
            print(f"File content length: {len(content)} bytes")
            
            # Process the file (example: convert to uppercase)
            processed_content = content.upper()
            
            # Save processed file
            processed_key = key.replace('uploads/', 'processed/')
            s3_client.put_object(
                Bucket=bucket,
                Key=processed_key,
                Body=processed_content
            )
            
            print(f"Processed file saved to: s3://{bucket}/{processed_key}")
            
        except Exception as e:
            print(f"Error processing file: {str(e)}")
            raise e
    
    return {
        'statusCode': 200,
        'body': json.dumps('File processed successfully!')
    }
EOF
    filename = "index.py"
  }
}

# Outputs
output "function_name" {
  value = aws_lambda_function.main.function_name
}

output "function_arn" {
  value = aws_lambda_function.main.arn
}

output "function_invoke_arn" {
  value = aws_lambda_function.main.invoke_arn
}
