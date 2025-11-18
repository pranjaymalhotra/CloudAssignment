import http from 'k6/http';
import { check, sleep } from 'k6';

// Stress test to trigger HPA scaling
export const options = {
  stages: [
    { duration: '1m', target: 50 },    // Ramp up
    { duration: '3m', target: 200 },   // Spike to trigger HPA
    { duration: '5m', target: 200 },   // Maintain load
    { duration: '2m', target: 0 },     // Ramp down
  ],
};

const API_URL = __ENV.API_URL || 'http://localhost';

export default function () {
  // Heavy load on order service to trigger HPA
  let orderPayload = JSON.stringify({
    user_id: Math.floor(Math.random() * 100) + 1,
    product_id: `prod-${Math.floor(Math.random() * 1000)}`,
    quantity: Math.floor(Math.random() * 10) + 1,
    total_price: Math.floor(Math.random() * 1000) + 100,
  });

  http.post(`${API_URL}/api/orders`, orderPayload, {
    headers: { 'Content-Type': 'application/json' },
  });

  // Also hit API gateway
  http.get(`${API_URL}/api/products`);
  
  sleep(0.5); // Faster pace for stress test
}
