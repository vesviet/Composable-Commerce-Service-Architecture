# Kubernetes Local Development Guide

> **Quick Setup**: Get a local Kubernetes development environment running in 5 minutes with k3d + Tilt.

## 📋 Overview

This guide helps you set up a local Kubernetes cluster for microservices development. We use **k3d** (lightweight Kubernetes) with **Tilt** for hot-reload development.

### Why k3d?

| Solution | Pros | Cons | Best For |
|----------|------|------|----------|
| **k3d** ⭐ | Lightest (~50MB), fastest, easy setup | Fewer features | **Local dev (recommended)** |
| **kind** | Popular, stable | Heavier than k3d | Local dev, CI/CD |
| **minikube** | Many features, driver options | Very heavy, slow | Production-like testing |
| **Docker Desktop K8s** | Built-in | Only on Docker Desktop | Mac/Windows users |

## 🚀 Quick Start

### 1. Automated Installation (Recommended)

```bash
# Install all tools automatically (k3d, kubectl, helm, tilt)
cd /home/tuananh/microservices
./k8s-local/install-all.sh

# Reload shell
source ~/.zshrc  # or source ~/.bashrc
```

**Note**: See [INSTALLATION.md](./INSTALLATION.md) for manual installation steps.

### 2. Setup Cluster

```bash
# Create k3d cluster
make -f k8s-local/Makefile setup

# Or use script directly
./k8s-local/setup-cluster.sh
```

### 3. Deploy Infrastructure

```bash
# Deploy PostgreSQL, Redis, Consul, Dapr
make -f k8s-local/Makefile deploy-infra

# Or use script
./k8s-local/deploy-infra.sh
```

### 4. Deploy Services

#### Option A: With Tilt (Hot Reload) ⭐ Recommended

```bash
# Start Tilt (auto-builds and deploys)
tilt up

# Tilt will:
# - Build Docker images
# - Deploy to k3d cluster
# - Watch for code changes
# - Auto rebuild/redeploy on changes

# Open browser: http://localhost:10350 to view Tilt UI
```

#### Option B: Manual Deploy

```bash
# Build image for a service (e.g., auth)
cd auth
docker build -t localhost:5000/auth-service:latest .
docker push localhost:5000/auth-service:latest
k3d image import localhost:5000/auth-service:latest -c microservices

# Deploy service
cd ..
make -f k8s-local/Makefile deploy-service SERVICE=auth
```

### 5. Verify

```bash
# Check status
make -f k8s-local/Makefile status

# View logs
make -f k8s-local/Makefile logs SERVICE=auth

# Port forward to test
make -f k8s-local/Makefile port-forward SERVICE=gateway PORT=8080
```

## 💼 Daily Development Workflow

### With Tilt (Recommended) ⭐

```bash
# Start cluster (if not running)
make -f k8s-local/Makefile start

# Start Tilt
tilt up

# Tilt automatically:
# - Watches code changes
# - Rebuilds images
# - Redeploys services
# - Shows logs in UI

# Stop Tilt: Press 'q' or Ctrl+C
tilt down
```

### Manual Deploy

```bash
# Start cluster (after reboot)
make -f k8s-local/Makefile start

# Deploy changes
# 1. Build image
cd auth
docker build -t localhost:5000/auth-service:latest .

# 2. Push and import to cluster
docker push localhost:5000/auth-service:latest
k3d image import localhost:5000/auth-service:latest -c microservices

# 3. Restart deployment
kubectl rollout restart deployment/auth-service -n development
```

### View Logs

```bash
# Service logs
make -f k8s-local/Makefile logs SERVICE=auth

# All pods
kubectl get pods -A
kubectl logs -f <pod-name> -n development
```

### Stop/Delete Cluster

```bash
# Stop cluster
make -f k8s-local/Makefile stop

# Delete cluster (cleanup)
make -f k8s-local/Makefile delete
```

## 🎯 Comparison with Docker Compose

| Feature | Docker Compose | k3d (K8s) | k3d + Tilt ⭐ |
|---------|---------------|-----------|--------------|
| **Startup time** | ~30-60s | ~10-20s | ~10-20s |
| **Resource usage** | High (all services) | Low (running pods only) | Low (running pods only) |
| **Hot reload** | Volume mounts | Manual rebuild | ✅ Auto rebuild/redeploy |
| **Scaling** | Manual | `kubectl scale` | `kubectl scale` |
| **Service discovery** | Docker network | K8s DNS | K8s DNS |
| **Production-like** | ❌ | ✅ | ✅ |
| **Developer UX** | Basic | Basic | ✅ UI Dashboard |
| **Learning curve** | Easy | Medium | Medium |

## 📚 Additional Documentation

- **[INSTALLATION.md](./INSTALLATION.md)** - Detailed installation steps for all tools
- **[ACCESS.md](./ACCESS.md)** - Service URLs and access methods
- **[DOMAIN_SETUP.md](./DOMAIN_SETUP.md)** - Setup custom domains (optional)
- **[DOCKERHUB.md](./DOCKERHUB.md)** - Use Docker Hub as registry (optional)
- **[DOCKER_TO_K8S.md](./DOCKER_TO_K8S.md)** - Convert Docker Compose to Kubernetes ⭐

## 🔧 Cluster Configuration

### Port Mappings

- `8080` → Gateway HTTP
- `8443` → Gateway HTTPS
- `30000-30010` → Service NodePorts
- `3500` → Dapr HTTP (internal)
- `50001` → Dapr gRPC (internal)

### Resource Limits (for local dev)

```yaml
resources:
  cpu: "4"        # 4 cores
  memory: "8Gi"   # 8GB RAM
  storage: "50Gi" # 50GB disk
```

## 💡 Tips & Tricks

### 1. Use Local Registry

```bash
# Registry is created automatically during cluster setup
# Build and push images
docker build -t localhost:5000/service-name:latest ./service-name
docker push localhost:5000/service-name:latest
k3d image import localhost:5000/service-name:latest -c microservices
```

### 2. Reduce Resource Usage

Edit `setup-cluster.sh` to reduce agents:

```bash
# Change from 2 agents to 1
--agents 1
```

### 3. Debug Pods

```bash
# Shell into pod
make -f k8s-local/Makefile shell SERVICE=auth

# Check environment variables
kubectl exec deployment/auth-service -n development -- env

# Check config
kubectl exec deployment/auth-service -n development -- cat /app/configs/config.yaml
```

## 🐛 Troubleshooting

### Cluster Won't Start

```bash
# Check Docker
docker ps

# Check k3d
k3d cluster list

# Restart cluster
k3d cluster stop microservices
k3d cluster start microservices
```

### Pods Won't Start

```bash
# Check pod status
kubectl describe pod <pod-name> -n <namespace>

# Check events
kubectl get events --sort-by='.lastTimestamp' -n development

# Check logs
kubectl logs <pod-name> -n <namespace>
```

### Image Pull Errors

```bash
# Import image to cluster
k3d image import <image-name> -c microservices

# Check images
k3d image list
```

## 🔗 Useful Commands

```bash
# Cluster info
kubectl cluster-info

# Get all resources
kubectl get all -n development

# Describe service
kubectl describe svc gateway-service -n development

# Edit deployment
kubectl edit deployment auth-service -n development

# Scale service
kubectl scale deployment auth-service --replicas=2 -n development

# Delete service
kubectl delete deployment auth-service -n development
```

## 📖 References

- [k3d Documentation](https://k3d.io/)
- [Tilt Documentation](https://docs.tilt.dev/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Dapr on Kubernetes](https://docs.dapr.io/operations/hosting/kubernetes/)
