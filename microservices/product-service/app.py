from flask import Flask, request, jsonify
import boto3
import os
import logging
import uuid
from decimal import Decimal

app = Flask(__name__)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# DynamoDB configuration
dynamodb = boto3.resource('dynamodb', region_name=os.getenv('AWS_REGION', 'us-east-1'))
table_name = os.getenv('DYNAMODB_TABLE', 'ecommerce-products')
table = dynamodb.Table(table_name)

@app.route('/health', methods=['GET'])
def health():
    return jsonify({"status": "healthy", "service": "product-service"}), 200

@app.route('/products', methods=['GET'])
def get_products():
    try:
        response = table.scan()
        products = response.get('Items', [])
        
        # Convert Decimal to float for JSON serialization
        for product in products:
            if 'price' in product:
                product['price'] = float(product['price'])
        
        return jsonify(products), 200
    except Exception as e:
        logger.error(f"Error fetching products: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products/<string:product_id>', methods=['GET'])
def get_product(product_id):
    try:
        response = table.get_item(Key={'product_id': product_id})
        product = response.get('Item')
        
        if product:
            if 'price' in product:
                product['price'] = float(product['price'])
            return jsonify(product), 200
        return jsonify({"error": "Product not found"}), 404
    except Exception as e:
        logger.error(f"Error fetching product: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/products', methods=['POST'])
def create_product():
    try:
        data = request.json
        name = data.get('name')
        price = data.get('price')
        stock = data.get('stock', 0)
        category = data.get('category', 'general')
        
        if not name or price is None:
            return jsonify({"error": "Name and price required"}), 400
        
        product_id = str(uuid.uuid4())
        
        table.put_item(Item={
            'product_id': product_id,
            'name': name,
            'price': Decimal(str(price)),
            'stock': stock,
            'category': category
        })
        
        return jsonify({
            "product_id": product_id,
            "name": name,
            "price": price,
            "stock": stock,
            "category": category
        }), 201
    except Exception as e:
        logger.error(f"Error creating product: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5002)
