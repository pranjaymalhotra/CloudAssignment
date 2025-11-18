# Quick Reference - Deployment Commands

## 🚀 Deploy Everything from Scratch
```bash
./deploy.sh
```
**Time:** ~40 minutes  
**What it does:** Deploys AWS infrastructure, builds Docker images, deploys to Kubernetes, configures everything

---

## 🧹 Destroy Everything
```bash
./teardown.sh
```
**Time:** ~15 minutes  
**What it does:** Deletes all Kubernetes resources, destroys AWS infrastructure, cleans local files

---

## 🧪 Test Deployment
```bash
./test-api.sh
```
**Expected:** 17/17 tests pass

---

## 📊 Check Status
```bash
# All pods
kubectl get pods

# Services and LoadBalancers
kubectl get svc

# Get public URLs
kubectl get svc api-gateway -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
kubectl get svc frontend -o jsonpath='{.status.loadBalancer.ingress[0].hostname}'
```

---

## 🔍 View Databases
```bash
# RDS MySQL
DB_ENDPOINT=$(cd terraform/aws && terraform output -raw rds_endpoint)
kubectl run mysql-client --image=mysql:8.0 --rm -it --restart=Never -- \
  mysql -h $DB_ENDPOINT -u admin -p'Admin123456!' -D ecommercedb \
  -e "SELECT * FROM users; SELECT * FROM orders;"

# DynamoDB
aws dynamodb scan --table-name ecommerce-products --region us-east-1
```

---

## 🐛 Troubleshooting
```bash
# Check pod logs
kubectl logs -l app=user-service --tail=50
kubectl logs -l app=product-service --tail=50
kubectl logs -l app=order-service --tail=50

# Describe problematic pod
kubectl describe pod <pod-name>

# Restart deployment
kubectl rollout restart deployment/<service-name>
```

---

## 💰 Cost Check
```bash
# View AWS costs
open https://console.aws.amazon.com/billing/home

# Current hourly: ~$0.36/hour (~$8.64/day)
```

---

## 🔄 Rebuild Single Service
```bash
# Example: Update user-service
cd microservices/user-service

# Edit app.py...

# Rebuild and push
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
docker buildx build --platform linux/amd64 \
  -t $AWS_ACCOUNT_ID.dkr.ecr.us-east-1.amazonaws.com/ecommerce-user-service:latest \
  --push .

# Restart
kubectl rollout restart deployment/user-service
kubectl get pods -w
```

---

## 📁 Important Files
- `deploy.sh` - Full deployment automation
- `teardown.sh` - Complete cleanup automation
- `test-api.sh` - Automated test suite
- `DEPLOYMENT_GUIDE.md` - Complete documentation
- `TESTING_GUIDE.md` - Testing documentation
- `REQUIREMENTS_STATUS.md` - Requirements checklist

---

## ✅ Success Checklist
After `./deploy.sh`:
- [ ] 11 pods running
- [ ] 2 LoadBalancers provisioned
- [ ] Frontend accessible in browser
- [ ] API responds to health check
- [ ] 17/17 tests passing
- [ ] Databases initialized with data

---

## ⚠️ Before You Leave
```bash
# Always destroy resources to avoid charges!
./teardown.sh

# Verify cleanup
aws resourcegroupstaggingapi get-resources \
  --tag-filters Key=Project,Values=ECommerce-Cloud-Assignment
```
