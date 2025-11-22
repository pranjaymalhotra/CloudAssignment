# VIVA Preparation Guide - E-Commerce Cloud Platform

## 🎯 Project Overview (30 seconds)

**What:** Enterprise e-commerce platform with 6 microservices on multi-cloud architecture (AWS + GCP)

**Technologies:** Kubernetes (EKS), Apache Flink, Kafka, Terraform, ArgoCD, Python/Flask

**Purpose:** Demonstrate cloud-native design patterns, auto-scaling, real-time stream processing, and GitOps

---

## 📋 Architecture Components

### 1. **Microservices (6 Services)**

#### **API Gateway** (Port 5000)
- **What it does:** Entry point for all client requests
- **How it works:** Routes HTTP requests to appropriate backend services
- **Technology:** Flask with CORS enabled
- **Why:** Single entry point, simplifies client interaction, handles load balancing
- **Scaling:** HPA (2-10 pods based on CPU 70%, Memory 80%)

#### **User Service** (Port 5001)
- **What it does:** Manages user accounts and authentication
- **How it works:** CRUD operations on MySQL database
- **Storage:** RDS MySQL (relational data)
- **Endpoints:** POST /users, GET /users, GET /users/:id
- **Why:** Separate concern for user management

#### **Product Service** (Port 5002)
- **What it does:** Product catalog management
- **How it works:** Stores products in NoSQL database
- **Storage:** DynamoDB (high-throughput, schema-less)
- **Why:** Products need flexible schema, high read performance
- **Key Feature:** Auto-generated UUID for product IDs

#### **Order Service** (Port 5003)
- **What it does:** Processes orders and publishes events
- **How it works:** 
  1. Stores order in MySQL
  2. Publishes event to Kafka for downstream processing
- **Storage:** RDS MySQL (transactional data)
- **Messaging:** Kafka producer
- **Scaling:** HPA (2-8 pods)
- **Why:** Orders need ACID compliance + event notification

#### **Notification Service** (Port 5004)
- **What it does:** Sends notifications when orders are placed
- **How it works:** 
  1. Kafka consumer listens to 'orders' topic
  2. Receives order events in real-time
  3. Sends notifications (email/SMS simulation)
- **Pattern:** Event-driven architecture
- **Why:** Decoupled, asynchronous processing

#### **Analytics Service** (Port 5005)
- **What it does:** Provides aggregated analytics data
- **How it works:** Reads pre-computed results from DynamoDB
- **Storage:** DynamoDB (analytics-results)
- **Endpoints:** GET /analytics/summary, GET /analytics/recent
- **Why:** Fast read access to analytics data

---

### 2. **Serverless Function (Lambda)**

**S3 File Processor**
- **Trigger:** S3 object creation event
- **What it does:** Processes uploaded files (CSV, JSON, images)
- **How it works:**
  1. File uploaded to S3 bucket
  2. S3 triggers Lambda function
  3. Lambda processes file (parse, validate, transform)
  4. Stores metadata in DynamoDB
- **Why:** Event-driven, pay-per-use, no server management

---

### 3. **Stream Processing (GCP Flink)**

**Apache Flink on Dataproc**
- **What it does:** Real-time analytics on order stream
- **How it works:**
  1. Consumes events from AWS MSK Kafka (orders topic)
  2. Performs stateful aggregation (count orders per user)
  3. Uses 1-minute tumbling window
  4. Publishes results to 'analytics-results' topic
- **Why on GCP:** Multi-cloud requirement, Flink on managed cluster
- **Code:** Java/Maven application
- **Key Feature:** Cross-cloud integration (AWS Kafka → GCP Flink)

---

### 4. **Infrastructure as Code (Terraform)**

**AWS Resources (48+ resources):**
```
VPC → Subnets → Security Groups → NAT Gateways
         ↓
    EKS Cluster (2 nodes)
         ↓
    RDS MySQL + DynamoDB + S3 + MSK Kafka + Lambda
```

**GCP Resources:**
```
VPC → Subnet → Firewall
      ↓
Dataproc Cluster (1 master + 2 workers with Flink)
      ↓
Cloud Storage (Flink JARs, checkpoints)
```

**Why Terraform:** Reproducible, version-controlled, consistent deployments

---

### 5. **GitOps Deployment (ArgoCD)**

**How it works:**
1. Code pushed to GitHub repository
2. ArgoCD monitors Git repository
3. Detects changes in `kubernetes/` directory
4. Automatically syncs to EKS cluster
5. Self-heals if manual changes are made

**Why GitOps:** 
- Single source of truth (Git)
- Automated deployments
- Audit trail
- Easy rollback

**Config:** `kubernetes/argocd/applications/microservices-app.yaml`

---

### 6. **Auto-Scaling (HPA)**

**Two HPAs Configured:**

**API Gateway HPA:**
- Min: 2 pods, Max: 10 pods
- Triggers: CPU > 70% OR Memory > 80%
- **Why:** Handle traffic spikes at entry point

