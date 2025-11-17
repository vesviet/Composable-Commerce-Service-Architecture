# Helm Charts for Microservices Deployment

## Overview
This directory contains Helm charts for deploying all microservices and infrastructure components of the e-commerce platform on Kubernetes.

## Structure
```
helm-charts/
├── charts/
│   ├── ecommerce-platform/          # Umbrella chart for entire platform
│   ├── microservices/
│   │   ├── catalog-service/         # Individual service charts
│   │   ├── order-service/
│   │   ├── payment-service/
│   │   ├── customer-service/
│   │   ├── pricing-service/
│   │   ├── inventory-service/
│   │   ├── auth-service/
│   │   ├── notification-service/
│   │   ├── search-service/
│   │   ├── review-service/
│   │   ├── analytics-service/
│   │   ├── loyalty-service/
│   │   └── shipping-service/
│   └── infrastructure/
│       ├── kafka/                   # Kafka cluster
│       ├── redis/                   # Redis cluster
│       ├── elasticsearch/           # Elasticsearch cluster
│       ├── monitoring/              # Prometheus + Grafana
│       └── api-gateway/             # Kong API Gateway
├── values/
│   ├── development.yaml             # Development environment values
│   ├── staging.yaml                 # Staging environment values
│   └── production.yaml              # Production environment values
└── scripts/
    ├── install.sh                   # Installation script
    ├── upgrade.sh                   # Upgrade script
    └── uninstall.sh                 # Uninstallation script
```

## Umbrella Chart - E-commerce Platform

### Chart.yaml
```yaml
# charts/ecommerce-platform/Chart.yaml
apiVersion: v2
name: ecommerce-platform
description: Complete e-commerce microservices platform
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  # Infrastructure Services
  - name: kafka
    version: "1.0.0"
    repository: "file://../infrastructure/kafka"
    condition: kafka.enabled
  
  - name: redis
    version: "1.0.0"
    repository: "file://../infrastructure/redis"
    condition: redis.enabled
  
  - name: elasticsearch
    version: "1.0.0"
    repository: "file://../infrastructure/elasticsearch"
    condition: elasticsearch.enabled
  
  - name: monitoring
    version: "1.0.0"
    repository: "file://../infrastructure/monitoring"
    condition: monitoring.enabled
  
  - name: api-gateway
    version: "1.0.0"
    repository: "file://../infrastructure/api-gateway"
    condition: apiGateway.enabled
  
  # Core Business Services
  - name: catalog-service
    version: "1.0.0"
    repository: "file://../microservices/catalog-service"
    condition: services.catalog.enabled
  
  - name: order-service
    version: "1.0.0"
    repository: "file://../microservices/order-service"
    condition: services.order.enabled
  
  - name: payment-service
    version: "1.0.0"
    repository: "file://../microservices/payment-service"
    condition: services.payment.enabled
  
  - name: customer-service
    version: "1.0.0"
    repository: "file://../microservices/customer-service"
    condition: services.customer.enabled
  
  - name: pricing-service
    version: "1.0.0"
    repository: "file://../microservices/pricing-service"
    condition: services.pricing.enabled
  
  - name: inventory-service
    version: "1.0.0"
    repository: "file://../microservices/inventory-service"
    condition: services.inventory.enabled
  
  - name: auth-service
    version: "1.0.0"
    repository: "file://../microservices/auth-service"
    condition: services.auth.enabled
  
  - name: notification-service
    version: "1.0.0"
    repository: "file://../microservices/notification-service"
    condition: services.notification.enabled
  
  - name: search-service
    version: "1.0.0"
    repository: "file://../microservices/search-service"
    condition: services.search.enabled
  
  - name: review-service
    version: "1.0.0"
    repository: "file://../microservices/review-service"
    condition: services.review.enabled
  
  - name: analytics-service
    version: "1.0.0"
    repository: "file://../microservices/analytics-service"
    condition: services.analytics.enabled
  
  - name: loyalty-service
    version: "1.0.0"
    repository: "file://../microservices/loyalty-service"
    condition: services.loyalty.enabled
  
  - name: shipping-service
    version: "1.0.0"
    repository: "file://../microservices/shipping-service"
    condition: services.shipping.enabled

maintainers:
  - name: E-commerce Team
    email: team@ecommerce.com
```

