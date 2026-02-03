# 🏗️ Infrastructure Architecture

**Purpose**: Infrastructure components, platform services, and underlying technology stack  
**Navigation**: [← Back to Architecture](README.md) | [Deployment Architecture →](deployment-architecture.md)

---

## 📋 Overview

This document describes the infrastructure architecture of our microservices platform, including the underlying technology stack, platform services, and infrastructure components that support the entire system. The infrastructure is designed for high availability, scalability, and maintainability.

---

## 🏛️ Infrastructure Stack

### **Technology Stack Overview**

```yaml
# Core Technology Stack
infrastructure_stack:
  orchestration:
    platform: Kubernetes 1.29+
    distribution: EKS/GKE/AKS
    networking: Calico CNI
    storage: CSI drivers
    
  service_mesh:
    platform: Dapr 1.13+
    features: Service discovery, mTLS, observability
    sidecar: Automatic injection
    
  runtime:
    language: Go 1.25+
    framework: Kratos v2
    protocol: gRPC + HTTP
    
  data_layer:
    databases: PostgreSQL 15, Redis 7
    message_broker: Redis Pub/Sub
    search: Elasticsearch
    
  monitoring:
    metrics: Prometheus + Grafana
    logging: Loki + Promtail
    tracing: Jaeger + OpenTelemetry
```

### **Infrastructure Components**

```
┌─────────────────────────────────────────────────────────────┐
│                    Load Balancer Layer                       │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   ALB/NLB   │  │   Ingress   │  │   Gateway   │         │
│  │  (External) │  │ Controller  │  │  Service    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Master    │  │   Master    │  │   Master    │         │
│  │   Nodes     │  │   Nodes     │  │   Nodes     │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Worker    │  │   Worker    │  │   Worker    │         │
│  │   Nodes     │  │   Nodes     │  │   Nodes     │         │
│  │             │  │             │  │             │         │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │
│  │ │Services │ │  │ │Services │ │  │ │Services │ │         │
│  │ │+ Dapr   │ │  │ │+ Dapr   │ │  │ │+ Dapr   │ │         │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                                │
┌─────────────────────────────────────────────────────────────┐
│                    Data Layer                                │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ PostgreSQL  │  │    Redis    │  │Elasticsearch│         │
│  │  Cluster    │  │   Cluster   │  │   Cluster   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## ☸️ Kubernetes Architecture

### **Cluster Configuration**

```yaml
# Kubernetes Cluster Setup
cluster:
  version: 1.29+
  control_plane:
    nodes: 3
    instance_type: m5.xlarge
    high_availability: Multi-AZ
    
  worker_nodes:
    min_nodes: 3
    max_nodes: 20
    instance_types: [m5.large, m5.xlarge, m5.2xlarge]
    auto_scaling: Enabled
    
  networking:
    cni: Calico
    pod_cidr: 10.244.0.0/16
    service_cidr: 10.96.0.0/12
    network_policies: Enabled
    
  storage:
    storage_classes:
      - gp3 (default)
      - io1 (high performance)
      - standard (backup)
```

### **Namespace Strategy**

```yaml
# Namespace Organization
namespaces:
  core-business-prod:
    purpose: Production core business services
    resource_quotas:
      requests.cpu: "50"
      requests.memory: 100Gi
      limits.cpu: "100"
      limits.memory: 200Gi
      
  platform-prod:
    purpose: Production platform services
    resource_quotas:
      requests.cpu: "30"
      requests.memory: 60Gi
      limits.cpu: "60"
      limits.memory: 120Gi
      
  infrastructure:
    purpose: Infrastructure components
    resource_quotas:
      requests.cpu: "20"
      requests.memory: 40Gi
      limits.cpu: "40"
      limits.memory: 80Gi
```

---

## 🔧 Dapr Service Mesh

### **Dapr Configuration**

```yaml
# Dapr Control Plane Configuration
dapr:
  version: 1.13.0
  ha_mode: true
  replicas: 3
  
  components:
    pubsub:
      name: redis-pubsub
      type: pubsub.redis
      metadata:
        redisHost: redis.infrastructure.svc.cluster.local:6379
        redisPassword: ${REDIS_PASSWORD}
        
    statestore:
      name: redis-state
      type: state.redis
      metadata:
        redisHost: redis.infrastructure.svc.cluster.local:6379
        redisPassword: ${REDIS_PASSWORD}
        
  configuration:
    name: appconfig
    tracing:
      samplingRate: "1"
      zipkin:
        endpointAddress: "http://jaeger-collector.infrastructure.svc.cluster.local:9411/api/v2/spans"
