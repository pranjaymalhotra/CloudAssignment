# Cloud Architecture Design Document

## Executive Summary

This document provides a comprehensive overview of a production-grade, cloud-native e-commerce platform built using microservices architecture with multi-cloud deployment across AWS and GCP. The system demonstrates modern DevOps practices including Infrastructure as Code, GitOps, event-driven architecture, and comprehensive observability.

---

## System Overview

### Business Context
The platform is a scalable e-commerce solution that enables:
- **Customer Operations**: User registration, authentication, and profile management
- **Product Management**: Dynamic product catalog with search and filtering
- **Order Processing**: Real-time order creation, payment processing, and order tracking
- **Notifications**: Multi-channel customer notifications (Email, SMS, Push)
- **Analytics**: Real-time business intelligence and reporting

### Technical Goals
1. **High Availability**: 99.9% uptime with multi-AZ deployment
2. **Scalability**: Auto-scaling from 2 to 100+ concurrent users
3. **Event-Driven Architecture**: Asynchronous processing with Kafka
4. **Real-Time Analytics**: Stream processing with Apache Flink
5. **Infrastructure as Code**: Reproducible environments with Terraform
6. **GitOps Deployment**: Automated deployments with ArgoCD
7. **Observability**: Comprehensive monitoring with Prometheus/Grafana
8. **Security**: Zero-trust architecture with IAM and network policies

### Technology Stack
- **Container Orchestration**: Kubernetes (EKS on AWS, GKE on GCP)
- **Microservices Framework**: Python Flask, Spring Boot (Analytics)
- **Message Broker**: Apache Kafka (AWS MSK)
- **Databases**: PostgreSQL (RDS), DynamoDB, Redis
- **Stream Processing**: Apache Flink on GCP Dataproc
- **Infrastructure**: Terraform
- **CI/CD**: ArgoCD, GitHub Actions
- **Monitoring**: Prometheus, Grafana, EFK Stack

---

## Cloud Deployment Architecture

### High-Level Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              INTERNET / USERS                                │
└────────────────────────────────┬────────────────────────────────────────────┘
                                 │ HTTPS
                                 ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                            AWS CLOUD (Primary)                               │
│  ┌──────────────────────────────────────────────────────────────────────┐  │
│  │                    VPC (10.0.0.0/16)                                  │  │
│  │  ┌────────────────────────────────────────────────────────────────┐  │  │
│  │  │                    Public Subnets (Multi-AZ)                    │  │  │
│  │  │  ┌──────────────┐           ┌──────────────┐                   │  │  │
│  │  │  │  AWS ALB     │           │   Ingress    │                   │  │  │
│  │  │  │  (Layer 7)   │──────────▶│  Controller  │                   │  │  │
│  │  │  └──────────────┘           └──────┬───────┘                   │  │  │
│  │  └─────────────────────────────────────┼─────────────────────────┘  │  │
│  │                                         ▼                              │  │
│  │  ┌──────────────────────────────────────────────────────────────┐    │  │
│  │  │              Amazon EKS Cluster (Kubernetes 1.27)             │    │  │
│  │  │  ┌──────────────────────────────────────────────────────┐    │    │  │
│  │  │  │              Microservices Pods                       │    │    │  │
│  │  │  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │    │    │  │
│  │  │  │  │   API    │  │  User    │  │ Product  │           │    │    │  │
│  │  │  │  │ Gateway  │─▶│ Service  │  │ Service  │           │    │    │  │
│  │  │  │  │ (2-10x)  │  │  (2x)    │  │  (2x)    │           │    │    │  │
│  │  │  │  └──────────┘  └────┬─────┘  └────┬─────┘           │    │    │  │
│  │  │  │                     │             │                  │    │    │  │
│  │  │  │  ┌──────────┐      │             │                  │    │    │  │
│  │  │  │  │  Order   │◀─────┘             ▼                  │    │    │  │
│  │  │  │  │ Service  │              ┌──────────┐             │    │    │  │
│  │  │  │  │ (2-8x)   │◀─────────────│ Payment  │             │    │    │  │
│  │  │  │  └────┬─────┘              │ Service  │             │    │    │  │
│  │  │  │       │                    │  (2x)    │             │    │    │  │
│  │  │  │       │ Kafka Events       └──────────┘             │    │    │  │
│  │  │  │       ├──────────────┐                              │    │    │  │
│  │  │  │       │              ▼                              │    │    │  │
│  │  │  │       │        ┌──────────────┐                     │    │    │  │
│  │  │  │       │        │ Notification │                     │    │    │  │
│  │  │  │       │        │   Service    │                     │    │    │  │
│  │  │  │       │        │    (1x)      │                     │    │    │  │
│  │  │  │       │        └──────────────┘                     │    │    │  │
│  │  │  └───────┼─────────────────────────────────────────────┘    │    │  │
│  │  │          │                                                   │    │  │
│  │  │          │ HPA: Horizontal Pod Autoscaler                    │    │  │
│  │  │          │ Prometheus: Metrics Collection                    │    │  │
│  │  │          │ ArgoCD: GitOps Deployment                         │    │  │
│  │  └──────────┼───────────────────────────────────────────────────┘    │  │
│  │             │                                                         │  │
│  │  ┌──────────▼──────────────────────────────────────────────────┐    │  │
│  │  │               Private Subnets (Multi-AZ)                     │    │  │
│  │  │  ┌───────────┐  ┌────────────┐  ┌──────────┐               │    │  │
│  │  │  │   RDS     │  │ DynamoDB   │  │  Redis   │               │    │  │
│  │  │  │PostgreSQL │  │(Products)  │  │ (Cache)  │               │    │  │
│  │  │  │(Multi-AZ) │  └────────────┘  └──────────┘               │    │  │
│  │  │  └───────────┘                                              │    │  │
│  │  │  ┌─────────────────────────────┐                           │    │  │
│  │  │  │     AWS MSK (Kafka)         │                           │    │  │
│  │  │  │  - orders topic             │                           │    │  │
│  │  │  │  - analytics-results topic  │                           │    │  │
│  │  │  └──────────────┬──────────────┘                           │    │  │
│  │  └─────────────────┼────────────────────────────────────────────    │  │
│  └────────────────────┼──────────────────────────────────────────────────┘
│                       │                                                     │
│  ┌────────────────────┼────────────────────────────────────────────────┐  │
│  │                    │  Additional AWS Services                        │  │
│  │  ┌─────────────┐   │   ┌──────────┐   ┌─────────────┐             │  │
│  │  │    S3       │   │   │ Lambda   │   │   ECR       │             │  │
│  │  │ (Storage)   │   │   │(Serverless)│ │(Container   │             │  │
│  │  └─────────────┘   │   └──────────┘   │ Registry)   │             │  │
│  └────────────────────┼──────────────────└─────────────┘─────────────┘  │
└───────────────────────┼─────────────────────────────────────────────────┘
                        │ Cross-Cloud Kafka Connection
                        ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                         GOOGLE CLOUD (Analytics)                             │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │                     GCP Dataproc Cluster                               │  │