### Default Values (charts/ecommerce-platform/values.yaml)
```yaml
# Global configuration
global:
  imageRegistry: "ecommerce"
  imageTag: "1.0.0"
  imagePullPolicy: IfNotPresent
  storageClass: "gp2"
  
  # Database configuration
  postgresql:
    auth:
      postgresPassword: "postgres123"
      database: "ecommerce"
  
  # Redis configuration
  redis:
    auth:
      password: "redis123"
  
  # Kafka configuration
  kafka:
    auth:
      enabled: false
  
  # Monitoring
  monitoring:
    enabled: true
    namespace: "monitoring"

# Infrastructure Services
kafka:
  enabled: true
  replicaCount: 3
  persistence:
    enabled: true
    size: 100Gi

redis:
  enabled: true
  architecture: cluster
  auth:
    enabled: true
  master:
    persistence:
      enabled: true
      size: 10Gi

elasticsearch:
  enabled: true
  replicas: 3
  minimumMasterNodes: 2
  volumeClaimTemplate:
    resources:
      requests:
        storage: 50Gi

monitoring:
  enabled: true
  prometheus:
    enabled: true
    retention: "30d"
    storage:
      size: 50Gi
  grafana:
    enabled: true
    adminPassword: "admin123"

apiGateway:
  enabled: true
  replicaCount: 2
  service:
    type: LoadBalancer

# Microservices
services:
  catalog:
    enabled: true
    replicaCount: 3
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
  
  order:
    enabled: true
    replicaCount: 5
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    autoscaling:
      enabled: true
      minReplicas: 3
      maxReplicas: 20
      targetCPUUtilizationPercentage: 70
  
  payment:
    enabled: true
    replicaCount: 3
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
  
  customer:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
  
  pricing:
    enabled: true
    replicaCount: 3
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
  
  inventory:
    enabled: true
    replicaCount: 3
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 10
      targetCPUUtilizationPercentage: 70
  
  auth:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
  
  notification:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 1
      maxReplicas: 5
      targetCPUUtilizationPercentage: 70
  
  search:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
  
  review:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 1
      maxReplicas: 5
      targetCPUUtilizationPercentage: 70
  
  analytics:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
  
  loyalty:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 1
      maxReplicas: 5
      targetCPUUtilizationPercentage: 70
  
  shipping:
    enabled: true
    replicaCount: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
    autoscaling:
      enabled: true
      minReplicas: 2
      maxReplicas: 8
      targetCPUUtilizationPercentage: 70
```

## Individual Service Chart Example

### Catalog Service Chart (charts/microservices/catalog-service/Chart.yaml)
```yaml
apiVersion: v2
name: catalog-service
description: Catalog and CMS microservice
type: application
version: 1.0.0
appVersion: "1.0.0"

dependencies:
  - name: postgresql
    version: "12.x.x"
    repository: "https://charts.bitnami.com/bitnami"
    condition: postgresql.enabled
```

### Catalog Service Deployment Template
```yaml
# charts/microservices/catalog-service/templates/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "catalog-service.fullname" . }}
  labels:
    {{- include "catalog-service.labels" . | nindent 4 }}
spec:
  {{- if not .Values.autoscaling.enabled }}
  replicas: {{ .Values.replicaCount }}
  {{- end }}
  selector:
    matchLabels:
      {{- include "catalog-service.selectorLabels" . | nindent 6 }}
  template:
    metadata:
      annotations:
        checksum/config: {{ include (print $.Template.BasePath "/configmap.yaml") . | sha256sum }}
        {{- with .Values.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "catalog-service.selectorLabels" . | nindent 8 }}
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      serviceAccountName: {{ include "catalog-service.serviceAccountName" . }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: {{ .Chart.Name }}
          securityContext:
            {{- toYaml .Values.securityContext | nindent 12 }}
          image: "{{ .Values.image.repository }}:{{ .Values.image.tag | default .Chart.AppVersion }}"
          imagePullPolicy: {{ .Values.image.pullPolicy }}
          ports:
            - name: http
              containerPort: {{ .Values.service.port }}
              protocol: TCP
          env:
            - name: NODE_ENV
              value: {{ .Values.environment }}
            - name: PORT
              value: "{{ .Values.service.port }}"
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "catalog-service.fullname" . }}-db
                  key: url
            - name: REDIS_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "catalog-service.fullname" . }}-redis
                  key: url
            - name: KAFKA_BROKERS
              value: {{ .Values.kafka.brokers }}
            - name: ELASTICSEARCH_URL
              value: {{ .Values.elasticsearch.url }}
            {{- range $key, $value := .Values.env }}
            - name: {{ $key }}
              value: {{ $value | quote }}
            {{- end }}
          livenessProbe:
            httpGet:
              path: /health
              port: http
            initialDelaySeconds: 30
            periodSeconds: 10
            timeoutSeconds: 5
            failureThreshold: 3
          readinessProbe:
            httpGet:
              path: /ready
              port: http
            initialDelaySeconds: 5
            periodSeconds: 5
            timeoutSeconds: 3
            failureThreshold: 3
          resources:
            {{- toYaml .Values.resources | nindent 12 }}
          volumeMounts:
            - name: config
              mountPath: /app/config
              readOnly: true
      volumes:
        - name: config
          configMap:
            name: {{ include "catalog-service.fullname" . }}
      {{- with .Values.nodeSelector }}
      nodeSelector:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.affinity }}
      affinity:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      {{- with .Values.tolerations }}
      tolerations:
        {{- toYaml . | nindent 8 }}
      {{- end }}
```