```

### **Dapr Sidecar Configuration**

```yaml
# Service Dapr Annotations
annotations:
  dapr.io/enabled: "true"
  dapr.io/app-id: "service-name"
  dapr.io/app-port: "8000"
  dapr.io/app-protocol: "http"
  dapr.io/config: "appconfig"
  dapr.io/log-level: "info"
  dapr.io/sidecar-cpu-limit: "300m"
  dapr.io/sidecar-memory-limit: "300Mi"
  dapr.io/sidecar-readiness-probe-delay-seconds: "30"
  dapr.io/sidecar-liveness-probe-delay-seconds: "30"
```

---

## 💾 Data Infrastructure

### **PostgreSQL Configuration**

```yaml
# PostgreSQL Cluster
postgresql:
  version: 15
  deployment: StatefulSet
  replicas: 3
  mode: Primary-Replica
  
  resources:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
      
  storage:
    size: 100Gi
    storage_class: io1
    iops: 3000
    
  configuration:
    max_connections: 200
    shared_buffers: 1GB
    effective_cache_size: 3GB
    work_mem: 4MB
    
  backup:
    retention: 30 days
    schedule: "0 2 * * *"
    storage: s3://backups/postgresql
```

### **Redis Configuration**

```yaml
# Redis Cluster
redis:
  version: 7
  deployment: StatefulSet
  mode: Cluster
  replicas: 6
  
  resources:
    requests:
      cpu: "500m"
      memory: 2Gi
    limits:
      cpu: "1"
      memory: 4Gi
      
  storage:
    size: 50Gi
    storage_class: gp3
    
  configuration:
    maxmemory: 2gb
    maxmemory_policy: allkeys-lru
    save: "900 1 300 10 60 10000"
    
  cluster:
    node_timeout: 5000
    cluster_node_timeout: 5000
    cluster_replica_validity_factor: 0
```

---

## 📊 Monitoring Infrastructure

### **Prometheus Configuration**

```yaml
# Prometheus Setup
prometheus:
  version: 2.47.0
  deployment: StatefulSet
  replicas: 2
  
  resources:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
      
  storage:
    size: 200Gi
    storage_class: gp3
    retention: 15 days
    
  configuration:
    scrape_interval: 15s
    evaluation_interval: 15s
    
  alerting:
    alertmanager:
      replicas: 3
      storage: 10Gi
      
    rules:
      - name: infrastructure
        file: /etc/prometheus/rules/infrastructure.yml
      - name: applications
        file: /etc/prometheus/rules/applications.yml
```

### **Grafana Configuration**

```yaml
# Grafana Setup
grafana:
  version: 10.2.0
  deployment: Deployment
  replicas: 2
  
  resources:
    requests:
      cpu: "500m"
      memory: 1Gi
    limits:
      cpu: "1"
      memory: 2Gi
      
  configuration:
    auth: OAuth2
    database: PostgreSQL
    
  dashboards:
    - infrastructure
    - applications
    - business_metrics
    - security
```

### **Jaeger Configuration**

```yaml
# Jaeger Setup
jaeger:
  version: 1.50
  deployment: Production
  
  components:
    collector:
      replicas: 2
      resources:
        requests:
          cpu: "500m"
          memory: 1Gi
        
    query:
      replicas: 2
      resources:
        requests:
          cpu: "500m"
          memory: 1Gi
        
    agent:
      daemonset: true
      
  storage:
    type: elasticsearch
    elasticsearch:
      nodes: 3
      storage: 100Gi
```

---

## 🔍 Logging Infrastructure

### **Loki Configuration**

```yaml
# Loki Setup
loki:
  version: 2.9.0
  deployment: StatefulSet
  replicas: 3
  
  resources:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
      
  storage:
    size: 200Gi
    storage_class: gp3
    retention: 30 days
    
  configuration:
    chunk_store_config:
      max_look_back_period: 0s
      
    table_manager:
      retention_deletes_enabled: true
      retention_period: 30d