**Order Service HPA:**
- Min: 2 pods, Max: 8 pods
- Triggers: CPU > 70% OR Memory > 80%
- **Why:** Order processing is CPU-intensive

**How it works:**
1. Metrics-server collects pod metrics
2. HPA controller checks every 15 seconds
3. If threshold exceeded, scales out
4. If load decreases, scales in (after 5 min cooldown)

---

### 7. **Storage Strategy (3 Types)**

| Type | Service | Use Case | Why |
|------|---------|----------|-----|
| **Object Store** | S3 | File uploads, raw data | Scalable, durable, cost-effective |
| **Relational SQL** | RDS MySQL | Users, Orders | ACID compliance, relationships |
| **NoSQL** | DynamoDB | Products, Analytics | High throughput, flexible schema |

---

### 8. **Observability Stack**

**Prometheus:**
- Scrapes metrics from all pods
- Stores time-series data
- Monitors CPU, memory, request rate, latency

**Grafana:**
- Visualizes Prometheus metrics
- Pre-built dashboards:
  - Kubernetes cluster health
  - Service request rates (RPS)
  - Error rates
  - P50/P95/P99 latency

**Logging:**
- Application logs via stdout/stderr
- kubectl logs for pod logs
- CloudWatch integration

---

### 9. **Load Testing (k6)**

**What:** Simulates real user traffic

**Scenarios:**
1. Warm-up: 10 users for 30s
2. Ramp-up: 10→100 users over 2 min
3. Sustained load: 100 users for 5 min
4. Spike: 200 users for 1 min
5. Ramp-down: 200→10 users

**Purpose:** Validate HPA scaling

**Expected Results:**
- API Gateway: 2 → 10 pods
- Order Service: 2 → 8 pods
- P95 latency < 500ms
- Success rate > 95%

---

## 🔄 Complete Pipeline Flow

### **User Places Order (End-to-End):**

```
1. Frontend (Browser)
   ↓ HTTP POST /api/orders
   
2. LoadBalancer
   ↓ Routes to
   
3. API Gateway Pod
   ↓ Forwards to
   
4. Order Service Pod
   ├─→ Stores in RDS MySQL (transactional)
   └─→ Publishes to Kafka (event)
   
5. Kafka (MSK)
   ├─→ Notification Service (AWS)
   │   └─→ Sends notification
   │
   └─→ Flink Job (GCP Dataproc)
       ├─→ Aggregates in 1-min window
       └─→ Publishes to 'analytics-results' topic
       
6. Analytics Service
   └─→ Reads results from Kafka/DynamoDB
   └─→ Serves via /api/analytics
```

---

## 🎤 VIVA Questions & Answers

