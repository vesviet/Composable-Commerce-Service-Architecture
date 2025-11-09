# 🚀 Infrastructure Guide - AWS EKS Deployment

> **Complete guide for deploying microservices on AWS EKS (Kubernetes)**  
> **Scale:** 1,000 orders/day | 10K SKUs | 10K customers | 20 warehouses  
> **Cost:** $880-$3,500/month (scalable)

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [AWS EKS Architecture](#aws-eks-architecture)
3. [Cost Analysis](#cost-analysis)
4. [Kubernetes Configuration](#kubernetes-configuration)
5. [Auto-Scaling](#auto-scaling)
6. [Deployment](#deployment)
7. [Monitoring](#monitoring)

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
│  │  │ 2 pods   │  │ 2 pods   │  │ 2 pods   │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │ Catalog  │  │ Pricing  │  │Warehouse │           │  │
│  │  │ 2 pods   │  │ 2 pods   │  │ 2 pods   │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐           │  │
│  │  │  Order   │  │ Customer │  │  Admin   │           │  │
│  │  │ 2 pods   │  │ 2 pods   │  │ 1 pod    │           │  │
│  │  └──────────┘  └──────────┘  └──────────┘           │  │
│  │                                                        │  │
│  │  ┌──────────────────────────────────────────────┐   │  │
│  │  │           Workers (CronJobs)                  │   │  │
│  │  │  - Catalog Worker (1 pod)                    │   │  │
│  │  │  - Pricing Worker (1 pod)                    │   │  │
│  │  │  - Warehouse Worker (1 pod)                  │   │  │
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
│  RDS PostgreSQL (db.t3.large)           $120/month      │
│  ElastiCache Redis (cache.t3.medium)    $50/month       │
│  S3 Storage (100GB)                      $3/month        │
│  CloudWatch Logs                         $10/month       │
└──────────────────────────────────────────────────────────┘
```

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

### Namespace Structure

```yaml
# namespaces.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: microservices
  labels:
    name: microservices
---
apiVersion: v1
kind: Namespace
metadata:
  name: infrastructure
  labels:
    name: infrastructure
---
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  labels:
    name: monitoring
```

### Service Deployment Example

```yaml
# catalog-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog
  namespace: microservices
  labels:
    app: catalog
    version: v1
spec:
  replicas: 2  # Min replicas
  selector:
    matchLabels:
      app: catalog
  template:
    metadata:
      labels:
        app: catalog
        version: v1
    spec:
      containers:
      - name: catalog
        image: your-registry/catalog:latest
        ports:
        - containerPort: 8001
          name: http
        - containerPort: 9001
          name: grpc
        env:
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: catalog-secrets
              key: database-url
        - name: REDIS_ADDR
          value: "redis.infrastructure.svc.cluster.local:6379"
        - name: CONSUL_ADDR
          value: "consul.infrastructure.svc.cluster.local:8500"
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8001
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8001
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: catalog
  namespace: microservices
spec:
  selector:
    app: catalog
  ports:
  - name: http
    port: 8001
    targetPort: 8001
  - name: grpc
    port: 9001
    targetPort: 9001
  type: ClusterIP
```

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

## 📈 Auto-Scaling

### Horizontal Pod Autoscaler (HPA)

```yaml
# catalog-hpa.yaml
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
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 0
      policies:
      - type: Percent
        value: 100
        periodSeconds: 30
      - type: Pods
        value: 2
        periodSeconds: 30
      selectPolicy: Max
```

### Cluster Autoscaler

```yaml
# cluster-autoscaler.yaml
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
        resources:
          limits:
            cpu: 100m
            memory: 300Mi
          requests:
            cpu: 100m
            memory: 300Mi
```

### Node Groups Configuration

```yaml
# eksctl config
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig

metadata:
  name: microservices-cluster
  region: ap-southeast-1
  version: "1.28"

vpc:
  cidr: 10.0.0.0/16
  nat:
    gateway: HighlyAvailable

nodeGroups:
  # Application nodes
  - name: app-nodes
    instanceType: t3.medium
    desiredCapacity: 2
    minSize: 2
    maxSize: 6
    volumeSize: 50
    volumeType: gp3
    labels:
      role: application
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/microservices-cluster: "owned"
    iam:
      withAddonPolicies:
        autoScaler: true
        cloudWatch: true
        ebs: true
    ssh:
      allow: true
      publicKeyName: microservices-key
  
  # Worker nodes (for cron jobs)
  - name: worker-nodes
    instanceType: t3.small
    desiredCapacity: 1
    minSize: 1
    maxSize: 3
    volumeSize: 30
    volumeType: gp3
    labels:
      role: worker
    taints:
      - key: workload
        value: worker
        effect: NoSchedule
    tags:
      k8s.io/cluster-autoscaler/enabled: "true"
      k8s.io/cluster-autoscaler/microservices-cluster: "owned"
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

# 4. Deploy ingress
kubectl apply -f k8s/ingress.yaml

# 5. Verify deployment
kubectl get pods -n microservices
kubectl get svc -n microservices
kubectl get ingress -n microservices
```

### Ingress Configuration

```yaml
# ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-ingress
  namespace: microservices
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
    nginx.ingress.kubernetes.io/rate-limit: "100"
spec:
  tls:
  - hosts:
    - api.yourdomain.com
    secretName: api-tls
  rules:
  - host: api.yourdomain.com
    http:
      paths:
      - path: /api/v1/products
        pathType: Prefix
        backend:
          service:
            name: catalog
            port:
              number: 8001
      - path: /api/v1/pricing
        pathType: Prefix
        backend:
          service:
            name: pricing
            port:
              number: 8002
      - path: /api/v1/inventory
        pathType: Prefix
        backend:
          service:
            name: warehouse
            port:
              number: 8003
      - path: /api/v1/orders
        pathType: Prefix
        backend:
          service:
            name: order
            port:
              number: 8004
      - path: /api/v1/customers
        pathType: Prefix
        backend:
          service:
            name: customer
            port:
              number: 8007
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

### Prometheus Metrics

```yaml
# servicemonitor.yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: microservices-metrics
  namespace: monitoring
spec:
  selector:
    matchLabels:
      monitoring: enabled
  endpoints:
  - port: metrics
    interval: 30s
    path: /metrics
```

### Grafana Dashboards

**Key Metrics:**
- Pod CPU/Memory usage
- Request rate (RPS)
- Response time (P50, P95, P99)
- Error rate
- Database connections
- Cache hit rate

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
```

### Cost Optimization Tips

1. **Use Spot Instances** for worker nodes (60-70% savings)
2. **Reserved Instances** for stable workloads (1-year: 30% off)
3. **Right-size pods** based on actual usage
4. **Enable cluster autoscaler** to scale down during off-hours
5. **Use gp3 volumes** instead of gp2 (20% cheaper)
6. **Optimize data transfer** (use CloudFront CDN)
7. **Clean up unused resources** regularly

---

## 📋 Summary

### Minimum Setup (1K orders/day)
- **Cost:** $576/month
- **Nodes:** 3 (2 app + 1 worker)
- **Pods:** 19 total
- **Capacity:** 1,000 orders/day

### Maximum Setup (10K orders/day)
- **Cost:** $2,025/month
- **Nodes:** 9 (6 app + 3 worker)
- **Pods:** 50+ total
- **Capacity:** 10,000+ orders/day

### Scaling Efficiency
- **3x scale:** 1.6x cost
- **10x scale:** 3.5x cost
- **Cost per order drops 66%** at 10x scale

---

**Document Version:** 1.0  
**Last Updated:** November 9, 2024  
**Platform:** AWS EKS  
**Region:** ap-southeast-1 (Singapore)
