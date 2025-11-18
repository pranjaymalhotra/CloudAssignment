# Video Recording Guidelines

## Individual Code Walkthrough Video (12 minutes max)

### Setup
1. Open terminal with your ID visible:
```bash
export PS1="[YOUR_ID_HERE] \w $ "
```

2. Open VS Code or your IDE
3. Have project structure visible

### What to Cover (in order)

#### 1. Introduction (1 min)
- State your name and ID number
- Project overview: "E-Commerce microservices on AWS & GCP"
- Show project structure briefly

#### 2. Infrastructure as Code (3 min)
```bash
# Show Terraform files
cd terraform/aws
cat main.tf | head -50
```
- Explain VPC module
- Explain EKS setup
- Show RDS, DynamoDB, MSK configuration
- GCP Dataproc setup

#### 3. Microservices Code (4 min)
```bash
# Show one microservice in detail
cd microservices/order-service
cat app.py
```
- Explain Order Service architecture
- Show database connection
- Show Kafka producer integration
- Explain Dockerfile

#### 4. Kubernetes Manifests (2 min)
```bash
cd kubernetes/base
cat order-service.yaml
```
- Explain Deployment
- Show HPA configuration
- Explain resource limits

#### 5. Monitoring & Testing (1 min)
```bash
cd load-testing
cat scripts/load-test.js | head -30
```
- Show k6 test script
- Explain Prometheus/Grafana setup

#### 6. Design Decisions (1 min)
- Why this architecture?
- Technology choices
- Scalability approach

### Recording Tips
- Use screen recording (QuickTime, OBS, Loom)
- Speak clearly
- Don't rush - explain concepts
- Show terminal commands working
- Keep ID visible throughout

### Upload
1. Upload to YouTube (Unlisted) or Google Drive
2. Save link:
```bash
echo "https://your-video-link" > YOUR_ID_video.txt
```

---

## Demo Video (30 minutes max)

### Part 1: Infrastructure (5 min)
1. **AWS Console**
   - Show EKS cluster
   - Show RDS database
   - Show DynamoDB table
   - Show MSK Kafka cluster
   - Show S3 bucket
   - Show Lambda function

2. **GCP Console**
   - Show Dataproc cluster
   - Show Cloud Storage buckets

3. **Terraform State**
```bash
cd terraform/aws
terraform show | head -100
```

### Part 2: Application Deployment (5 min)
1. **Kubernetes Dashboard**
```bash
kubectl get all
kubectl get pods -o wide
kubectl get svc
kubectl get hpa
```

2. **ArgoCD**
   - Open ArgoCD UI
   - Show all applications synced
   - Show Git repository connection

### Part 3: Functional Testing (10 min)
```bash
# Get API URL
API_URL=$(kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Test all endpoints
echo "Creating user..."
curl -X POST http://$API_URL/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "Demo User", "email": "demo@example.com"}'

echo "Getting users..."
curl http://$API_URL/api/users

echo "Creating product..."
curl -X POST http://$API_URL/api/products \
  -H "Content-Type: application/json" \
  -d '{"name": "Demo Product", "price": 99.99, "stock": 10, "category": "demo"}'

echo "Creating order..."
curl -X POST http://$API_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"user_id": 1, "product_id": "prod-123", "quantity": 2, "total_price": 199.98}'
```

3. **Lambda Testing**
```bash
# Upload file to S3
echo "test data" > demo.txt
aws s3 cp demo.txt s3://YOUR_BUCKET/uploads/demo.txt

# Show Lambda logs
aws logs tail /aws/lambda/s3-file-processor --follow

# Show processed file
aws s3 ls s3://YOUR_BUCKET/processed/
```

4. **Kafka Messages**
```bash
# Show Kafka topics
aws kafka list-clusters

# In notification service logs, show consumed messages
kubectl logs -f deployment/notification-service
```

### Part 4: Monitoring (5 min)
1. **Prometheus**
   - Open Prometheus UI
   - Show metrics for services
   - Show queries

2. **Grafana**
   - Open Grafana dashboards
   - Show service metrics (RPS, latency, errors)
   - Show cluster health
   - Show HPA metrics

3. **Logs (Kibana or kubectl)**
```bash
kubectl logs -f deployment/order-service
```

### Part 5: Load Testing & Auto-Scaling (5 min)
1. **Initial State**
```bash
kubectl get hpa
kubectl get pods
```

2. **Start Load Test**
```bash
# In one terminal
k6 run -e API_URL=http://$API_URL load-testing/scripts/stress-test.js

# In another terminal
kubectl get hpa -w
```

3. **Watch Scaling**
   - Show HPA increasing target
   - Show new pods spinning up
   - Show Grafana metrics spiking
   - Show pods handling load

4. **After Test**
   - Show scale down
   - Show final metrics

### Part 6: Analytics on GCP (2 min)
```bash
# Show Flink job running
gcloud dataproc jobs list \
  --cluster=analytics-cluster \
  --region=us-central1

# Show job details
gcloud dataproc jobs describe <job-id> \
  --cluster=analytics-cluster \
  --region=us-central1
```

### Conclusion (1 min)
- Summary of what was demonstrated
- All requirements met
- System is production-ready

### Upload
```bash
echo "https://demo-video-link" > demo_video.txt
```

---

## Recording Tools

### macOS
- **QuickTime Player**: Built-in, simple
  - File → New Screen Recording
  
- **OBS Studio**: Free, professional
  - Download: https://obsproject.com

### Video Hosting
- **YouTube**: Upload as Unlisted
- **Google Drive**: Share with link
- **Loom**: Easy browser-based recording

### Tips
- Use 1080p resolution
- Enable microphone
- Close unnecessary tabs/windows
- Practice once before final recording
- Have a script/outline
- Keep within time limits

---

## Checklist

- [ ] Terminal shows ID number
- [ ] All code files explained
- [ ] Infrastructure shown in AWS/GCP console
- [ ] All 6 microservices running
- [ ] API calls demonstrated
- [ ] Lambda function tested
- [ ] Kafka events shown
- [ ] Monitoring dashboards shown
- [ ] Load test executed
- [ ] HPA scaling demonstrated
- [ ] Flink job shown on GCP
- [ ] Video uploaded
- [ ] Links saved in txt files
