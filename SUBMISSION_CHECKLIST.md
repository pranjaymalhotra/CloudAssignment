# Assignment Submission Checklist

## 📋 Before Submission

### Code & Infrastructure
- [ ] All Terraform code committed to Git
- [ ] All microservices code committed
- [ ] Kubernetes manifests committed
- [ ] ArgoCD configurations committed
- [ ] Git repository pushed to GitHub (or provided platform)
- [ ] Repository is accessible (public or shared with instructor)

### Infrastructure Deployed
- [ ] AWS infrastructure deployed via Terraform
- [ ] GCP infrastructure deployed via Terraform
- [ ] EKS cluster running
- [ ] All 6 microservices deployed
- [ ] ArgoCD syncing from Git
- [ ] Monitoring stack deployed
- [ ] Lambda function tested
- [ ] Flink job running on GCP

### Testing
- [ ] API endpoints tested (all CRUD operations)
- [ ] Lambda function triggered and verified
- [ ] Kafka messages flowing
- [ ] Load tests executed successfully
- [ ] HPA scaling verified (at least 2 services)
- [ ] Flink analytics job processing events

### Documentation
- [ ] Design document complete (docs/DESIGN.md)
- [ ] Architecture diagrams included
- [ ] Microservice responsibilities documented
- [ ] Communication patterns explained
- [ ] Design rationale provided
- [ ] API documentation complete

### Videos
- [ ] Individual video recorded (max 12 min)
  - [ ] ID visible in terminal
  - [ ] Code walkthrough complete
  - [ ] Explains infrastructure code
  - [ ] Explains microservices
  - [ ] Explains design decisions
- [ ] Video uploaded (YouTube/Drive)
- [ ] Video link saved in `YOUR_ID_video.txt`
- [ ] Demo video recorded (showing full working)
  - [ ] Infrastructure shown
  - [ ] All services running
  - [ ] API calls demonstrated
  - [ ] Load testing with scaling
  - [ ] Monitoring dashboards
  - [ ] Flink on GCP
- [ ] Demo video uploaded
- [ ] Demo link saved in `demo_video.txt`

## 📦 Submission Package

Your repository should contain:

```
Cloud_A15/
├── terraform/
│   ├── aws/          # ✅ Complete AWS IaC
│   └── gcp/          # ✅ Complete GCP IaC
├── microservices/
│   ├── api-gateway/      # ✅ Service 1
│   ├── user-service/     # ✅ Service 2
│   ├── product-service/  # ✅ Service 3
│   ├── order-service/    # ✅ Service 4
│   └── notification-service/  # ✅ Service 5
├── analytics/        # ✅ Service 6 (Flink on GCP)
├── lambda/           # ✅ Serverless function
├── kubernetes/
│   ├── base/         # ✅ All K8s manifests
│   └── argocd/       # ✅ GitOps configs
├── monitoring/       # ✅ Prometheus/Grafana
├── load-testing/     # ✅ k6 scripts
├── docs/
│   ├── DESIGN.md         # ✅ Architecture document
│   ├── API.md            # ✅ API documentation
│   └── TROUBLESHOOTING.md
├── scripts/          # ✅ Deployment scripts
├── README.md         # ✅ Project overview
├── SETUP.md          # ✅ Setup instructions
├── YOUR_ID_video.txt # ✅ Individual video link
└── demo_video.txt    # ✅ Demo video link
```

## ✅ Requirements Verification

### Requirement A: Infrastructure as Code
- [ ] 100% provisioned by Terraform
- [ ] Separate modules for resources
- [ ] No manual resource creation

### Requirement B: 6 Microservices
- [ ] All 6 services implemented
- [ ] Distinct functional purposes
- [ ] Analytics service on different provider (GCP)
- [ ] Serverless function included (Lambda)
- [ ] Services communicate via REST/Kafka

