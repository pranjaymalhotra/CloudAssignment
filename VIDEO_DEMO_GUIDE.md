# 🎥 AWS Cloud Assignment - Complete Video Demo Guide

## 📋 Overview
This guide provides a **step-by-step walkthrough** for demonstrating all 8 requirements in your AWS cloud assignment video. Each section includes what to show, what to say, and terminal commands to execute.

**Estimated Video Duration:** 15-20 minutes  
**Recording Tips:** 
- Use screen recording software (QuickTime, OBS, Loom)
- Show terminal and browser side-by-side when possible
- Speak clearly and explain what you're demonstrating
- Pause briefly between sections for editing

---

## 🎬 Video Structure

### Opening (1 minute)
**What to Show:**
- Title slide or dashboard overview
- Your name and assignment title

**What to Say:**
```
"Hello! I'm demonstrating my AWS Cloud Assignment implementing a complete 
microservices-based e-commerce platform with Infrastructure as Code, GitOps, 
observability, and load testing. This project includes 6 microservices, 
Kubernetes with autoscaling, ArgoCD for GitOps, Prometheus and Grafana for 
monitoring, and comprehensive load testing with k6."
```

**What to Do:**
1. Open `dashboard.html` in browser
2. Show the clean interface with all 8 requirements

```bash
open dashboard.html
```

---

## 📦 REQUIREMENT A: Infrastructure as Code (3 minutes)

### Show Terraform Configuration
**What to Show:**
- VS Code with Terraform files
- Terraform state
- AWS resources created

**What to Say:**
```
"Starting with Requirement A - Infrastructure as Code. I've used Terraform to 
define and provision all AWS infrastructure. Let me show you the Terraform 
configuration and the resources it manages."
```

**Terminal Commands:**
```bash
# Navigate to Terraform directory
cd terraform/aws

# Show Terraform configuration files
ls -la

# Display main Terraform file structure
cat main.tf | head -50

# Show current Terraform state - 48+ resources
terraform state list

# Show outputs (VPC, EKS, RDS, etc.)
terraform output

# Show resource count
terraform state list | wc -l
```

**AWS Console - What to Show:**
1. **VPC Dashboard**
   - Show VPC created by Terraform
   - Navigate to: AWS Console → VPC → Your VPCs
   - Point out: VPC ID, CIDR block, subnets

2. **EKS Cluster**
   - Navigate to: AWS Console → EKS → Clusters
   - Show: Cluster name (ecommerce-eks), version, status
   - Click on cluster → Show nodes tab

3. **RDS Database**
   - Navigate to: AWS Console → RDS → Databases
   - Show: Database identifier, engine (MySQL), endpoint
   - Point out: Multi-AZ, automated backups

4. **DynamoDB Tables**
   - Navigate to: AWS Console → DynamoDB → Tables
   - Show: ecommerce-products table
   - Show: ecommerce-analytics table (newly added)

5. **MSK (Kafka)**
   - Navigate to: AWS Console → MSK → Clusters
   - Show: Kafka cluster running
   - Point out: Brokers, topics

6. **S3 Bucket**
   - Navigate to: AWS Console → S3 → Buckets
   - Show: ecommerce-data-bucket
   - Show some uploaded files if available

---

## 🔧 REQUIREMENT B: Microservices Architecture (3 minutes)

### Show 6 Microservices + Lambda
**What to Say:**
```
"Requirement B - I've implemented 6 microservices using containerized applications, 
plus a serverless Lambda function for S3 file processing. Let me show you all 
services running in Kubernetes."
```

**Terminal Commands:**
```bash
# Show all running pods
kubectl get pods

# Show services with LoadBalancers
kubectl get svc

# Show deployments for all 6 microservices
kubectl get deployments

# Test API Gateway health
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -s http://$API_URL/health | jq

# Test User Service
curl -s http://$API_URL/api/users | jq

# Test Product Service
curl -s http://$API_URL/api/products | jq

# Test Order Service
curl -s http://$API_URL/api/orders | jq

# Show analytics service
kubectl get pods -l app=analytics-service
```

**AWS Console - What to Show:**
1. **EKS - Workloads**
   - Navigate to: AWS Console → EKS → Clusters → ecommerce-eks → Workloads
   - Show all 6 deployments running
   - Click on one deployment → Show pods

