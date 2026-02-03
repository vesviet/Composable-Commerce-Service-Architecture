# Kubernetes Operations

**Purpose**: Kubernetes cluster management and operations  
**Last Updated**: 2026-02-03  
**Status**: ✅ Active - Production cluster management

---

## 📋 Overview

This section contains Kubernetes cluster management, setup, and operational procedures for the microservices platform.

### 🎯 What You'll Find Here
- **[Installation Guide](./INSTALLATION.md)** - Cluster setup and installation
- **[Docker to K8s](./DOCKER_TO_K8S.md)** - Container migration procedures
- **[Summary](./SUMMARY.md)** - Cluster overview and status

---

## 🚀 Quick Start

### **Cluster Setup**
```bash
# Install kubectl
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"

# Install helm
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

# Verify cluster access
kubectl cluster-info
```

### **Deploy Services**
```bash
# Deploy to production
kubectl apply -f apps/

# Check deployment status
kubectl get pods -n production

# Monitor services
kubectl get services -n production
```

---

## 📊 Cluster Status

| Component | Status | Version |
|-----------|--------|--------|
| **Kubernetes** | ✅ Active | v1.25+ |
| **Nodes** | ✅ Healthy | 3+ nodes |
| **Storage** | ✅ Available | Persistent volumes |
| **Networking** | ✅ Active | CNI configured |

---

## 🔧 Common Commands

### **Cluster Management**
```bash
# Check cluster health
kubectl get nodes
kubectl get pods --all-namespaces

# Check resource usage
kubectl top nodes
kubectl top pods

# Get cluster info
kubectl cluster-info dump
```

### **Troubleshooting**
```bash
# Check pod logs
kubectl logs -f pod-name -n namespace

# Describe pod
kubectl describe pod pod-name -n namespace

# Check events
kubectl get events --sort-by=.metadata.creationTimestamp
```
---

## 📞 Support

- **Documentation**: [Installation Guide](./INSTALLATION.md)
- **Issues**: GitLab Issues with `kubernetes` label
- **Help**: #ops-infrastructure channel
```

## 📖 References

- [k3d Documentation](https://k3d.io/)
- [Tilt Documentation](https://docs.tilt.dev/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Dapr on Kubernetes](https://docs.dapr.io/operations/hosting/kubernetes/)
