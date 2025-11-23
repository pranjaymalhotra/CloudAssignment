import functions_framework
import json
from datetime import datetime
import os
import requests

@functions_framework.http
def analyze_user(request):
    """HTTP Cloud Function for analyzing user order history.
    Calls AWS API Gateway to fetch data (which connects to AWS RDS).
    This demonstrates GCP → AWS cross-cloud integration.
    """
    
    # Set CORS headers for the preflight request
    if request.method == 'OPTIONS':
        headers = {
            'Access-Control-Allow-Origin': '*',
            'Access-Control-Allow-Methods': 'GET, POST',
            'Access-Control-Allow-Headers': 'Content-Type',
            'Access-Control-Max-Age': '3600'
        }
        return ('', 204, headers)

    # Set CORS headers for the main request
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Content-Type': 'application/json'
    }

    try:
        # Get user_id from request
        request_json = request.get_json(silent=True)
        request_args = request.args
        
        user_id = None
        if request_json and 'user_id' in request_json:
            user_id = request_json['user_id']
        elif request_args and 'user_id' in request_args:
            user_id = request_args['user_id']
        
        if not user_id:
            return (json.dumps({'error': 'user_id is required'}), 400, headers)
        
        # Call AWS API Gateway (which connects to AWS RDS)
        # This is true cross-cloud integration: GCP → AWS
        api_gateway_url = os.environ.get('API_GATEWAY_URL', 'http://ab5f1ab6f0e634756bc7fb5c74faf562-1234779937.us-east-1.elb.amazonaws.com')
        
        # Fetch user info from AWS API Gateway
        user_response = requests.get(f'{api_gateway_url}/api/users/{user_id}', timeout=10)
        if user_response.status_code == 404:
            return (json.dumps({'error': f'User {user_id} not found'}), 404, headers)
        
        user = user_response.json()
        
        # Fetch user orders from AWS API Gateway
        orders_response = requests.get(f'{api_gateway_url}/api/orders', timeout=10)
        all_orders = orders_response.json()
        
        # Filter orders for this user
        orders = [o for o in all_orders if str(o.get('user_id')) == str(user_id)]
        
        # Calculate analytics
        total_spent = sum(float(order.get('total_price', 0)) for order in orders)
        order_count = len(orders)
        avg_order_value = total_spent / order_count if order_count > 0 else 0
        
        # Determine customer segment
        if total_spent > 1000:
            customer_segment = 'VIP Customer'
            recommendation = 'Offer exclusive 20% discount + free shipping + priority support'
        elif total_spent > 500:
            customer_segment = 'High-Value'
            recommendation = 'Offer 15% discount on next purchase + free shipping'
        elif total_spent > 100:
            customer_segment = 'Regular Customer'
            recommendation = 'Send personalized product recommendations'
        elif order_count > 0:
            customer_segment = 'New Customer'
            recommendation = 'Welcome bonus: 10% off next order'
        else:
            customer_segment = 'No Orders'
            recommendation = 'Send welcome email with special offer'
        
        # Build response
        analytics = {
            'user_id': int(user_id),
            'name': user.get('name', f'User {user_id}'),
            'email': user.get('email', f'user{user_id}@example.com'),
            'order_count': order_count,
            'lifetime_value': round(total_spent, 2),
            'avg_order_value': round(avg_order_value, 2),
            'customer_segment': customer_segment,
            'recommendation': recommendation,
            'data_source': 'GCP Cloud Function → AWS API Gateway → AWS RDS MySQL',
            'cross_cloud_integration': True,
            'timestamp': datetime.now().isoformat()
        }
        
        return (json.dumps(analytics), 200, headers)
        
    except requests.exceptions.RequestException as e:
        return (json.dumps({
            'status': 'error',
            'message': f'Failed to connect to AWS API Gateway: {str(e)}',
            'timestamp': datetime.now().isoformat()
        }), 500, headers)
    except Exception as e:
        return (json.dumps({
            'status': 'error',
            'message': str(e),
            'timestamp': datetime.now().isoformat()
        }), 500, headers)
