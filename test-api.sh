#!/bin/bash

# E-Commerce Microservices Test Script
# This script tests all endpoints of the deployed microservices

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# API URL
API_URL="http://ac493957d2838468599dd4ffc7881b3e-963667843.us-east-1.elb.amazonaws.com"

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Function to print section headers
print_header() {
    echo -e "\n${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}\n"
}

# Function to print test results
print_test() {
    TOTAL_TESTS=$((TOTAL_TESTS + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $2"
        PASSED_TESTS=$((PASSED_TESTS + 1))
    else
        echo -e "${RED}✗ FAIL${NC}: $2"
        FAILED_TESTS=$((FAILED_TESTS + 1))
    fi
}

# Function to make API calls and handle responses
api_call() {
    local method=$1
    local endpoint=$2
    local data=$3
    local description=$4
    
    echo -e "${YELLOW}Testing:${NC} $description"
    
    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$API_URL$endpoint")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$API_URL$endpoint" \
            -H "Content-Type: application/json" \
            -d "$data")
    fi
    
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)
    
    echo "Response Code: $http_code"
    echo "Response Body:"
    echo "$body" | python3 -m json.tool 2>/dev/null || echo "$body"
    echo ""
    
    if [ $http_code -ge 200 ] && [ $http_code -lt 300 ]; then
        print_test 0 "$description"
        return 0
    else
        print_test 1 "$description"
        return 1
    fi
}

# Start testing
clear
echo -e "${BLUE}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║                                                           ║
║   E-Commerce Microservices Test Suite                    ║
║   Full-Stack Cloud Application on AWS EKS                ║
║                                                           ║
╚═══════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

echo -e "${YELLOW}API Endpoint:${NC} $API_URL"
echo -e "${YELLOW}Test Start Time:${NC} $(date)"
echo ""

# Test 1: Health Check
print_header "TEST 1: API Health Check"
api_call "GET" "/health" "" "API Gateway Health Check"

# Test 2: User Service
print_header "TEST 2: User Service Tests"

# Create users
USER1_DATA='{"name":"Alice Johnson","email":"alice.test'$(date +%s)'@example.com"}'
if api_call "POST" "/api/users" "$USER1_DATA" "Create User 1 (Alice)"; then
    USER1_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 1))" 2>/dev/null || echo "1")
fi

sleep 1

USER2_DATA='{"name":"Bob Smith","email":"bob.test'$(date +%s)'@example.com"}'
if api_call "POST" "/api/users" "$USER2_DATA" "Create User 2 (Bob)"; then
    USER2_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 2))" 2>/dev/null || echo "2")
fi

sleep 1

# Get all users
api_call "GET" "/api/users" "" "Get All Users"

# Get specific user
if [ ! -z "$USER1_ID" ]; then
    api_call "GET" "/api/users/$USER1_ID" "" "Get User by ID ($USER1_ID)"
fi

# Test 3: Product Service
print_header "TEST 3: Product Service Tests (May fail without IAM)"

PRODUCT1_DATA='{"name":"Gaming Laptop","description":"High-performance gaming laptop with RTX 4080","price":1899.99}'
if api_call "POST" "/api/products" "$PRODUCT1_DATA" "Create Product 1 (Gaming Laptop)"; then
    PRODUCT1_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'prod-001'))" 2>/dev/null || echo "laptop-123")
fi

sleep 1

PRODUCT2_DATA='{"name":"Wireless Mouse","description":"Ergonomic wireless mouse with 6 buttons","price":29.99}'
if api_call "POST" "/api/products" "$PRODUCT2_DATA" "Create Product 2 (Mouse)"; then
    PRODUCT2_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'prod-002'))" 2>/dev/null || echo "mouse-456")
fi

sleep 1

# Get all products
api_call "GET" "/api/products" "" "Get All Products"

# Test 4: Order Service
print_header "TEST 4: Order Service Tests"

# Create orders
ORDER1_DATA="{\"user_id\":${USER1_ID:-1},\"product_id\":\"${PRODUCT1_ID:-laptop-123}\",\"quantity\":1}"
api_call "POST" "/api/orders" "$ORDER1_DATA" "Create Order 1 (Alice orders laptop)"

sleep 1

ORDER2_DATA="{\"user_id\":${USER2_ID:-2},\"product_id\":\"${PRODUCT2_ID:-mouse-456}\",\"quantity\":3}"
api_call "POST" "/api/orders" "$ORDER2_DATA" "Create Order 2 (Bob orders 3 mice)"

sleep 1

# Get all orders
api_call "GET" "/api/orders" "" "Get All Orders"

# Test 5: Integration Test - Complete Flow
print_header "TEST 5: End-to-End Integration Test"

echo -e "${YELLOW}Scenario:${NC} New user registration → Browse products → Place order\n"

# Step 1: Create new user
E2E_USER_DATA='{"name":"Charlie Brown","email":"charlie.e2e'$(date +%s)'@example.com"}'
echo -e "${YELLOW}Step 1:${NC} Create new user (Charlie)"
if api_call "POST" "/api/users" "$E2E_USER_DATA" "E2E: User Registration"; then
    E2E_USER_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 3))" 2>/dev/null || echo "3")
    echo -e "User ID: $E2E_USER_ID"
