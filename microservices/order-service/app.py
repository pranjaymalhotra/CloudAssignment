from flask import Flask, request, jsonify
import pymysql
import os
import json
import logging
from kafka import KafkaProducer
from datetime import datetime

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Database configuration
DB_HOST = os.getenv('DB_HOST')
DB_PORT = int(os.getenv('DB_PORT', 3306))
DB_NAME = os.getenv('DB_NAME')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')

# Kafka configuration
KAFKA_BOOTSTRAP_SERVERS = os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'localhost:9092')
KAFKA_SECURITY_PROTOCOL = os.getenv('KAFKA_SECURITY_PROTOCOL', 'PLAINTEXT')
KAFKA_SSL_CAFILE = os.getenv('KAFKA_SSL_CAFILE', '')
KAFKA_API_VERSION = os.getenv('KAFKA_API_VERSION', '')
producer = None

def get_kafka_producer():
    global producer
    if producer is None:
        kafka_config = {
            'bootstrap_servers': KAFKA_BOOTSTRAP_SERVERS.split(','),
            'value_serializer': lambda v: json.dumps(v).encode('utf-8')
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
        
        producer = KafkaProducer(**kafka_config)
    return producer

def get_db_connection():
    return pymysql.connect(
        host=DB_HOST,
        port=DB_PORT,
        user=DB_USER,
        password=DB_PASSWORD,
        database=DB_NAME,
        cursorclass=pymysql.cursors.DictCursor
    )

def init_db():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('''
            CREATE TABLE IF NOT EXISTS orders (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                product_id VARCHAR(255) NOT NULL,
                quantity INT NOT NULL,
                total_price DECIMAL(10, 2),
                status VARCHAR(50) DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ''')
        conn.commit()
        conn.close()
        logger.info("Database initialized successfully")
    except Exception as e:
        logger.error(f"Error initializing database: {e}")

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "order-service"}), 200

@app.route('/orders', methods=['GET'])
def get_orders():
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM orders')
        orders = cursor.fetchall()
        conn.close()
        
        # Convert Decimal to float
        for order in orders:
            if 'total_price' in order and order['total_price']:
                order['total_price'] = float(order['total_price'])
        
        return jsonify(orders), 200
    except Exception as e:
        logger.error(f"Error fetching orders: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders/<int:order_id>', methods=['GET'])
def get_order(order_id):
    try:
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute('SELECT * FROM orders WHERE id = %s', (order_id,))
        order = cursor.fetchone()
        conn.close()
        
        if order:
            if 'total_price' in order and order['total_price']:
                order['total_price'] = float(order['total_price'])
            return jsonify(order), 200
        return jsonify({"error": "Order not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching order: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/orders', methods=['POST'])
def create_order():
    try:
        data = request.json
        user_id = data.get('user_id')
        product_id = data.get('product_id')
        quantity = data.get('quantity', 1)
        # Accept both 'price' and 'total_price' for backwards compatibility
        price = data.get('price', data.get('total_price', 0.0))
        
        if not user_id or not product_id:
            return jsonify({"error": "User ID and Product ID required"}), 400
        
        conn = get_db_connection()
        cursor = conn.cursor()
        cursor.execute(
            'INSERT INTO orders (user_id, product_id, quantity, total_price, status) VALUES (%s, %s, %s, %s, %s)',
            (user_id, product_id, quantity, price, 'pending')
        )
        conn.commit()
        order_id = cursor.lastrowid
        conn.close()
        
        # Publish to Kafka
        order_event = {
            "order_id": str(order_id),
            "user_id": str(user_id),
            "product_id": str(product_id),
            "quantity": quantity,
            "price": float(price),
            "timestamp": datetime.utcnow().isoformat() + 'Z',
            "status": "pending"
        }
        
        try:
            kafka_producer = get_kafka_producer()
            kafka_producer.send('orders-events', value=order_event)
            kafka_producer.flush()
            logger.info(f"Order event published to Kafka topic 'orders-events': {order_id}")
        except Exception as kafka_error:
            logger.error(f"Error publishing to Kafka: {kafka_error}")
        
        return jsonify({"id": order_id, **order_event}), 201
    except Exception as e:
        logger.error(f"Error creating order: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    init_db()
    app.run(host='0.0.0.0', port=5003)
