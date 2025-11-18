# Cloud Architecture Design Document

## System Overview

This document describes the architecture of a cloud-native e-commerce platform built using microservices architecture across AWS and GCP.

### Business Context
The platform enables online shopping with real-time order processing, inventory management, and analytics.

### Technical Goals
- High availability and scalability
- Event-driven architecture
- Real-time analytics
- Infrastructure as Code
- GitOps deployment model

---

## Cloud Deployment Architecture

### Multi-Cloud Strategy

**Primary Cloud: AWS**
- EKS for container orchestration
- RDS MySQL for relational data
- DynamoDB for NoSQL storage
- MSK for event streaming (Kafka)
- S3 for object storage
- Lambda for serverless processing

**Secondary Cloud: GCP**
- Dataproc for Flink analytics
- Cloud Storage for data lake

### Rationale
- **AWS**: Mature managed Kubernetes (EKS), rich database options, cost-effective for primary workloads
- **GCP**: Superior data processing with Dataproc/Flink, good for analytics workload isolation

---

## Microservices Architecture

### Service Inventory

#### 1. API Gateway (Port 5000)
- **Responsibility**: Public-facing REST API, request routing, load distribution
- **Technology**: Python/Flask
- **Storage**: None (stateless)
- **Communication**: HTTP REST to downstream services
- **Scaling**: HPA based on CPU/memory (2-10 replicas)

#### 2. User Service (Port 5001)
- **Responsibility**: User management (CRUD operations)
- **Technology**: Python/Flask
- **Storage**: RDS MySQL (users table)
- **Communication**: REST API, consumed by API Gateway
- **Scaling**: Static 2 replicas

#### 3. Product Service (Port 5002)
- **Responsibility**: Product catalog management
- **Technology**: Python/Flask
- **Storage**: DynamoDB (product_id as key)
- **Communication**: REST API
- **Scaling**: Static 2 replicas

#### 4. Order Service (Port 5003)
- **Responsibility**: Order processing, publishes events to Kafka
- **Technology**: Python/Flask + Kafka Producer
- **Storage**: RDS MySQL (orders table)
- **Communication**: REST API + Kafka event publication
- **Scaling**: HPA based on CPU/memory (2-8 replicas)

#### 5. Notification Service (Port 5004)
- **Responsibility**: Consumes order events, sends notifications
- **Technology**: Python/Flask + Kafka Consumer
- **Storage**: None
- **Communication**: Kafka consumer (orders topic)
- **Scaling**: Static 1 replica (consumer group)

#### 6. Analytics Service (GCP)
- **Responsibility**: Real-time stream processing and aggregation
- **Technology**: Apache Flink on Dataproc
- **Storage**: GCS for checkpoints, results to Kafka
- **Communication**: Kafka consumer → Flink → Kafka producer
- **Scaling**: Dataproc cluster (1 master + 2 workers)

---

## Service Interconnections

### Communication Patterns

```
┌─────────────┐
│   Client    │
└──────┬──────┘
       │ HTTP
       ▼
┌─────────────────┐
│  API Gateway    │◄── LoadBalancer (Public)
│  (Port 5000)    │
└────┬─────┬──────┘
     │     │
     │     └──────────┐
     ▼                ▼
┌──────────┐    ┌──────────────┐
│  User    │    │  Product     │
│ Service  │    │  Service     │
│  :5001   │    │  :5002       │
└────┬─────┘    └───────┬──────┘
     │                  │
     ▼                  ▼
┌─────────┐      ┌────────────┐
│   RDS   │      │ DynamoDB   │
│  MySQL  │      └────────────┘
└─────────┘
                 
┌──────────────┐     Kafka     ┌──────────────────┐
│  Order       │──────────────▶│  Notification    │
│  Service     │   (orders)    │  Service         │
│  :5003       │               │  :5004           │
└──────┬───────┘               └──────────────────┘
       │                                │
       ▼                                ▼
   ┌────────┐                    (sends emails/SMS)
   │  RDS   │
   │ MySQL  │
   └────────┘
       
       Kafka
    (orders topic)
       │
       ▼
┌────────────────────┐
│  Flink Analytics   │  (GCP Dataproc)
│  Windowed Agg      │
└─────────┬──────────┘
          │
          ▼ Kafka
    (analytics-results)
```

### Inter-Service Communication Mechanisms

1. **Synchronous (REST)**
   - API Gateway ↔ All services
   - Simple request/response
   - Uses service discovery (Kubernetes DNS)