### **Q1: Why microservices instead of monolithic?**
**A:** 
- Independent scaling (Order service scales more than User service)
- Technology flexibility (can use different databases)
- Fault isolation (one service failure doesn't crash entire system)
- Team autonomy (different teams work on different services)

### **Q2: Why use Kafka instead of direct API calls?**
**A:**
- **Asynchronous:** Order service doesn't wait for notification
- **Decoupling:** Services don't need to know about each other
- **Reliability:** Messages persist even if consumer is down
- **Scalability:** Can handle millions of events
- **Replay:** Can reprocess events if needed

### **Q3: Why HPA on only 2 services?**
**A:**
- API Gateway: Entry point, receives all traffic
- Order Service: CPU-intensive (database writes + Kafka publish)
- User/Product services: Read-heavy, relatively stable load
- Notification service: Event-driven, 1 replica sufficient

### **Q4: Why use both RDS and DynamoDB?**
**A:**
- **RDS (MySQL):** Orders need ACID transactions, foreign keys to users
- **DynamoDB:** Products don't need relationships, need high read throughput
- **Right tool for right job:** Relational vs. document data

### **Q5: What happens if a pod crashes?**
**A:**
1. Kubernetes detects pod failure
2. Restarts pod automatically (liveness probe)
3. Service routes traffic to healthy pods only
4. ArgoCD ensures desired state is maintained

### **Q6: Why Flink on GCP instead of AWS?**
**A:**
- **Requirement:** Stream processing on Provider B (multi-cloud)
- **GCP Dataproc:** Managed Flink cluster
- **Cross-cloud:** Demonstrates cloud-agnostic architecture
- **Cost:** Can use GCP free credits

### **Q7: How does GitOps ensure no manual kubectl apply?**
**A:**
1. All configs stored in Git
2. ArgoCD watches Git repository
3. Any Git change auto-deploys to cluster
4. If someone runs kubectl manually, ArgoCD reverts it (self-heal)
5. Audit trail: All changes tracked in Git history

### **Q8: How do you handle secrets?**
**A:**
- Kubernetes Secrets for sensitive data
- Environment variables for configs
- IAM roles for AWS service access (no hardcoded credentials)
- ConfigMaps for non-sensitive configuration

### **Q9: What's the difference between HPA and VPA?**
**A:**
- **HPA (Horizontal):** Adds more pods (scales out)
- **VPA (Vertical):** Increases CPU/memory per pod (scales up)
- **Our choice:** HPA - better for handling traffic spikes

### **Q10: Disaster recovery strategy?**
**A:**
- **Infrastructure:** Terraform can rebuild everything
- **Data:** RDS automated backups (7 days)
- **DynamoDB:** Point-in-time recovery enabled
- **Multi-AZ:** RDS in multiple availability zones
- **State:** All configs in Git, can redeploy anytime

---

## 📊 Requirements Verification

| # | Requirement | ✓ | Proof |
|---|-------------|---|-------|
| a | 100% IaC (Terraform) | ✅ | `terraform/aws/`, `terraform/gcp/` |
| b | 6 microservices + serverless | ✅ | 6 Flask services + Lambda |
| c | Managed K8s + HPA | ✅ | EKS + 2 HPAs |
| d | GitOps (ArgoCD) | ✅ | `kubernetes/argocd/` |
| e | Flink on Provider B | ✅ | GCP Dataproc + Kafka |
| f | 3 storage types | ✅ | S3 + RDS + DynamoDB |
| g | Prometheus + Grafana | ✅ | Helm installation |
| h | Load testing + HPA | ✅ | k6 scripts |

---

## 🚀 Demo Steps (For VIVA)

### **Step 1: Show Architecture**
```
Open docs/DESIGN.md - explain diagram
```

### **Step 2: Show Code**
```bash
# Show microservice
cat microservices/order-service/app.py | head -50

# Show Terraform
cat terraform/aws/main.tf | head -30

# Show Flink job
cat analytics/src/main/java/com/ecommerce/analytics/OrderAnalyticsJob.java
```

### **Step 3: Show Running Services**
```bash
# List all pods
kubectl get pods

# Show HPAs
kubectl get hpa

# Show services
kubectl get svc
```

### **Step 4: Test API**
```bash
# Health check
curl http://<LOAD_BALANCER>/health

# Create user
curl -X POST http://<LB>/api/users \
  -H "Content-Type: application/json" \
  -d '{"name":"Demo User","email":"demo@test.com"}'

# Get users
curl http://<LB>/api/users
```

### **Step 5: Show Monitoring**
```bash
# Port-forward Grafana
kubectl port-forward svc/prometheus-grafana 3000:80

# Open http://localhost:3000
# Show dashboards
```

### **Step 6: Run Load Test**
```bash
cd load-testing
k6 run load-test.js

# Watch scaling
kubectl get hpa --watch
```

---

## 💡 Key Technical Decisions

### **Why Flask over Spring Boot?**
- Lightweight, fast development
- Python ecosystem for data processing
- Easy containerization

### **Why MSK over self-hosted Kafka?**
- Managed service (AWS handles operations)
- Automatic scaling
- Built-in monitoring
- Multi-AZ for high availability

### **Why ArgoCD over Jenkins?**
- Kubernetes-native
- Declarative (desired state in Git)
- Built-in diff/sync
- Better visibility

### **Why Prometheus over CloudWatch?**
- Open-source, portable
- Better for Kubernetes
- Rich query language (PromQL)
- Integration with Grafana

---

## 🎯 Project Highlights

1. **Multi-Cloud:** AWS (main) + GCP (analytics) = cloud-agnostic
2. **Event-Driven:** Kafka for async, decoupled communication
3. **Auto-Scaling:** HPAs respond to load automatically
4. **GitOps:** Single source of truth, automated deployments
5. **Observability:** Full visibility with Prometheus + Grafana
6. **Real-time Processing:** Flink performs windowed aggregations
7. **IaC:** Entire infrastructure reproducible with Terraform
8. **Load Tested:** Validated with k6, proven to scale

---

## 📝 Quick Command Reference

### **Check Status:**
```bash
kubectl get pods                    # All pods
kubectl get hpa                     # Autoscalers
kubectl get svc                     # Services
kubectl logs <pod-name>             # Logs
```

### **Deploy:**
```bash
terraform apply -auto-approve       # Deploy infra
kubectl apply -f kubernetes/        # Deploy apps
```

### **Test:**
```bash
./test-api.sh                       # API tests
k6 run load-testing/load-test.js   # Load test
```

### **Monitor:**
```bash
kubectl port-forward svc/prometheus-grafana 3000:80
# Open http://localhost:3000
```

---

## 🏆 Project Strengths

- ✅ Production-ready architecture
- ✅ All 8 requirements met
- ✅ Comprehensive documentation
- ✅ Automated testing
- ✅ Clean, maintainable code
- ✅ Multi-cloud implementation
- ✅ Real-world design patterns

---

**Remember:** Be confident, know your architecture, and explain WHY you made each decision!

**Good Luck! 🚀**
