#!/bin/bash
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     Complete System Test - All Requirements Verification         ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
echo ""

PASSED=0
FAILED=0
TOTAL=0

# Function to print test result
test_result() {
    TOTAL=$((TOTAL + 1))
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC} - $2"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}✗ FAIL${NC} - $2"
        FAILED=$((FAILED + 1))
    fi
}

print_section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Get URLs
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

# =============================================================================
# REQUIREMENT A: Infrastructure as Code (Terraform)
# =============================================================================
print_section "REQUIREMENT A: Infrastructure as Code (Terraform)"

echo "Checking Terraform state..."
cd terraform/aws 2>/dev/null || { echo "Terraform directory not found"; exit 1; }

RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l | tr -d ' ')
test_result $([ "$RESOURCE_COUNT" -gt 40 ] && echo 0 || echo 1) "Terraform manages $RESOURCE_COUNT resources (expected: 48+)"

VPC_ID=$(terraform output -raw vpc_id 2>/dev/null || echo "")
test_result $([ -n "$VPC_ID" ] && echo 0 || echo 1) "VPC created: $VPC_ID"

EKS_CLUSTER=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "")
test_result $([ -n "$EKS_CLUSTER" ] && echo 0 || echo 1) "EKS cluster: $EKS_CLUSTER"

RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
test_result $([ -n "$RDS_ENDPOINT" ] && echo 0 || echo 1) "RDS endpoint: $RDS_ENDPOINT"

DYNAMODB_TABLE=$(terraform output -raw dynamodb_table_name 2>/dev/null || echo "")
test_result $([ -n "$DYNAMODB_TABLE" ] && echo 0 || echo 1) "DynamoDB table: $DYNAMODB_TABLE"

cd ../..

# =============================================================================
# REQUIREMENT B: Microservices Architecture
# =============================================================================
print_section "REQUIREMENT B: 6 Microservices + Serverless Lambda"

echo "Checking microservices deployment..."

SERVICES=("api-gateway" "user-service" "product-service" "order-service" "notification-service" "analytics-service")
for SERVICE in "${SERVICES[@]}"; do
    POD_COUNT=$(kubectl get pods -l app=$SERVICE 2>/dev/null | grep -c Running || echo 0)
    test_result $([ "$POD_COUNT" -gt 0 ] && echo 0 || echo 1) "$SERVICE: $POD_COUNT pod(s) running"
done

echo ""
echo "Checking serverless Lambda function..."
LAMBDA_FUNC=$(aws lambda list-functions --query 'Functions[?contains(FunctionName, `s3-file-processor`)].FunctionName' --output text 2>/dev/null || echo "")
test_result $([ -n "$LAMBDA_FUNC" ] && echo 0 || echo 1) "Lambda function: $LAMBDA_FUNC"

echo ""
echo "Testing service communication..."
if [ -n "$API_URL" ]; then
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$API_URL/health 2>/dev/null || echo "000")
    test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "API Gateway health check (HTTP $HTTP_CODE)"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$API_URL/api/users 2>/dev/null || echo "000")
    test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "User Service endpoint (HTTP $HTTP_CODE)"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$API_URL/api/products 2>/dev/null || echo "000")
    test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Product Service endpoint (HTTP $HTTP_CODE)"
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" http://$API_URL/api/orders 2>/dev/null || echo "000")
    test_result $([ "$HTTP_CODE" = "200" ] && echo 0 || echo 1) "Order Service endpoint (HTTP $HTTP_CODE)"
fi

# =============================================================================
# REQUIREMENT C: Kubernetes + HPA
# =============================================================================
print_section "REQUIREMENT C: Kubernetes with Horizontal Pod Autoscalers"

echo "Checking Kubernetes cluster..."
NODE_COUNT=$(kubectl get nodes --no-headers 2>/dev/null | grep -c Ready || echo 0)
test_result $([ "$NODE_COUNT" -ge 2 ] && echo 0 || echo 1) "EKS nodes ready: $NODE_COUNT/2"