2. **Lambda Functions**
   - Navigate to: AWS Console → Lambda → Functions
   - Show: s3-file-processor function
   - Click on function → Show code and triggers

3. **ECR (Container Registry)**
   - Navigate to: AWS Console → ECR → Repositories
   - Show: All microservice container images
   - Click on one → Show image tags and push timestamps

**Browser - Test Frontend:**
```bash
# Get frontend URL
FRONTEND_URL=$(kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "Frontend: http://$FRONTEND_URL"

# Open in browser
open http://$FRONTEND_URL
```

**What to Show in Frontend:**
- Homepage loads correctly
- Navigation between pages
- Forms work (create user, product, order)

---

## ☸️ REQUIREMENT C: Kubernetes + HPA (2 minutes)

### Show Kubernetes Resources and Autoscaling
**What to Say:**
```
"Requirement C - The application runs on Amazon EKS with Horizontal Pod Autoscalers 
configured for automatic scaling based on CPU utilization."
```

**Terminal Commands:**
```bash
# Show EKS nodes
kubectl get nodes -o wide

# Show all HPAs
kubectl get hpa

# Show detailed HPA configuration for user-service
kubectl describe hpa user-service-hpa

# Show current pod counts
kubectl get pods -l app=user-service

# Show deployment replica configuration
kubectl get deployment user-service -o yaml | grep -A 5 replicas
```

**AWS Console - What to Show:**
1. **EKS Nodes**
   - Navigate to: AWS Console → EKS → Clusters → ecommerce-eks → Compute
   - Show: Node groups, instance types, scaling configuration

2. **Auto Scaling Groups**
   - Navigate to: AWS Console → EC2 → Auto Scaling Groups
   - Show: EKS node group ASG
   - Point out: Min/Max/Desired capacity

**What to Explain:**
- HPAs scale pods from 2 to 10 based on 70% CPU threshold
- Node auto-scaling handles infrastructure
- Demonstrated during load test (shown later)

---

## 🔄 REQUIREMENT D: GitOps with ArgoCD (3 minutes)

### Show ArgoCD GitOps Workflow
**What to Say:**
```
"Requirement D - I've implemented GitOps using ArgoCD for continuous deployment. 
ArgoCD automatically syncs the cluster state with our GitHub repository."
```

**Terminal Commands:**
```bash
# Show ArgoCD pods
kubectl get pods -n argocd

# Show ArgoCD applications
kubectl get applications -n argocd

# Get ArgoCD URL and credentials
ARGOCD_URL=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "ArgoCD URL: https://$ARGOCD_URL"
echo "Username: admin"
echo "Password: $ARGOCD_PASSWORD"
```

**Browser - ArgoCD UI:**
```bash
# Open ArgoCD in browser
open https://$ARGOCD_URL
```

**What to Show in ArgoCD:**
1. **Login Page**
   - Enter username: `admin`
   - Enter password: `mxhzOEkYqPBck8ui`

2. **Applications Dashboard**
   - Show: "microservices" application card
   - Point out: Sync status (Synced), Health status (Healthy)
   - Click on the application

3. **Application Details**
   - Show: Deployment graph with all resources
   - Point out: Pods, Services, Deployments connected
   - Show: Recent sync activity

4. **Application Configuration**
   - Click "App Details"
   - Show: GitHub repository URL
   - Show: Target revision (main branch)
   - Show: Auto-sync enabled

5. **Sync History**
   - Click "History and Rollback"
   - Show: Recent deployments
   - Explain: Can rollback to any previous version

**GitHub - Show Repository:**
```bash
# Open GitHub repository
open https://github.com/pranjaymalhotra/CloudAssignment
```

**What to Show in GitHub:**
- kubernetes/base/ directory with all manifests
- Recent commits
- Explain: Any push to main triggers ArgoCD sync

---

## 📊 REQUIREMENT E: Stream Processing (2 minutes)

### Show Analytics Service and Flink
**What to Say:**
```
"Requirement E - I've implemented real-time stream processing using Apache Flink 
and MSK Kafka. The analytics service processes order events in 1-minute windows."
```

**Terminal Commands:**
```bash
# Show analytics service
kubectl get pods -l app=analytics-service
kubectl logs -l app=analytics-service --tail=50

# Show Flink job implementation
cat flink-jobs/analytics_job.py | head -80
```

