# Kubernetes Deployment Manifests

## Overview
This directory contains Kubernetes deployment manifests for all microservices in the e-commerce platform.

## Structure
```
kubernetes-manifests/
├── namespaces/
│   ├── production.yaml
│   ├── staging.yaml
│   └── development.yaml
├── services/
│   ├── catalog-service/
│   ├── order-service/
│   ├── payment-service/
│   └── ... (all services)
├── infrastructure/
│   ├── kafka/
│   ├── redis/
│   ├── elasticsearch/
│   └── monitoring/
├── ingress/
│   ├── api-gateway-ingress.yaml
│   └── admin-ingress.yaml
└── secrets/
    ├── database-secrets.yaml
    └── api-keys-secrets.yaml
```

## Quick Start

### 1. Create Namespaces
```bash
kubectl apply -f namespaces/
```

### 2. Deploy Infrastructure Services
```bash
kubectl apply -f infrastructure/
```

### 3. Deploy Application Services
```bash
kubectl apply -f services/
```

### 4. Configure Ingress
```bash
kubectl apply -f ingress/
```

## Service Deployment Example

### Catalog Service Deployment
```yaml
# services/catalog-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: catalog-service
  namespace: production
  labels:
    app: catalog-service
    version: v1
spec:
  replicas: 3
  selector:
    matchLabels:
      app: catalog-service
  template:
    metadata:
      labels:
        app: catalog-service
        version: v1
    spec:
      containers:
      - name: catalog-service
        image: ecommerce/catalog-service:1.0.0
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: catalog-db-secret
              key: url
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: url
        - name: KAFKA_BROKERS
          value: "kafka-cluster:9092"
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
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: catalog-service
  namespace: production
  labels:
    app: catalog-service
spec:
  selector:
    app: catalog-service
  ports:
  - port: 80
    targetPort: 3000
    protocol: TCP
  type: ClusterIP
```

### Order Service with Event Bus Integration
```yaml
# services/order-service/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: order-service
  namespace: production
  labels:
    app: order-service
    version: v1
spec:
  replicas: 5
  selector:
    matchLabels:
      app: order-service
  template:
    metadata:
      labels:
        app: order-service
        version: v1
    spec:
      containers:
      - name: order-service
        image: ecommerce/order-service:1.0.0
        ports:
        - containerPort: 3000
        env:
        - name: NODE_ENV
          value: "production"
        - name: DATABASE_URL
          valueFrom:
            secretKeyRef:
              name: order-db-secret
              key: url
        - name: KAFKA_BROKERS
          value: "kafka-cluster:9092"
        - name: REDIS_URL
          valueFrom:
            secretKeyRef:
              name: redis-secret
              key: url
        - name: JWT_SECRET
          valueFrom:
            secretKeyRef:
              name: auth-secret
              key: jwt-secret
        resources:
          requests:
            memory: "512Mi"
            cpu: "500m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        livenessProbe:
          httpGet:
            path: /health
            port: 3000
          initialDelaySeconds: 30
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /ready
            port: 3000
          initialDelaySeconds: 5
          periodSeconds: 5
```

## Infrastructure Services

### Kafka Cluster
```yaml
# infrastructure/kafka/kafka-cluster.yaml
apiVersion: kafka.strimzi.io/v1beta2
kind: Kafka
metadata:
  name: kafka-cluster
  namespace: production
spec:
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
      inter.broker.protocol.version: "3.5"
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
  entityOperator:
    topicOperator: {}
    userOperator: {}
```

### Redis Cluster
```yaml
# infrastructure/redis/redis-cluster.yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: production
spec:
  serviceName: redis-cluster
  replicas: 6
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      labels:
        app: redis-cluster
    spec:
      containers:
      - name: redis
        image: redis:7-alpine
        ports:
        - containerPort: 6379
        - containerPort: 16379
        command:
        - redis-server
        - /etc/redis/redis.conf
        - --cluster-enabled
        - "yes"
        - --cluster-config-file
        - /data/nodes.conf
        - --cluster-node-timeout
        - "5000"
        - --appendonly
        - "yes"
        volumeMounts:
        - name: redis-data
          mountPath: /data
        - name: redis-config
          mountPath: /etc/redis
        resources:
          requests:
            memory: "256Mi"
            cpu: "250m"
          limits:
            memory: "512Mi"
            cpu: "500m"
      volumes:
      - name: redis-config
        configMap:
          name: redis-config
  volumeClaimTemplates:
  - metadata:
      name: redis-data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```

### Elasticsearch Cluster
```yaml
# infrastructure/elasticsearch/elasticsearch.yaml
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: elasticsearch-cluster
  namespace: production
spec:
  version: 8.8.0
  nodeSets:
  - name: master
    count: 3
    config:
      node.roles: ["master"]
      xpack.security.enabled: true
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 50Gi
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 2Gi
              cpu: 1
            limits:
              memory: 4Gi
              cpu: 2
  - name: data
    count: 3
    config:
      node.roles: ["data", "ingest"]
    volumeClaimTemplates:
    - metadata:
        name: elasticsearch-data
      spec:
        accessModes:
        - ReadWriteOnce
        resources:
          requests:
            storage: 100Gi
    podTemplate:
      spec:
        containers:
        - name: elasticsearch
          resources:
            requests:
              memory: 4Gi
              cpu: 2
            limits:
              memory: 8Gi
              cpu: 4
```

## Monitoring Stack

