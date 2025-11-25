# Docker Hub Registry Setup

## 🐳 Sử dụng Docker Hub làm Image Registry

### Quick Start

#### 1. Login to Docker Hub

```bash
docker login
# Enter your Docker Hub username and password
```

#### 2. Configure Registry

```bash
# Option 1: Configure via script
./k8s-local/config-registry.sh dockerhub <your-dockerhub-username>

# Option 2: Use directly in deploy scripts
./k8s-local/deploy-gateway-dockerhub.sh <your-dockerhub-username> [gitlab-token]
```

#### 3. Deploy Services

```bash
# Deploy Gateway
./k8s-local/deploy-gateway-dockerhub.sh <username> [gitlab-token]

# Deploy all services
./k8s-local/deploy-services-dockerhub.sh <username> [gitlab-token]
```

---

## 📝 Detailed Setup

### Step 1: Docker Hub Account

1. **Create account** (if you don't have one):
   - Go to https://hub.docker.com
   - Sign up for free account

2. **Login**:
   ```bash
   docker login
   # Username: your-username
   # Password: your-password
   ```

### Step 2: Configure Registry

```bash
# Configure to use Docker Hub
./k8s-local/config-registry.sh dockerhub <your-username>

# Verify configuration
cat ~/.k8s-local-registry
```

**Output:**
```
REGISTRY_TYPE=dockerhub
DOCKERHUB_USERNAME=your-username
REGISTRY_PREFIX=your-username
```

### Step 3: Build and Push Images

#### Gateway Service

```bash
# Build and push
./k8s-local/deploy-gateway-dockerhub.sh <username> [gitlab-token]

# Or manually:
docker build -f gateway/Dockerfile --build-arg GITLAB_TOKEN=$GITLAB_TOKEN \
  -t <username>/gateway-service:latest .
docker push <username>/gateway-service:latest
```

#### Auth Service

```bash
docker build -f auth/Dockerfile --build-arg GITLAB_TOKEN=$GITLAB_TOKEN \
  -t <username>/auth-service:latest .
docker push <username>/auth-service:latest
```

#### User Service

```bash
docker build -f user/Dockerfile --build-arg GITLAB_TOKEN=$GITLAB_TOKEN \
  -t <username>/user-service:latest .
docker push <username>/user-service:latest
```

#### Admin Dashboard

```bash
cd admin
docker build -t <username>/admin-dashboard:latest .
docker push <username>/admin-dashboard:latest
```

### Step 4: Update Kubernetes Deployments

Images sẽ được tự động update khi chạy deploy scripts. Hoặc manually:

```bash
# Update Gateway
kubectl set image deployment/gateway-service \
  gateway-service=<username>/gateway-service:latest \
  -n development

# Update Auth
kubectl set image deployment/auth-service \
  auth-service=<username>/auth-service:latest \
  -n development

# Update User
kubectl set image deployment/user-service \
  user-service=<username>/user-service:latest \
  -n development

# Update Admin
kubectl set image deployment/admin-dashboard \
  admin-dashboard=<username>/admin-dashboard:latest \
  -n development
```

---

## 🔄 Switch Between Local and Docker Hub

### Use Local Registry

```bash
./k8s-local/config-registry.sh local
```

### Use Docker Hub

```bash
./k8s-local/config-registry.sh dockerhub <username>
```

---

## 📋 Image Naming Convention

### Docker Hub Format

```
<username>/<service-name>:<tag>
```

**Examples:**
- `tuananh/gateway-service:latest`
- `tuananh/auth-service:latest`
- `tuananh/user-service:latest`
- `tuananh/admin-dashboard:latest`

### Local Registry Format

```
k3d-local-registry:5000/<service-name>:latest
```

---

## 🚀 Automated Deployment

### Deploy All Services

```bash
# Using Docker Hub
./k8s-local/deploy-services-dockerhub.sh <username> [gitlab-token]

# This will:
# 1. Build all service images
# 2. Push to Docker Hub
# 3. Update Kubernetes deployments
# 4. Wait for pods to be ready
```

### Deploy Individual Service

```bash
# Gateway
./k8s-local/deploy-gateway-dockerhub.sh <username> [gitlab-token]

# Or use the generic deploy script with Docker Hub config
```

---

## 🔐 Private Images

Docker Hub supports private repositories:

1. **Make repository private**:
   - Go to Docker Hub → Repositories
   - Click on repository → Settings → Make Private

2. **Pull private images in Kubernetes**:
   - Create Docker Hub secret:
   ```bash
   kubectl create secret docker-registry dockerhub-secret \
     --docker-server=https://index.docker.io/v1/ \
     --docker-username=<username> \
     --docker-password=<password> \
     --docker-email=<email> \
     -n development
   ```
   
   - Update deployment to use secret:
   ```yaml
   spec:
     imagePullSecrets:
     - name: dockerhub-secret
     containers:
     - name: gateway-service
       image: <username>/gateway-service:latest
   ```

---

## 📊 Benefits of Docker Hub

✅ **Public Access**: Images accessible from anywhere  
✅ **No Local Setup**: No need for local registry  
✅ **Version Control**: Tag images with versions  
✅ **CI/CD Integration**: Easy to integrate with CI/CD  
✅ **Free Tier**: 1 private repo, unlimited public repos  

---

## 🔍 Verify Images

```bash
# List local images
docker images | grep <username>

# Check Docker Hub
# Go to https://hub.docker.com/u/<username>/repositories

# Pull and test
docker pull <username>/gateway-service:latest
docker run -p 8080:8080 <username>/gateway-service:latest
```

---

## 🐛 Troubleshooting

### Authentication Failed

```bash
# Re-login
docker logout
docker login

# Check credentials
cat ~/.docker/config.json
```

### Image Pull Errors

```bash
# Check if image exists
docker pull <username>/gateway-service:latest

# Check Kubernetes events
kubectl describe pod <pod-name> -n development

# Check image pull secrets
kubectl get secrets -n development
```

### Build Errors

```bash
# Check Dockerfile
cat gateway/Dockerfile

# Build with verbose output
docker build -f gateway/Dockerfile --progress=plain -t <username>/gateway-service:latest .
```

---

## 📚 Next Steps

1. **Tag with versions**: Use semantic versioning
   ```bash
   docker tag <username>/gateway-service:latest <username>/gateway-service:v1.0.0
   docker push <username>/gateway-service:v1.0.0
   ```

2. **Automate with CI/CD**: Push images automatically on git push

3. **Use private registry**: For production, consider private Docker Hub or other registries