```

### **Promtail Configuration**

```yaml
# Promtail Setup
promtail:
  version: 2.9.0
  deployment: DaemonSet
  
  resources:
    requests:
      cpu: "100m"
      memory: 128Mi
    limits:
      cpu: "500m"
      memory: 512Mi
      
  configuration:
    server:
      http_listen_port: 3101
      grpc_listen_port: 9080
      
    positions:
      filename: /tmp/positions.yaml
```

---

## 🛡️ Security Infrastructure

### **Network Security**

```yaml
# Network Security Configuration
network_security:
  cni: Calico
  network_policies: Enabled
  
  policies:
    - name: deny-all
      selector: all()
      ingress: []
      egress: []
      
    - name: allow-dns
      selector: all()
      egress:
        - to:
          - namespaceSelector:
              matchLabels:
                name: kube-system
          ports:
            - protocol: UDP
              port: 53
              
    - name: allow-services
      selector: app.kubernetes.io/name in (checkout, order, payment)
      ingress:
        - from:
          - namespaceSelector:
              matchLabels:
                name: core-business-prod
```

### **Certificate Management**

```yaml
# Certificate Management
certificates:
  issuer: cert-manager
  cluster_issuer: letsencrypt-prod
  
  certificates:
    - name: wildcard-tls
      secret_name: wildcard-tls
      dns_names:
        - "*.example.com"
        - "example.com"
      issuer: letsencrypt-prod
      
    - name: internal-tls
      secret_name: internal-tls
      dns_names:
        - "*.internal.example.com"
      issuer: selfsigned-issuer
```

---

## 🔄 CI/CD Infrastructure

### **GitOps Configuration**

```yaml
# ArgoCD Configuration
argocd:
  version: 2.8.0
  deployment: High Availability
  
  control_plane:
    replicas: 3
    
  applications:
    - name: core-business-services
      path: applications/main
      sync_policy:
        automated:
          prune: true
          self_heal: true
          
    - name: infrastructure
      path: applications/infrastructure
      sync_policy:
        automated:
          prune: true
          self_heal: true
```

### **Build Infrastructure**

```yaml
# Build Pipeline Configuration
build:
  runners:
    kubernetes:
      namespace: gitlab-runner
      replicas: 3
      
  cache:
    type: s3
    bucket: gitlab-cache
    path: cache/
    
  artifacts:
    type: s3
    bucket: gitlab-artifacts
    path: artifacts/
```

---

## 📈 Performance Infrastructure

### **Auto-scaling Configuration**

```yaml
# Cluster Auto-scaling
cluster_autoscaler:
  version: 1.29.0
  deployment: Deployment
  replicas: 2
  
  configuration:
    scale_down_delay_after_add: 10m
    scale_down_unneeded_time: 10m
    max_nodes_total: 50
    expander: least_waste
    
  node_groups:
    - name: general-purpose
      instance_types: [m5.large, m5.xlarge]
      min_size: 3
      max_size: 20
      
    - name: compute-optimized
      instance_types: [c5.large, c5.xlarge]
      min_size: 1
      max_size: 10
```

### **Resource Optimization**

```yaml
# Resource Optimization
resource_optimization:
  vertical_pod_autoscaler:
    enabled: true
    update_mode: Auto
    
  pod_disruption_budgets:
    - name: checkout-pdb
      selector: app.kubernetes.io/name=checkout
      min_available: 1
      
      max_unavailable: 1
      
  resource_quotas:
    - name: core-business-quota
      namespace: core-business-prod
      hard:
        requests.cpu: "50"
        requests.memory: 100Gi
        limits.cpu: "100"
        limits.memory: 200Gi
        persistentvolumeclaims: "20"
```

---

## 🔄 Disaster Recovery

### **Backup Infrastructure**

```yaml
# Backup Configuration
backup:
  velero:
    version: 1.12.0
    deployment: StatefulSet
    replicas: 2
    
  storage:
    type: s3
    bucket: velero-backups
    path: backups/
    
  schedules:
    - name: daily-backup
      schedule: "0 2 * * *"
      template: default
      included_namespaces:
        - core-business-prod
        - platform-prod
        
    - name: weekly-full-backup
      schedule: "0 3 * * 0"
      template: full-backup
      included_namespaces:
        - "*"