│  │  ┌─────────────────────────────────────────────────────────────────┐  │  │
│  │  │                  Apache Flink Analytics Job                      │  │  │
│  │  │  ┌──────────────┐      ┌──────────────┐     ┌────────────────┐ │  │  │
│  │  │  │Kafka Consumer│─────▶│Stream Process│────▶│ Kafka Producer │ │  │  │
│  │  │  │(orders topic)│      │  (Window Agg)│     │(analytics topic)│  │  │
│  │  │  └──────────────┘      └──────────────┘     └────────────────┘ │  │  │
│  │  └─────────────────────────────────────────────────────────────────┘  │  │
│  │                                 │                                      │  │
│  │  ┌──────────────────────────────▼───────────────────────────────┐    │  │
│  │  │            GCS (Google Cloud Storage)                         │    │  │
│  │  │  - Flink checkpoints                                          │    │  │
│  │  │  - Analytics results                                          │    │  │
│  │  │  - Data lake storage                                          │    │  │
│  │  └───────────────────────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Multi-Cloud Strategy

**Primary Cloud: AWS**
- **EKS (Elastic Kubernetes Service)**: Primary container orchestration platform
- **RDS PostgreSQL**: Relational data for users, orders, payments
- **DynamoDB**: NoSQL storage for product catalog
- **MSK (Managed Streaming for Kafka)**: Event streaming backbone
- **S3**: Object storage for static assets and backups
- **Lambda**: Serverless functions for event processing
- **ALB**: Application Load Balancer for traffic distribution
- **ECR**: Container image registry
- **Route 53**: DNS management
- **CloudWatch**: Basic monitoring and logging

**Secondary Cloud: GCP**
- **Dataproc**: Managed Spark/Flink cluster for stream processing
- **Cloud Storage (GCS)**: Data lake and checkpoints
- **Cloud Pub/Sub**: Alternative messaging (future)
- **BigQuery**: Data warehousing (future)

### Deployment Rationale

#### Why AWS as Primary Cloud?
1. **Mature Kubernetes Platform**: EKS is battle-tested with excellent AWS service integration
2. **Rich Database Options**: RDS and DynamoDB cover all data storage needs
3. **Managed Kafka**: MSK eliminates operational overhead of running Kafka clusters
4. **Cost Effectiveness**: Competitive pricing with reserved instances and savings plans
5. **Enterprise Support**: Extensive documentation and community support
6. **Compliance**: SOC 2, HIPAA, PCI-DSS certifications

#### Why GCP for Analytics?
1. **Best-in-Class Analytics**: Dataproc with Flink provides superior stream processing
2. **Workload Isolation**: Separates compute-intensive analytics from transactional workloads
3. **Cost Optimization**: Pay only for analytics compute when needed
4. **Data Processing Excellence**: GCP's heritage with Hadoop ecosystem
5. **Future Integration**: Easy path to BigQuery and ML services

#### Multi-Cloud Benefits
- **Vendor Lock-in Avoidance**: Not dependent on single cloud provider
- **Best-of-Breed Services**: Use optimal service from each provider
- **Risk Mitigation**: Disaster recovery across cloud providers
- **Skills Development**: Team gains multi-cloud expertise
- **Negotiation Power**: Better pricing negotiations with multiple options

---

## Microservices Architecture

### Architecture Principles

1. **Single Responsibility**: Each service owns a specific business capability
2. **Loose Coupling**: Services communicate via well-defined APIs
3. **High Cohesion**: Related functionality grouped within services
4. **Independent Deployment**: Services can be deployed independently
5. **Technology Diversity**: Different tech stacks per service needs
6. **Data Ownership**: Each service owns its database

### Detailed Microservices Diagram

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          MICROSERVICES ECOSYSTEM                             │
└─────────────────────────────────────────────────────────────────────────────┘

    ┌──────────────────────────────────────────────────────────────┐
    │                    API GATEWAY SERVICE                        │
    │  ┌──────────────────────────────────────────────────────┐   │
    │  │ Port: 5000                                            │   │
    │  │ Tech: Python/Flask                                    │   │
    │  │ Responsibilities:                                     │   │
    │  │  - Request routing                                    │   │
    │  │  - Load balancing                                     │   │
    │  │  - Rate limiting (future)                             │   │
    │  │  - Authentication gateway (future)                    │   │
    │  │ Scaling: HPA (2-10 pods, CPU 70%)                     │   │
    │  │ Database: None (stateless)                            │   │
    │  └──────────────────────────────────────────────────────┘   │
    └───────┬──────────────┬──────────────┬───────────────────────┘
            │              │              │
            ▼              ▼              ▼
    ┌───────────┐  ┌────────────┐  ┌────────────┐
    │           │  │            │  │            │
    