### Service Template
```yaml
# charts/microservices/catalog-service/templates/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ include "catalog-service.fullname" . }}
  labels:
    {{- include "catalog-service.labels" . | nindent 4 }}
spec:
  type: {{ .Values.service.type }}
  ports:
    - port: {{ .Values.service.port }}
      targetPort: http
      protocol: TCP
      name: http
  selector:
    {{- include "catalog-service.selectorLabels" . | nindent 4 }}
```

### HPA Template
```yaml
# charts/microservices/catalog-service/templates/hpa.yaml
{{- if .Values.autoscaling.enabled }}
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: {{ include "catalog-service.fullname" . }}
  labels:
    {{- include "catalog-service.labels" . | nindent 4 }}
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: {{ include "catalog-service.fullname" . }}
  minReplicas: {{ .Values.autoscaling.minReplicas }}
  maxReplicas: {{ .Values.autoscaling.maxReplicas }}
  metrics:
    {{- if .Values.autoscaling.targetCPUUtilizationPercentage }}
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetCPUUtilizationPercentage }}
    {{- end }}
    {{- if .Values.autoscaling.targetMemoryUtilizationPercentage }}
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: {{ .Values.autoscaling.targetMemoryUtilizationPercentage }}
    {{- end }}
  behavior:
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
{{- end }}
```

### Service Values (charts/microservices/catalog-service/values.yaml)
```yaml
# Default values for catalog-service
replicaCount: 3

image:
  repository: ecommerce/catalog-service
  pullPolicy: IfNotPresent
  tag: "1.0.0"

imagePullSecrets: []
nameOverride: ""
fullnameOverride: ""

serviceAccount:
  create: true
  annotations: {}
  name: ""

podAnnotations: {}

podSecurityContext:
  fsGroup: 2000

securityContext:
  capabilities:
    drop:
    - ALL
  readOnlyRootFilesystem: true
  runAsNonRoot: true
  runAsUser: 1000

service:
  type: ClusterIP
  port: 3000

ingress:
  enabled: false
  className: ""
  annotations: {}
  hosts:
    - host: catalog-service.local
      paths:
        - path: /
          pathType: Prefix
  tls: []

resources:
  limits:
    cpu: 500m
    memory: 512Mi
  requests:
    cpu: 250m
    memory: 256Mi

autoscaling:
  enabled: true
  minReplicas: 2
  maxReplicas: 10
  targetCPUUtilizationPercentage: 70
  targetMemoryUtilizationPercentage: 80

nodeSelector: {}

tolerations: []

affinity: {}

# Application configuration
environment: production

# External dependencies
postgresql:
  enabled: true
  auth:
    postgresPassword: "catalog123"
    database: "catalog_db"
    username: "catalog_user"
    password: "catalog_pass"
  primary:
    persistence:
      enabled: true
      size: 20Gi

redis:
  url: "redis://redis:6379"

kafka:
  brokers: "kafka:9092"

elasticsearch:
  url: "http://elasticsearch:9200"

# Environment variables
env:
  LOG_LEVEL: "info"
  CACHE_TTL: "300"
  MAX_CONNECTIONS: "100"

# Health check configuration
healthCheck:
  enabled: true
  path: "/health"
  initialDelaySeconds: 30
  periodSeconds: 10

readinessCheck:
  enabled: true
  path: "/ready"
  initialDelaySeconds: 5
  periodSeconds: 5
```

## Infrastructure Charts

