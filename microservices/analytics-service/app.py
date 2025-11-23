from flask import Flask, jsonify, request
import boto3
import json
import os
from datetime import datetime
from kafka import KafkaConsumer
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
DYNAMODB_TABLE = os.getenv('ANALYTICS_DYNAMODB_TABLE', 'ecommerce-analytics')

# Kafka Configuration
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
KAFKA_SSL_CAFILE = os.getenv('KAFKA_SSL_CAFILE', '')
KAFKA_API_VERSION = os.getenv('KAFKA_API_VERSION', '')

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

@app.route('/api/analytics/flink/top-users', methods=['GET'])
def get_flink_top_users():
    """Get top users from Flink analytics-results topic"""
    try:
        limit = request.args.get('limit', 10, type=int)
        
        # Create Kafka consumer to read from Flink output topic (supports TLS endpoints)
        kafka_config = {
            'bootstrap_servers': [server.strip() for server in KAFKA_BOOTSTRAP_SERVERS.split(',') if server.strip()],
            'auto_offset_reset': 'earliest',
            'enable_auto_commit': False,
            'consumer_timeout_ms': 5000,
            'value_deserializer': lambda x: json.loads(x.decode('utf-8'))
        }

        if KAFKA_SECURITY_PROTOCOL:
            kafka_config['security_protocol'] = KAFKA_SECURITY_PROTOCOL

        if KAFKA_SSL_CAFILE:
            kafka_config['ssl_cafile'] = KAFKA_SSL_CAFILE

        if KAFKA_API_VERSION:
            try:
                version_tuple = tuple(int(part) for part in KAFKA_API_VERSION.replace(',', '.').split('.') if part.strip())
                if version_tuple:
                    kafka_config['api_version'] = version_tuple
                    logger.info(f"Using explicit Kafka API version override: {version_tuple}")
            except ValueError:
                logger.warning(f"Invalid KAFKA_API_VERSION '{KAFKA_API_VERSION}', falling back to auto-detection")

        consumer = KafkaConsumer('analytics-results', **kafka_config)
        
        # Collect all analytics results
        user_analytics = {}
        for message in consumer:
            try:
                data = message.value
                user_id = data.get('user_id')
                if user_id:
                    # Keep the latest data for each user
                    if user_id not in user_analytics or data.get('window_end', '') > user_analytics[user_id].get('window_end', ''):
                        user_analytics[user_id] = data
            except Exception as e:
                logger.error(f"Error processing message: {e}")
                continue
        
        consumer.close()
        
        # Convert to list and sort by total_spent
        results = list(user_analytics.values())
        results.sort(key=lambda x: x.get('total_spent', 0), reverse=True)
        
        # Return top N users
        top_users = results[:limit]
        
        return jsonify({
            "status": "success",
            "source": "Flink Real-Time Analytics",
            "topic": "analytics-results",
            "total_users_analyzed": len(results),
            "top_users": top_users,
            "timestamp": datetime.now().isoformat()
        }), 200
        
    except Exception as e:
        logger.error(f"Error reading Flink results: {e}")
        return jsonify({
            "status": "error",
            "message": str(e),
            "note": "Make sure Flink job is running and producing to analytics-results topic"
        }), 500

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "analytics-service"}), 200

@app.route('/api/analytics/summary', methods=['GET'])
def get_analytics_summary():
    """Get overall analytics summary"""
    try:
        response = table.scan(Limit=100)
        items = response.get('Items', [])
        
        total_orders = sum(item.get('order_count', 0) for item in items)
        total_revenue = sum(float(item.get('total_revenue', 0)) for item in items)
        unique_users = len(set(item.get('user_id', '') for item in items if item.get('user_id')))
        
        return jsonify({
            "total_orders": total_orders,
            "total_revenue": round(total_revenue, 2),
            "unique_users": unique_users,
            "data_points": len(items)
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/analytics/recent', methods=['GET'])
def get_recent_analytics():
    """Get recent analytics data"""
    try:
        response = table.scan(Limit=20)
        items = response.get('Items', [])
        
        # Sort by timestamp
        items.sort(key=lambda x: x.get('timestamp', ''), reverse=True)
        
        return jsonify({
            "count": len(items),
            "analytics": items[:10]
        }), 200
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/analytics/window/<window_id>', methods=['GET'])
def get_window_analytics(window_id):
    """Get analytics for specific time window"""
    try:
        response = table.get_item(Key={'window_id': window_id})
        
        if 'Item' in response:
            return jsonify(response['Item']), 200
        else:
            return jsonify({"error": "Window not found"}), 404
    except Exception as e:
        return jsonify({"error": str(e)}), 500

@app.route('/api/analytics/process', methods=['POST'])
def process_analytics():
    """Trigger analytics processing (simulated for demo)"""
    try:
        # In real implementation, this would trigger Flink job
        # For now, we'll create a sample analytics record
        
        window_id = f"window-{int(datetime.now().timestamp())}"
        item = {
            'window_id': window_id,
            'timestamp': datetime.now().isoformat(),
            'order_count': 10,
            'total_revenue': 1999.90,
            'unique_users': 5,
            'window_start': datetime.now().isoformat(),
            'window_end': datetime.now().isoformat()
        }
        
        table.put_item(Item=item)
        
        return jsonify({
            "message": "Analytics processed",
            "window_id": window_id,
            "data": item
        }), 201
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
