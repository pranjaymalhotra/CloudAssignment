from flask import Flask, request, jsonify
import requests
import os
import logging

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Service endpoints
USER_SERVICE = os.getenv('USER_SERVICE_URL', 'http://user-service:5001')
PRODUCT_SERVICE = os.getenv('PRODUCT_SERVICE_URL', 'http://product-service:5002')
ORDER_SERVICE = os.getenv('ORDER_SERVICE_URL', 'http://order-service:5003')

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

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000)