2. **Asynchronous (Kafka)**
   - Order Service → Notification Service
   - Order Service → Analytics Service (GCP)
   - Event-driven, decoupled
   - MSK managed Kafka

3. **Database Access**
   - User/Order services → RDS (relational)
   - Product service → DynamoDB (NoSQL)
   - Direct connection via VPC

---

## Design Rationale

### Why Microservices?
- **Independent scaling**: Order service scales differently than user service
- **Technology flexibility**: Can use different languages/databases per service
- **Fault isolation**: Failure in one service doesn't bring down the entire system
- **Team autonomy**: Different teams can own different services

### Why Kafka?
- **Decoupling**: Order service doesn't need to know about notification/analytics services
- **Reliability**: Messages persist, can be replayed
- **Scalability**: Handles high throughput
- **MSK**: Managed service reduces operational overhead

### Why Multi-Cloud?
- **Best-of-breed**: Use AWS for app hosting, GCP for analytics
- **Risk mitigation**: Not locked into single vendor
- **Learning**: Demonstrates multi-cloud skills

### Why EKS?
- **Mature platform**: Battle-tested Kubernetes
- **AWS integration**: Native support for IAM, VPC, Load Balancers
- **Auto-scaling**: HPA for pods, Cluster Autoscaler for nodes

### Why RDS + DynamoDB?
- **RDS**: ACID transactions for users/orders (relational data)
- **DynamoDB**: High throughput, flexible schema for products
- **Managed**: No database administration overhead

### Why GitOps (ArgoCD)?
- **Declarative**: Desired state in Git
- **Auditability**: All changes tracked in Git
- **Rollback**: Easy to revert
- **Security**: No direct kubectl access needed

---

## Infrastructure as Code

### Terraform Modules

1. **VPC Module**: Network isolation, public/private subnets
2. **EKS Module**: Kubernetes cluster with node groups
3. **RDS Module**: MySQL database with security groups
4. **MSK Module**: Kafka cluster configuration
5. **Lambda Module**: S3-triggered function
6. **GCP Module**: Dataproc cluster and Cloud Storage

### Benefits
- **Reproducibility**: Spin up identical environments
- **Version control**: Infrastructure changes tracked
- **Collaboration**: Team can review infrastructure changes
- **Automation**: CI/CD can apply infrastructure changes

---

## Scalability & Resilience

### Horizontal Pod Autoscaling (HPA)
- **API Gateway**: 2-10 pods based on CPU (70%)
- **Order Service**: 2-8 pods based on CPU (70%)
- **Triggers**: CPU/memory utilization

### Database Scaling
- **RDS**: Vertical scaling (instance size)
- **DynamoDB**: Auto-scaling (pay-per-request)

### High Availability
- **Multi-AZ**: RDS and EKS nodes across 2 AZs
- **Load Balancing**: AWS ELB for API Gateway
- **Health Checks**: Kubernetes liveness/readiness probes

---

## Observability

### Metrics (Prometheus + Grafana)
- Request rate, latency, error rate per service
- Kubernetes cluster health
- Database connections
- Kafka lag

### Logging (EFK Stack)
- Centralized log aggregation
- Application logs from all pods
- Searchable via Kibana

### Tracing (Future)
- Distributed tracing with OpenTelemetry
- End-to-end request tracking

---

## Security Considerations

1. **Network Isolation**: Private subnets for databases
2. **IAM Roles**: Service accounts with least privilege
3. **Secrets Management**: Kubernetes secrets for credentials
4. **TLS**: HTTPS for public endpoints
5. **Security Groups**: Firewall rules limiting access

---

## Cost Optimization

### Free Tier Usage
- **RDS**: db.t3.micro (free tier eligible)
- **EKS**: Control plane free first 30 days
- **Lambda**: 1M requests free
- **S3/DynamoDB**: Generous free tiers

### Cost Management
- **Auto-scaling**: Pay only for what you use
- **Spot instances**: (Future) For non-critical workloads
- **Monitoring**: CloudWatch to track spending

**Estimated Monthly Cost**: $50-100 (mostly MSK Kafka)

---

## Future Enhancements

1. **Service Mesh** (Istio): Traffic management, security
2. **API Gateway** (Kong): Rate limiting, authentication
3. **Caching** (Redis): Reduce database load
4. **CDN** (CloudFront): Static asset delivery
5. **Multi-region**: Global deployment

---

## Conclusion

This architecture demonstrates:
- Modern cloud-native patterns
- Multi-cloud deployment
- Event-driven design
- GitOps workflows
- Comprehensive observability
- Production-ready practices

All while remaining cost-effective and manageable.
