# Troubleshooting Guide

## Common Issues and Solutions

### 1. EKS Cluster Issues

#### Nodes Not Ready
```bash
# Check node status
kubectl get nodes

# Describe node for details
kubectl describe node <node-name>

# Check IAM roles
aws iam get-role --role-name ecommerce-cluster-node-role
```

**Solution:** Ensure IAM roles have proper policies attached

---

### 2. Pod Issues

#### Pods in CrashLoopBackOff
```bash
# Check pod logs
kubectl logs <pod-name>

# Check previous pod logs
kubectl logs <pod-name> --previous

# Describe pod
kubectl describe pod <pod-name>
```

**Common causes:**
- Database connection failure → Check RDS endpoint in ConfigMap
- Kafka connection failure → Check MSK brokers in ConfigMap
- Image pull errors → Check ECR permissions

---

### 3. Database Connection Issues

#### RDS Connection Failed
```bash
# Test from a pod
kubectl run -it --rm debug --image=mysql:8.0 --restart=Never -- \
  mysql -h <RDS_ENDPOINT> -u admin -p

# Check security group
aws ec2 describe-security-groups --group-ids <sg-id>
```

**Solution:**
- Ensure security group allows traffic from EKS security group
- Check VPC/subnet configuration
- Verify credentials in Secret

---

### 4. Kafka Issues

#### Cannot Connect to MSK
```bash
# Get MSK brokers
aws kafka get-bootstrap-brokers --cluster-arn <arn>

# Test from pod
kubectl run -it --rm kafka-test --image=confluentinc/cp-kafka:latest \
  --restart=Never -- kafka-topics --list \
  --bootstrap-server <MSK_BROKERS>
```

**Solution:**
- Check MSK security group
- Ensure VPC connectivity
- Verify broker addresses in ConfigMap

---

### 5. ArgoCD Issues

#### Application Not Syncing
```bash
# Check application status
kubectl get application -n argocd

# Describe application
kubectl describe application <app-name> -n argocd

# Check ArgoCD logs
kubectl logs -n argocd deployment/argocd-application-controller
```

**Solution:**
- Verify Git repository URL
- Check repository permissions
- Force sync: `argocd app sync <app-name> --force`

---

### 6. HPA Not Scaling

#### Pods Not Scaling Up
```bash
# Check HPA status
kubectl get hpa

# Describe HPA
kubectl describe hpa <hpa-name>

# Check metrics server
kubectl top pods
```

**Solution:**
- Ensure metrics-server is installed: `kubectl get deployment metrics-server -n kube-system`
- Check resource requests are set in deployment
- Verify CPU/memory thresholds

---

### 7. Load Balancer Issues

#### Service LoadBalancer Pending
```bash
# Check service
kubectl get svc

# Describe service
kubectl describe svc <service-name>

# Check AWS Load Balancer Controller
kubectl logs -n kube-system deployment/aws-load-balancer-controller
```

**Solution:**
- Install AWS Load Balancer Controller
- Check IAM permissions
- Verify subnets are properly tagged

---

### 8. Terraform Issues

#### Terraform Apply Fails
```bash
# Check terraform state
terraform show

# Refresh state
terraform refresh

# Check for drift
terraform plan
```

**Solution:**
- Check AWS credentials
- Verify region is correct
- Check for conflicting resources

---

### 9. Image Build/Push Issues

#### ECR Push Fails
```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  <account-id>.dkr.ecr.us-east-1.amazonaws.com

# Check repository exists
aws ecr describe-repositories
```

**Solution:**
- Ensure AWS credentials are valid
- Check ECR permissions
- Verify repository exists

---

### 10. GCP Dataproc Issues

#### Flink Job Fails
```bash
# Check job status
gcloud dataproc jobs describe <job-id> \
  --cluster=analytics-cluster \
  --region=us-central1

# Check cluster logs
gcloud dataproc clusters list --region=us-central1
```

**Solution:**
- Check Kafka connection from GCP
- Verify JAR file in GCS
- Check Dataproc cluster is running

---

## Quick Commands Reference

```bash
# Get all resources
kubectl get all

# Check pod logs
kubectl logs -f <pod-name>

# Execute into pod
kubectl exec -it <pod-name> -- /bin/bash

# Port forward to service
kubectl port-forward svc/<service-name> 8080:80

# Get events
kubectl get events --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods

# Force delete stuck pod
kubectl delete pod <pod-name> --force --grace-period=0

# Restart deployment
kubectl rollout restart deployment/<deployment-name>

# Check Terraform outputs
terraform output

# Get AWS resources
aws eks list-clusters
aws rds describe-db-instances
aws kafka list-clusters
```

---

## Cost Monitoring

```bash
# Check AWS costs
aws ce get-cost-and-usage \
  --time-period Start=2025-11-01,End=2025-11-19 \
  --granularity DAILY \
  --metrics UnblendedCost \
  --group-by Type=SERVICE

# List all running resources
aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"
aws rds describe-db-instances
aws eks list-clusters
```

---

## Emergency Procedures

### Scale Down Everything
```bash
# Scale deployments to 0
kubectl scale deployment --all --replicas=0

# Or delete everything
kubectl delete -f kubernetes/base/
```

### Complete Teardown
```bash
# Delete Kubernetes resources
kubectl delete all --all

# Destroy AWS infrastructure
cd terraform/aws
terraform destroy -auto-approve

# Destroy GCP infrastructure
cd terraform/gcp
terraform destroy -auto-approve
```

---

## Getting Help

1. Check logs: `kubectl logs <pod-name>`
2. Check events: `kubectl get events`
3. Check AWS CloudWatch logs
4. Check GCP Cloud Logging
5. Review Terraform state: `terraform show`
