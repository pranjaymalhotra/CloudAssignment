from flask import Flask, request, jsonify
from flask_cors import CORS
import requests
import os
import logging
import boto3
from botocore.exceptions import ClientError

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service endpoints
USER_SERVICE = os.getenv('USER_SERVICE_URL', 'http://user-service:5001')
PRODUCT_SERVICE = os.getenv('PRODUCT_SERVICE_URL', 'http://product-service:5002')
ORDER_SERVICE = os.getenv('ORDER_SERVICE_URL', 'http://order-service:5003')
ANALYTICS_SERVICE = os.getenv('ANALYTICS_SERVICE_URL', 'http://analytics-service:5000')

# S3 configuration
S3_BUCKET = os.getenv('S3_BUCKET_NAME', 'ecommerce-data-bucket-129257836401')
if os.getenv('S3_BUCKET_NAME') is None:
    logger.warning('S3_BUCKET_NAME env var missing, defaulting to ecommerce-data-bucket-129257836401')

s3_client = boto3.client('s3')

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "api-gateway"}), 200

@app.route('/api/users', methods=['GET', 'POST'])
def users():
    try:
        if request.method == 'GET':
            response = requests.get(f'{USER_SERVICE}/users', timeout=5)
        else:
            response = requests.post(f'{USER_SERVICE}/users', json=request.json, timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error calling user service: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/users/<int:user_id>', methods=['GET'])
def get_user(user_id):
    try:
        response = requests.get(f'{USER_SERVICE}/users/{user_id}', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error getting user: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/products', methods=['GET', 'POST'])
def products():
    try:
        if request.method == 'GET':
            response = requests.get(f'{PRODUCT_SERVICE}/products', timeout=5)
        else:
            response = requests.post(f'{PRODUCT_SERVICE}/products', json=request.json, timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error calling product service: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/products/<string:product_id>', methods=['GET'])
def get_product(product_id):
    try:
        response = requests.get(f'{PRODUCT_SERVICE}/products/{product_id}', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error getting product: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders', methods=['GET', 'POST'])
def orders():
    try:
        if request.method == 'GET':
            response = requests.get(f'{ORDER_SERVICE}/orders', timeout=5)
        else:
            response = requests.post(f'{ORDER_SERVICE}/orders', json=request.json, timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error calling order service: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    try:
        response = requests.get(f'{ORDER_SERVICE}/orders/{order_id}', timeout=5)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error getting order: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/analytics/flink/top-users', methods=['GET'])
def flink_top_users():
    """Proxy to analytics service for Flink real-time data"""
    try:
        limit = request.args.get('limit', 10)
        response = requests.get(f'{ANALYTICS_SERVICE}/api/analytics/flink/top-users?limit={limit}', timeout=10)
        return jsonify(response.json()), response.status_code
    except Exception as e:
        logger.error(f"Error calling analytics service: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/s3/presigned-url', methods=['POST'])
def get_presigned_url():
    """Generate pre-signed URL for S3 upload"""
    try:
        data = request.json
        file_name = data.get('file_name')
        file_type = data.get('file_type', 'text/plain')

        if not file_name:
            return jsonify({"error": "file_name is required"}), 400

        # Generate pre-signed POST for better CORS support
        presigned_post = s3_client.generate_presigned_post(
            Bucket=S3_BUCKET,
            Key=file_name,
            Fields={
                'Content-Type': file_type,
                'acl': 'private'
            },
            Conditions=[
                {'Content-Type': file_type},
                {'acl': 'private'},
                ['content-length-range', 0, 10485760]  # Max 10MB
            ],
            ExpiresIn=300  # URL valid for 5 minutes
        )

        return jsonify({
            "upload_url": presigned_post['url'],
            "upload_fields": presigned_post['fields'],
            "bucket": S3_BUCKET,
            "key": file_name,
            "method": "POST"  # Indicate to use POST instead of PUT
        }), 200
    except ClientError as e:
        logger.error(f"Error generating pre-signed URL: {e}")
        return jsonify({"error": str(e)}), 500
    except Exception as e:
        logger.error(f"Unexpected error: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/s3/file-status', methods=['GET'])
def check_file_status():
    """Check if processed file exists and return its content"""
    try:
        key = request.args.get('key')
        if not key:
            return jsonify({"error": "key parameter is required"}), 400
        
        # Check if file exists
        try:
            response = s3_client.get_object(Bucket=S3_BUCKET, Key=key)
            content = response['Body'].read().decode('utf-8')
            return jsonify({
                "exists": True,
                "content": content,
                "size": response['ContentLength']
            }), 200
        except ClientError as e:
            if e.response['Error']['Code'] == 'NoSuchKey':
                return jsonify({"exists": False}), 200
            raise
    except Exception as e:
        logger.error(f"Error checking file status: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