**AWS Console - What to Show:**
1. **MSK Cluster**
   - Navigate to: AWS Console → MSK → Clusters
   - Show: Cluster running
   - Click on cluster → Show: Brokers, bootstrap servers

2. **MSK Topics** (if accessible)
   - Show: orders-events topic
   - Show: analytics-results topic

3. **DynamoDB Analytics Table**
   - Navigate to: AWS Console → DynamoDB → Tables → ecommerce-analytics
   - Click "Explore table items"
   - Show: Analytics results with window_id and aggregated data
   - Point out: Unique users, total orders, revenue per window

**What to Explain:**
- Orders published to Kafka topic
- Flink job consumes events
- 1-minute tumbling window aggregation
- Results stored in DynamoDB
- Analytics service provides REST API

**Test Analytics Endpoint:**
```bash
curl -s http://$API_URL/api/analytics/summary | jq
curl -s http://$API_URL/api/analytics/recent | jq
```

---

## 💾 REQUIREMENT F: Multi-Database Architecture (2 minutes)

### Show 3 Storage Types
**What to Say:**
```
"Requirement F - I've implemented a multi-database architecture using three different 
storage types: RDS MySQL for relational data, DynamoDB for NoSQL, and S3 for object storage."
```

**AWS Console - What to Show:**
1. **RDS MySQL**
   - Navigate to: AWS Console → RDS → Databases → ecommerce-db
   - Show: Database details, endpoint, configuration
   - Click "Monitoring" tab → Show CPU, connections

2. **RDS Query Editor** (if available)
   - Click "Query Editor"
   - Connect to database
   - Run query:
   ```sql
   SELECT COUNT(*) as user_count FROM users;
   SELECT * FROM users LIMIT 5;
   ```

3. **DynamoDB - Products Table**
   - Navigate to: AWS Console → DynamoDB → Tables → ecommerce-products
   - Click "Explore table items"
   - Show: Products with attributes
   - Show: Table metrics

4. **DynamoDB - Analytics Table**
   - Navigate to: AWS Console → DynamoDB → Tables → ecommerce-analytics
   - Click "Explore table items"
   - Show: Analytics windows

5. **S3 Bucket**
   - Navigate to: AWS Console → S3 → Buckets → ecommerce-data-bucket
   - Show: Uploaded files
   - Click on a file → Show metadata, storage class

**Terminal Commands:**
```bash
# Show products in DynamoDB
aws dynamodb scan --table-name ecommerce-products --select COUNT

# Show analytics data
aws dynamodb scan --table-name ecommerce-analytics --max-items 5

# List S3 contents
aws s3 ls s3://$(aws s3 ls | grep ecommerce-data-bucket | awk '{print $3}')/ --recursive
```

---

## 📈 REQUIREMENT G: Observability (3 minutes)

### Show Prometheus + Grafana
**What to Say:**
```
"Requirement G - I've implemented comprehensive observability using Prometheus for 
metrics collection and Grafana for visualization with pre-configured dashboards."
```

**Terminal Commands:**
```bash
# Show monitoring stack
kubectl get pods -n monitoring

# Show monitoring services
kubectl get svc -n monitoring

# Get Grafana credentials
GRAFANA_URL=$(kubectl get svc prometheus-grafana -n monitoring -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
GRAFANA_PASSWORD=$(kubectl --namespace monitoring get secrets prometheus-grafana -o jsonpath="{.data.admin-password}" | base64 -d)

echo "Grafana URL: http://$GRAFANA_URL"
echo "Username: admin"
echo "Password: $GRAFANA_PASSWORD"
```

**Browser - Grafana UI:**
```bash
# Open Grafana
open http://$GRAFANA_URL
```

**What to Show in Grafana:**
1. **Login Page**
   - Username: `admin`
   - Password: `exs5QfljA7yxKUGkoTA9pD8twaas1AvYjrnDGvAr`

2. **Home Dashboard**
   - Show: Welcome screen
   - Navigate to: Dashboards

3. **Kubernetes Cluster Monitoring**
   - Click: Dashboards → Browse
   - Select: "Kubernetes / Compute Resources / Cluster"
   - Show: CPU usage, memory usage across nodes
   - Show: Network I/O
   - Point out: Real-time metrics

4. **Pod Monitoring**
   - Select: "Kubernetes / Compute Resources / Namespace (Pods)"
   - Select namespace: default
   - Show: Individual pod metrics
   - Show: CPU and memory per pod

