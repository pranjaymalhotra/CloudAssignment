from flask import Flask, jsonify
import json
import logging
import os
from kafka import KafkaConsumer
from threading import Thread

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
consumer = None

def start_kafka_consumer():
    """Background thread to consume Kafka messages"""
    global consumer
    try:
        consumer = KafkaConsumer(
            'orders',
            bootstrap_servers=KAFKA_BOOTSTRAP_SERVERS.split(','),
            value_deserializer=lambda m: json.loads(m.decode('utf-8')),
            group_id='notification-service-group',
            auto_offset_reset='latest'
        )
        
        logger.info("Kafka consumer started")
        
        for message in consumer:
            order_data = message.value
            logger.info(f"Received order notification: {order_data}")
            # In a real system, this would send email/SMS/push notifications
            send_notification(order_data)
    except Exception as e:
        logger.error(f"Kafka consumer error: {e}")

def send_notification(order_data):
    """Simulate sending notification"""
    logger.info(f"📧 Notification sent for order {order_data.get('order_id')}")
    # Here you would integrate with email service (SES), SMS (SNS), etc.

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "notification-service"}), 200

@app.route('/send', methods=['POST'])
def send_manual_notification():
    """Manual notification endpoint for testing"""
    try:
        # This would send actual notifications
        return jsonify({"status": "notification sent"}), 200
    except Exception as e:
        logger.error(f"Error sending notification: {e}")
        return jsonify({"error": str(e)}), 500

# Start Kafka consumer in background thread
consumer_thread = Thread(target=start_kafka_consumer, daemon=True)
consumer_thread.start()

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5004)
