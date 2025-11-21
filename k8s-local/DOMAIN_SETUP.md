# Domain Setup Guide - Local Development

> **Quick Reference**: Setup custom domain names for local Kubernetes services.

## 🌐 Overview

This guide shows you how to set up custom domain names (like `api.microservices.local`) for your local Kubernetes services instead of using localhost with ports.

## 🚀 Quick Setup (Recommended)

### Option 1: NGINX Ingress + /etc/hosts ⭐

This is the cleanest solution for local development.

#### Step 1: Install NGINX Ingress Controller

```bash
./k8s-local/setup-ingress.sh
```

#### Step 2: Create Ingress Rules

```bash
./k8s-local/create-ingress-rules.sh
```

#### Step 3: Setup Local Domains

```bash
./k8s-local/setup-local-domains.sh
```

**After setup, you can access:**
- **Gateway API**: `http://api.microservices.local`
- **Admin Dashboard**: `http://admin.microservices.local`

---

### Option 2: NodePort (No sudo needed)

Use NodePort directly without port forwarding:

```bash
./k8s-local/start-domain-access-alt.sh

# Access URLs:
# Gateway: http://api.microservices.local:32318
# Admin: http://admin.microservices.local:32318
```

**Advantages:**
- ✅ No sudo needed
- ✅ No port forward process
- ✅ Works immediately

---

### Option 3: Dynamic DNS (nip.io / xip.io)

No need to edit /etc/hosts, uses dynamic DNS:

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Access via nip.io
# Gateway: http://api.${INGRESS_IP}.nip.io
# Admin: http://admin.${INGRESS_IP}.nip.io
```

**Example:**
- If IP is `172.18.0.6`:
  - Gateway: `http://api.172.18.0.6.nip.io`
  - Admin: `http://admin.172.18.0.6.nip.io`

---

## 📝 Manual Setup

### 1. Install NGINX Ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \\
  --namespace ingress-nginx \\
  --create-namespace \\
  --set controller.service.type=LoadBalancer \\
  --set controller.admissionWebhooks.enabled=false
```

### 2. Create Ingress Rules

```bash
kubectl apply -f k8s-local/services/gateway/ingress.yaml
kubectl apply -f k8s-local/services/admin/ingress.yaml
```

**Example Ingress Rule:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: gateway-ingress
  namespace: development
spec:
  ingressClassName: nginx
  rules:
  - host: api.microservices.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: gateway-service
            port:
              number: 80
```

### 3. Add to /etc/hosts

```bash
# Get ingress IP
INGRESS_IP=$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Add to /etc/hosts
echo "$INGRESS_IP    api.microservices.local" | sudo tee -a /etc/hosts
echo "$INGRESS_IP    admin.microservices.local" | sudo tee -a /etc/hosts
```

---

## ❌ Port 80 Issue & Solutions

### Problem

Port 80 requires root/sudo privileges. You may encounter errors like:

- `bind: permission denied`
- `unable to listen on port 80`

### Solutions

#### Solution 1: Use NodePort (No sudo) ⭐ Recommended

```bash
# Access via NodePort directly
# URLs: http://api.microservices.local:32318
```

No port forwarding needed, no sudo required.

#### Solution 2: Run with sudo

```bash
# Port forward with sudo
sudo kubectl port-forward svc/ingress-nginx-controller 80:80 -n ingress-nginx

# Then access: http://api.microservices.local
```

#### Solution 3: Use Different Port

```bash
# Port forward to port 8080
kubectl port-forward svc/ingress-nginx-controller 8080:80 -n ingress-nginx

# Then access: http://api.microservices.local:8080
```

#### Solution 4: Recreate Cluster with Port 80 Mapping

```bash
# Recreate cluster with port 80 mapped
./k8s-local/setup-ingress-port80.sh

# This maps port 80 directly to the load balancer
# Then access without port forward: http://api.microservices.local
```

---

## 🧪 Testing

```bash
# Test Gateway
curl http://api.microservices.local/health

# Or with NodePort
curl http://api.microservices.local:32318/health

# Test Admin
curl http://admin.microservices.local/

# Test with browser
# Open: http://api.microservices.local/health
# Open: http://admin.microservices.local
```

---

## 📋 Configured Domains

After setup, the following domains will be available:

```
127.0.0.1    api.microservices.local
127.0.0.1    admin.microservices.local
127.0.0.1    gateway.microservices.local
```

### Ingress Rules

| Host | Service | Port | Path |
|------|---------|------|------|
| `api.microservices.local` | `gateway-service` | 80 | `/` |
| `admin.microservices.local` | `admin-dashboard` | 80 | `/` |

---

## 🔍 Troubleshooting

### Cannot Resolve Domain

```bash
# Check /etc/hosts
cat /etc/hosts | grep microservices.local

# Check ingress IP
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Test with curl
curl -v http://api.microservices.local/health
```

### Ingress Not Working

```bash
# Check ingress controller
kubectl get pods -n ingress-nginx

# Check ingress rules
kubectl get ingress -n development

# Check ingress logs
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller
```

### Domain Not Accessible

```bash
# Test with Host header
curl -H "Host: api.microservices.local" http://<ingress-ip>/health

# Check ingress controller service
kubectl describe svc -n ingress-nginx ingress-nginx-controller
```

### Port Already in Use

```bash
# Check what's using port 80
sudo lsof -i :80

# Kill the process or use a different port
```

---

## 💡 Tips

- **Browser**: Access `http://api.microservices.local:32318/health` in your browser
- **API Testing**: Use Postman/curl with domain names
- **No Port Number**: If you port forward the ingress controller to port 80, you can omit the port number
- **Clean URLs**: For the best experience, use Option 4 (recreate cluster with port 80 mapping)

---

## 📚 Additional Resources

- [NGINX Ingress Documentation](https://kubernetes.github.io/ingress-nginx/)
- [nip.io Documentation](https://nip.io/)
- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
