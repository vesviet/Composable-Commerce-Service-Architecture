# Access URLs - Kubernetes Local Services

## 🌐 Gateway Service

### Option 1: LoadBalancer IP (k3d)
```bash
# Access via LoadBalancer IPs
http://172.18.0.3:80
http://172.18.0.4:80
http://172.18.0.5:80
```

### Option 2: NodePort
```bash
# Access via NodePort
http://localhost:30798
```

### Option 3: Port Forward (Recommended) ⭐
```bash
# Port forward gateway
kubectl port-forward svc/gateway-service 8080:80 -n development

# Then access
http://localhost:8080
```

### Test Gateway
```bash
# Health check
curl http://localhost:8080/health

# Services health
curl http://localhost:8080/api/services/health
```

---

## 🎨 Admin Dashboard

### Option 1: Port Forward (Recommended) ⭐
```bash
# Port forward admin dashboard
kubectl port-forward svc/admin-dashboard 3000:80 -n development

# Then access
http://localhost:3000
```

### Option 2: Direct Pod Port Forward (Vite Dev Server)
```bash
# Get admin pod name
kubectl get pods -l app=admin-dashboard -n development

# Port forward to Vite dev server (port 5173)
kubectl port-forward <admin-pod-name> 5173:5173 -n development

# Then access
http://localhost:5173
```

### Quick Access Script
```bash
# Port forward both services
kubectl port-forward svc/gateway-service 8080:80 -n development &
kubectl port-forward svc/admin-dashboard 3000:80 -n development &

# Access:
# Gateway: http://localhost:8080
# Admin: http://localhost:3000
```

---

## 🔗 Service URLs (Internal K8s DNS)

### From within cluster:
```
Gateway:  http://gateway-service.development.svc.cluster.local:80
Auth:     http://auth-service.development.svc.cluster.local:80
User:     http://user-service.development.svc.cluster.local:80
Admin:    http://admin-dashboard.development.svc.cluster.local:80
```

### From local machine (via port forward):
```bash
# Gateway
kubectl port-forward svc/gateway-service 8080:80 -n development
# Access: http://localhost:8080

# Admin
kubectl port-forward svc/admin-dashboard 3000:80 -n development
# Access: http://localhost:3000

# Auth (if needed)
kubectl port-forward svc/auth-service 8000:80 -n development
# Access: http://localhost:8000

# User (if needed)
kubectl port-forward svc/user-service 8001:80 -n development
# Access: http://localhost:8001
```

---

## 🚀 Quick Start Commands

```bash
# Start port forwards for Gateway and Admin
kubectl port-forward svc/gateway-service 8080:80 -n development &
kubectl port-forward svc/admin-dashboard 3000:80 -n development &

# Access URLs:
# - Gateway: http://localhost:8080
# - Admin: http://localhost:3000

# Stop port forwards
pkill -f "port-forward"
```

---

## 📝 Notes

1. **Gateway**: LoadBalancer type, accessible via multiple IPs
2. **Admin**: ClusterIP type, requires port-forward
3. **Vite Dev Server**: Admin runs Vite dev server on port 5173 inside container
4. **Health Checks**: 
   - Gateway: `/health`
   - Auth: `/api/v1/auth/health`
   - User: `/health`

---

## 🔍 Troubleshooting

### Cannot access Gateway
```bash
# Check service
kubectl get svc gateway-service -n development

# Check pods
kubectl get pods -l app=gateway-service -n development

# Check logs
kubectl logs -l app=gateway-service -n development
```

### Cannot access Admin
```bash
# Check service
kubectl get svc admin-dashboard -n development

# Check pods
kubectl get pods -l app=admin-dashboard -n development

# Check logs
kubectl logs -l app=admin-dashboard -n development
```

### Port forward fails
```bash
# Check if port is already in use
lsof -i :8080
lsof -i :3000

# Use different ports
kubectl port-forward svc/gateway-service 8081:80 -n development
```

