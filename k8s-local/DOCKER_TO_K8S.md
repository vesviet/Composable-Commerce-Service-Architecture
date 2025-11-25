# Converting Docker Compose to Kubernetes

> **Guide**: How to convert your Docker Compose services to Kubernetes manifests

## 📋 Overview

This guide shows you how to convert a Docker Compose service to Kubernetes manifests. We use **warehouse service** as a concrete example, but the patterns apply to all services.

## 🎯 Quick Reference

### Docker Compose → Kubernetes Mapping

| Docker Compose | Kubernetes | Notes |
|----------------|------------|-------|
| `service` (one-off) | `Job` | Migration jobs, one-time tasks |
| `service` (long-running) | `Deployment` | API servers, workers |
| `ports` | `Service` | Expose ports to other services |
| `volumes` (config) | `ConfigMap` or `Secret` | Configuration files |
| `volumes` (data) | `PersistentVolumeClaim` | Persistent storage |
| `environment` | `ConfigMap` or `env` | Environment variables |
| `depends_on` | `initContainers` or ordering | Service dependencies |
| `healthcheck` | `livenessProbe` / `readinessProbe` | Health checks |
| `deploy.resources` | `resources.limits/requests` | Resource limits |

---

## 📚 Example: Warehouse Service

### Original Docker Compose Structure

```yaml
services:
  warehouse-migration:      # One-off job
  warehouse-service:        # API server
  warehouse-service-dapr:   # Dapr sidecar
  warehouse-worker:         # Background worker
  warehouse-worker-dapr:    # Dapr sidecar
```

### Kubernetes Structure

```
k8s-local/services/warehouse/
├── 00-namespace.yaml          # (optional) Namespace
├── 10-configmap.yaml          # Configuration
├── 20-migration-job.yaml      # Migration job
├── 30-deployment.yaml         # Service deployment
├── 31-service.yaml            # K8s Service
├── 40-deployment-worker.yaml  # Worker deployment
└── 50-ingress.yaml           # (optional) Ingress
```

**Note**: Dapr sidecars are **automatically injected** by Dapr, no need to define them separately.

---

## 🔧 Step-by-Step Conversion

### Step 1: Create ConfigMap

**Docker Compose:**
```yaml
environment:
  - DATABASE_URL=postgresql://...
  - REDIS_URL=redis://...
```

**Kubernetes:**
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: warehouse-config
  namespace: development
data:
  database.url: "postgresql://warehouse_user:warehouse_pass@postgres.infrastructure.svc.cluster.local:5432/warehouse_db?sslmode=disable"
  redis.url: "redis://redis.infrastructure.svc.cluster.local:6379"
  dapr.pubsub.name: "pubsub-redis"
```

---

### Step 2: Convert Migration Job

**Docker Compose:**
```yaml
warehouse-migration:
  build: ...
  entrypoint: ["sh", "-lc", "cd /app && exec /app/bin/migrate -command up"]
  restart: "no"
  depends_on:
    postgres:
      condition: service_healthy
```

**Kubernetes:**
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: warehouse-migration
  namespace: development
spec:
  backoffLimit: 3
  template:
    metadata:
      labels:
        app: warehouse-migration
    spec:
      restartPolicy: OnFailure
      containers:
      - name: migrate
        image: k3d-local-registry:5000/warehouse-service:latest
        command: ["sh", "-lc", "cd /app && exec /app/bin/migrate -command up"]
        env:
        - name: MIGRATIONS_DIR
          value: /app/migrations
        - name: DATABASE_URL
          valueFrom:
            configMapKeyRef:
              name: warehouse-config
              key: database.url
        resources:
          limits:
            memory: "256Mi"
            cpu: "500m"
          requests:
            memory: "128Mi"
            cpu: "100m"
```

**Key Changes:**
- ✅ `restart: "no"` → `restartPolicy: OnFailure`
- ✅ Environment from ConfigMap
- ✅ Resource limits added (K8s best practice)
- ✅ No need for `depends_on` (run job manually before deploy)

---

### Step 3: Convert API Service

**Docker Compose:**
```yaml
warehouse-service:
  build: ...
  ports:
    - "8008:80"
    - "9008:81"
  environment:
    - WORKER_MODE=api
    - DAPR_GRPC_ENDPOINT=warehouse-service-dapr:50001
  depends_on:
    warehouse-service-dapr:
      condition: service_started
  healthcheck:
    test: ["CMD-SHELL", "wget --no-verbose --tries=1 --spider http://localhost/health || exit 1"]
```

**Kubernetes Deployment:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: warehouse-service
  namespace: development
