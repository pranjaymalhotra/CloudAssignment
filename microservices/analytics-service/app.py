from flask import Flask, jsonify
import boto3
import json
import os
from datetime import datetime

app = Flask(__name__)

# AWS Configuration
AWS_REGION = os.getenv('AWS_REGION', 'us-east-1')
DYNAMODB_TABLE = os.getenv('ANALYTICS_DYNAMODB_TABLE', 'ecommerce-analytics')

# Initialize AWS clients
dynamodb = boto3.resource('dynamodb', region_name=AWS_REGION)
table = dynamodb.Table(DYNAMODB_TABLE)

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
