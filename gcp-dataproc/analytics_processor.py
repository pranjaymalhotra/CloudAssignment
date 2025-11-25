#!/usr/bin/env python3
"""
Real-time Order Analytics Processor for GCP Dataproc
Processes order events from AWS MSK Kafka and aggregates user analytics
"""

from kafka import KafkaConsumer, KafkaProducer
from collections import defaultdict
from datetime import datetime, timedelta, timezone
import json
import os
import logging
import time

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Kafka configuration
KAFKA_BROKERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'b-1.ecommercekafka.sexwyl.c6.kafka.us-east-1.amazonaws.com:9094,b-2.ecommercekafka.sexwyl.c6.kafka.us-east-1.amazonaws.com:9094')
INPUT_TOPIC = 'orders-events'
OUTPUT_TOPIC = 'analytics-results'
WINDOW_MINUTES = 1

def create_kafka_consumer():
    """Create Kafka consumer with SSL configuration"""
    return KafkaConsumer(
        INPUT_TOPIC,
        bootstrap_servers=KAFKA_BROKERS.split(','),
        security_protocol='SSL',
        ssl_check_hostname=False,
        ssl_cafile='/etc/ssl/certs/ca-certificates.crt',
        group_id='gcp-analytics-processor',
        value_deserializer=lambda m: json.loads(m.decode('utf-8')),
        api_version=(3, 5, 1),
        auto_offset_reset='latest',
        enable_auto_commit=True
    )

def create_kafka_producer():
    """Create Kafka producer with SSL configuration"""
    return KafkaProducer(
        bootstrap_servers=KAFKA_BROKERS.split(','),
        security_protocol='SSL',
        ssl_check_hostname=False,
        ssl_cafile='/etc/ssl/certs/ca-certificates.crt',
        value_serializer=lambda v: json.dumps(v).encode('utf-8'),
        api_version=(3, 5, 1)
    )

def process_orders():
    """Main processing loop - aggregates orders by user in time windows"""
    consumer = create_kafka_consumer()
    producer = create_kafka_producer()
    
    user_data = defaultdict(lambda: {
        'total_orders': 0,
        'total_revenue': 0.0,
        'first_order_time': None,
        'last_order_time': None
    })
    
    last_publish = datetime.now(timezone.utc)
    publish_interval = timedelta(minutes=WINDOW_MINUTES)
    
    logger.info(f"Analytics Processor Started")
    logger.info(f"Job ID: 9fc61193978247b18f5be0fc249839cb")
    logger.info(f"Kafka Brokers: {KAFKA_BROKERS}")
    logger.info(f"Input Topic: {INPUT_TOPIC}")
    logger.info(f"Output Topic: {OUTPUT_TOPIC}")
    logger.info(f"Window: {WINDOW_MINUTES} minute(s)")
    
    for message in consumer:
        try:
            event = message.value
            user_id = str(event.get('user_id'))
            
            # Extract order details
            price = float(event.get('price', 0))
            quantity = int(event.get('quantity', 1))
            revenue = price * quantity
            order_time = event.get('timestamp', datetime.now(timezone.utc).isoformat())
            
            # Aggregate per user
            user_data[user_id]['total_orders'] += 1
            user_data[user_id]['total_revenue'] += revenue
            
            if user_data[user_id]['first_order_time'] is None:
                user_data[user_id]['first_order_time'] = order_time
            user_data[user_id]['last_order_time'] = order_time
            
            # Publish aggregated results every window
            now = datetime.now(timezone.utc)
            if now - last_publish >= publish_interval:
                results = []
                for uid, stats in user_data.items():
                    avg_order = stats['total_revenue'] / stats['total_orders'] if stats['total_orders'] > 0 else 0
                    
                    # Determine VIP status
                    is_vip = stats['total_revenue'] > 10000
                    tier = 'VIP' if stats['total_revenue'] > 10000 else 'Premium' if stats['total_revenue'] > 5000 else 'Regular'
                    
                    result = {
                        'user_id': uid,
                        'total_orders': stats['total_orders'],
                        'total_spent': round(stats['total_revenue'], 2),
                        'avg_order_value': round(avg_order, 2),
                        'customer_tier': tier,
                        'is_vip': is_vip,
                        'first_order': stats['first_order_time'],
                        'last_order': stats['last_order_time'],
                        'window_end': now.isoformat()
                    }
                    
                    producer.send(OUTPUT_TOPIC, value=result)
                    results.append(result)
                
                # Log top VIP users
                vip_users = sorted([r for r in results if r['is_vip']], key=lambda x: x['total_spent'], reverse=True)[:10]
                logger.info(f"Published analytics for {len(results)} users ({len(vip_users)} VIPs)")
                for i, user in enumerate(vip_users[:3], 1):
                    logger.info(f"  #{i} VIP: User {user['user_id']} - ${user['total_spent']:.2f} ({user['total_orders']} orders)")
                
                last_publish = now
                producer.flush()
                
        except Exception as e:
            logger.error(f"Error processing message: {e}")
            continue

if __name__ == '__main__':
    logger.info("Starting GCP Dataproc Analytics Processor...")
    while True:
        try:
            process_orders()
        except Exception as e:
            logger.error(f"Fatal error: {e}")
            logger.info("Restarting in 10 seconds...")
            time.sleep(10)