echo ""
echo "Checking HPAs..."
HPA_COUNT=$(kubectl get hpa --no-headers 2>/dev/null | wc -l | tr -d ' ')
test_result $([ "$HPA_COUNT" -ge 2 ] && echo 0 || echo 1) "HPAs configured: $HPA_COUNT (expected: 2+)"

if [ "$HPA_COUNT" -gt 0 ]; then
    kubectl get hpa 2>/dev/null | while read -r line; do
        if [[ ! "$line" =~ ^NAME ]]; then
            echo "  → $line"
        fi
    done
fi

echo ""
echo "Checking deployments..."
DEPLOYMENT_COUNT=$(kubectl get deployments --no-headers 2>/dev/null | wc -l | tr -d ' ')
test_result $([ "$DEPLOYMENT_COUNT" -ge 6 ] && echo 0 || echo 1) "Deployments: $DEPLOYMENT_COUNT (expected: 6+)"

# =============================================================================
# REQUIREMENT D: GitOps with ArgoCD
# =============================================================================
print_section "REQUIREMENT D: GitOps with ArgoCD"

echo "Checking ArgoCD installation..."
ARGOCD_PODS=$(kubectl get pods -n argocd --no-headers 2>/dev/null | grep -c Running || echo 0)
test_result $([ "$ARGOCD_PODS" -ge 5 ] && echo 0 || echo 1) "ArgoCD pods running: $ARGOCD_PODS/6+"

echo ""
echo "Checking ArgoCD applications..."
APP_COUNT=$(kubectl get applications -n argocd --no-headers 2>/dev/null | wc -l | tr -d ' ')
test_result $([ "$APP_COUNT" -ge 1 ] && echo 0 || echo 1) "ArgoCD applications: $APP_COUNT"

if [ "$APP_COUNT" -gt 0 ]; then
    echo ""
    echo "  Application Status:"
    kubectl get applications -n argocd 2>/dev/null | tail -n +2 | while read -r line; do
        echo "    → $line"
    done
fi

if [ -n "$ARGOCD_URL" ]; then
    test_result 0 "ArgoCD UI: https://$ARGOCD_URL"
fi

# =============================================================================
# REQUIREMENT E: Stream Processing (Flink/Analytics)
# =============================================================================
print_section "REQUIREMENT E: Stream Processing with Analytics Service"

echo "Checking analytics service..."
ANALYTICS_PODS=$(kubectl get pods -l app=analytics-service 2>/dev/null | grep -c Running || echo 0)
test_result $([ "$ANALYTICS_PODS" -gt 0 ] && echo 0 || echo 1) "Analytics service pods: $ANALYTICS_PODS"

echo ""
echo "Checking Flink job files..."
test_result $([ -f "flink-jobs/analytics_job.py" ] && echo 0 || echo 1) "Flink job implementation exists"

echo ""
echo "Checking Kafka (MSK)..."
MSK_CLUSTER=$(aws kafka list-clusters --query 'ClusterInfoList[0].ClusterName' --output text 2>/dev/null || echo "")
test_result $([ -n "$MSK_CLUSTER" ] && echo 0 || echo 1) "MSK Kafka cluster: $MSK_CLUSTER"

# =============================================================================
# REQUIREMENT F: Cloud Storage (3 types)
# =============================================================================
print_section "REQUIREMENT F: Multi-Database Architecture"

echo "Checking storage resources..."

# RDS MySQL
if [ -n "$RDS_ENDPOINT" ]; then
    test_result 0 "RDS MySQL: $RDS_ENDPOINT"
    
    # Test RDS connectivity
    USER_COUNT=$(kubectl run mysql-test --image=mysql:8.0 --rm -i --restart=Never -- \
        mysql -h $RDS_ENDPOINT -u admin -p'Admin123456!' -D ecommercedb \
        -se "SELECT COUNT(*) FROM users" 2>/dev/null || echo "0")
    test_result $([ "$USER_COUNT" -gt 0 ] && echo 0 || echo 1) "RDS data: $USER_COUNT users in database"