### Kafka Chart (charts/infrastructure/kafka/values.yaml)
```yaml
# Kafka configuration using Strimzi operator
kafka:
  version: 3.5.0
  replicas: 3
  
  listeners:
    - name: plain
      port: 9092
      type: internal
      tls: false
    - name: tls
      port: 9093
      type: internal
      tls: true
  
  config:
    offsets.topic.replication.factor: 3
    transaction.state.log.replication.factor: 3
    transaction.state.log.min.isr: 2
    default.replication.factor: 3
    min.insync.replicas: 2
  
  storage:
    type: jbod
    volumes:
    - id: 0
      type: persistent-claim
      size: 100Gi
      deleteClaim: false

zookeeper:
  replicas: 3
  storage:
    type: persistent-claim
    size: 10Gi
    deleteClaim: false

# Topics to create
topics:
  - name: order.created
    partitions: 6
    replicas: 3
  - name: order.updated
    partitions: 6
    replicas: 3
  - name: payment.processed
    partitions: 3
    replicas: 3
  - name: inventory.updated
    partitions: 6
    replicas: 3
  - name: product.created
    partitions: 3
    replicas: 3
  - name: customer.created
    partitions: 3
    replicas: 3
  - name: notification.email
    partitions: 3
    replicas: 3
  - name: fulfillment.created
    partitions: 6
    replicas: 3
```

### Monitoring Chart (charts/infrastructure/monitoring/values.yaml)
```yaml
# Prometheus configuration
prometheus:
  enabled: true
  retention: "30d"
  
  server:
    persistentVolume:
      enabled: true
      size: 50Gi
      storageClass: "gp2"
    
    resources:
      requests:
        memory: "2Gi"
        cpu: "1000m"
      limits:
        memory: "4Gi"
        cpu: "2000m"
  
  alertmanager:
    enabled: true
    persistentVolume:
      enabled: true
      size: 10Gi

# Grafana configuration
grafana:
  enabled: true
  
  adminPassword: "admin123"
  
  persistence:
    enabled: true
    size: 10Gi
    storageClassName: "gp2"
  
  resources:
    requests:
      memory: "256Mi"
      cpu: "100m"
    limits:
      memory: "512Mi"
      cpu: "500m"
  
  # Pre-configured dashboards
  dashboards:
    default:
      kubernetes-cluster:
        gnetId: 7249
        revision: 1
        datasource: Prometheus
      microservices-overview:
        gnetId: 6417
        revision: 1
        datasource: Prometheus

# Node Exporter
nodeExporter:
  enabled: true

# Kube State Metrics
kubeStateMetrics:
  enabled: true

# Service monitors for microservices
serviceMonitors:
  - name: catalog-service
    selector:
      matchLabels:
        app: catalog-service
    endpoints:
    - port: http
      path: /metrics
  
  - name: order-service
    selector:
      matchLabels:
        app: order-service
    endpoints:
    - port: http
      path: /metrics
```

## Environment-Specific Values

### Production Values (values/production.yaml)
```yaml
global:
  imageTag: "1.0.0"
  environment: "production"

# Infrastructure scaling for production
kafka:
  enabled: true
  replicaCount: 5
  persistence:
    size: 200Gi

redis:
  enabled: true
  architecture: cluster
  master:
    persistence:
      size: 20Gi
  replica:
    replicaCount: 3
    persistence:
      size: 20Gi

elasticsearch:
  enabled: true
  replicas: 5
  minimumMasterNodes: 3
  volumeClaimTemplate:
    resources:
      requests:
        storage: 100Gi

# Service scaling for production
services:
  catalog:
    replicaCount: 5
    autoscaling:
      minReplicas: 3
      maxReplicas: 20
  
  order:
    replicaCount: 10
    autoscaling:
      minReplicas: 5
      maxReplicas: 50
  
  payment:
    replicaCount: 5
    autoscaling:
      minReplicas: 3
      maxReplicas: 20

# Resource limits for production
resources:
  catalog:
    requests:
      memory: "512Mi"
      cpu: "500m"
    limits:
      memory: "1Gi"
      cpu: "1000m"
  
  order:
    requests:
      memory: "1Gi"
      cpu: "1000m"
    limits:
      memory: "2Gi"
      cpu: "2000m"
```

### Development Values (values/development.yaml)
```yaml
global:
  imageTag: "latest"
  environment: "development"

# Minimal infrastructure for development
kafka:
  enabled: true
  replicaCount: 1
  persistence:
    size: 10Gi

redis:
  enabled: true
  architecture: standalone
  master:
    persistence:
      size: 1Gi

elasticsearch:
  enabled: true
  replicas: 1
  minimumMasterNodes: 1
  volumeClaimTemplate:
    resources:
      requests:
        storage: 10Gi

# Minimal service scaling for development
services:
  catalog:
    replicaCount: 1
    autoscaling:
      enabled: false
  
  order:
    replicaCount: 1
    autoscaling:
      enabled: false
  
  payment:
    replicaCount: 1
    autoscaling:
      enabled: false

# Minimal resources for development
resources:
  catalog:
    requests:
      memory: "128Mi"
      cpu: "100m"
    limits:
      memory: "256Mi"
      cpu: "250m"
  
  order:
    requests:
      memory: "256Mi"
      cpu: "250m"
    limits:
      memory: "512Mi"
      cpu: "500m"
```