spec:
  replicas: 1
  selector:
    matchLabels:
      app: warehouse-service
  template:
    metadata:
      labels:
        app: warehouse-service
      annotations:
        # Dapr will auto-inject sidecar based on these annotations
        dapr.io/enabled: "true"
        dapr.io/app-id: "warehouse-service"
        dapr.io/app-port: "80"
        dapr.io/app-protocol: "http"
        dapr.io/log-level: "info"
    spec:
      containers:
      - name: warehouse-service
        image: k3d-local-registry:5000/warehouse-service:latest
        ports:
        - containerPort: 80
          name: http
        - containerPort: 81
          name: grpc
        env:
        - name: WORKER_MODE
          value: "api"
        - name: KRATOS_CONF
          value: /app/configs
        # Dapr sidecar is on localhost in same pod
        - name: DAPR_GRPC_ENDPOINT
          value: "localhost:50001"
        envFrom:
        - configMapRef:
            name: warehouse-config
        livenessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 10
          periodSeconds: 30
          timeoutSeconds: 10
          failureThreshold: 3
        readinessProbe:
          httpGet:
            path: /health
            port: 80
          initialDelaySeconds: 5
          periodSeconds: 10
          timeoutSeconds: 5
          failureThreshold: 3
        resources:
          limits:
            memory: "512Mi"
            cpu: "1000m"
          requests:
            memory: "256Mi"
            cpu: "200m"
```

**Kubernetes Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: warehouse-service
  namespace: development
spec:
  selector:
    app: warehouse-service
  ports:
  - name: http
    port: 80
    targetPort: 80
    protocol: TCP
  - name: grpc
    port: 81
    targetPort: 81
    protocol: TCP
  type: ClusterIP
```

**Key Changes:**
- ✅ **Dapr sidecar**: Auto-injected via annotations (no separate container)
- ✅ **DAPR_GRPC_ENDPOINT**: `localhost:50001` (sidecar in same pod)
- ✅ **Health checks**: `healthcheck` → `livenessProbe` + `readinessProbe`
- ✅ **Service**: Separate K8s Service to expose ports
- ✅ **Resources**: Explicit limits and requests

---

### Step 4: Convert Worker

**Docker Compose:**
```yaml
warehouse-worker:
  build: ...
  command: ["./worker", "-mode", "all", "-conf", "../configs"]
  ports:
    - "5006:5005"
  environment:
    - WORKER_MODE=all
    - WORKER_GRPC_PORT=5005
    - DAPR_GRPC_ENDPOINT=warehouse-worker-dapr:50001
  depends_on:
    warehouse-worker-dapr:
      condition: service_started
```

**Kubernetes:**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: warehouse-worker
  namespace: development
spec:
  replicas: 1  # Usually 1 for workers (avoid duplicate cron jobs)
  selector:
    matchLabels:
      app: warehouse-worker
  template:
    metadata:
      labels:
        app: warehouse-worker
      annotations:
        dapr.io/enabled: "true"
        dapr.io/app-id: "warehouse-worker"
        dapr.io/app-port: "5005"
        dapr.io/app-protocol: "grpc"
        dapr.io/log-level: "info"
    spec:
      containers:
      - name: warehouse-worker
        image: k3d-local-registry:5000/warehouse-worker:latest
        command: ["./worker", "-mode", "all", "-conf", "../configs"]
        ports:
        - containerPort: 5005
          name: grpc
        env:
        - name: WORKER_MODE
          value: "all"
        - name: WORKER_GRPC_PORT
          value: "5005"
        - name: WORKER_PROTOCOL
          value: "grpc"
        - name: KRATOS_CONF
          value: /app/configs
        - name: DAPR_GRPC_ENDPOINT
          value: "localhost:50001"
        envFrom:
        - configMapRef:
            name: warehouse-config
        livenessProbe:
          tcpSocket:
            port: 5005
          initialDelaySeconds: 30
          periodSeconds: 30
        resources:
          limits:
            memory: "384Mi"
            cpu: "750m"
          requests:
            memory: "256Mi"
            cpu: "500m"
```

---

## 🎨 Best Practices

### 1. Naming Conventions

```yaml
# Use consistent naming
metadata:
  name: <service-name>-<component>  # e.g., warehouse-service, warehouse-worker
  namespace: development
  labels:
    app: <service-name>
    component: <api|worker|migration>
    version: v1
```

### 2. Resource Management

**Always set resources:**
```yaml
resources:
  limits:     # Maximum resources
    memory: "512Mi"
    cpu: "1000m"
  requests:   # Minimum guaranteed
    memory: "256Mi"
    cpu: "200m"
