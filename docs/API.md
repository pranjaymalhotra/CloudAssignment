# API Documentation

## Base URL
```
http://<API_GATEWAY_URL>
```

## Endpoints

### Health Check
```http
GET /health
```

**Response:**
```json
{
  "status": "healthy",
  "service": "api-gateway"
}
```

---

### Users

#### Get All Users
```http
GET /api/users
```

**Response:**
```json
[
  {
    "id": 1,
    "name": "John Doe",
    "email": "john@example.com",
    "created_at": "2025-11-18T10:00:00"
  }
]
```

#### Get User by ID
```http
GET /api/users/{user_id}
```

**Response:**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com",
  "created_at": "2025-11-18T10:00:00"
}
```

#### Create User
```http
POST /api/users
Content-Type: application/json

{
  "name": "John Doe",
  "email": "john@example.com"
}
```

**Response:**
```json
{
  "id": 1,
  "name": "John Doe",
  "email": "john@example.com"
}
```

---

### Products

#### Get All Products
```http
GET /api/products
```

**Response:**
```json
[
  {
    "product_id": "uuid-here",
    "name": "Laptop",
    "price": 999.99,
    "stock": 10,
    "category": "electronics"
  }
]
```

#### Get Product by ID
```http
GET /api/products/{product_id}
```

#### Create Product
```http
POST /api/products
Content-Type: application/json

{
  "name": "Laptop",
  "price": 999.99,
  "stock": 10,
  "category": "electronics"
}
```

---

### Orders

#### Get All Orders
```http
GET /api/orders
```

**Response:**
```json
[
  {
    "id": 1,
    "user_id": 1,
    "product_id": "uuid-here",
    "quantity": 2,
    "total_price": 1999.98,
    "status": "pending",
    "created_at": "2025-11-18T10:00:00"
  }
]
```

#### Get Order by ID
```http
GET /api/orders/{order_id}
```

#### Create Order
```http
POST /api/orders
Content-Type: application/json

{
  "user_id": 1,
  "product_id": "uuid-here",
  "quantity": 2,
  "total_price": 1999.98
}
```

**Response:**
```json
{
  "id": 1,
  "user_id": 1,
  "product_id": "uuid-here",
  "quantity": 2,
  "total_price": 1999.98,
  "status": "pending"
}
```

**Side Effect:** Publishes event to Kafka `orders` topic

---

## Testing with curl

```bash
# Get API Gateway URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Create a user
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com"}'

# Get all users
curl http://$API_URL/api/users

# Create a product
curl -X POST http://$API_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Laptop", "price": 999.99, "stock": 10, "category": "electronics"}'

# Create an order
curl -X POST http://$API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": "prod-123", "quantity": 2, "total_price": 1999.98}'
```