## Deployment Scripts

### Installation Script (scripts/install.sh)
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
NAMESPACE=${2:-ecommerce}
RELEASE_NAME=${3:-ecommerce-platform}

echo "🚀 Installing E-commerce Platform on Kubernetes"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"

# Check if kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is required but not installed."
    exit 1
fi

# Check if helm is available
if ! command -v helm &> /dev/null; then
    echo "❌ Helm is required but not installed."
    exit 1
fi

# Create namespace if it doesn't exist
echo "📁 Creating namespace: $NAMESPACE"
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Add required Helm repositories
echo "📦 Adding Helm repositories..."
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo add strimzi https://strimzi.io/charts/
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# Install dependencies first
echo "🏗️ Installing infrastructure dependencies..."

# Install Strimzi Kafka Operator
helm upgrade --install strimzi-kafka-operator strimzi/strimzi-kafka-operator \
  --namespace $NAMESPACE \
  --wait

# Wait for operator to be ready
echo "⏳ Waiting for Strimzi operator to be ready..."
kubectl wait --for=condition=ready pod -l name=strimzi-cluster-operator -n $NAMESPACE --timeout=300s

# Install the main platform
echo "🚀 Installing E-commerce Platform..."
helm upgrade --install $RELEASE_NAME ./charts/ecommerce-platform \
  --namespace $NAMESPACE \
  --values ./values/$ENVIRONMENT.yaml \
  --wait \
  --timeout 20m

# Verify installation
echo "✅ Verifying installation..."
kubectl get pods -n $NAMESPACE
kubectl get services -n $NAMESPACE

echo ""
echo "🎉 E-commerce Platform installed successfully!"
echo ""
echo "📋 Access Information:"
echo "  Namespace: $NAMESPACE"
echo "  Release: $RELEASE_NAME"
echo ""
echo "🔍 To check status:"
echo "  kubectl get pods -n $NAMESPACE"
echo "  helm status $RELEASE_NAME -n $NAMESPACE"
```

### Upgrade Script (scripts/upgrade.sh)
```bash
#!/bin/bash

set -e

ENVIRONMENT=${1:-development}
NAMESPACE=${2:-ecommerce}
RELEASE_NAME=${3:-ecommerce-platform}

echo "🔄 Upgrading E-commerce Platform"
echo "Environment: $ENVIRONMENT"
echo "Namespace: $NAMESPACE"
echo "Release: $RELEASE_NAME"

# Update Helm repositories
echo "📦 Updating Helm repositories..."
helm repo update

# Upgrade the platform
echo "🚀 Upgrading E-commerce Platform..."
helm upgrade $RELEASE_NAME ./charts/ecommerce-platform \
  --namespace $NAMESPACE \
  --values ./values/$ENVIRONMENT.yaml \
  --wait \
  --timeout 20m

# Verify upgrade
echo "✅ Verifying upgrade..."
kubectl get pods -n $NAMESPACE
helm status $RELEASE_NAME -n $NAMESPACE

echo ""
echo "🎉 E-commerce Platform upgraded successfully!"
```

## Usage Instructions

### Prerequisites
```bash
# Install Helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Deployment Commands
```bash
# Install development environment
./scripts/install.sh development ecommerce-dev

# Install production environment
./scripts/install.sh production ecommerce-prod

# Upgrade existing installation
./scripts/upgrade.sh production ecommerce-prod

# Uninstall
./scripts/uninstall.sh production ecommerce-prod
```

### Monitoring and Troubleshooting
```bash
# Check pod status
kubectl get pods -n ecommerce-prod

# Check service status
kubectl get services -n ecommerce-prod

# View logs
kubectl logs -f deployment/catalog-service -n ecommerce-prod

# Check Helm release status
helm status ecommerce-platform -n ecommerce-prod

# View Helm values
helm get values ecommerce-platform -n ecommerce-prod
```

This Helm chart structure provides a complete, production-ready deployment solution for the e-commerce microservices platform with proper scaling, monitoring, and environment-specific configurations.