5. **Node Exporter Dashboard**
   - Select: "Node Exporter / Nodes"
   - Show: Detailed node metrics
   - Show: Disk I/O, network traffic

6. **Create Custom Query**
   - Click: Explore (compass icon)
   - Select: Prometheus datasource
   - Query: `rate(container_cpu_usage_seconds_total[5m])`
   - Show: Real-time CPU usage graph

7. **Prometheus Targets**
   - Open Prometheus directly if available
   - Show: All targets being scraped
   - Show: Target health status

**What to Explain:**
- Prometheus scrapes metrics every 30 seconds
- Grafana provides 20+ pre-built dashboards
- Custom dashboards can be created
- Alerts can be configured

---

## ⚡ REQUIREMENT H: Load Testing (3 minutes)

### Run k6 Load Test
**What to Say:**
```
"Requirement H - I'll now demonstrate load testing using k6 to validate the 
Horizontal Pod Autoscaler. This test simulates 200 concurrent users over 14 minutes."
```

**Terminal Setup (3 windows):**

**Terminal 1 - Run Load Test:**
```bash
# Set API URL
export API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Show k6 version
k6 version

# Start load test
k6 run load-test.js
```

**Terminal 2 - Watch HPA:**
```bash
# Watch HPA in real-time
watch -n 2 'kubectl get hpa'
```

**Terminal 3 - Watch Pods:**
```bash
# Watch pods scaling
watch -n 2 'kubectl get pods'
```

**What to Show During Load Test:**

1. **Before Load Test Starts:**
   - Terminal 2: Show HPA with 2/2 replicas
   - Terminal 3: Show 2 user-service pods running
   - Grafana: Show baseline CPU usage (~10-20%)

2. **Load Test Running (0-5 minutes):**
   - Terminal 1: k6 output showing requests, response times
   - Point out: Successful requests, response time metrics
   - Terminal 2: CPU % increasing (targeting 70%)
   - Terminal 3: Still 2 pods (not yet triggered)

3. **HPA Triggers (5-8 minutes):**
   - Terminal 2: HPA shows REPLICAS changing from 2/2 to X/Y
   - Terminal 3: New pods appearing (ContainerCreating → Running)
   - Grafana: Switch to dashboard, show CPU spike
   - Point out: Pods scaling to handle load

4. **Peak Load (8-10 minutes):**
   - Terminal 2: Show final replica count (should reach 8-10 pods)
   - Terminal 3: All pods Running
   - Terminal 1: k6 showing consistent performance despite load
   - Grafana: Show distributed load across pods

5. **Scale Down (10-14 minutes):**
   - Terminal 1: k6 reducing virtual users
   - Terminal 2: HPA scaling down
   - Terminal 3: Pods terminating
   - Grafana: CPU usage decreasing

**What to Explain:**
- Load test has 5 stages: ramp up, sustain, spike, scale down, ramp down
- HPA triggers at 70% CPU threshold
- Pods scale from 2 to 10 automatically
- System maintains performance during scaling
- k6 validates all endpoints remain healthy

**After Test Completes:**
```bash
# Show test summary
# k6 automatically prints summary

# Show final HPA state
kubectl get hpa

# Show final pod count
kubectl get pods | grep user-service
```

---

## 🎯 Final Demo - Dashboard and Complete Test (2 minutes)

### Show Comprehensive Test Script
**What to Say:**
```
"Finally, let me run my comprehensive test script that validates all 8 requirements 
automatically."
```

**Terminal Commands:**
```bash
# Make script executable
chmod +x complete-test.sh

# Run complete test
./complete-test.sh
```

**What to Show:**
- Script output with color-coded results
- Each requirement tested automatically
- Pass/Fail indicators
- Final summary showing all tests passed
- Public endpoints listed

### Show Dashboard
```bash
# Open dashboard
open dashboard.html
```

**What to Show in Dashboard:**
- All 8 requirement cards with status
- Real-time metrics
- Quick action buttons
- API endpoints list
- Access credentials table
- Click "Test All Services" button
- Click through to different services

---

## 🎬 Closing (1 minute)

