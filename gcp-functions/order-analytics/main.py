import functions_framework
import requests
from flask import jsonify
from datetime import datetime
import os

# AWS API Gateway URL - UPDATED
API_GATEWAY_URL = os.getenv('API_GATEWAY_URL', 'http://aec7aa94d97374d3b9daac7ac9126b93-298005368.us-east-1.elb.amazonaws.com')

@functions_framework.http
def order_analytics(request):
    """
    HTTP Cloud Function for order analytics
    Analyzes user orders and calculates lifetime value
    """
    # Set CORS headers for the preflight request
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    # Set CORS headers for the main request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'POST, GET, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type'
    }
    
    try:
        # Parse request
        request_json = request.get_json(silent=True)
        
        if not request_json or 'user_id' not in request_json:
            response = jsonify({
                'status': 'error',
                'message': 'user_id is required',
                'timestamp': datetime.utcnow().isoformat()
            })
            return (response, 400, headers)
        
        user_id = request_json['user_id']
        
        # Fetch user details from AWS
        try:
            user_response = requests.get(f'{API_GATEWAY_URL}/api/users/{user_id}', timeout=10)
            user_response.raise_for_status()
            user_data = user_response.json()
        except Exception as e:
            response = jsonify({
                'status': 'error',
                'message': f'Failed to connect to AWS API Gateway: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
            return (response, 500, headers)
        
        # Fetch all orders
        try:
            orders_response = requests.get(f'{API_GATEWAY_URL}/api/orders', timeout=10)
            orders_response.raise_for_status()
            all_orders = orders_response.json()
        except Exception as e:
            response = jsonify({
                'status': 'error',
                'message': f'Failed to fetch orders: {str(e)}',
                'timestamp': datetime.utcnow().isoformat()
            })
            return (response, 500, headers)
        
        # Filter orders for this user
        user_orders = [order for order in all_orders if str(order.get('user_id')) == str(user_id)]
        
        # Calculate analytics
        total_orders = len(user_orders)
        total_spent = sum(float(order.get('total_price', 0)) for order in user_orders)
        avg_order_value = total_spent / total_orders if total_orders > 0 else 0
        
        # Generate insights
        customer_tier = 'VIP' if total_spent > 10000 else 'Premium' if total_spent > 5000 else 'Regular'
        
        recommendations = []
        if total_orders > 5:
            recommendations.append('Loyalty reward eligible - 10% discount on next order')
        if avg_order_value > 1000:
            recommendations.append('Premium customer - priority shipping available')
        if total_spent > 20000:
            recommendations.append('Top VIP - personal account manager assigned')
        
        # Build response
        analytics = {
            'status': 'success',
            'timestamp': datetime.utcnow().isoformat(),
            'user_info': {
                'user_id': user_id,
                'name': user_data.get('name', 'Unknown'),
                'email': user_data.get('email', 'Unknown')
            },
            'order_analytics': {
                'total_orders': total_orders,
                'total_spent': round(total_spent, 2),
                'average_order_value': round(avg_order_value, 2),
                'customer_tier': customer_tier
            },
            'recommendations': recommendations,
            'insights': {
                'spending_category': 'High Spender' if total_spent > 10000 else 'Moderate Spender' if total_spent > 1000 else 'New Customer',
                'loyalty_score': min(100, int((total_orders * 10) + (total_spent / 100))),
                'predicted_lifetime_value': round(total_spent * 1.5, 2)  # Simple prediction
            }
        }
        
        response = jsonify(analytics)
        return (response, 200, headers)
        
    except Exception as e:
        response = jsonify({
            'status': 'error',
            'message': f'Internal error: {str(e)}',
            'timestamp': datetime.utcnow().isoformat()
        })
        return (response, 500, headers)