┌───▼───────────────────┐  ┌───▼────────────────┐  ┌───▼────────────────┐
│   USER SERVICE        │  │  PRODUCT SERVICE   │  │   ORDER SERVICE    │
│ ┌───────────────────┐ │  │ ┌────────────────┐ │  │ ┌────────────────┐ │
│ │ Port: 5001        │ │  │ │ Port: 5002     │ │  │ │ Port: 5003     │ │
│ │ Tech: Python/Flask│ │  │ │ Tech: Python   │ │  │ │ Tech: Python   │ │
│ │                   │ │  │ │      Flask     │ │  │ │      Flask     │ │
│ │ Responsibilities: │ │  │ │                │ │  │ │                │ │
│ │ - User CRUD       │ │  │ │ Responsibilities│ │  │ │ Responsibilities│ │
│ │ - Authentication  │ │  │ │ - Product CRUD │ │  │ │ - Order CRUD   │ │
│ │ - JWT token gen   │ │  │ │ - Inventory    │ │  │ │ - Order flow   │ │
│ │ - Profile mgmt    │ │  │ │ - Search       │ │  │ │ - Kafka publish│ │
│ │                   │ │  │ │ - Pagination   │ │  │ │ - Payment coord│ │
│ │ Endpoints:        │ │  │ │                │ │  │ │                │ │
│ │ POST /register    │ │  │ │ Endpoints:     │ │  │ │ Endpoints:     │ │
│ │ POST /login       │ │  │ │ GET /products  │ │  │ │ POST /orders   │ │
│ │ GET /users/:id    │ │  │ │ POST /products │ │  │ │ GET /orders/:id│ │
│ │ PUT /users/:id    │ │  │ │ GET /products  │ │  │ │ PATCH /status  │ │
│ │ GET /health       │ │  │ │     /:id       │ │  │ │ GET /health    │ │
│ │                   │ │  │ │ PATCH /stock   │ │  │ │                │ │
│ │ Scaling:          │ │  │ │ GET /health    │ │  │ │ Scaling:       │ │
│ │ Static 2 replicas │ │  │ │                │ │  │ │ HPA (2-8 pods) │ │
│ └─────────┬─────────┘ │  │ │ Scaling:       │ │  │ │ CPU 70%        │ │
│           │           │  │ │ Static 2 pods  │ │  │ └───────┬────────┘ │
│           ▼           │  │ └───────┬────────┘ │  │         │          │
│   ┌───────────────┐   │  │         │          │  │         │          │
│   │ PostgreSQL    │   │  │         ▼          │  │         ▼          │
│   │   (RDS)       │   │  │  ┌─────────────┐  │  │  ┌──────────────┐  │
│   │ users table   │   │  │  │  DynamoDB   │  │  │  │ PostgreSQL   │  │
│   │ - id (PK)     │   │  │  │  products   │  │  │  │   (RDS)      │  │
│   │ - username    │   │  │  │  - id (PK)  │  │  │  │ orders table │  │
│   │ - email       │   │  │  │  - name     │  │  │  │ - id (PK)    │  │
│   │ - password    │   │  │  │  - price    │  │  │  │ - user_id    │  │
│   │ - created_at  │   │  │  │  - stock    │  │  │  │ - total      │  │
│   └───────────────┘   │  │  │  - category │  │  │  │ - status     │  │
└───────────────────────┘  │  └─────────────┘  │  │  │ - created_at │  │
                           └────────────────────┘  │  │              │  │
                                                   │  │ order_items  │  │
                                                   │  │ - order_id   │  │
                                                   │  │ - product_id │  │
                                                   │  │ - quantity   │  │
                                                   │  │ - price      │  │
                                                   │  └──────────────┘  │
                                                   └─────────┬──────────┘
                                                             │ Kafka Events
                                                             │
    ┌────────────────────────────────────────────────────────┼──────────────┐
    │                 APACHE KAFKA (AWS MSK)                 │              │
    │  ┌──────────────────────────────────────────────────┐  │              │
    │  │ Topics:                                           │  │              │
    │  │  - orders (partition: 3, replication: 2)         │◀─┘              │
    │  │  - analytics-results (partition: 3, rep: 2)      │                 │
    │  │  - notifications (partition: 1, rep: 2)          │                 │
    │  │                                                   │                 │
    │  │ Message Format:                                   │                 │
    │  │  {                                                │                 │
    │  │    "event_type": "order_created",                │                 │
    │  │    "order_id": 123,                              │                 │
    │  │    "user_id": 456,                               │                 │
    │  │    "total_amount": 99.99,                        │                 │
    │  │    "timestamp": "2025-11-23T10:30:00Z"           │                 │
    │  │  }                                                │                 │
    │  └──────────────────────────────────────────────────┘                 │
    └────────┬──────────────────────────────┬──────────────────────────────┘
             │                              │
             ▼                              ▼
┌────────────────────────┐      ┌──────────────────────────┐
│  NOTIFICATION SERVICE  │      │   PAYMENT SERVICE        │
│ ┌────────────────────┐ │      │ ┌──────────────────────┐ │
│ │ Port: 5004         │ │      │ │ Port: 5005           │ │
│ │ Tech: Python/Flask │ │      │ │ Tech: Python/Flask   │ │
│ │                    │ │      │ │                      │ │
│ │ Responsibilities:  │ │      │ │ Responsibilities:    │ │
│ │ - Kafka consumer   │ │      │ │ - Payment processing│ │
│ │ - Email sending    │ │      │ │ - Transaction mgmt  │ │
│ │ - SMS sending      │ │      │ │ - Refund handling   │ │
│ │ - Push notifs      │ │      │ │ - Stripe integration│ │
│ │ - Template mgmt    │ │      │ │                      │ │
│ │                    │ │      │ │ Endpoints:           │ │
│ │ Consumes:          │ │      │ │ POST /process       │ │
│ │ - orders topic     │ │      │ │ GET /payments/:id   │ │
│ │                    │ │      │ │ POST /refund        │ │
│ │ Integrations:      │ │      │ │ GET /health         │ │
│ │ - SMTP server      │ │      │ │                      │ │
│ │ - Twilio (SMS)     │ │      │ │ Scaling:             │ │
│ │ - Firebase (Push)  │ │      │ │ Static 2 replicas   │ │
│ │                    │ │      │ └──────────┬───────────┘ │
│ │ Scaling:           │ │      │            │             │
│ │ Static 1 replica   │ │      │            ▼             │
│ │ (consumer group)   │ │      │   ┌────────────────┐    │
│ └────────────────────┘ │      │   │  PostgreSQL    │    │
│                        │      │   │    (RDS)       │    │
│ Database: None         │      │   │ payments table │    │
└────────────────────────┘      │   │ - id (PK)      │    │
                                │   │ - order_id     │    │
                                │   │ - amount       │    │
             Kafka              │   │ - status       │    │
             orders             │   │ - txn_id       │    │
             topic              │   │ - created_at   │    │
               │                │   └────────────────┘    │
               │                └──────────────────────────┘
               ▼
    ┌──────────────────────────────────────┐
    │  ANALYTICS SERVICE (GCP Dataproc)    │
    │ ┌──────────────────────────────────┐ │
    │ │ Tech: Apache Flink + Java        │ │
    │ │                                  │ │
    │ │ Responsibilities:                │ │
    │ │ - Stream processing              │ │
    │ │ - Windowed aggregations          │ │
    │ │ - Real-time metrics              │ │
    │ │ - Anomaly detection              │ │
    │ │                                  │ │
    │ │ Processing:                      │ │
    │ │ 1. Consume from orders topic     │ │
    │ │ 2. Window by time (5 min)        │ │
    │ │ 3. Aggregate: sum, count, avg    │ │
    │ │ 4. Produce to analytics topic    │ │
    │ │                                  │ │
    │ │ Metrics Computed:                │ │
    │ │ - Orders per minute              │ │
    │ │ - Revenue per window             │ │
    │ │ - Top products                   │ │
    │ │ - User activity patterns         │ │
    │ │                                  │ │
    │ │ Scaling:                         │ │
    │ │ Dataproc cluster:                │ │
    │ │ - 1 master (n1-standard-2)       │ │
    │ │ - 2 workers (n1-standard-2)      │ │
    │ └──────────────┬───────────────────┘ │
    │                │                     │
    │                ▼                     │
    │      ┌──────────────────┐           │
    │      │  GCS (Storage)   │           │
    │      │  - Checkpoints   │           │
    │      │  - State backups │           │
    │      │  - Results       │           │
    │      └──────────────────┘           │
    └──────────────────────────────────────┘