```

**Guidelines:**
- API services: 256Mi-512Mi memory, 200m-1000m CPU
- Workers: 256Mi-384Mi memory, 500m-750m CPU
- Dapr sidecars: Auto-configured by Dapr

### 3. Health Checks

**Always define both:**
```yaml
livenessProbe:   # When to restart container
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:  # When to start serving traffic
  httpGet:
    path: /health
    port: 80
  initialDelaySeconds: 5
  periodSeconds: 10
```

### 4. Configuration Management

**Use ConfigMaps for:**
- ✅ Non-sensitive config (URLs, settings)
- ✅ Shared configuration across services

**Use Secrets for:**
- ✅ Passwords, API keys
- ✅ TLS certificates

```yaml
# ConfigMap
env:
- name: DATABASE_URL
  valueFrom:
    configMapKeyRef:
      name: warehouse-config
      key: database.url

# Secret
env:
- name: DATABASE_PASSWORD
  valueFrom:
    secretKeyRef:
      name: warehouse-secrets
      key: db-password
```

### 5. Dapr Integration

**Annotations for Dapr:**
```yaml
annotations:
  dapr.io/enabled: "true"              # Enable Dapr
  dapr.io/app-id: "warehouse-service"  # Unique app ID
  dapr.io/app-port: "80"               # Your app port
  dapr.io/app-protocol: "http"         # http or grpc
  dapr.io/log-level: "info"            # debug, info, warn, error
```

**Dapr endpoint in your app:**
```yaml
env:
- name: DAPR_GRPC_ENDPOINT
  value: "localhost:50001"  # Sidecar is on localhost
- name: DAPR_HTTP_PORT
  value: "3500"
```

### 6. Service DNS

**In Kubernetes, services are accessible via DNS:**
```
<service-name>.<namespace>.svc.cluster.local:<port>

Examples:
- postgres.infrastructure.svc.cluster.local:5432
- redis.infrastructure.svc.cluster.local:6379
- warehouse-service.development.svc.cluster.local:80
```

**Short form (within same namespace):**
```
<service-name>:<port>

Examples:
- warehouse-service:80
- warehouse-worker:5005
```

---

## 📦 Deployment Order

1. **Namespace** (if creating new)
2. **ConfigMaps & Secrets**
3. **Migration Job** (run and wait for completion)
4. **Deployments** (services and workers)
5. **Services** (expose ports)
6. **Ingress** (if needed)

**Commands:**
```bash
# Apply in order
kubectl apply -f k8s-local/services/warehouse/00-namespace.yaml
kubectl apply -f k8s-local/services/warehouse/10-configmap.yaml

# Run migration
kubectl apply -f k8s-local/services/warehouse/20-migration-job.yaml
kubectl wait --for=condition=complete job/warehouse-migration -n development --timeout=300s

# Deploy services
kubectl apply -f k8s-local/services/warehouse/30-deployment.yaml
kubectl apply -f k8s-local/services/warehouse/31-service.yaml
kubectl apply -f k8s-local/services/warehouse/40-deployment-worker.yaml

# Check status
kubectl get pods -n development -l app=warehouse-service
kubectl get pods -n development -l app=warehouse-worker
```

---

## 🔍 Troubleshooting

### Pod not starting

```bash
# Check pod status
kubectl get pods -n development

# Describe pod
kubectl describe pod <pod-name> -n development

# Check logs
kubectl logs <pod-name> -n development

# Check previous logs (if restarted)
kubectl logs <pod-name> -n development --previous
```

### Dapr sidecar issues

```bash
# Check Dapr sidecar logs
kubectl logs <pod-name> -c daprd -n development

# Check Dapr annotations
kubectl get pod <pod-name> -n development -o yaml | grep -A 5 annotations
```

### Configuration issues

```bash
# Check ConfigMap
kubectl get configmap warehouse-config -n development -o yaml

# Check environment variables in pod
kubectl exec -it <pod-name> -n development -- env
```

---

## 📋 Checklist for New Service

When converting a new service from Docker Compose to K8s:

- [ ] Create `k8s-local/services/<service-name>/` directory
- [ ] Create ConfigMap with all configuration
- [ ] Convert migration job (if exists)
- [ ] Convert main service deployment
- [ ] Add Dapr annotations (if using Dapr)
- [ ] Create K8s Service to expose ports
- [ ] Convert worker deployment (if exists)
- [ ] Set resource limits and requests
- [ ] Add health checks (liveness + readiness)
- [ ] Update service DNS references
- [ ] Test deployment
- [ ] Update deployment scripts

---

## 🔗 See Also

- [Main K8s Guide](./README.md)
- [Dapr Documentation](https://docs.dapr.io/operations/hosting/kubernetes/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Warehouse Example](file:///home/tuananh/microservices/k8s-local/services/warehouse/)
