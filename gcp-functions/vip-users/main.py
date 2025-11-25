"""
GCP Cloud Function to fetch top VIP users from Kafka analytics-results topic
"""
import functions_framework
from kafka import KafkaConsumer
import json
import os
from collections import defaultdict

KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'b-1.ecommercekafka.sexwyl.c6.kafka.us-east-1.amazonaws.com:9094,b-2.ecommercekafka.sexwyl.c6.kafka.us-east-1.amazonaws.com:9094')

@functions_framework.http
def get_vip_users(request):
    """Fetch top 10 VIP users from Kafka analytics-results topic"""
    
    # Handle CORS
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)
    
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }
    
    try:
        # Create consumer
        consumer = KafkaConsumer(
            'analytics-results',
            bootstrap_servers=KAFKA_BROKERS.split(','),
            security_protocol='SSL',
            ssl_check_hostname=False,
            ssl_cafile='/etc/ssl/certs/ca-certificates.crt',
            group_id='vip-users-api',
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            api_version=(3, 5, 1),
            auto_offset_reset='latest',
            consumer_timeout_ms=5000,
            enable_auto_commit=False
        )
        
        # Collect latest data per user
        user_analytics = {}
        message_count = 0
        
        for message in consumer:
            try:
                data = message.value
                user_id = data.get('user_id')
                user_analytics[user_id] = data
                message_count += 1
            except Exception as e:
                continue
        
        consumer.close()
        
        # Sort by total_spent and get top 10 VIPs
        all_users = sorted(user_analytics.values(), key=lambda x: x.get('total_spent', 0), reverse=True)
        vip_users = [u for u in all_users if u.get('is_vip', False) or u.get('total_spent', 0) > 10000][:10]
        
        response_data = {
            'status': 'success',
            'job_id': '9fc61193978247b18f5be0fc249839cb',
            'cluster': 'analytics-cluster',
            'messages_processed': message_count,
            'total_users': len(user_analytics),
            'vip_count': len(vip_users),
            'top_vip_users': vip_users
        }
        
        return (json.dumps(response_data), 200, headers)
        
    except Exception as e:
        error_response = {
            'status': 'error',
            'message': str(e),
            'job_id': '9fc61193978247b18f5be0fc249839cb'
        }
        return (json.dumps(error_response), 500, headers)