### Prometheus
```yaml
# infrastructure/monitoring/prometheus.yaml
apiVersion: monitoring.coreos.com/v1
kind: Prometheus
metadata:
  name: prometheus
  namespace: monitoring
spec:
  serviceAccountName: prometheus
  serviceMonitorSelector:
    matchLabels:
      team: ecommerce
  ruleSelector:
    matchLabels:
      team: ecommerce
  resources:
    requests:
      memory: 400Mi
      cpu: 100m
    limits:
      memory: 2Gi
      cpu: 1
  retention: 30d
  storage:
    volumeClaimTemplate:
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: 50Gi
```

### Grafana
```yaml
# infrastructure/monitoring/grafana.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: grafana
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: grafana
  template:
    metadata:
      labels:
        app: grafana
    spec:
      containers:
      - name: grafana
        image: grafana/grafana:10.0.0
        ports:
        - containerPort: 3000
        env:
        - name: GF_SECURITY_ADMIN_PASSWORD
          valueFrom:
            secretKeyRef:
              name: grafana-secret
              key: admin-password
        volumeMounts:
        - name: grafana-storage
          mountPath: /var/lib/grafana
        resources:
          requests:
            memory: 256Mi
            cpu: 100m
          limits:
            memory: 512Mi
            cpu: 500m
      volumes:
      - name: grafana-storage
        persistentVolumeClaim:
          claimName: grafana-pvc
```

## API Gateway Ingress

### Kong Ingress Controller
```yaml
# ingress/api-gateway-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: api-gateway
  namespace: production
  annotations:
    kubernetes.io/ingress.class: kong
    konghq.com/plugins: rate-limiting, cors, jwt-auth
spec:
  tls:
  - hosts:
    - api.ecommerce.com
    secretName: api-tls-secret
  rules:
  - host: api.ecommerce.com
    http:
      paths:
      - path: /api/v1/products
        pathType: Prefix
        backend:
          service:
            name: catalog-service
            port:
              number: 80
      - path: /api/v1/orders
        pathType: Prefix
        backend:
          service:
            name: order-service
            port:
              number: 80
      - path: /api/v1/cart
        pathType: Prefix
        backend:
          service:
            name: cart-service
            port:
              number: 80
      - path: /api/v1/checkout
        pathType: Prefix
        backend:
          service:
            name: checkout-service
            port:
              number: 80
      - path: /api/v1/payments
        pathType: Prefix
        backend:
          service:
            name: payment-service
            port:
              number: 80
```

## Secrets Management

### Database Secrets
```yaml
# secrets/database-secrets.yaml
apiVersion: v1
kind: Secret
metadata:
  name: catalog-db-secret
  namespace: production
type: Opaque
data:
  url: <base64-encoded-database-url>
  username: <base64-encoded-username>
  password: <base64-encoded-password>
---
apiVersion: v1
kind: Secret
metadata:
  name: order-db-secret
  namespace: production
type: Opaque
data:
  url: <base64-encoded-database-url>
  username: <base64-encoded-username>
  password: <base64-encoded-password>
```

## Horizontal Pod Autoscaler

### Order Service HPA
```yaml
# services/order-service/hpa.yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service-hpa
  namespace: production
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  minReplicas: 3
  maxReplicas: 20
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
        value: 10
        periodSeconds: 60
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 50
        periodSeconds: 60
```

## Network Policies

### Service-to-Service Communication
```yaml
# security/network-policies.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: order-service-policy
  namespace: production
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
      port: 3000
  egress:
  - to:
    - podSelector:
        matchLabels:
          app: catalog-service
    ports:
    - protocol: TCP
      port: 80
  - to:
    - podSelector:
        matchLabels:
          app: payment-service
    ports:
    - protocol: TCP
      port: 80
  - to: []
    ports:
    - protocol: TCP
      port: 5432  # PostgreSQL
    - protocol: TCP
      port: 6379  # Redis
    - protocol: TCP
      port: 9092  # Kafka
```

## Deployment Commands

### Production Deployment
```bash
# Create namespace
kubectl create namespace production

# Deploy secrets
kubectl apply -f secrets/ -n production

# Deploy infrastructure
kubectl apply -f infrastructure/ -n production

# Wait for infrastructure to be ready
kubectl wait --for=condition=ready pod -l app=kafka-cluster -n production --timeout=300s
kubectl wait --for=condition=ready pod -l app=redis-cluster -n production --timeout=300s

# Deploy services
kubectl apply -f services/ -n production

# Configure ingress
kubectl apply -f ingress/ -n production

# Verify deployment
kubectl get pods -n production
kubectl get services -n production
kubectl get ingress -n production
```

### Rolling Updates
```bash
# Update service image
kubectl set image deployment/catalog-service catalog-service=ecommerce/catalog-service:1.1.0 -n production

# Check rollout status
kubectl rollout status deployment/catalog-service -n production

# Rollback if needed
kubectl rollout undo deployment/catalog-service -n production
```

## Monitoring and Troubleshooting

### Health Checks
```bash
# Check pod health
kubectl get pods -n production
kubectl describe pod <pod-name> -n production

# Check service endpoints
kubectl get endpoints -n production

# Check logs
kubectl logs -f deployment/order-service -n production
```

### Performance Monitoring
```bash
# Check resource usage
kubectl top pods -n production
kubectl top nodes

# Check HPA status
kubectl get hpa -n production
kubectl describe hpa order-service-hpa -n production
```