```

### **High Availability**

```yaml
# High Availability Configuration
high_availability:
  control_plane:
    replicas: 3
    zones: [us-west-2a, us-west-2b, us-west-2c]
    
  data_plane:
    min_nodes: 3
    max_nodes: 50
    zones: [us-west-2a, us-west-2b, us-west-2c]
    
  databases:
    postgresql:
      mode: Primary-Replica
      replicas: 2
      
    redis:
      mode: Cluster
      replicas: 6
      
  monitoring:
    prometheus: 2 replicas
    grafana: 2 replicas
    alertmanager: 3 replicas
```

---

## 📊 Infrastructure Monitoring

### **Health Monitoring**

```yaml
# Health Check Configuration
health_monitoring:
  node_exporter:
    version: 1.7.0
    deployment: DaemonSet
    
  kube_state_metrics:
    version: 2.10.0
    deployment: Deployment
    replicas: 2
    
  blackbox_exporter:
    version: 0.24.0
    deployment: Deployment
    replicas: 2
    
    targets:
      - https://api.example.com/health
      - https://checkout.example.com/health
      - https://order.example.com/health
```

### **Alerting Configuration**

```yaml
# Alerting Rules
alerting:
  infrastructure_alerts:
    - name: NodeDown
      condition: up{job="node-exporter"} == 0
      severity: critical
      duration: 1m
      
    - name: HighCPUUsage
      condition: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
      severity: warning
      duration: 5m
      
    - name: HighMemoryUsage
      condition: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
      severity: warning
      duration: 5m
      
  application_alerts:
    - name: ServiceDown
      condition: up{job="kubernetes-pods"} == 0
      severity: critical
      duration: 1m
      
    - name: HighErrorRate
      condition: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
      severity: warning
      duration: 5m
```

---

## 🔧 Infrastructure as Code

### **Terraform Configuration**

```hcl
# Example Terraform Configuration
terraform {
  required_version = ">= 1.5"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_eks_cluster" "main" {
  name     = var.cluster_name
  role_arn = aws_iam_role.eks_cluster.arn
  version  = var.kubernetes_version
  
  vpc_config {
    subnet_ids = var.subnet_ids
  }
}
```

### **Helm Chart Management**

```yaml
# Helm Chart Dependencies
dependencies:
  - name: postgresql
    version: "12.12.10"
    repository: "https://charts.bitnami.com/bitnami"
    
  - name: redis
    version: "18.1.5"
    repository: "https://charts.bitnami.com/bitnami"
    
  - name: prometheus
    version: "25.8.0"
    repository: "https://prometheus-community.github.io/helm-charts"
    
  - name: grafana
    version: "7.0.17"
    repository: "https://grafana.github.io/helm-charts"
```

---

## 🚀 Infrastructure Best Practices

### **Security Best Practices**

1. **Network Security**
   - Implement network policies
   - Use private subnets for databases
   - Enable encryption in transit
   - Regular security audits

2. **Access Control**
   - Principle of least privilege
   - Regular access reviews
   - MFA for all access
   - Audit logging

3. **Data Protection**
   - Encryption at rest and in transit
   - Regular backups
   - Data classification
   - Compliance monitoring

### **Performance Best Practices**

1. **Resource Management**
   - Right-size instances
   - Use auto-scaling
   - Monitor resource utilization
   - Optimize storage I/O

2. **Network Optimization**
   - Use appropriate instance types
   - Optimize network paths
   - Implement caching
   - Monitor network performance

3. **Cost Optimization**
   - Use spot instances where appropriate
   - Implement resource scheduling
   - Regular cost reviews
   - Use reserved instances

---

## 🔗 Related Documentation

- **[Deployment Architecture](deployment-architecture.md)** - Deployment patterns and strategies
- **[Security Architecture](security-architecture.md)** - Security design and compliance
- **[Performance Architecture](performance-architecture.md)** - Performance considerations
- **[Integration Architecture](integration-architecture.md)** - Service integration patterns
- **[Operations Guide](../06-operations/README.md)** - Operational procedures

---

**Last Updated**: February 1, 2026  
**Review Cycle**: Quarterly  
**Maintained By**: Infrastructure Team
