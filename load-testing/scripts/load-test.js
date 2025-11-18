import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 10 },   // Ramp up to 10 users
    { duration: '5m', target: 50 },   // Stay at 50 users
    { duration: '2m', target: 100 },  // Ramp up to 100 users
    { duration: '5m', target: 100 },  // Stay at 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests under 500ms
    http_req_failed: ['rate<0.1'],    // Less than 10% errors
    errors: ['rate<0.1'],
  },
};

// Replace with your API Gateway URL
const API_URL = __ENV.API_URL || 'http://localhost';

export default function () {
  // Test 1: Create User
  let userPayload = JSON.stringify({
    name: `User${__VU}_${__ITER}`,
    email: `user${__VU}_${__ITER}@example.com`,
  });

  let userRes = http.post(`${API_URL}/api/users`, userPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(userRes, {
    'user created': (r) => r.status === 201 || r.status === 409,
  }) || errorRate.add(1);

  sleep(1);

  // Test 2: Get Users
  let getUsersRes = http.get(`${API_URL}/api/users`);
  
  check(getUsersRes, {
    'get users success': (r) => r.status === 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test 3: Create Product
  let productPayload = JSON.stringify({
    name: `Product${__VU}_${__ITER}`,
    price: Math.floor(Math.random() * 1000) + 10,
    stock: Math.floor(Math.random() * 100) + 1,
    category: 'electronics',
  });

  let productRes = http.post(`${API_URL}/api/products`, productPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(productRes, {
    'product created': (r) => r.status === 201,
  }) || errorRate.add(1);

  sleep(1);

  // Test 4: Get Products
  let getProductsRes = http.get(`${API_URL}/api/products`);
  
  check(getProductsRes, {
    'get products success': (r) => r.status === 200,
  }) || errorRate.add(1);

  sleep(1);

  // Test 5: Create Order
  let orderPayload = JSON.stringify({
    user_id: Math.floor(Math.random() * 10) + 1,
    product_id: `prod-${Math.floor(Math.random() * 100)}`,
    quantity: Math.floor(Math.random() * 5) + 1,
    total_price: Math.floor(Math.random() * 500) + 50,
  });

  let orderRes = http.post(`${API_URL}/api/orders`, orderPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  check(orderRes, {
    'order created': (r) => r.status === 201,
  }) || errorRate.add(1);

  sleep(2);
}

export function handleSummary(data) {
  return {
    'load-test-results.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options) {
  // Basic summary implementation
  return `
Load Test Summary:
==================
Total Requests: ${data.metrics.http_reqs.values.count}
Failed Requests: ${data.metrics.http_req_failed.values.rate * 100}%
Average Duration: ${data.metrics.http_req_duration.values.avg}ms
95th Percentile: ${data.metrics.http_req_duration.values['p(95)']}ms
  `;
}