### Requirement C: Kubernetes
- [ ] Managed K8s service (EKS)
- [ ] All stateless services on K8s
- [ ] HPA on 2+ critical services
- [ ] HPA configured for CPU/memory

### Requirement D: GitOps
- [ ] ArgoCD installed
- [ ] ArgoCD tracks Git repository
- [ ] No manual kubectl apply used
- [ ] All deployments via ArgoCD

### Requirement E: Stream Processing
- [ ] Flink on managed cluster (Dataproc)
- [ ] Runs on provider B (GCP)
- [ ] Consumes from Kafka
- [ ] Performs windowed aggregation
- [ ] Publishes results to Kafka
- [ ] Managed Kafka (MSK)

### Requirement F: Storage
- [ ] Object store (S3) for raw data
- [ ] Managed SQL (RDS) for relational data
- [ ] Managed NoSQL (DynamoDB) for semi-structured data
- [ ] All distinct storage types used

### Requirement G: Observability
- [ ] Prometheus deployed
- [ ] Grafana deployed with dashboards
- [ ] Key metrics shown (RPS, errors, latency)
- [ ] Centralized logging (kubectl logs or EFK)
- [ ] Logs from all services aggregated

### Requirement H: Load Testing
- [ ] k6 (or similar) configured
- [ ] Load tests executed
- [ ] HPA scaling demonstrated
- [ ] System resilience validated

## 🎥 Video Content Verification

### Individual Video Must Show:
- [ ] Your ID clearly visible
- [ ] Code walkthrough of YOUR contributions
- [ ] Terraform configurations explained
- [ ] Microservices code explained
- [ ] Kubernetes manifests explained
- [ ] Design decisions explained

### Demo Video Must Show:
- [ ] Full system running
- [ ] All infrastructure deployed
- [ ] All 6 services operational
- [ ] API calls working
- [ ] Lambda function triggered
- [ ] Kafka events flowing
- [ ] Flink job processing on GCP
- [ ] Monitoring dashboards
- [ ] Load test with HPA scaling

## 📤 Final Submission Steps

1. **Verify Everything Works**
```bash
# Test all endpoints
./scripts/run-tests.sh

# Check all pods running
kubectl get pods

# Verify HPA
kubectl get hpa

# Check ArgoCD apps
kubectl get applications -n argocd
```

2. **Record Videos**
   - Individual code walkthrough
   - Full system demonstration

3. **Create Video Links**
```bash
echo "YOUR_VIDEO_URL" > YOUR_ID_video.txt
echo "DEMO_VIDEO_URL" > demo_video.txt
```

4. **Push to Git**
```bash
git add .
git commit -m "Final submission"
git push origin main
```

5. **Submit on Nalanda**
   - Submit Git repository URL
   - Ensure repository is accessible

## ⚠️ Common Mistakes to Avoid

- [ ] Don't forget video link files
- [ ] Don't use placeholder values in configs
- [ ] Don't commit secrets/credentials
- [ ] Don't exceed video time limits
- [ ] Don't forget to show ID in individual video
- [ ] Don't submit without testing everything
- [ ] Don't forget to document design decisions

## 💡 Tips for High Marks

- Clear, well-documented code
- Comprehensive architecture documentation
- Working end-to-end demonstration
- Professional video presentation
- Clean Git history
- Complete README with setup instructions
- Proper use of all required technologies
- System actually scales and is resilient

## 📞 If Something Goes Wrong

1. Check troubleshooting guide: `docs/TROUBLESHOOTING.md`
2. Review logs: `kubectl logs <pod-name>`
3. Check events: `kubectl get events`
4. Verify Terraform state: `terraform show`

## 🎯 After Submission

**IMPORTANT**: Destroy all infrastructure to avoid charges!

```bash
# Destroy AWS
cd terraform/aws
terraform destroy -auto-approve

# Destroy GCP
cd terraform/gcp
terraform destroy -auto-approve
```

---

Good luck with your submission! 🚀
