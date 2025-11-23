"""
Simple Kafka Stream Processor for VIP User Analytics
Consumes order events and produces 1-minute windowed aggregations
"""
from kafka import KafkaConsumer, KafkaProducer
from collections import defaultdict
from datetime import datetime, timedelta
import json
import time
import os
import logging

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

def create_kafka_consumer():
    return KafkaConsumer(
        'orders-events',
        bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
        security_protocol='SSL',
        ssl_cafile='/etc/ssl/certs/ca-certificates.crt',
        group_id='simple-analytics',
        value_deserializer=lambda m: json.loads(m.decode('utf-8')),
        api_version=(3, 5, 1),
        auto_offset_reset='latest'
    )

def create_kafka_producer():
    return KafkaProducer(
        bootstrap_servers=os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092'),
        security_protocol='SSL',
        ssl_cafile='/etc/ssl/certs/ca-certificates.crt',
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        api_version=(3, 5, 1)
    )

def process_orders():
    consumer = create_kafka_consumer()
    producer = create_kafka_producer()
    
    window_data = defaultdict(lambda: {
        'users': set(),
        'total_orders': 0,
        'total_revenue': 0.0
    })
    
    window_duration = timedelta(minutes=1)
    last_flush = datetime.utcnow()
    
    logger.info(f"Starting analytics processor...")
    logger.info(f"Kafka: {os.getenv('KAFKA_BOOTSTRAP_SERVERS')}")
    logger.info(f"Input: orders-events, Output: analytics-results")
    
    for message in consumer:
        try:
            event = message.value
            timestamp = datetime.fromisoformat(event.get('timestamp', '').replace('Z', '+00:00'))
            
            # Round to window start
            window_start = timestamp.replace(second=0, microsecond=0)
            window_key = window_start.isoformat()
            
            # Aggregate
            window_data[window_key]['users'].add(event['user_id'])
            window_data[window_key]['total_orders'] += 1
            revenue = float(event.get('price', 0)) * int(event.get('quantity', 1))
            window_data[window_key]['total_revenue'] += revenue
            
            # Flush completed windows every minute
            now = datetime.utcnow()
            if now - last_flush > window_duration:
                cutoff = now - window_duration
                
                for window_key in list(window_data.keys()):
                    window_time = datetime.fromisoformat(window_key)
                    if window_time < cutoff:
                        data = window_data[window_key]
                        unique_users = len(data['users'])
                        total_orders = data['total_orders']
                        total_revenue = data['total_revenue']
                        avg_value = total_revenue / total_orders if total_orders > 0 else 0
                        
                        result = {
                            'window_start': window_key,
                            'window_end': (window_time + window_duration).isoformat(),
                            'unique_users': unique_users,
                            'total_orders': total_orders,
                            'total_revenue': round(total_revenue, 2),
                            'avg_order_value': round(avg_value, 2)
                        }
                        
                        producer.send('analytics-results', value=result)
                        logger.info(f"Published analytics: {result}")
                        
                        del window_data[window_key]
                
                last_flush = now
                producer.flush()
        
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            continue

if __name__ == '__main__':
    process_orders()