```

### Service Inventory & Detailed Responsibilities

#### 1. API Gateway Service
- **Port**: 5000
- **Technology**: Python 3.11, Flask 3.0, Gunicorn
- **Storage**: None (stateless)
- **Primary Functions**:
  - Route HTTP requests to appropriate microservices
  - Load distribution across service instances
  - Request/response transformation
  - Error handling and standardization
  - Health check aggregation
  
- **Communication Pattern**: 
  - Inbound: HTTP REST from Internet via AWS ALB
  - Outbound: HTTP REST to all internal services
  
- **Scaling Strategy**: 
  - HPA based on CPU (70%) and memory (80%)
  - Min: 2 replicas, Max: 10 replicas
  - Scale up: 100% increase every 30s
  - Scale down: 50% decrease every 5min
  
- **Resource Allocation**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU

#### 2. User Service
- **Port**: 5001
- **Technology**: Python 3.11, Flask 3.0, SQLAlchemy 2.0, JWT
- **Storage**: PostgreSQL 15 (RDS Multi-AZ)
- **Primary Functions**:
  - User registration with password hashing (bcrypt)
  - Authentication and JWT token generation
  - User profile CRUD operations
  - Password reset functionality
  - Session management
  
- **Database Schema**:
  ```sql
  CREATE TABLE users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(80) UNIQUE NOT NULL,
    email VARCHAR(120) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(120),
    phone VARCHAR(20),
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  ```
  
- **API Endpoints**:
  - `POST /api/users/register` - Create new user
  - `POST /api/users/login` - Authenticate and get JWT
  - `GET /api/users/:id` - Get user profile
  - `PUT /api/users/:id` - Update user profile
  - `DELETE /api/users/:id` - Soft delete user
  - `GET /health` - Health check
  
- **Scaling Strategy**: Static 2 replicas (low variance in load)
  
- **Resource Allocation**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU

#### 3. Product Service
- **Port**: 5002
- **Technology**: Python 3.11, Flask 3.0, Boto3 (DynamoDB SDK)
- **Storage**: DynamoDB (On-demand billing)
- **Primary Functions**:
  - Product catalog management
  - Inventory tracking
  - Product search and filtering
  - Category management
  - Stock level monitoring
  
- **Database Schema** (DynamoDB):
  ```
  Table: products
  Partition Key: id (Number)
  Attributes:
    - name (String)
    - description (String)
    - price (Number)
    - category (String)
    - stock_quantity (Number)
    - image_url (String)
    - sku (String)
    - created_at (String - ISO 8601)
    - updated_at (String - ISO 8601)
    
  Global Secondary Indexes:
    - category-index (category as partition key)
    - sku-index (sku as partition key)
  ```
  
- **API Endpoints**:
  - `GET /api/products` - List products (paginated)
  - `GET /api/products/:id` - Get product details
  - `POST /api/products` - Create product (admin)
  - `PUT /api/products/:id` - Update product (admin)
  - `DELETE /api/products/:id` - Delete product (admin)
  - `PATCH /api/products/:id/stock` - Update stock
  - `GET /health` - Health check
  
- **Scaling Strategy**: Static 2 replicas
  
- **Resource Allocation**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU

#### 4. Order Service
- **Port**: 5003
- **Technology**: Python 3.11, Flask 3.0, SQLAlchemy 2.0, Kafka-Python
- **Storage**: PostgreSQL 15 (RDS Multi-AZ)
- **Primary Functions**:
  - Order creation and validation
  - Order status management workflow
  - Integration with payment service
  - Integration with product service (stock check)
  - Publish order events to Kafka
  - Order history tracking
  
- **Database Schema**:
  ```sql
  CREATE TABLE orders (
    id SERIAL PRIMARY KEY,
    user_id INTEGER NOT NULL,
    total_amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    shipping_address TEXT,
    payment_id VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  
  CREATE TABLE order_items (
    id SERIAL PRIMARY KEY,
    order_id INTEGER REFERENCES orders(id),
    product_id INTEGER NOT NULL,
    product_name VARCHAR(200) NOT NULL,
    quantity INTEGER NOT NULL,
    price DECIMAL(10, 2) NOT NULL
  );
  ```
  
- **Order Status Flow**:
  1. `pending` → Order created, awaiting payment
  2. `processing` → Payment confirmed
  3. `shipped` → Order dispatched
  4. `delivered` → Order completed
  5. `cancelled` → Order cancelled
  
- **API Endpoints**:
  - `POST /api/orders` - Create order
  - `GET /api/orders/:id` - Get order details
  - `GET /api/orders/user/:userId` - Get user orders
  - `PATCH /api/orders/:id/status` - Update status
  - `DELETE /api/orders/:id` - Cancel order
  - `GET /health` - Health check
  
- **Kafka Integration**:
  - Produces to `orders` topic on order creation
  - Event payload includes order details for downstream processing
  
- **Scaling Strategy**: 
  - HPA based on CPU (70%)
  - Min: 2 replicas, Max: 8 replicas
  
- **Resource Allocation**:
  - Requests: 512Mi memory, 500m CPU
  - Limits: 1Gi memory, 1000m CPU

#### 5. Payment Service
- **Port**: 5005
- **Technology**: Python 3.11, Flask 3.0, SQLAlchemy 2.0, Stripe SDK
- **Storage**: PostgreSQL 15 (RDS Multi-AZ)
- **Primary Functions**:
  - Payment processing integration
  - Transaction management
  - Refund handling
  - Payment method management
  - PCI compliance (via Stripe)
  
- **Database Schema**:
  ```sql
  CREATE TABLE payments (
    id SERIAL PRIMARY KEY,
    order_id INTEGER UNIQUE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    payment_method VARCHAR(50),
    transaction_id VARCHAR(100) UNIQUE,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
  );
  ```
  
- **API Endpoints**:
  - `POST /api/payments/process` - Process payment
  - `GET /api/payments/:id` - Get payment details
  - `POST /api/payments/refund` - Issue refund
  - `GET /api/payments/order/:orderId` - Get payment by order
  - `GET /health` - Health check
  
- **Scaling Strategy**: Static 2 replicas
  
- **Resource Allocation**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU

#### 6. Notification Service
- **Port**: 5004
- **Technology**: Python 3.11, Flask 3.0, Kafka-Python, SMTP, Twilio
- **Storage**: None (stateless)
- **Primary Functions**:
  - Consume order events from Kafka
  - Send email notifications (SMTP/SendGrid)
  - Send SMS notifications (Twilio)
  - Send push notifications (Firebase)
  - Template management
  - Notification retry logic
  
- **Notification Types**:
  - Order confirmation
  - Order status updates
  - Payment confirmation
  - Shipping notifications
  - Promotional emails (future)
  
- **API Endpoints**:
  - `POST /api/notifications/send` - Manual notification
  - `GET /health` - Health check
  
- **Kafka Integration**:
  - Consumes from `orders` topic
  - Consumer group: `notification-service-group`
  - Auto-commit: false (manual offset management)
  
- **Scaling Strategy**: Static 1 replica (single consumer per partition)
  
- **Resource Allocation**:
  - Requests: 256Mi memory, 250m CPU
  - Limits: 512Mi memory, 500m CPU

#### 7. Analytics Service (Flink)
- **Technology**: Apache Flink 1.17, Java 11, Kafka Connector
- **Infrastructure**: GCP Dataproc cluster
- **Primary Functions**:
  - Real-time stream processing
  - Windowed aggregations (tumbling, sliding)
  - Event time processing
  - Stateful computations
  - Anomaly detection
  
- **Processing Pipeline**:
  1. **Source**: Kafka consumer (orders topic)
  2. **Transform**: Parse JSON, extract fields
  3. **Window**: 5-minute tumbling windows
  4. **Aggregate**: Count, sum, average operations
  5. **Sink**: Kafka producer (analytics-results topic) + GCS
  
- **Metrics Computed**:
  - Total orders per window
  - Revenue per window
  - Average order value
  - Top-selling products
  - Orders by region
  - Peak hour analysis
  
- **Cluster Configuration**:
  - Master: n1-standard-2 (2 vCPU, 7.5GB RAM)
  - Workers: 2x n1-standard-2
  - Parallelism: 4
  - Checkpointing: Every 60 seconds to GCS
  
- **Resource Allocation**:
  - Job Manager: 2GB heap
  - Task Manager: 4GB heap
  - Network buffers: 512MB

---

## Service Interconnections & Communication Mechanisms

### Detailed Communication Flow Diagram

```
                        ┌─────────────┐
                        │   CLIENT    │
                        │  (Browser)  │
                        └──────┬──────┘
                               │ HTTPS
                               ▼
                        ┌──────────────┐
                        │  AWS ALB     │
                        │ (443/80)     │
                        └──────┬───────┘
                               │
                               ▼
                    ┌──────────────────────┐
                    │  INGRESS CONTROLLER  │
                    │  (NGINX)             │
                    │  Path-based routing  │
                    └──────────┬───────────┘
                               │
                               ▼
        ┌──────────────────────┼──────────────────────┐
        │                      │                      │
        ▼                      ▼                      ▼
┌───────────────┐      ┌──────────────┐      ┌──────────────┐
│  /api/users/* │      │/api/products│      │ /api/orders/*│
└───────┬───────┘      └──────┬───────┘      └──────┬───────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  API GATEWAY    │   │  API GATEWAY    │   │  API GATEWAY    │
│   Service       │   │    Service      │   │    Service      │
│   :5000         │   │    :5000        │   │    :5000        │
└────────┬────────┘   └────────┬────────┘   └────────┬────────┘
         │                     │                     │
         │ HTTP REST           │ HTTP REST           │ HTTP REST
         │ (Cluster IP)        │ (Cluster IP)        │ (Cluster IP)
         ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│  USER SERVICE   │   │ PRODUCT SERVICE │   │  ORDER SERVICE  │
│  ClusterIP      │   │   ClusterIP     │   │   ClusterIP     │
│  user-service   │   │ product-service │   │  order-service  │
│      :80        │   │       :80       │   │       :80       │
└────────┬────────┘   └────────┬────────┘   └────────┬────────┘
         │                     │                     │
         │ SQL                 │ SDK API             │ SQL + Kafka
         ▼                     ▼                     ▼
┌─────────────────┐   ┌─────────────────┐   ┌─────────────────┐
│   PostgreSQL    │   │    DynamoDB     │   │   PostgreSQL    │
│   (RDS)         │   │   (NoSQL)       │   │   (RDS)         │
│   user-db:5432  │   │   products      │   │  order-db:5432  │
└─────────────────┘   └─────────────────┘   └────────┬────────┘
                                                      │
                                                      │ Produce
                                                      ▼
                                          ┌────────────────────────┐
                                          │   KAFKA (MSK)          │
                                          │   Topic: orders        │
                                          │   Partitions: 3        │
                                          │   Replication: 2       │
                                          └───┬──────────────┬─────┘
                                              │              │
                                    Consume   │              │ Consume
                                              ▼              ▼
                                    ┌──────────────┐  ┌──────────────┐
                                    │ NOTIFICATION │  │  ANALYTICS   │
                                    │   SERVICE    │  │   SERVICE    │
                                    │   :5004      │  │  (Flink)     │
                                    └──────┬───────┘  └──────┬───────┘
                                           │                 │
                                           │ SMTP/SMS        │ Produce
                                           ▼                 ▼
                                    ┌──────────────┐  ┌──────────────┐
                                    │ Email/SMS    │  │   KAFKA      │
                                    │ Providers    │  │  analytics-  │
                                    └──────────────┘  │  results     │
                                                      └──────────────┘
                                                             │
                                                             │ Consume
                                                             ▼
                                                      ┌──────────────┐
                                                      │  Dashboard   │
                                                      │  Service     │
                                                      │  (Future)    │
                                                      └──────────────┘


Inter-Service Authentication Flow:
═══════════════════════════════════

1. User Login:
   Client → API Gateway → User Service
   POST /api/users/login {username, password}
   ← JWT Token (expires in 1 hour)

2. Authenticated Request:
   Client → API Gateway → Order Service
   Headers: {Authorization: Bearer <JWT>}
   Order Service validates JWT
   ← Response with order data

3. Service-to-Service:
   Order Service → Product Service
   Headers: {Authorization: Bearer <SERVICE_TOKEN>}
   (Service tokens from Kubernetes secrets)
```

### Communication Patterns in Detail

#### 1. Synchronous Communication (HTTP REST)

**Pattern**: Request-Response over HTTP/HTTPS

**Use Cases**:
- Client → API Gateway: All user-initiated actions
- API Gateway → Microservices: Request routing
- Order Service → Product Service: Stock validation
- Order Service → Payment Service: Payment processing
- Order Service → User Service: User validation

**Implementation**:
```python
# Example: Order Service calling Product Service
import requests

response = requests.get(
    f"{PRODUCT_SERVICE_URL}/api/products/{product_id}",
    headers={"Authorization": f"Bearer {service_token}"},
    timeout=5  # 5 second timeout
)

if response.status_code == 200:
    product = response.json()
    # Process product data
elif response.status_code == 404:
    raise ProductNotFoundException()
else:
    raise ServiceCommunicationException()
```

**Service Discovery**:
- Uses Kubernetes DNS: `http://product-service.default.svc.cluster.local:80`
- Short form: `http://product-service:80`
- Environment variables for service URLs

**Benefits**:
- Simple to understand and debug
- Immediate response
- Strong consistency

**Challenges**:
- Tight coupling
- Cascading failures
- Increased latency

**Mitigation**:
- Circuit breakers (future: Istio)
- Timeouts and retries
- Health checks
- Fallback responses

#### 2. Asynchronous Communication (Apache Kafka)

**Pattern**: Event-driven messaging

**Use Cases**:
- Order Service → Notification Service: Order events
- Order Service → Analytics Service: Business intelligence
- Payment Service → Order Service: Payment status (future)

**Kafka Configuration**:
```yaml
Cluster: MSK (3 brokers)
Topic: orders
  Partitions: 3
  Replication Factor: 2
  Retention: 7 days
  Compression: snappy

Topic: analytics-results
  Partitions: 3
  Replication Factor: 2
  Retention: 30 days
  Compression: gzip
```

**Producer Implementation** (Order Service):
```python
from kafka import KafkaProducer
import json

producer = KafkaProducer(
    bootstrap_servers=KAFKA_BROKERS,
    value_serializer=lambda v: json.dumps(v).encode('utf-8'),
    acks='all',  # Wait for all replicas
    retries=3,
    max_in_flight_requests_per_connection=1  # Preserve order
)

# Produce event
order_event = {
    'event_type': 'order_created',
    'order_id': order.id,
    'user_id': order.user_id,
    'total_amount': float(order.total_amount),
    'items': [item.to_dict() for item in order.items],
    'timestamp': datetime.utcnow().isoformat()
}

future = producer.send('orders', value=order_event)
record_metadata = future.get(timeout=10)
print(f"Sent to partition {record_metadata.partition}")
```

**Consumer Implementation** (Notification Service):
```python
from kafka import KafkaConsumer
import json

consumer = KafkaConsumer(
    'orders',
    bootstrap_servers=KAFKA_BROKERS,
    group_id='notification-service-group',
    value_deserializer=lambda m: json.loads(m.decode('utf-8')),
    auto_offset_reset='earliest',
    enable_auto_commit=False,  # Manual commit
    max_poll_records=10
)

for message in consumer:
    try:
        event = message.value
        
        if event['event_type'] == 'order_created':
            send_order_confirmation(event)
        elif event['event_type'] == 'order_shipped':
            send_shipping_notification(event)
        
        # Manual commit after successful processing
        consumer.commit()
    except Exception as e:
        logger.error(f"Processing failed: {e}")
        # Don't commit - message will be reprocessed
```

**Benefits**:
- Loose coupling
- Asynchronous processing
- Event replay capability
- Scalability
- Fault tolerance

**Challenges**:
- Eventual consistency
- Message ordering
- Duplicate handling

**Mitigation**:
- Idempotent consumers
- Message deduplication
- Offset management
- Dead letter queues

#### 3. Database Access Patterns

**Pattern**: Direct database connections

**User Service → PostgreSQL**:
```python
# SQLAlchemy ORM
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

class User(db.Model):
    __tablename__ = 'users'
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True)
    email = db.Column(db.String(120), unique=True)

# Query
user = User.query.filter_by(username='john').first()

# Transaction
db.session.add(new_user)
db.session.commit()
```

**Product Service → DynamoDB**:
```python
# Boto3 SDK
import boto3

dynamodb = boto3.resource('dynamodb', region_name='us-east-1')
table = dynamodb.Table('products')

# Get item
response = table.get_item(Key={'id': product_id})
product = response.get('Item')

# Put item
table.put_item(Item={
    'id': product_id,
    'name': 'Laptop',
    'price': Decimal('999.99'),
    'stock_quantity': 50
})

# Query with GSI
response = table.query(
    IndexName='category-index',
    KeyConditionExpression=Key('category').eq('Electronics')
)
```

**Connection Pooling**:
- PostgreSQL: pgbouncer (session pooling)
- Max connections per service: 20
- Connection timeout: 30 seconds

#### 4. Caching Strategy (Redis)

**Pattern**: Read-through cache

**Use Cases**:
- Product catalog caching
- User session storage
- Rate limiting counters
- Frequently accessed data

**Implementation**:
```python
import redis

redis_client = redis.Redis(
    host='redis.default.svc.cluster.local',
    port=6379,
    db=0,
    decode_responses=True
)

# Cache product data
def get_product(product_id):
    # Try cache first
    cache_key = f"product:{product_id}"
    cached = redis_client.get(cache_key)
    
    if cached:
        return json.loads(cached)
    
    # Cache miss - fetch from database
    product = fetch_from_dynamodb(product_id)
    
    # Store in cache (TTL: 1 hour)
    redis_client.setex(
        cache_key,
        3600,
        json.dumps(product)
    )
    
    return product
```

### Service Resilience Patterns

#### Circuit Breaker (Planned)
```python
from pybreaker import CircuitBreaker

# Trips after 5 failures in 60 seconds
breaker = CircuitBreaker(fail_max=5, timeout_duration=60)

@breaker
def call_product_service(product_id):
    response = requests.get(f"{PRODUCT_SERVICE_URL}/api/products/{product_id}")
    return response.json()

try:
    product = call_product_service(123)
except CircuitBreakerOpen:
    # Return cached data or default
    product = get_cached_product(123)
```

#### Retry with Exponential Backoff
```python
from tenacity import retry, stop_after_attempt, wait_exponential

@retry(
    stop=stop_after_attempt(3),
    wait=wait_exponential(multiplier=1, min=1, max=10)
)
def call_payment_service(payment_data):
    response = requests.post(
        f"{PAYMENT_SERVICE_URL}/api/payments/process",
        json=payment_data,
        timeout=10
    )
    response.raise_for_status()
    return response.json()
```

#### Timeout Configuration
- API Gateway → Services: 30 seconds
- Service → Service: 5 seconds
- Service → Database: 10 seconds
- Kafka producer: 10 seconds
- Health checks: 3 seconds

### Data Consistency Patterns

#### Strong Consistency (ACID Transactions)
- User Service: PostgreSQL transactions
- Order Service: PostgreSQL transactions
- Payment Service: PostgreSQL transactions

```python
# Example: Order creation with transaction
try:
    db.session.begin()
    
    # Create order
    order = Order(user_id=user_id, total=total)
    db.session.add(order)
    db.session.flush()  # Get order ID
    
    # Create order items
    for item in items:
        order_item = OrderItem(order_id=order.id, **item)
        db.session.add(order_item)
    
    # Commit transaction
    db.session.commit()
    
except Exception as e:
    db.session.rollback()
    raise
```

#### Eventual Consistency (Event-Driven)
- Order events to notifications
- Order events to analytics
- Payment status updates

**Strategy**:
- Idempotent operations
- Event versioning
- Compensating transactions for failures

### Security in Service Communication

#### Mutual TLS (Future Enhancement)
```yaml
apiVersion: v1
kind: ServiceMesh
metadata:
  name: istio-config
spec:
  mtls:
    mode: STRICT  # Enforce mTLS between all services
```

#### API Authentication
- **External**: JWT tokens from User Service
- **Internal**: Service accounts with Kubernetes secrets

#### Network Policies
```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-netpol
spec:
  podSelector:
    matchLabels:
      app: order-service
  policyTypes:
  - Ingress
  - Egress
  ingress:
  - from:
    - podSelector:
        matchLabels:
          app: api-gateway
    ports:
    - protocol: TCP
      port: 5003
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: product-service
    ports:
    - protocol: TCP
      port: 5002
```

---

## Design Rationale & Decision Log

### Architectural Decisions

#### Decision 1: Why Microservices Over Monolith?

**Context**: Need to build scalable e-commerce platform

**Options Considered**:
1. Monolithic architecture
2. Microservices architecture
3. Modular monolith

**Decision**: Microservices Architecture

**Rationale**:
- **Independent Scaling**: Order service experiences 10x traffic during sales, while user service remains steady. Microservices allow scaling only what's needed
- **Technology Flexibility**: Analytics needs Java/Flink for stream processing, while REST APIs work well in Python. Microservices enable polyglot architecture
- **Fault Isolation**: Payment service failure shouldn't crash product browsing. Microservices provide bulkheads
- **Team Autonomy**: Different teams can own different services with independent release cycles
- **Deployment Flexibility**: Can deploy order service updates without touching user service

**Trade-offs Accepted**:
- Increased operational complexity (mitigated by Kubernetes)
- Network latency between services (acceptable for our SLAs)
- Eventual consistency challenges (managed with event sourcing)
- Higher infrastructure costs (offset by independent scaling efficiency)

---

#### Decision 2: Why Apache Kafka for Event Streaming?

**Context**: Need asynchronous communication between services

**Options Considered**:
1. Apache Kafka
2. RabbitMQ
3. AWS SQS
4. Direct HTTP callbacks

**Decision**: Apache Kafka (AWS MSK)

**Rationale**:
- **Durability**: Messages persist for 7 days, enabling event replay and debugging
- **Scalability**: Handles millions of events per second with partitioning
- **Decoupling**: Order service doesn't know about consumers (notification, analytics)
- **Stream Processing**: Native integration with Apache Flink for analytics
- **Managed Service**: MSK eliminates operational overhead of running Kafka
- **Ordering Guarantees**: Per-partition ordering crucial for order processing
- **Multiple Consumers**: Both notification and analytics consume same events

**Trade-offs Accepted**:
- Higher cost than SQS ($300/month for MSK vs $50 for SQS)
- Learning curve for team
- Eventual consistency model
- More complex than simple queues

**Why Not Alternatives**:
- RabbitMQ: Less suited for high-throughput streaming
- SQS: No event replay, limited retention, not ideal for stream processing
- HTTP callbacks: Tight coupling, retry complexity, no persistence

---

#### Decision 3: Why Multi-Cloud (AWS + GCP)?

**Context**: Need to deploy application infrastructure

**Options Considered**:
1. Single cloud (AWS only)
2. Single cloud (GCP only)
3. Multi-cloud (AWS + GCP)
4. On-premises + cloud hybrid

**Decision**: Multi-Cloud (AWS Primary + GCP for Analytics)

**Rationale**:
- **Best-of-Breed**: AWS excels at application hosting, GCP excels at data processing
- **Risk Mitigation**: Not locked into single vendor; disaster recovery across clouds
- **Cost Optimization**: GCP Dataproc more cost-effective for Flink than AWS EMR
- **Learning Opportunity**: Team gains multi-cloud expertise
- **Workload Isolation**: Analytics workload separated from transactional load

**Trade-offs Accepted**:
- Increased operational complexity (two cloud consoles)
- Cross-cloud networking costs
- Skill requirement for two platforms
- Inconsistent tooling and APIs

**Implementation Strategy**:
- Keep compute and data gravity in AWS
- Use GCP only for analytics workload
- Kafka as integration point between clouds
- Minimize cross-cloud data transfer

---

#### Decision 4: Why Kubernetes (EKS) Over ECS or Lambda?

**Context**: Need container orchestration platform

**Options Considered**:
1. Amazon EKS (Kubernetes)
2. Amazon ECS (proprietary)
3. AWS Lambda (serverless)
4. EC2 instances directly

**Decision**: Amazon EKS (Kubernetes)

**Rationale**:
- **Industry Standard**: Kubernetes is cloud-agnostic, transferable skills
- **Rich Ecosystem**: Helm charts, operators, service meshes, monitoring tools
- **Portability**: Can migrate to GKE or on-premises if needed
- **Advanced Features**: HPA, network policies, custom schedulers, StatefulSets
- **Community Support**: Massive community, extensive documentation
- **GitOps Ready**: Native integration with ArgoCD for declarative deployments

**Trade-offs Accepted**:
- Steeper learning curve than ECS
- Control plane costs ($0.10/hour = $73/month)
- More complex than serverless
- Requires more operational expertise

**Why Not Alternatives**:
- ECS: Vendor lock-in to AWS, less feature-rich, smaller community
- Lambda: Cold starts, 15-minute timeout limit, not suitable for long-running processes
- EC2: Manual scaling, no self-healing, higher operational burden

---

#### Decision 5: Why PostgreSQL (RDS) + DynamoDB?

**Context**: Need database for different data patterns

**Options Considered**:
1. PostgreSQL for everything
2. DynamoDB for everything
3. MongoDB
4. PostgreSQL + DynamoDB (chosen)

**Decision**: PostgreSQL (RDS) for transactional + DynamoDB for catalog

**Rationale**:

**PostgreSQL for Users/Orders/Payments**:
- **ACID Transactions**: Critical for financial data integrity
- **Complex Queries**: JOIN operations for order items, user orders
- **Relational Data**: Natural fit for user-order-payment relationships
- **Referential Integrity**: Foreign keys ensure data consistency
- **Mature Ecosystem**: ORMs, migration tools, backup solutions

**DynamoDB for Products**:
- **High Throughput**: Product catalog read-heavy (90% reads)
- **Flexible Schema**: Product attributes vary by category
- **Predictable Performance**: Single-digit millisecond latency at scale
- **Auto-Scaling**: Pay-per-request pricing scales with traffic
- **No Maintenance**: Fully managed, no patches or upgrades

**Trade-offs Accepted**:
- Two databases to manage instead of one
- Different query patterns and SDKs
- Cross-database joins not possible (mitigated by API composition)

---

#### Decision 6: Why GitOps with ArgoCD?

**Context**: Need CI/CD deployment strategy

**Options Considered**:
1. kubectl apply in CI/CD pipeline
2. Helm direct installs
3. ArgoCD (GitOps)
4. Flux CD (GitOps alternative)

**Decision**: ArgoCD for GitOps

**Rationale**:
- **Declarative**: Git is single source of truth for cluster state
- **Auditability**: Every change tracked in Git history
- **Easy Rollback**: `git revert` to previous working state
- **Security**: No kubectl credentials in CI/CD; ArgoCD pulls changes
- **Drift Detection**: Auto-sync corrects manual kubectl changes
- **Multi-Cluster**: Can manage multiple Kubernetes clusters from one place
- **Visualization**: UI shows deployment status and sync health

**Trade-offs Accepted**:
- Additional component to run in cluster
- Git becomes critical path (mitigated by multiple repos)
- Learning curve for GitOps concepts

**Why Not Alternatives**:
- kubectl in CI/CD: Requires credentials in pipeline, no drift detection
- Helm direct: No automated sync, manual updates
- Flux CD: ArgoCD has better UI and multi-tenancy support

---

#### Decision 7: Why Python Flask for Microservices?

**Context**: Choose technology stack for REST APIs

**Options Considered**:
1. Python with Flask
2. Node.js with Express
3. Java with Spring Boot
4. Go with Gin

**Decision**: Python with Flask (except Analytics)

**Rationale**:
- **Team Expertise**: Team already proficient in Python
- **Fast Development**: Flask is lightweight and productive
- **Rich Ecosystem**: SQLAlchemy, Kafka clients, AWS SDKs
- **Readability**: Python code is maintainable and self-documenting
- **Data Science Integration**: Easy to add ML features later
- **Docker Support**: Official slim Python images are lightweight

**Trade-offs Accepted**:
- Lower raw performance than Go or Java
- GIL limitations for CPU-bound tasks (not an issue for I/O-bound APIs)
- Async support less mature than Node.js

**Why Analytics in Java?**:
- Apache Flink is Java-native
- Better performance for stream processing
- Mature Flink SDK in Java

---

#### Decision 8: Why Horizontal Pod Autoscaling (HPA)?

**Context**: Need to scale applications based on load

**Options Considered**:
1. Static replica count
2. Horizontal Pod Autoscaler (HPA)
3. Vertical Pod Autoscaler (VPA)
4. Manual scaling

**Decision**: HPA for API Gateway and Order Service, Static for others

**Rationale**:

**HPA for API Gateway & Order Service**:
- **Variable Load**: Traffic varies 10x between off-peak and sales events
- **Cost Optimization**: Scale down during low traffic to save money
- **Automatic**: No manual intervention during traffic spikes
- **Reliable**: Kubernetes manages scaling decisions based on metrics

**Static Replicas for User/Product/Payment/Notification**:
- **Predictable Load**: User CRUD operations are steady
- **Simplicity**: No need for scaling complexity
- **Faster Startup**: Always have capacity ready
- **Cost**: Minimal cost difference (2-3 pods)

**Configuration**:
- API Gateway: 2-10 replicas at 70% CPU
- Order Service: 2-8 replicas at 70% CPU
- Scale up fast (100% increase every 30s)
- Scale down slow (50% decrease every 5min)

**Trade-offs Accepted**:
- Metric collection overhead (Prometheus)
- Potential overprovisioning during scale-up
- Complexity in tuning thresholds

---

#### Decision 9: Why Prometheus + Grafana for Observability?

**Context**: Need monitoring and alerting

**Options Considered**:
1. CloudWatch only
2. Prometheus + Grafana
3. Datadog (commercial)
4. New Relic (commercial)

**Decision**: Prometheus + Grafana + CloudWatch

**Rationale**:
- **Open Source**: No per-host licensing costs
- **Kubernetes Native**: Service discovery, pod metrics out-of-box
- **Flexible Querying**: PromQL for custom queries and dashboards
- **Rich Ecosystem**: Exporters for databases, Kafka, etc.
- **Alertmanager**: Flexible alerting with Slack/PagerDuty integration
- **Grafana**: Beautiful dashboards, template variables, annotations

**CloudWatch for**:
- AWS-specific metrics (EKS, RDS, MSK)
- Log aggregation
- Billing alerts

**Trade-offs Accepted**:
- Need to run Prometheus in cluster
- Data retention limits (30 days default)
- Learning curve for PromQL

**Why Not Commercial**:
- Datadog: $15/host/month = $500+/month for our scale
- New Relic: Similar pricing
- Budget-conscious for learning project

---

### Infrastructure Design Rationale

#### Multi-AZ Deployment

**Decision**: Deploy across 2 Availability Zones

**Rationale**:
- **High Availability**: Survive single AZ failure
- **Load Distribution**: Traffic balanced across zones
- **Database Resilience**: RDS Multi-AZ automatic failover

**Cost Impact**:
- 2x data transfer costs between AZs
- Acceptable for production-grade availability

---

#### VPC Design (10.0.0.0/16)

**Decision**: Public subnets for EKS, private subnets for databases

**Rationale**:
- **Security**: Databases not publicly accessible
- **Compliance**: Industry best practice
- **NAT Gateway**: Future for egress from private subnets

**Subnet Allocation**:
- 10.0.0.0/24 - Public Subnet AZ1 (256 IPs)
- 10.0.1.0/24 - Public Subnet AZ2 (256 IPs)
- 10.0.10.0/24 - Private Subnet AZ1 (256 IPs)
- 10.0.11.0/24 - Private Subnet AZ2 (256 IPs)

---

#### Resource Sizing

**EKS Node Group**:
- Instance Type: t3.medium (2 vCPU, 4GB RAM)
- Min: 2 nodes, Max: 4 nodes
- **Rationale**: 
  - t3 burstable for variable workloads
  - medium size balances cost and capacity
  - Can run 8-12 pods per node (256Mi pods)

**RDS Instance**:
- Instance Type: db.t3.micro (2 vCPU, 1GB RAM)
- Storage: 20GB gp3
- **Rationale**:
  - Free tier eligible
  - Sufficient for development/demo
  - Can scale vertically if needed

---

#### Security Groups

**EKS Node Security Group**:
- Ingress: Port 443 from ALB
- Egress: All (for pulling images, calling AWS APIs)

**RDS Security Group**:
- Ingress: Port 5432 from EKS nodes only
- No public internet access

**MSK Security Group**:
- Ingress: Port 9092 from EKS nodes
- Cross-cloud: Port 9092 from GCP IP range

---

### Future Enhancements & Trade-offs

#### What We Would Add in Production

1. **Service Mesh (Istio)**:
   - Mutual TLS between services
   - Advanced traffic management (canary, blue-green)
   - Distributed tracing
   - **Why not now**: Complexity for learning project

2. **API Gateway Layer (Kong/Ambassador)**:
   - Rate limiting per user
   - API key management
   - Request transformation
   - **Why not now**: Kubernetes Ingress sufficient for demo

3. **Caching Layer (Redis)**:
   - Product catalog caching
   - Session storage
   - Rate limit counters
   - **Why not now**: Database performance adequate currently

4. **CDN (CloudFront)**:
   - Static asset delivery
   - Global edge caching
   - DDoS protection
   - **Why not now**: No static assets currently

5. **Secrets Management (Vault/Secrets Manager)**:
   - Dynamic secrets rotation
   - Centralized secret storage
   - Audit logging
   - **Why not now**: Kubernetes Secrets sufficient for demo

6. **Service Mesh Observability**:
   - Distributed tracing (Jaeger)
   - Service topology visualization
   - Request flow analysis
   - **Why not now**: Prometheus metrics sufficient

7. **Multi-Region Deployment**:
   - Active-active across regions
   - Global load balancing
   - Data replication
   - **Why not now**: Regional deployment sufficient, cost prohibitive

---

### Cost-Benefit Analysis

**Current Monthly Costs** (estimated):
- EKS Control Plane: $73
- EC2 Instances (2x t3.medium): $60
- RDS (db.t3.micro): $15
- MSK (kafka.t3.small): $300
- DynamoDB: $10 (on-demand)
- Data Transfer: $20
- **Total**: ~$478/month

**Cost Optimization Strategies**:
1. Reserved Instances: Save 30-40% on EC2/RDS
2. Spot Instances: Use for dev/test environments
3. Auto-scaling: Scale down during off-hours
4. Data lifecycle: Move old data to S3 Glacier

**Cost vs. Alternative Architectures**:
- Serverless (Lambda + API Gateway): ~$200/month but cold starts
- Monolith on single EC2: ~$50/month but no scaling
- Managed containers (ECS Fargate): ~$350/month but less features

**Value Delivered**:
- Production-grade architecture
- Skills development in modern DevOps
- Portfolio showcase
- Real-world experience with cloud-native patterns

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
