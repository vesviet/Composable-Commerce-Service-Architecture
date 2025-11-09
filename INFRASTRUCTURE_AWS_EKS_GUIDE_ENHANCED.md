# 🚀 Infrastructure Guide - AWS EKS Deployment (Enhanced)

> **Complete guide for deploying microservices on AWS EKS (Kubernetes)**  
> **Scale:** 1,000 orders/day | 10K SKUs | 10K customers | 20 warehouses  
> **Cost:** $576-$2,025/month (scalable)  
> **Enhanced with:** Advanced Auto-Scaling | Disaster Recovery | Cost Optimization

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [AWS EKS Architecture](#aws-eks-architecture)
3. [Traffic Flow & Conversion Analysis](#traffic-flow--conversion-analysis) ⭐ NEW
4. [Cost Analysis](#cost-analysis)
5. [Kubernetes Configuration](#kubernetes-configuration)
6. [Auto-Scaling (Enhanced)](#auto-scaling-enhanced)
7. [Disaster Recovery Plan](#disaster-recovery-plan)
8. [Cost Optimization Strategies](#cost-optimization-strategies)
9. [Deployment](#deployment)
10. [Monitoring](#monitoring)
11. [Quick Reference](#quick-reference)

---

## 🎯 Overview

### Infrastructure Stack

**Compute:**
- AWS EKS (Kubernetes 1.28+)
- EC2 instances (t3.medium, t3.large)
- Auto Scaling Groups

**Database:**
- Amazon RDS PostgreSQL 15
- Multi-AZ deployment
- Read replicas

**Cache:**
- Amazon ElastiCache Redis 7
- Cluster mode enabled

**Storage:**
- Amazon EBS (gp3)
- Amazon S3 (media storage)

**Networking:**
- Application Load Balancer
- VPC with private/public subnets
- NAT Gateway

**Monitoring:**
- CloudWatch
- Prometheus + Grafana
- Jaeger tracing

---

## 🏗️ AWS EKS Architecture

### Cluster Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS EKS CLUSTER                           │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────────────────────────────────────────────┐  │
│  │              Application Load Balancer                │  │
│  │              (ALB - $16/month)                        │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────┴─────────────────────────────────┐  │
│  │              Ingress Controller                       │  │
│  │              (nginx-ingress)                          │  │
│  └────────────────────┬─────────────────────────────────┘  │
│                       │                                      │
│  ┌────────────────────┴─────────────────────────────────┐  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ Gateway  │  │  Auth    │  │  User    │           │  │
│  │  │ 2-5 pods │  │ 2-4 pods │  │ 2-4 pods │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ Catalog  │  │ Pricing  │  │Warehouse │           │  │
│  │  │ 2-6 pods │  │ 2-5 pods │  │ 2-6 pods │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │  Order   │  │ Customer │  │  Admin   │           │  │
│  │  │ 2-5 pods │  │ 2-4 pods │  │ 1-2 pods │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │           Workers (CronJobs)                  │   │  │
│  │  │  - Catalog Worker (1-2 pods)                 │   │  │
│  │  │  - Pricing Worker (1-2 pods)                 │   │  │
│  │  │  - Warehouse Worker (1-2 pods)               │   │  │
│  │  └──────────────────────────────────────────────┘   │  │
│  │                                                        │  │
│  └────────────────────────────────────────────────────────┘
│                                                              │
│  Node Groups:                                                │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  App Nodes: 2-6 × t3.medium (2 vCPU, 4GB)           │  │
│  │  Worker Nodes: 1-3 × t3.small (2 vCPU, 2GB)         │  │
│  └──────────────────────────────────────────────────────┘  │
│                                                              │
└─────────────────────────────────────────────────────────────┘

External Services:
┌──────────────────────────────────────────────────────────┐
│  RDS PostgreSQL (db.t3.large → db.r5.xlarge)            │
│  ElastiCache Redis (cache.t3.medium → cache.r5.large)   │
│  S3 Storage (100GB → 500GB)                              │
│  CloudWatch Logs                                          │
└──────────────────────────────────────────────────────────┘
```

---

## 🔄 Traffic Flow & Conversion Analysis

### Conversion Funnel: Visitors to Orders

**Industry Standard E-commerce Conversion Rate: 2.5%**

```
To achieve 1 order, you need approximately 40 visitors

Detailed Funnel:
100 Visitors
    ↓ (40% browse products)
40 Product Browsers
    ↓ (25% add to cart)
10 Cart Additions
    ↓ (30% proceed to checkout)
3 Checkout Started
    ↓ (83% complete purchase)
2.5 Orders Completed

Conversion Rate: 2.5%
```

### Traffic Requirements by Order Volume

| Orders/Day | Visitors/Day | Monthly Visitors | Peak Hour | API Requests/Day |
|------------|--------------|------------------|-----------|------------------|
| **1,000** | 40,000 | 1,200,000 | 5,000 | 147,200 |
| **3,000** | 120,000 | 3,600,000 | 15,000 | 441,600 |
| **5,000** | 200,000 | 6,000,000 | 25,000 | 736,000 |
| **10,000** | 400,000 | 12,000,000 | 50,000 | 1,472,000 |

**Key Insight:** For every 1 order, expect ~40 visitors and ~30 API requests

### Complete Request Flow (Per Order)

```
User Journey: Landing → Product → Cart → Checkout → Order

1. Landing Page (3 requests)
   ├─ GET /
   ├─ GET /api/v1/catalog/featured
   └─ GET /api/v1/catalog/categories

2. Product Search (2 requests)
   ├─ GET /api/v1/search/products
   └─ GET /api/v1/catalog/products

3. Product Detail - 3 products viewed (12 requests)
   ├─ GET /api/v1/catalog/products/{id} × 3
   ├─ GET /api/v1/pricing/calculate × 3
   ├─ GET /api/v1/warehouse/stock/{sku} × 3
   └─ GET /api/v1/catalog/reviews/{id} × 3

4. Add to Cart (3 requests)
   ├─ POST /api/v1/order/cart/items
   ├─ GET /api/v1/order/cart
   └─ GET /api/v1/pricing/calculate-bulk

5. Checkout (4 requests)
   ├─ GET /api/v1/customer/addresses
   ├─ POST /api/v1/order/checkout/validate
   ├─ GET /api/v1/shipping/calculate
   └─ GET /api/v1/pricing/final-price

6. Order Creation (4 requests)
   ├─ POST /api/v1/order/create
   ├─ POST /api/v1/warehouse/reserve
   ├─ POST /api/v1/payment/process
   └─ POST /api/v1/notification/send

Total: ~30 API requests per order
```

### Backend Service Load (Per Order)

```
Internal Service Calls:
├─ Gateway: 30 requests (from frontend)
├─ Catalog: 8 calls → 12 DB queries, 15 cache hits
├─ Pricing: 6 calls → 8 DB queries, 10 cache hits
├─ Warehouse: 4 calls → 6 DB queries, 5 cache hits
├─ Order: 5 calls → 10 DB queries
├─ Customer: 2 calls → 4 DB queries, 3 cache hits
├─ Payment: 2 calls → 3 DB queries, 1 external API
└─ Notification: 1 call → 1 external API

Total per Order:
- 28 internal service calls
- 43 database queries
- 33 cache operations
- 2 external API calls
```

### Infrastructure Load by Scale

#### 1,000 Orders/Day
```
Daily Visitors: 40,000
Peak Hour: 5,000 visitors
API Requests: 147,200/day (307/minute peak)
Database Queries: 43,000/day
Cache Operations: 33,000/day

Required Infrastructure:
- 2 × t3.medium (app nodes)
- 1 × t3.small (worker)
- db.t3.large (RDS)
- cache.t3.medium (Redis)

Cost: $576/month ($0.58/order)
```

#### 10,000 Orders/Day
```
Daily Visitors: 400,000
Peak Hour: 50,000 visitors
API Requests: 1,472,000/day (3,067/minute peak)
Database Queries: 430,000/day
Cache Operations: 330,000/day

Required Infrastructure:
- 6 × t3.large (app nodes)
- 3 × t3.medium (workers)
- db.r5.xlarge + 2 replicas (RDS)
- 2 × cache.r5.large (Redis cluster)

Cost: $2,025/month ($0.20/order)
```

### Optimization Impact

**Improve Conversion Rate: 2.5% → 3.5%**
- Same traffic = 40% more orders
- 40,000 visitors = 1,400 orders (vs 1,000)
- Cost per order: $0.41 (vs $0.58)

**Reduce API Calls: 30 → 20 per order**
- 33% less infrastructure load
- Cost savings: ~$150/month

**Better Caching: 60% → 90% hit rate**
- 50% less database load
- Faster response times
- Better user experience

> 📊 **Detailed Analysis:** See `docs/TRAFFIC_FLOW_AND_CONVERSION_ANALYSIS.md` for complete breakdown

---

## 💰 Cost Analysis

### Monthly Cost Breakdown

#### Minimum Configuration (1K orders/day)

| Component | Spec | Quantity | Unit Cost | Total |
|-----------|------|----------|-----------|-------|
| **EKS Cluster** | Control Plane | 1 | $73 | $73 |
| **EC2 - App Nodes** | t3.medium (2vCPU, 4GB) | 2 | $30 | $60 |
| **EC2 - Worker Nodes** | t3.small (2vCPU, 2GB) | 1 | $15 | $15 |
| **RDS Primary** | db.t3.large (2vCPU, 8GB) | 1 | $120 | $120 |
| **RDS Replica** | db.t3.medium (2vCPU, 4GB) | 1 | $60 | $60 |
| **ElastiCache** | cache.t3.medium (2vCPU, 3.1GB) | 1 | $50 | $50 |
| **ALB** | Application Load Balancer | 1 | $16 | $16 |
| **NAT Gateway** | High Availability | 2 | $32 | $64 |
| **EBS Storage** | gp3 (500GB) | 1 | $40 | $40 |
| **S3 Storage** | Standard (100GB) | 1 | $3 | $3 |
| **Data Transfer** | Outbound (500GB) | 1 | $45 | $45 |
| **CloudWatch** | Logs + Metrics | 1 | $20 | $20 |
| **Backup** | RDS Snapshots | 1 | $10 | $10 |
| **TOTAL** | | | | **$576** |

**Cost per Order:** $0.58  
**Cost per Customer:** $0.06/month

#### Maximum Configuration (10K orders/day)

| Component | Spec | Quantity | Unit Cost | Total |
|-----------|------|----------|-----------|-------|
| **EKS Cluster** | Control Plane | 1 | $73 | $73 |
| **EC2 - App Nodes** | t3.large (2vCPU, 8GB) | 6 | $60 | $360 |
| **EC2 - Worker Nodes** | t3.medium (2vCPU, 4GB) | 3 | $30 | $90 |
| **RDS Primary** | db.r5.xlarge (4vCPU, 32GB) | 1 | $350 | $350 |
| **RDS Replica** | db.r5.large (2vCPU, 16GB) | 2 | $175 | $350 |
| **ElastiCache** | cache.r5.large (2vCPU, 13GB) | 2 | $125 | $250 |
| **ALB** | Application Load Balancer | 1 | $16 | $16 |
| **NAT Gateway** | High Availability | 2 | $32 | $64 |
| **EBS Storage** | gp3 (2TB) | 1 | $160 | $160 |
| **S3 Storage** | Standard (500GB) | 1 | $12 | $12 |
| **Data Transfer** | Outbound (2TB) | 1 | $180 | $180 |
| **CloudWatch** | Logs + Metrics | 1 | $80 | $80 |
| **Backup** | RDS Snapshots | 1 | $40 | $40 |
| **TOTAL** | | | | **$2,025** |

**Cost per Order:** $0.20  
**Cost per Customer:** $0.02/month

### Cost Comparison by Scale

| Orders/Day | Monthly Cost | Cost/Order | Savings vs Min |
|------------|--------------|------------|----------------|
| 1,000 | $576 | $0.58 | - |
| 3,000 | $950 | $0.32 | 45% |
| 5,000 | $1,250 | $0.25 | 57% |
| 10,000 | $2,025 | $0.20 | 66% |

**Key Insight:** Cost per order decreases significantly with scale (economies of scale)


---

## ⚙️ Kubernetes Configuration

### Resource Limits by Service

```yaml
# Resource allocation
services:
  gateway:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
    replicas: { min: 2, max: 5 }
  
  auth:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 200m, memory: 256Mi }
    replicas: { min: 2, max: 4 }
  
  catalog:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
    replicas: { min: 2, max: 6 }
  
  pricing:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
    replicas: { min: 2, max: 5 }
  
  warehouse:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
    replicas: { min: 2, max: 6 }
  
  order:
    requests: { cpu: 250m, memory: 256Mi }
    limits: { cpu: 500m, memory: 512Mi }
    replicas: { min: 2, max: 5 }
  
  customer:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 200m, memory: 256Mi }
    replicas: { min: 2, max: 4 }
  
  user:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 200m, memory: 256Mi }
    replicas: { min: 2, max: 4 }
  
  admin:
    requests: { cpu: 100m, memory: 128Mi }
    limits: { cpu: 200m, memory: 256Mi }
    replicas: { min: 1, max: 2 }

workers:
  catalog-worker:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 200m, memory: 512Mi }
    replicas: { min: 1, max: 2 }
  
  pricing-worker:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 200m, memory: 512Mi }
    replicas: { min: 1, max: 2 }
  
  warehouse-worker:
    requests: { cpu: 100m, memory: 256Mi }
    limits: { cpu: 200m, memory: 512Mi }
    replicas: { min: 1, max: 2 }
```


---

## 📈 Auto-Scaling (Enhanced)

### 1. Horizontal Pod Autoscaler (HPA) - Advanced Configuration

#### Multi-Metric HPA for High-Traffic Services

```yaml
# catalog-hpa-advanced.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: catalog-hpa
  namespace: microservices
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog
  minReplicas: 2
  maxReplicas: 6
  
  # Multiple metrics for intelligent scaling
  metrics:
  # CPU-based scaling
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  
  # Memory-based scaling
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  
  # Custom metric: Request rate (RPS)
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "1000"
  
  # Custom metric: Response time
  - type: Pods
    pods:
      metric:
        name: http_request_duration_seconds
      target:
        type: AverageValue
        averageValue: "0.1"  # 100ms
  
  # Scaling behavior
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300  # Wait 5 min before scale down
      policies:
      - type: Percent
        value: 50  # Scale down max 50% at a time
        periodSeconds: 60
      - type: Pods
        value: 2  # Or max 2 pods at a time
        periodSeconds: 60
      selectPolicy: Min  # Choose the slower scale down
    
    scaleUp:
      stabilizationWindowSeconds: 0  # Scale up immediately
      policies:
      - type: Percent
        value: 100  # Can double pods
        periodSeconds: 30
      - type: Pods
        value: 4  # Or add max 4 pods at a time
        periodSeconds: 30
      selectPolicy: Max  # Choose the faster scale up
```

#### Time-Based Scaling (Predictive)

```yaml
# scheduled-scaler.yaml
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-up-peak-hours
  namespace: microservices
spec:
  # Scale up before peak hours (8 AM)
  schedule: "0 7 * * 1-5"  # Mon-Fri at 7 AM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              kubectl scale deployment catalog --replicas=6 -n microservices
              kubectl scale deployment pricing --replicas=5 -n microservices
              kubectl scale deployment warehouse --replicas=6 -n microservices
              kubectl scale deployment order --replicas=5 -n microservices
          restartPolicy: OnFailure
---
apiVersion: batch/v1
kind: CronJob
metadata:
  name: scale-down-off-hours
  namespace: microservices
spec:
  # Scale down after peak hours (8 PM)
  schedule: "0 20 * * 1-5"  # Mon-Fri at 8 PM
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: kubectl
            image: bitnami/kubectl:latest
            command:
            - /bin/sh
            - -c
            - |
              kubectl scale deployment catalog --replicas=2 -n microservices
              kubectl scale deployment pricing --replicas=2 -n microservices
              kubectl scale deployment warehouse --replicas=2 -n microservices
              kubectl scale deployment order --replicas=2 -n microservices
          restartPolicy: OnFailure
```


#### Event-Driven Autoscaling (KEDA)

```yaml
# keda-scaledobject.yaml
apiVersion: keda.sh/v1alpha1
kind: ScaledObject
metadata:
  name: order-scaler
  namespace: microservices
spec:
  scaleTargetRef:
    name: order
  minReplicaCount: 2
  maxReplicaCount: 10
  pollingInterval: 30
  cooldownPeriod: 300
  
  triggers:
  # Scale based on Redis queue length
  - type: redis
    metadata:
      address: redis.infrastructure.svc.cluster.local:6379
      listName: order_queue
      listLength: "10"  # Scale up if queue > 10
  
  # Scale based on Prometheus metrics
  - type: prometheus
    metadata:
      serverAddress: http://prometheus.monitoring.svc.cluster.local:9090
      metricName: http_requests_total
      threshold: "1000"
      query: sum(rate(http_requests_total{service="order"}[1m]))
  
  # Scale based on CPU (backup trigger)
  - type: cpu
    metricType: Utilization
    metadata:
      value: "70"
```

### 2. Cluster Autoscaler - Advanced Configuration

```yaml
# cluster-autoscaler-advanced.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cluster-autoscaler
  namespace: kube-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cluster-autoscaler
  template:
    metadata:
      labels:
        app: cluster-autoscaler
    spec:
      serviceAccountName: cluster-autoscaler
      containers:
      - image: k8s.gcr.io/autoscaling/cluster-autoscaler:v1.28.0
        name: cluster-autoscaler
        command:
        - ./cluster-autoscaler
        - --v=4
        - --stderrthreshold=info
        - --cloud-provider=aws
        - --skip-nodes-with-local-storage=false
        - --expander=least-waste
        - --node-group-auto-discovery=asg:tag=k8s.io/cluster-autoscaler/enabled,k8s.io/cluster-autoscaler/microservices-cluster
        - --balance-similar-node-groups
        - --skip-nodes-with-system-pods=false
        # Advanced settings
        - --scale-down-enabled=true
        - --scale-down-delay-after-add=10m
        - --scale-down-unneeded-time=10m
        - --scale-down-utilization-threshold=0.5
        - --max-node-provision-time=15m
        - --max-graceful-termination-sec=600
        # Cost optimization
        - --new-pod-scale-up-delay=0s
        - --max-empty-bulk-delete=10
        resources:
          limits:
            cpu: 100m
            memory: 600Mi
          requests:
            cpu: 100m
            memory: 600Mi
```

### 3. Vertical Pod Autoscaler (VPA)

```yaml
# catalog-vpa.yaml
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: catalog-vpa
  namespace: microservices
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog
  updatePolicy:
    updateMode: "Auto"  # Auto, Recreate, Initial, Off
  resourcePolicy:
    containerPolicies:
    - containerName: catalog
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 1000m
        memory: 1Gi
      controlledResources: ["cpu", "memory"]
      # Recommendation margins
      mode: Auto
```


### 4. Auto-Scaling Strategy Summary

| Scaling Type | Use Case | Response Time | Cost Impact |
|--------------|----------|---------------|-------------|
| **HPA (CPU/Memory)** | General workload | 30-60s | Low |
| **HPA (Custom Metrics)** | Traffic spikes | 15-30s | Medium |
| **KEDA (Event-driven)** | Queue processing | 10-20s | Low |
| **VPA** | Resource optimization | Hours | Savings |
| **Cluster Autoscaler** | Node capacity | 2-5 min | High |
| **Scheduled Scaling** | Predictable patterns | Instant | Savings |

### 5. Scaling Policies by Service

```yaml
# Scaling matrix
services:
  # High-traffic services (aggressive scaling)
  catalog:
    hpa: { cpu: 70%, memory: 80%, rps: 1000 }
    min: 2, max: 6
    scaleUp: fast (30s)
    scaleDown: slow (5min)
  
  pricing:
    hpa: { cpu: 70%, memory: 80%, rps: 800 }
    min: 2, max: 5
    scaleUp: fast (30s)
    scaleDown: slow (5min)
  
  warehouse:
    hpa: { cpu: 70%, memory: 80%, rps: 1000 }
    min: 2, max: 6
    scaleUp: fast (30s)
    scaleDown: slow (5min)
  
  order:
    hpa: { cpu: 70%, memory: 80%, queue: 10 }
    keda: redis queue
    min: 2, max: 10
    scaleUp: very fast (15s)
    scaleDown: slow (10min)
  
  # Medium-traffic services (moderate scaling)
  gateway:
    hpa: { cpu: 70%, memory: 80% }
    min: 2, max: 5
    scaleUp: moderate (60s)
    scaleDown: moderate (3min)
  
  customer:
    hpa: { cpu: 70%, memory: 80% }
    min: 2, max: 4
    scaleUp: moderate (60s)
    scaleDown: moderate (3min)
  
  # Low-traffic services (conservative scaling)
  auth:
    hpa: { cpu: 80%, memory: 85% }
    min: 2, max: 4
    scaleUp: slow (2min)
    scaleDown: fast (2min)
  
  user:
    hpa: { cpu: 80%, memory: 85% }
    min: 2, max: 4
    scaleUp: slow (2min)
    scaleDown: fast (2min)
  
  admin:
    hpa: { cpu: 80%, memory: 85% }
    min: 1, max: 2
    scaleUp: slow (5min)
    scaleDown: fast (1min)
```

### 6. Testing Auto-Scaling

```bash
# Load test to trigger HPA
kubectl run -i --tty load-generator --rm --image=busybox --restart=Never -- /bin/sh -c "while sleep 0.01; do wget -q -O- http://catalog.microservices.svc.cluster.local:8001/api/v1/products; done"

# Watch HPA in action
watch kubectl get hpa -n microservices

# Watch pods scaling
watch kubectl get pods -n microservices

# Check cluster autoscaler logs
kubectl logs -f deployment/cluster-autoscaler -n kube-system

# Simulate queue load for KEDA
redis-cli LPUSH order_queue "order1" "order2" "order3" ... (repeat 100 times)

# Watch KEDA scaling
watch kubectl get scaledobject -n microservices
```


---

## 🔥 Disaster Recovery Plan

### 1. Backup Strategy

#### Database Backups (RDS)

```yaml
# Automated RDS backups
RDS Configuration:
  BackupRetentionPeriod: 7 days
  PreferredBackupWindow: "03:00-04:00"  # 3-4 AM (low traffic)
  BackupType: Automated + Manual
  
  # Point-in-Time Recovery (PITR)
  PITR: Enabled
  RetentionPeriod: 7 days
  
  # Cross-Region Backup
  CrossRegionBackup: Enabled
  DestinationRegion: ap-northeast-1 (Tokyo)
  
  # Snapshot Schedule
  DailySnapshot: 04:00 AM
  WeeklyFullBackup: Sunday 02:00 AM
  MonthlyArchive: First Sunday of month
```

**Backup Script:**

```bash
#!/bin/bash
# rds-backup.sh

# Create manual snapshot
aws rds create-db-snapshot \
  --db-instance-identifier microservices-db \
  --db-snapshot-identifier microservices-db-$(date +%Y%m%d-%H%M%S) \
  --region ap-southeast-1

# Copy to another region
aws rds copy-db-snapshot \
  --source-db-snapshot-identifier arn:aws:rds:ap-southeast-1:xxx:snapshot:microservices-db-latest \
  --target-db-snapshot-identifier microservices-db-dr-$(date +%Y%m%d) \
  --region ap-northeast-1

# Cleanup old snapshots (keep last 30 days)
aws rds describe-db-snapshots \
  --db-instance-identifier microservices-db \
  --query "DBSnapshots[?SnapshotCreateTime<='$(date -d '30 days ago' --iso-8601)'].DBSnapshotIdentifier" \
  --output text | xargs -n 1 aws rds delete-db-snapshot --db-snapshot-identifier
```

#### Redis Backups (ElastiCache)

```yaml
# ElastiCache backup configuration
ElastiCache:
  SnapshotRetentionLimit: 7
  SnapshotWindow: "04:00-05:00"
  AutomaticFailover: Enabled
  MultiAZ: Enabled
  
  # Manual snapshot
  ManualSnapshot: Daily at 05:00 AM
  
  # Export to S3
  S3Export: Enabled
  S3Bucket: microservices-redis-backups
```

#### Kubernetes Backups (Velero)

```yaml
# velero-backup-schedule.yaml
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: daily-backup
  namespace: velero
spec:
  schedule: "0 2 * * *"  # Daily at 2 AM
  template:
    includedNamespaces:
    - microservices
    - infrastructure
    - monitoring
    excludedResources:
    - events
    - events.events.k8s.io
    storageLocation: aws-s3
    volumeSnapshotLocations:
    - aws-ebs
    ttl: 720h  # 30 days
---
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: weekly-full-backup
  namespace: velero
spec:
  schedule: "0 1 * * 0"  # Weekly on Sunday at 1 AM
  template:
    includedNamespaces:
    - "*"
    storageLocation: aws-s3
    volumeSnapshotLocations:
    - aws-ebs
    ttl: 2160h  # 90 days
```

**Install Velero:**

```bash
# Install Velero CLI
brew install velero

# Install Velero on cluster
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket microservices-velero-backups \
  --backup-location-config region=ap-southeast-1 \
  --snapshot-location-config region=ap-southeast-1 \
  --secret-file ./credentials-velero

# Create backup schedules
kubectl apply -f velero-backup-schedule.yaml

# Manual backup
velero backup create manual-backup-$(date +%Y%m%d) --include-namespaces microservices
```


### 2. High Availability Configuration

#### Multi-AZ Deployment

```yaml
# EKS cluster across 3 AZs
Availability Zones:
  - ap-southeast-1a
  - ap-southeast-1b
  - ap-southeast-1c

# Node distribution
Node Groups:
  app-nodes:
    desiredCapacity: 6
    distribution:
      az-1a: 2 nodes
      az-1b: 2 nodes
      az-1c: 2 nodes
  
  worker-nodes:
    desiredCapacity: 3
    distribution:
      az-1a: 1 node
      az-1b: 1 node
      az-1c: 1 node

# Pod anti-affinity
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
spec:
  replicas: 3
  template:
    spec:
      affinity:
        podAntiAffinity:
          requiredDuringSchedulingIgnoredDuringExecution:
          - labelSelector:
              matchExpressions:
              - key: app
                operator: In
                values:
                - catalog
            topologyKey: topology.kubernetes.io/zone
```

#### Database High Availability

```yaml
# RDS Multi-AZ with Read Replicas
RDS Primary:
  Instance: db.r5.xlarge
  AZ: ap-southeast-1a
  MultiAZ: true (standby in 1b)
  
RDS Read Replicas:
  Replica-1:
    Instance: db.r5.large
    AZ: ap-southeast-1b
    Purpose: Read traffic
  
  Replica-2:
    Instance: db.r5.large
    AZ: ap-southeast-1c
    Purpose: Read traffic + DR
  
  Replica-DR:
    Instance: db.r5.large
    Region: ap-northeast-1 (Tokyo)
    Purpose: Cross-region DR

# Connection pooling
Database Connections:
  Primary: Write operations
  Replicas: Read operations (round-robin)
  Failover: Automatic (60-120 seconds)
```

#### Redis High Availability

```yaml
# ElastiCache Redis Cluster Mode
Redis Cluster:
  Mode: Cluster
  Shards: 3
  ReplicasPerShard: 2
  TotalNodes: 9 (3 primary + 6 replicas)
  
  Distribution:
    Shard-1: Primary (1a), Replica (1b, 1c)
    Shard-2: Primary (1b), Replica (1a, 1c)
    Shard-3: Primary (1c), Replica (1a, 1b)
  
  AutomaticFailover: Enabled
  FailoverTime: 30-60 seconds
```

### 3. Disaster Recovery Procedures

#### RTO & RPO Targets

| Scenario | RTO (Recovery Time) | RPO (Data Loss) | Priority |
|----------|---------------------|-----------------|----------|
| **Pod Failure** | < 30 seconds | 0 | Critical |
| **Node Failure** | < 2 minutes | 0 | Critical |
| **AZ Failure** | < 5 minutes | < 1 minute | High |
| **Region Failure** | < 30 minutes | < 5 minutes | Medium |
| **Complete Disaster** | < 2 hours | < 15 minutes | Low |

#### Recovery Procedures

**Scenario 1: Pod Failure**

```bash
# Automatic recovery by Kubernetes
# No manual intervention needed

# Verify recovery
kubectl get pods -n microservices
kubectl describe pod <pod-name> -n microservices
```

**Scenario 2: Node Failure**

```bash
# Automatic recovery by Kubernetes + Cluster Autoscaler
# Pods rescheduled to healthy nodes
# New node provisioned if needed

# Monitor recovery
watch kubectl get nodes
watch kubectl get pods -n microservices -o wide

# Force drain if node stuck
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data
```

**Scenario 3: AZ Failure**

```bash
# Automatic failover (Multi-AZ setup)
# Traffic redirected to healthy AZs

# Verify service health
kubectl get pods -n microservices -o wide | grep <failed-az>

# Check database failover
aws rds describe-db-instances --db-instance-identifier microservices-db

# Check Redis failover
aws elasticache describe-replication-groups --replication-group-id microservices-redis
```

**Scenario 4: Region Failure (Full DR)**

```bash
# 1. Promote DR database (Tokyo region)
aws rds promote-read-replica \
  --db-instance-identifier microservices-db-dr \
  --region ap-northeast-1

# 2. Create new EKS cluster in DR region
eksctl create cluster -f cluster-config-dr.yaml --region ap-northeast-1

# 3. Restore from Velero backup
velero restore create --from-backup daily-backup-latest \
  --namespace-mappings microservices:microservices

# 4. Update DNS to point to DR region
aws route53 change-resource-record-sets \
  --hosted-zone-id Z1234567890ABC \
  --change-batch file://dns-failover.json

# 5. Verify services
kubectl get pods -n microservices
kubectl get svc -n microservices
curl https://api.yourdomain.com/health
```


### 4. Backup Testing & Validation

```bash
# Monthly DR drill script
#!/bin/bash
# dr-drill.sh

echo "=== DR Drill Started: $(date) ==="

# 1. Test database restore
echo "Testing RDS restore..."
aws rds restore-db-instance-from-db-snapshot \
  --db-instance-identifier microservices-db-test \
  --db-snapshot-identifier microservices-db-latest \
  --region ap-southeast-1

# 2. Test Velero restore
echo "Testing Velero restore..."
velero restore create test-restore-$(date +%Y%m%d) \
  --from-backup daily-backup-latest \
  --namespace-mappings microservices:microservices-test

# 3. Verify data integrity
echo "Verifying data integrity..."
kubectl exec -it deployment/catalog -n microservices-test -- \
  psql -h microservices-db-test -U admin -d catalog -c "SELECT COUNT(*) FROM products;"

# 4. Test application functionality
echo "Testing application..."
kubectl port-forward svc/catalog 8001:8001 -n microservices-test &
sleep 5
curl http://localhost:8001/api/v1/products | jq '.total'

# 5. Cleanup
echo "Cleaning up test resources..."
kubectl delete namespace microservices-test
aws rds delete-db-instance \
  --db-instance-identifier microservices-db-test \
  --skip-final-snapshot

echo "=== DR Drill Completed: $(date) ==="
```

### 5. Monitoring & Alerting for DR

```yaml
# prometheus-alerts-dr.yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: disaster-recovery-alerts
  namespace: monitoring
spec:
  groups:
  - name: disaster-recovery
    interval: 30s
    rules:
    # Backup failures
    - alert: BackupFailed
      expr: velero_backup_failure_total > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "Velero backup failed"
        description: "Backup {{ $labels.schedule }} has failed"
    
    # Database replication lag
    - alert: DatabaseReplicationLag
      expr: aws_rds_replica_lag_seconds > 300
      for: 5m
      labels:
        severity: warning
      annotations:
        summary: "RDS replication lag high"
        description: "Replication lag is {{ $value }} seconds"
    
    # Multi-AZ failure
    - alert: MultiAZFailure
      expr: count(up{job="kubernetes-nodes"}) by (zone) < 1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Availability Zone {{ $labels.zone }} is down"
        description: "No healthy nodes in AZ {{ $labels.zone }}"
    
    # Redis cluster health
    - alert: RedisClusterUnhealthy
      expr: redis_cluster_state != 1
      for: 2m
      labels:
        severity: critical
      annotations:
        summary: "Redis cluster is unhealthy"
        description: "Redis cluster state is {{ $value }}"
```


---

## 💰 Cost Optimization Strategies

### 1. Compute Cost Optimization

#### Use Spot Instances for Non-Critical Workloads

```yaml
# spot-node-group.yaml
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

nodeGroups:
  # Spot instances for workers (60-70% savings)
  - name: worker-nodes-spot
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 1
    maxSize: 5
    spot: true
    instancesDistribution:
      maxPrice: 0.05  # Max price per hour
      instanceTypes:
        - t3.medium
        - t3a.medium
        - t2.medium
      onDemandBaseCapacity: 0
      onDemandPercentageAboveBaseCapacity: 0
      spotInstancePools: 3
    labels:
      workload: worker
      lifecycle: spot
    taints:
      - key: spot
        value: "true"
        effect: NoSchedule

# Deploy workers to spot nodes
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-worker
spec:
  template:
    spec:
      tolerations:
      - key: spot
        operator: Equal
        value: "true"
        effect: NoSchedule
      nodeSelector:
        lifecycle: spot
```

**Savings:**
- Spot instances: 60-70% cheaper than on-demand
- Worker nodes on spot: $15/month → $5/month
- Total savings: ~$30/month (3 worker nodes)

#### Reserved Instances for Stable Workloads

```bash
# Purchase 1-year Reserved Instances for app nodes
# Savings: 30-40% vs on-demand

# Calculate savings
On-Demand: 6 × t3.large × $60/month = $360/month
Reserved (1-year): 6 × t3.large × $40/month = $240/month
Savings: $120/month ($1,440/year)

# Purchase through AWS Console or CLI
aws ec2 purchase-reserved-instances-offering \
  --reserved-instances-offering-id <offering-id> \
  --instance-count 6
```

#### Right-Sizing with VPA

```bash
# Use VPA recommendations to right-size pods
kubectl get vpa -n microservices

# Example: Reduce over-provisioned resources
# Before: requests: { cpu: 500m, memory: 512Mi }
# After:  requests: { cpu: 250m, memory: 256Mi }
# Savings: 50% resource usage = more pods per node
```

### 2. Storage Cost Optimization

#### Use gp3 Instead of gp2 (20% cheaper)

```yaml
# gp3-storage-class.yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: gp3
provisioner: ebs.csi.aws.com
parameters:
  type: gp3
  iops: "3000"
  throughput: "125"
  encrypted: "true"
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer

# Savings
# gp2: 500GB × $0.10/GB = $50/month
# gp3: 500GB × $0.08/GB = $40/month
# Savings: $10/month per 500GB
```

#### S3 Lifecycle Policies

```json
{
  "Rules": [
    {
      "Id": "TransitionToIA",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "STANDARD_IA"
        },
        {
          "Days": 90,
          "StorageClass": "GLACIER"
        }
      ],
      "NoncurrentVersionTransitions": [
        {
          "NoncurrentDays": 30,
          "StorageClass": "GLACIER"
        }
      ],
      "Expiration": {
        "Days": 365
      }
    }
  ]
}
```

**Savings:**
- Standard: $0.023/GB
- Standard-IA: $0.0125/GB (after 30 days)
- Glacier: $0.004/GB (after 90 days)
- Example: 500GB → $11.50/month → $6.25/month → $2/month

### 3. Network Cost Optimization

#### Use VPC Endpoints (Avoid NAT Gateway costs)

```yaml
# VPC endpoints for AWS services
VPC Endpoints:
  - Service: s3
    Type: Gateway
    Cost: Free
  
  - Service: dynamodb
    Type: Gateway
    Cost: Free
  
  - Service: ecr.api
    Type: Interface
    Cost: $7/month
  
  - Service: ecr.dkr
    Type: Interface
    Cost: $7/month

# Savings on data transfer
# NAT Gateway: $0.045/GB
# VPC Endpoint: $0.01/GB
# Savings: $0.035/GB
# Example: 1TB/month → $45 → $10 = $35 savings
```

#### CloudFront CDN for Static Assets

```yaml
# CloudFront distribution
CloudFront:
  Origins:
    - S3: microservices-static-assets
    - ALB: api.yourdomain.com
  
  Behaviors:
    - PathPattern: /static/*
      Origin: S3
      CachePolicy: CachingOptimized
    
    - PathPattern: /api/*
      Origin: ALB
      CachePolicy: CachingDisabled
  
  PriceClass: PriceClass_100  # US, Europe, Asia

# Savings
# Direct ALB: $0.09/GB data transfer
# CloudFront: $0.085/GB (first 10TB)
# Cache hit rate: 80%
# Effective cost: $0.017/GB
# Savings: 81% on cached content
```


### 4. Database Cost Optimization

#### Use Aurora Serverless v2 for Variable Workloads

```yaml
# Aurora Serverless v2 configuration
Aurora Serverless v2:
  MinCapacity: 0.5 ACU ($0.12/hour)
  MaxCapacity: 4 ACU ($0.96/hour)
  
  # Cost comparison (1K orders/day)
  RDS db.t3.large: $120/month (always on)
  Aurora Serverless: $36-$288/month (scales with load)
  Average: ~$80/month
  Savings: $40/month

  # Auto-pause during low traffic
  AutoPause: true
  AutoPauseDelay: 5 minutes
```

#### Read Replica Optimization

```yaml
# Smart read replica usage
Read Replicas:
  # Use smaller instances for read replicas
  Primary: db.r5.xlarge ($350/month)
  Replica-1: db.r5.large ($175/month)  # Instead of xlarge
  Replica-2: db.t3.large ($120/month)  # For reporting/analytics
  
  # Savings
  Before: 1 primary + 2 xlarge replicas = $1,050/month
  After: 1 primary + 1 large + 1 t3.large = $645/month
  Savings: $405/month
```

#### Connection Pooling with RDS Proxy

```yaml
# RDS Proxy configuration
RDS Proxy:
  MaxConnectionsPercent: 100
  MaxIdleConnectionsPercent: 50
  ConnectionBorrowTimeout: 120
  
  # Benefits
  - Reduce database connections by 80%
  - Allow smaller RDS instance
  - Cost: $15/month
  - Savings: $50/month (smaller instance)
  - Net savings: $35/month
```

### 5. Monitoring & Observability Cost Optimization

#### Use CloudWatch Logs Insights Instead of Full Logs

```yaml
# Log filtering and sampling
CloudWatch Logs:
  # Only log errors and warnings
  LogLevel: WARN
  
  # Sample debug logs (10%)
  SamplingRate: 0.1
  
  # Retention policies
  ErrorLogs: 30 days
  AccessLogs: 7 days
  DebugLogs: 3 days
  
  # Savings
  Before: 100GB/month × $0.50/GB = $50/month
  After: 20GB/month × $0.50/GB = $10/month
  Savings: $40/month
```

#### Prometheus Remote Write to S3

```yaml
# Store metrics in S3 instead of EBS
Prometheus:
  RemoteWrite:
    - url: s3://microservices-metrics/prometheus
      queueConfig:
        capacity: 10000
        maxShards: 50
  
  # Retention
  Local: 7 days (EBS)
  Remote: 90 days (S3)
  
  # Savings
  EBS (500GB): $40/month
  S3 (500GB): $11.50/month
  Savings: $28.50/month
```

### 6. Scheduled Scaling for Cost Savings

```yaml
# Scale down during off-hours
# Weekdays: 8 AM - 8 PM (peak)
# Weekends: Minimal capacity

# Cost calculation
Peak hours (12h × 5 days = 60h/week):
  Nodes: 6 app + 3 worker = 9 nodes
  Cost: $450/month

Off-peak hours (108h/week):
  Nodes: 2 app + 1 worker = 3 nodes
  Cost: $150/month

Weighted average:
  (60h × $450 + 108h × $150) / 168h = $290/month
  
Savings: $450 - $290 = $160/month
```

### 7. Total Cost Optimization Summary

| Strategy | Monthly Savings | Implementation |
|----------|----------------|----------------|
| **Spot Instances (workers)** | $30 | Easy |
| **Reserved Instances (1-year)** | $120 | Easy |
| **Right-sizing (VPA)** | $50 | Medium |
| **gp3 Storage** | $10 | Easy |
| **S3 Lifecycle** | $5 | Easy |
| **VPC Endpoints** | $35 | Medium |
| **CloudFront CDN** | $40 | Medium |
| **Aurora Serverless** | $40 | Hard |
| **Read Replica Optimization** | $405 | Medium |
| **RDS Proxy** | $35 | Medium |
| **CloudWatch Optimization** | $40 | Easy |
| **Prometheus to S3** | $28 | Medium |
| **Scheduled Scaling** | $160 | Easy |
| **TOTAL SAVINGS** | **$998/month** | - |

### 8. Optimized Cost Breakdown

#### Before Optimization (1K orders/day)
```
Total: $576/month
Cost per order: $0.58
```

#### After Optimization (1K orders/day)
```
Compute: $75 - $30 (spot) - $120 (RI) = -$75 (covered by RI)
Database: $180 - $40 (Aurora) - $35 (proxy) = $105
Cache: $50 (no change)
Network: $80 - $35 (VPC endpoints) - $40 (CloudFront) = $5
Storage: $43 - $10 (gp3) - $5 (S3 lifecycle) = $28
Monitoring: $20 - $40 (logs) - $28 (metrics) = -$48 (covered)
Other: $118 (no change)

Total: $316/month
Cost per order: $0.32
Savings: 45% ($260/month)
```

#### After Optimization (10K orders/day)
```
Before: $2,025/month
After: $1,200/month
Savings: 41% ($825/month)
Cost per order: $0.12 (down from $0.20)
```


---

## 🚀 Deployment

### Prerequisites

```bash
# Install required tools
brew install awscli eksctl kubectl helm

# Configure AWS credentials
aws configure

# Create EKS cluster
eksctl create cluster -f cluster-config.yaml

# Update kubeconfig
aws eks update-kubeconfig --region ap-southeast-1 --name microservices-cluster
```

### Infrastructure Setup

```bash
# 1. Create namespaces
kubectl apply -f k8s/namespaces.yaml

# 2. Install Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install nginx-ingress ingress-nginx/ingress-nginx \
  --namespace infrastructure \
  --set controller.service.type=LoadBalancer

# 3. Install Cert Manager (for SSL)
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 4. Install Dapr
helm repo add dapr https://dapr.github.io/helm-charts/
helm install dapr dapr/dapr \
  --namespace infrastructure \
  --set global.ha.enabled=true

# 5. Install Consul
helm repo add hashicorp https://helm.releases.hashicorp.com
helm install consul hashicorp/consul \
  --namespace infrastructure \
  --values consul-values.yaml

# 6. Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring

# 7. Install Velero (backup)
velero install \
  --provider aws \
  --plugins velero/velero-plugin-for-aws:v1.8.0 \
  --bucket microservices-velero-backups \
  --backup-location-config region=ap-southeast-1 \
  --snapshot-location-config region=ap-southeast-1

# 8. Install KEDA (event-driven autoscaling)
helm repo add kedacore https://kedacore.github.io/charts
helm install keda kedacore/keda --namespace kube-system
```

### Application Deployment

```bash
# 1. Create secrets
kubectl create secret generic catalog-secrets \
  --from-literal=database-url="postgresql://..." \
  --namespace microservices

# 2. Deploy services
kubectl apply -f k8s/services/

# 3. Deploy workers
kubectl apply -f k8s/workers/

# 4. Deploy HPA
kubectl apply -f k8s/hpa/

# 5. Deploy ingress
kubectl apply -f k8s/ingress.yaml

# 6. Verify deployment
kubectl get pods -n microservices
kubectl get svc -n microservices
kubectl get ingress -n microservices
kubectl get hpa -n microservices
```

---

## 📊 Monitoring

### CloudWatch Integration

```yaml
# cloudwatch-agent.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: cloudwatch-config
  namespace: monitoring
data:
  cwagentconfig.json: |
    {
      "logs": {
        "metrics_collected": {
          "kubernetes": {
            "cluster_name": "microservices-cluster",
            "metrics_collection_interval": 60
          }
        }
      },
      "metrics": {
        "namespace": "EKS/Microservices",
        "metrics_collected": {
          "cpu": {
            "measurement": [
              {"name": "cpu_usage_idle", "rename": "CPU_IDLE", "unit": "Percent"}
            ]
          },
          "mem": {
            "measurement": [
              {"name": "mem_used_percent", "rename": "MEM_USED", "unit": "Percent"}
            ]
          }
        }
      }
    }
```

### Grafana Dashboards

**Key Metrics:**
- Pod CPU/Memory usage
- Request rate (RPS)
- Response time (P50, P95, P99)
- Error rate
- Database connections
- Cache hit rate
- Auto-scaling events
- Cost metrics

---

## 🎯 Quick Reference

### Common Commands

```bash
# Scale deployment
kubectl scale deployment catalog --replicas=4 -n microservices

# Check pod status
kubectl get pods -n microservices -o wide

# View logs
kubectl logs -f deployment/catalog -n microservices

# Execute command in pod
kubectl exec -it catalog-xxx -n microservices -- /bin/sh

# Port forward for debugging
kubectl port-forward svc/catalog 8001:8001 -n microservices

# Check HPA status
kubectl get hpa -n microservices

# Check node status
kubectl get nodes

# Check resource usage
kubectl top nodes
kubectl top pods -n microservices

# Backup commands
velero backup create manual-backup
velero restore create --from-backup manual-backup

# Cost analysis
kubectl cost --namespace microservices
```


---

## 📋 Summary

### Minimum Setup (1K orders/day)

**Before Optimization:**
- **Cost:** $576/month
- **Nodes:** 3 (2 app + 1 worker)
- **Pods:** 19 total
- **Capacity:** 1,000 orders/day
- **Cost per order:** $0.58

**After Optimization:**
- **Cost:** $316/month
- **Nodes:** 3 (2 app + 1 worker, with spot & RI)
- **Pods:** 19 total
- **Capacity:** 1,000 orders/day
- **Cost per order:** $0.32
- **Savings:** 45% ($260/month)

### Maximum Setup (10K orders/day)

**Before Optimization:**
- **Cost:** $2,025/month
- **Nodes:** 9 (6 app + 3 worker)
- **Pods:** 50+ total
- **Capacity:** 10,000+ orders/day
- **Cost per order:** $0.20

**After Optimization:**
- **Cost:** $1,200/month
- **Nodes:** 9 (6 app + 3 worker, optimized)
- **Pods:** 50+ total
- **Capacity:** 10,000+ orders/day
- **Cost per order:** $0.12
- **Savings:** 41% ($825/month)

### Key Features

**Auto-Scaling:**
- ✅ HPA (CPU, Memory, Custom Metrics)
- ✅ KEDA (Event-driven, Queue-based)
- ✅ VPA (Resource optimization)
- ✅ Cluster Autoscaler (Node scaling)
- ✅ Scheduled Scaling (Time-based)

**Disaster Recovery:**
- ✅ Multi-AZ deployment (3 AZs)
- ✅ Automated backups (RDS, Redis, K8s)
- ✅ Cross-region replication
- ✅ Point-in-time recovery
- ✅ RTO: < 30 minutes
- ✅ RPO: < 5 minutes

**Cost Optimization:**
- ✅ Spot instances (60-70% savings)
- ✅ Reserved instances (30-40% savings)
- ✅ Right-sizing (VPA)
- ✅ Storage optimization (gp3, S3 lifecycle)
- ✅ Network optimization (VPC endpoints, CloudFront)
- ✅ Database optimization (Aurora Serverless, RDS Proxy)
- ✅ Scheduled scaling (off-hours)
- ✅ Total savings: 41-45%

### Scaling Efficiency

| Scale | Cost | Cost/Order | Savings |
|-------|------|------------|---------|
| 1K orders/day | $316/month | $0.32 | 45% |
| 3K orders/day | $550/month | $0.18 | 42% |
| 5K orders/day | $750/month | $0.15 | 40% |
| 10K orders/day | $1,200/month | $0.12 | 41% |

**Key Insight:** Cost per order drops 62% from 1K to 10K scale (economies of scale)

---

## 🎯 Next Steps

### Immediate Actions

1. **Review and approve infrastructure plan**
2. **Set up AWS account and billing alerts**
3. **Create EKS cluster with optimizations**
4. **Configure auto-scaling policies**
5. **Set up backup and DR procedures**

### Week 1

1. Deploy infrastructure (EKS, RDS, Redis)
2. Configure monitoring and alerting
3. Set up CI/CD pipelines
4. Deploy services to staging

### Week 2

1. Load testing and optimization
2. DR drill and validation
3. Security audit
4. Production deployment

### Ongoing

1. Monitor costs and optimize
2. Monthly DR drills
3. Quarterly cost reviews
4. Continuous optimization

---

**Document Version:** 2.0 (Enhanced)  
**Last Updated:** November 9, 2024  
**Platform:** AWS EKS  
**Region:** ap-southeast-1 (Singapore)  
**DR Region:** ap-northeast-1 (Tokyo)

**Enhancements:**
- ✅ Advanced auto-scaling policies (HPA, KEDA, VPA, Scheduled)
- ✅ Complete disaster recovery plan (Multi-AZ, Backups, Procedures)
- ✅ Comprehensive cost optimization (41-45% savings)
- ✅ Production-ready configuration
- ✅ Monitoring and alerting setup

**Status:** Production Ready 🚀
