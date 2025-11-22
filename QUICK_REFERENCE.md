# Quick Reference Card - E-Commerce Multi-Cloud Platform

## 🔗 Access URLs

```bash
# Frontend
http://aefbb433685234901b11e08e97e3198e-1887305954.us-east-1.elb.amazonaws.com

# API Gateway  
http://ab5f1ab6f0e634756bc7fb5c74faf562-1234779937.us-east-1.elb.amazonaws.com/api

# Grafana
http://a0766309961cd44068e1382b81704655-1493425140.us-east-1.elb.amazonaws.com
Login: admin / admin123

# ArgoCD
http://abfe27899ec454f47ac5df288916cde0-779693884.us-east-1.elb.amazonaws.com
Login: admin / Rokivt5AdaHohNpE
```

## 🎬 Demo Commands

```bash
# Set custom prompt (for recording)
export PS1="2024H1030072P "

# Show running pods
kubectl get pods -A

# Show HPAs
kubectl get hpa

# Run load test
k6 run load-test.js

# Watch HPA scaling (in another terminal)
watch kubectl get hpa

# Show ArgoCD apps
kubectl get applications -n argocd

# Show Flink job
gcloud dataproc jobs describe 4add9a6ce97c4f10aed1beb4d83ebf46 --region=us-central1
```

## 📊 What to Show

### 1. Frontend Features
- User Management (Create/View users)
- Order Management (Create/View orders)
- Product Catalog
- **Real-Time Processing Section:**
  - Send Event to Kafka → Shows full pipeline
  - Check Notifications → Kafka consumer details
  - View Analytics (Flink) → GCP Dataproc details
- **Database Health** → RDS + DynamoDB status
- **K8s & GitOps** → EKS info + ArgoCD access
- **Monitoring** → Grafana + Prometheus links

### 2. Monitoring (Grafana)
- Import custom dashboard: `monitoring/grafana-dashboard-microservices.json`
- Show: CPU, Memory, HPA replicas, Pod status

### 3. GitOps (ArgoCD)
- Applications: microservices, monitoring-stack
- Show sync status
- Show resource tree

### 4. Load Testing
- Run k6 test
- Show terminal output
- Watch HPA scale from 2 → 8-10 replicas
- Show Grafana metrics spiking

## 📋 Requirements Checklist

- [x] (a) Multi-Cloud: AWS EKS + GCP Dataproc
- [x] (b) Serverless: Lambda S3 processor
- [x] (c) HPA: api-gateway-hpa + order-service-hpa
- [x] (d) GitOps: ArgoCD with 2 applications
- [x] (e) Stream Processing: Flink with checkpointing
- [x] (f) Cross-Cloud: AWS MSK → GCP Flink
- [x] (g) Monitoring: Prometheus + Grafana + custom dashboard
- [x] (h) Load Testing: k6 with HPA validation

## 🛠️ Troubleshooting Quick Fixes

### Database Tables Don't Exist
```sql
kubectl run mysql-client --rm -it --image=mysql:8.0 -- bash
mysql -h ecommercedb.catc86eyes0c.us-east-1.rds.amazonaws.com -u admin -p
USE ecommercedb;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    product_id VARCHAR(255) NOT NULL,
    quantity INT NOT NULL,
    total_price DECIMAL(10,2) DEFAULT 0.00,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id)
);
```

### RDS Security Group Issue
```bash
EKS_SG=$(aws eks describe-cluster --name ecommerce-cluster --query 'cluster.resourcesVpcConfig.clusterSecurityGroupId' --output text)
RDS_SG=$(aws rds describe-db-instances --db-instance-identifier ecommercedb --query 'DBInstances[0].VpcSecurityGroups[0].VpcSecurityGroupId' --output text)

aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --source-group $EKS_SG
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --cidr 10.0.10.0/24
aws ec2 authorize-security-group-ingress --group-id $RDS_SG --protocol tcp --port 3306 --cidr 10.0.11.0/24
```

### HPA Not Showing Metrics
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
kubectl get deployment metrics-server -n kube-system
```

## 📁 Key Files

| File | Purpose |
|------|---------|
| `COMPLETE_DEPLOYMENT_GUIDE.md` | Full deployment steps |
| `IMPROVEMENTS_SUMMARY.md` | All improvements made |
| `load-test.js` | k6 load testing script |
| `monitoring/grafana-dashboard-microservices.json` | Grafana dashboard |
| `kubernetes/argocd/applications/` | ArgoCD app definitions |
| `kubernetes/base/*-hpa.yaml` | HPA configurations |
| `analytics/.../OrderAnalyticsJob.java` | Flink job with checkpointing |

## 🎯 Recording Script

1. **Show Infrastructure**
   ```bash
   kubectl get nodes
   kubectl get pods -A | grep -v kube-system
   ```

2. **Open Frontend** → Demonstrate all sections

3. **Open Grafana** → Show custom dashboard

4. **Open ArgoCD** → Show synced apps

5. **Run Load Test**
   ```bash
   k6 run load-test.js &
   watch kubectl get hpa
   ```

6. **Show Scaling in Grafana** → HPA Current Replicas panel

7. **Show Flink Job**
   ```bash
   gcloud dataproc jobs describe 4add9a6ce97c4f10aed1beb4d83ebf46 --region=us-central1
   ```
