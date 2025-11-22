import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// Custom metrics
const requestDuration = new Trend('request_duration');
const successfulRequests = new Counter('successful_requests');
const failedRequests = new Counter('failed_requests');

// Test configuration
export const options = {
  stages: [
    { duration: '2m', target: 50 },   // Ramp up to 50 users over 2 minutes
    { duration: '5m', target: 100 },  // Stay at 100 users for 5 minutes (trigger HPA)
    { duration: '2m', target: 200 },  // Spike to 200 users for 2 minutes
    { duration: '3m', target: 100 },  // Scale down to 100 users
    { duration: '2m', target: 0 },    // Ramp down to 0 users
  ],
  thresholds: {
    http_req_duration: ['p(95)<500'], // 95% of requests should be below 500ms
    http_req_failed: ['rate<0.05'],   // Less than 5% of requests should fail
  },
};

// Get API URL from environment variable
const API_URL = __ENV.API_URL || 'http://ab5f1ab6f0e634756bc7fb5c74faf562-1234779937.us-east-1.elb.amazonaws.com/api';

export default function () {
  const scenarios = [
    testHealthCheck,
    testCreateUser,
    testGetUsers,
    testCreateProduct,
    testGetProducts,
    testCreateOrder,
    testGetOrders,
  ];

  // Randomly execute one of the scenarios
  const scenario = scenarios[Math.floor(Math.random() * scenarios.length)];
  scenario();

  sleep(1); // Wait 1 second between iterations
}

function testHealthCheck() {
  const res = http.get(`${API_URL}/health`);
  
  const success = check(res, {
    'health check status is 200': (r) => r.status === 200,
    'health check response time < 200ms': (r) => r.timings.duration < 200,
  });

  recordMetrics(res, success);
}

function testCreateUser() {
  const payload = JSON.stringify({
    name: `LoadTestUser${Date.now()}`,
    email: `loadtest${Date.now()}@example.com`,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(`${API_URL}/api/users`, payload, params);
  
  const success = check(res, {
    'create user status is 201': (r) => r.status === 201,
    'create user has id': (r) => JSON.parse(r.body).id !== undefined,
  });

  recordMetrics(res, success);
}

function testGetUsers() {
  const res = http.get(`${API_URL}/api/users`);
  
  const success = check(res, {
    'get users status is 200': (r) => r.status === 200,
    'get users returns array': (r) => Array.isArray(JSON.parse(r.body)),
  });

  recordMetrics(res, success);
}

function testCreateProduct() {
  const products = [
    { name: 'Gaming Laptop', description: 'High-performance laptop', price: 1999.99 },
    { name: 'Wireless Mouse', description: 'Ergonomic mouse', price: 79.99 },
    { name: 'Mechanical Keyboard', description: 'RGB keyboard', price: 149.99 },
    { name: 'Monitor 4K', description: '27-inch 4K display', price: 499.99 },
    { name: 'USB-C Hub', description: 'Multi-port hub', price: 59.99 },
  ];

  const product = products[Math.floor(Math.random() * products.length)];
  const payload = JSON.stringify(product);

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(`${API_URL}/api/products`, payload, params);
  
  const success = check(res, {
    'create product status is 201': (r) => r.status === 201,
    'create product has product_id': (r) => JSON.parse(r.body).product_id !== undefined,
  });

  recordMetrics(res, success);
}

function testGetProducts() {
  const res = http.get(`${API_URL}/api/products`);
  
  const success = check(res, {
    'get products status is 200': (r) => r.status === 200,
    'get products returns array': (r) => Array.isArray(JSON.parse(r.body)),
  });

  recordMetrics(res, success);
}

function testCreateOrder() {
  const payload = JSON.stringify({
    user_id: Math.floor(Math.random() * 100) + 1,
    product_id: `product-${Math.floor(Math.random() * 1000)}`,
    quantity: Math.floor(Math.random() * 5) + 1,
  });

  const params = {
    headers: {
      'Content-Type': 'application/json',
    },
  };

  const res = http.post(`${API_URL}/api/orders`, payload, params);
  
  const success = check(res, {
    'create order status is 201': (r) => r.status === 201,
    'create order has id': (r) => JSON.parse(r.body).id !== undefined,
  });

  recordMetrics(res, success);
}

function testGetOrders() {
  const res = http.get(`${API_URL}/api/orders`);
  
  const success = check(res, {
    'get orders status is 200': (r) => r.status === 200,
    'get orders returns array': (r) => Array.isArray(JSON.parse(r.body)),
  });

  recordMetrics(res, success);
}

function recordMetrics(response, success) {
  requestDuration.add(response.timings.duration);
  
  if (success) {
    successfulRequests.add(1);
  } else {
    failedRequests.add(1);
  }
}

export function handleSummary(data) {
  return {
    'load-test-results.json': JSON.stringify(data),
    stdout: textSummary(data, { indent: ' ', enableColors: true }),
  };
}

function textSummary(data, options = {}) {
  const indent = options.indent || '';
  const enableColors = options.enableColors || false;

  let summary = '\n';
  summary += `${indent}==================== LOAD TEST SUMMARY ====================\n\n`;
  summary += `${indent}Total Duration: ${(data.state.testRunDurationMs / 1000).toFixed(2)}s\n`;
  summary += `${indent}Total Requests: ${data.metrics.http_reqs.values.count}\n`;
  summary += `${indent}Failed Requests: ${data.metrics.http_req_failed.values.rate.toFixed(2)}%\n`;
  summary += `${indent}Requests/sec: ${data.metrics.http_reqs.values.rate.toFixed(2)}\n\n`;
  
  summary += `${indent}Response Times:\n`;
  summary += `${indent}  - Average: ${data.metrics.http_req_duration.values.avg.toFixed(2)}ms\n`;
  summary += `${indent}  - Min: ${data.metrics.http_req_duration.values.min.toFixed(2)}ms\n`;
  summary += `${indent}  - Max: ${data.metrics.http_req_duration.values.max.toFixed(2)}ms\n`;
  summary += `${indent}  - p(90): ${data.metrics.http_req_duration.values['p(90)'].toFixed(2)}ms\n`;
  summary += `${indent}  - p(95): ${data.metrics.http_req_duration.values['p(95)'].toFixed(2)}ms\n`;
  summary += `${indent}  - p(99): ${data.metrics.http_req_duration.values['p(99)'].toFixed(2)}ms\n\n`;
  
  summary += `${indent}Data Transfer:\n`;
  summary += `${indent}  - Sent: ${(data.metrics.data_sent.values.count / 1024 / 1024).toFixed(2)} MB\n`;
  summary += `${indent}  - Received: ${(data.metrics.data_received.values.count / 1024 / 1024).toFixed(2)} MB\n\n`;
  
  summary += `${indent}===========================================================\n`;
  
  return summary;
}