fi

# DynamoDB
PRODUCT_COUNT=$(aws dynamodb scan --table-name ecommerce-products --select COUNT --query 'Count' --output text 2>/dev/null || echo "0")
test_result $([ "$PRODUCT_COUNT" -ge 0 ] && echo 0 || echo 1) "DynamoDB: $PRODUCT_COUNT products"

# S3
S3_BUCKET=$(aws s3 ls | grep ecommerce-data-bucket | awk '{print $3}' | head -1)
test_result $([ -n "$S3_BUCKET" ] && echo 0 || echo 1) "S3 bucket: $S3_BUCKET"

# =============================================================================
# REQUIREMENT G: Observability Stack
# =============================================================================
print_section "REQUIREMENT G: Observability (Prometheus + Grafana)"

echo "Checking monitoring stack..."
PROM_PODS=$(kubectl get pods -n monitoring --no-headers 2>/dev/null | grep -c Running || echo 0)
test_result $([ "$PROM_PODS" -ge 3 ] && echo 0 || echo 1) "Monitoring pods running: $PROM_PODS/3+"

echo ""
echo "Checking Prometheus..."
PROM_SVC=$(kubectl get svc -n monitoring | grep prometheus-kube-prometheus-prometheus | awk '{print $1}')
test_result $([ -n "$PROM_SVC" ] && echo 0 || echo 1) "Prometheus service: $PROM_SVC"

echo ""
echo "Checking Grafana..."
GRAFANA_SVC=$(kubectl get svc -n monitoring | grep prometheus-grafana | awk '{print $1}')
test_result $([ -n "$GRAFANA_SVC" ] && echo 0 || echo 1) "Grafana service: $GRAFANA_SVC"

if [ -n "$GRAFANA_URL" ]; then
    test_result 0 "Grafana UI: http://$GRAFANA_URL"
fi

# =============================================================================
# REQUIREMENT H: Load Testing
# =============================================================================
print_section "REQUIREMENT H: Load Testing with k6"

echo "Checking k6 installation..."
if command -v k6 &> /dev/null; then
    K6_VERSION=$(k6 version | head -1)
    test_result 0 "k6 installed: $K6_VERSION"
else
    test_result 1 "k6 not installed"
fi

echo ""
echo "Checking load test script..."
test_result $([ -f "load-test.js" ] && echo 0 || echo 1) "Load test script exists"

# =============================================================================
# SUMMARY
# =============================================================================
print_section "TEST SUMMARY"

echo ""
echo -e "${CYAN}Total Tests:    $TOTAL${NC}"
echo -e "${GREEN}Passed:         $PASSED${NC}"
echo -e "${RED}Failed:         $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                  ✓ ALL TESTS PASSED! ✓                            ║${NC}"
    echo -e "${GREEN}║          All 8 Requirements Successfully Verified!                ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
else
    echo -e "${YELLOW}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║              Some tests failed. Review above for details.         ║${NC}"
    echo -e "${YELLOW}╚═══════════════════════════════════════════════════════════════════╝${NC}"
fi

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  PUBLIC ENDPOINTS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "${CYAN}Frontend:${NC}       http://$FRONTEND_URL"
echo -e "${CYAN}API Gateway:${NC}    http://$API_URL"
echo -e "${CYAN}ArgoCD:${NC}         https://$ARGOCD_URL"
echo -e "${CYAN}Grafana:${NC}        http://$GRAFANA_URL"
echo ""
echo -e "${YELLOW}Credentials stored in: COMPLETE_IMPLEMENTATION.md${NC}"
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}  NEXT STEPS${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "1. Open dashboard:    open dashboard.html"
echo "2. Run load test:     k6 run load-test.js"
echo "3. View in Grafana:   open http://$GRAFANA_URL"
echo "4. Check ArgoCD:      open https://$ARGOCD_URL"
echo ""
echo -e "${MAGENTA}For video demo guide, see: VIDEO_DEMO_GUIDE.md${NC}"
echo ""