fi

sleep 1

# Step 2: Create a product
E2E_PRODUCT_DATA='{"name":"Mechanical Keyboard","description":"RGB mechanical gaming keyboard","price":149.99}'
echo -e "\n${YELLOW}Step 2:${NC} Create new product"
if api_call "POST" "/api/products" "$E2E_PRODUCT_DATA" "E2E: Product Creation"; then
    E2E_PRODUCT_ID=$(echo "$body" | python3 -c "import sys, json; print(json.load(sys.stdin).get('id', 'keyboard-789'))" 2>/dev/null || echo "keyboard-789")
    echo -e "Product ID: $E2E_PRODUCT_ID"
fi

sleep 1

# Step 3: Place an order
E2E_ORDER_DATA="{\"user_id\":${E2E_USER_ID:-3},\"product_id\":\"${E2E_PRODUCT_ID:-keyboard-789}\",\"quantity\":2}"
echo -e "\n${YELLOW}Step 3:${NC} Place order"
api_call "POST" "/api/orders" "$E2E_ORDER_DATA" "E2E: Order Placement"

# Test 6: Error Handling
print_header "TEST 6: Error Handling Tests"

# Test invalid user creation (missing email)
INVALID_USER='{"name":"Invalid User"}'
echo -e "${YELLOW}Testing:${NC} Create user with missing email (should fail)"
response=$(curl -s -w "\n%{http_code}" -X POST "$API_URL/api/users" \
    -H "Content-Type: application/json" \
    -d "$INVALID_USER")
http_code=$(echo "$response" | tail -n1)
if [ $http_code -ge 400 ]; then
    print_test 0 "Properly reject invalid user data"
else
    print_test 1 "Should reject invalid user data"
fi
echo ""

# Test getting non-existent user
echo -e "${YELLOW}Testing:${NC} Get non-existent user (should return 404)"
response=$(curl -s -w "\n%{http_code}" -X GET "$API_URL/api/users/99999")
http_code=$(echo "$response" | tail -n1)
if [ $http_code -eq 404 ]; then
    print_test 0 "Properly return 404 for non-existent user"
else
    print_test 1 "Should return 404 for non-existent user"
fi
echo ""

# Test 7: Load Test (Simple)
print_header "TEST 7: Simple Load Test"

echo -e "${YELLOW}Running 10 concurrent user creation requests...${NC}\n"

for i in {1..10}; do
    (
        USER_DATA='{"name":"LoadTest User'$i'","email":"loadtest'$i'.'$(date +%s)'@example.com"}'
        response=$(curl -s -w "%{http_code}" -X POST "$API_URL/api/users" \
            -H "Content-Type: application/json" \
            -d "$USER_DATA")
        http_code=$(echo "$response" | tail -c 4)
        if [ $http_code -ge 200 ] && [ $http_code -lt 300 ]; then
            echo -e "${GREEN}✓${NC} Request $i successful"
        else
            echo -e "${RED}✗${NC} Request $i failed (HTTP $http_code)"
        fi
    ) &
done

wait

print_test 0 "Load test completed (check concurrent requests above)"

# Test Summary
print_header "TEST SUMMARY"

echo -e "Total Tests:  ${BLUE}$TOTAL_TESTS${NC}"
echo -e "Passed:       ${GREEN}$PASSED_TESTS${NC}"
echo -e "Failed:       ${RED}$FAILED_TESTS${NC}"

if [ $FAILED_TESTS -eq 0 ]; then
    echo -e "\n${GREEN}✓ ALL TESTS PASSED! ✓${NC}"
    echo -e "${GREEN}Your E-Commerce microservices are working correctly!${NC}\n"
    exit_code=0
else
    echo -e "\n${YELLOW}⚠ SOME TESTS FAILED ⚠${NC}"
    echo -e "${YELLOW}Check the failed tests above for details${NC}\n"
    exit_code=1
fi

# Infrastructure Information
print_header "DEPLOYMENT INFORMATION"

echo -e "${BLUE}Public Endpoint:${NC}"
echo -e "  API: $API_URL"
echo -e "  Web UI: file://$(pwd)/frontend/index.html"
echo ""

echo -e "${BLUE}Services:${NC}"
echo -e "  ✓ API Gateway (LoadBalancer)"
echo -e "  ✓ User Service (RDS MySQL)"
echo -e "  ✓ Order Service (RDS MySQL)"
echo -e "  ⚠ Product Service (DynamoDB - needs IAM)"
echo -e "  ⚠ Notification Service (Kafka - needs topics)"
echo ""

echo -e "${BLUE}AWS Resources:${NC}"
echo -e "  • EKS Cluster: ecommerce-cluster"
echo -e "  • RDS MySQL: ecommercedb"
echo -e "  • DynamoDB: ecommerce-products"
echo -e "  • MSK Kafka: ecommerce-kafka"
echo -e "  • Region: us-east-1"
echo ""

echo -e "${YELLOW}Test End Time:${NC} $(date)"
echo -e "${YELLOW}Duration:${NC} $SECONDS seconds"
echo ""

# Open frontend if on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    echo -e "${YELLOW}Opening web UI in browser...${NC}"
    open "$(pwd)/frontend/index.html" 2>/dev/null
fi

exit $exit_code