### Wrap Up
**What to Say:**
```
"To summarize, I've successfully implemented all 8 requirements:

A - Infrastructure as Code using Terraform with 48+ AWS resources
B - 6 microservices plus serverless Lambda function
C - Kubernetes with EKS and Horizontal Pod Autoscalers
D - GitOps workflow using ArgoCD for continuous deployment
E - Stream processing with Flink and Kafka for real-time analytics
F - Multi-database architecture with RDS, DynamoDB, and S3
G - Complete observability stack with Prometheus and Grafana
H - Load testing with k6 demonstrating autoscaling under load

The entire system is production-ready, fully automated, and demonstrates 
modern cloud-native best practices. Thank you for watching!"
```

**Final Screen:**
- Show dashboard one more time
- Show GitHub repository
- End recording

---

## 📝 AWS Console Navigation Checklist

Use this checklist while recording to ensure you show everything:

### ✅ VPC & Networking
- [ ] VPC Dashboard - Show VPC
- [ ] Subnets (public/private)
- [ ] NAT Gateways
- [ ] Internet Gateway
- [ ] Route Tables

### ✅ EKS & Compute
- [ ] EKS Cluster overview
- [ ] EKS Nodes
- [ ] EKS Workloads
- [ ] Node Groups
- [ ] Auto Scaling Groups

### ✅ Databases & Storage
- [ ] RDS instance details
- [ ] RDS monitoring graphs
- [ ] DynamoDB products table
- [ ] DynamoDB analytics table
- [ ] S3 bucket and files

### ✅ Container & Serverless
- [ ] ECR repositories
- [ ] Lambda function
- [ ] Lambda monitoring

### ✅ Messaging & Streaming
- [ ] MSK Kafka cluster
- [ ] MSK configuration

### ✅ Monitoring (CloudWatch)
- [ ] Log groups
- [ ] Metrics (optional)

---

## 🎥 Recording Tips

### Screen Layout
1. **Full Screen Mode:** Use for AWS Console navigation
2. **Split Screen:** Terminal (left) + Browser (right) for live demos
3. **Picture-in-Picture:** Show yourself in corner (optional)

### Audio
- Use good microphone
- Reduce background noise
- Speak clearly and not too fast
- Pause between sections for breath

### Video Quality
- Record at 1080p minimum
- 30 FPS is sufficient
- Use MP4 format for compatibility

### Editing
- Add section titles/overlays
- Speed up long waits (loading, scaling)
- Add arrows/highlights to important UI elements
- Include background music (low volume, optional)

### What NOT to Show
- ❌ Don't expose real AWS account numbers (blur if needed)
- ❌ Don't show billing/cost dashboards
- ❌ Don't show IAM credentials
- ❌ Skip long loading screens (edit out)

---

## 📤 Video Submission

**File Naming:** `CloudAssignment_A15_[YourName].mp4`

**Description to Include:**
```
AWS Cloud Computing Assignment - Complete Microservices Platform

Demonstrates:
✅ Infrastructure as Code (Terraform)
✅ 6 Microservices + Serverless
✅ Kubernetes with Auto-scaling
✅ GitOps with ArgoCD
✅ Real-time Stream Processing
✅ Multi-Database Architecture
✅ Observability (Prometheus/Grafana)
✅ Load Testing with k6

Duration: [XX] minutes
GitHub: https://github.com/pranjaymalhotra/CloudAssignment
```

---

## 🆘 Troubleshooting During Recording

If something doesn't work during recording:

1. **Service Not Responding:**
   - Check pod status: `kubectl get pods`
   - Check logs: `kubectl logs <pod-name>`
   - Restart: `kubectl rollout restart deployment/<service-name>`

2. **LoadBalancer Not Ready:**
   - Wait 2-3 minutes for DNS propagation
   - Use `kubectl get svc` to verify

3. **ArgoCD/Grafana Login Issues:**
   - Re-retrieve password from secrets
   - Try incognito/private browser window

4. **Load Test Fails:**
   - Verify API_URL is set correctly
   - Check if services are healthy
   - Reduce load in script if needed

---

## ✨ Pro Tips for Impressive Demo

1. **Show Real Data:** Create a few users, products, orders before recording
2. **Smooth Transitions:** Prepare browser tabs in advance
3. **Explain as You Go:** Don't just click, explain WHY
4. **Highlight Achievements:** Point out complex integrations
5. **Show Monitoring:** Always show Grafana during load test
6. **Confidence:** If something minor breaks, stay calm and troubleshoot

---

**Good luck with your demo! 🚀**
