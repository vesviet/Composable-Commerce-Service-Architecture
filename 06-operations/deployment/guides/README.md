# Deployment Guides

**Purpose**: Step-by-step deployment procedures and best practices  
**Last Updated**: 2026-02-03  
**Status**: ✅ Active - Essential deployment procedures

---

## � Overview

This section contains essential deployment guides and best practices for the microservices platform.

### 🎯 What You'll Find Here
- **[Quick Action Guide](./QUICK_ACTION_GUIDE.md)** - Fast deployment procedures
- **[Service Configuration](./service-configuration-guide.md)** - Service setup and configuration

---

## � Quick Start

### **Deploy New Service**
```bash
# 1. Create service configuration
cp templates/service-config.yaml apps/new-service/

# 2. Configure values
vim apps/new-service/values.yaml

# 3. Deploy to cluster
kubectl apply -f apps/new-service/

# 4. Monitor deployment
kubectl get pods -l app=new-service -n production
```

### **Update Existing Service**
```bash
# 1. Update configuration
vim apps/service-name/values.yaml

# 2. Commit changes
git add apps/service-name/values.yaml
git commit -m "Update service configuration"

# 3. Push to Git
git push origin main

# 4. ArgoCD will auto-sync
argocd app get service-name
```

---

## 📚 Available Guides

### **Essential Guides**
- **[Quick Action Guide](./QUICK_ACTION_GUIDE.md)** - Fast deployment commands
- **[Service Configuration](./service-configuration-guide.md)** - Service setup procedures

---

## 🔧 Common Commands

### **Application Management**
```bash
# List all applications
kubectl get applications -n argocd

# Deploy application
kubectl apply -f apps/service-name/

# Update application
kubectl patch deployment service-name -p '{"spec":{"template":{"spec":{"containers":[{"name":"service-name","image":"new-image:tag"}]}}}}'

# Scale application
kubectl scale deployment service-name --replicas=3

# Delete application
kubectl delete deployment service-name
```

### **Troubleshooting**
```bash
# Check pod status
kubectl get pods -l app=service-name

# Check events
kubectl get events --sort-by='.lastTimestamp'

# Check logs
kubectl logs -f deployment/service-name
```

---

## 📞 Support

- **Documentation**: See individual guide files
- **Issues**: GitLab Issues with `deployment` label
- **Help**: #ops-deployments channel

---

**Last Updated**: February 3, 2026  
**Review Cycle**: Monthly deployment review  
**Maintained By**: DevOps & Platform Engineering Teams
- Khi service cần communicate với services khác
- Khi troubleshoot connection issues

### 3. [Configuration Best Practices](./configuration-best-practices.md)
**Mục đích**: Best practices cho việc cấu hình microservices

**Nội dung chính**:
- Nguyên tắc cơ bản (Consistency, Security, Environment Parity)
- Configuration patterns và structures
- Security best practices
- Resource management
- Health check best practices
- Monitoring và observability

**Khi nào sử dụng**:
- Khi thiết kế configuration cho service mới
- Khi review và improve configuration hiện tại
- Khi train team members về best practices
- Khi troubleshoot configuration issues

---

## 🎯 Quick Start Guide

### Cho Service Mới
1. **Đọc [Service Configuration Guide](./service-configuration-guide.md)** để hiểu structure chuẩn
2. **Copy template** từ service tương tự (ví dụ: customer-service)
3. **Update configuration** theo service-specific requirements
4. **Review [Common Service Dependencies](./common-service-dependencies.md)** để cấu hình dependencies
5. **Apply [Configuration Best Practices](./configuration-best-practices.md)**
6. **Validate configuration** bằng Helm template và kubectl dry-run

### Cho Service Hiện Tại
1. **Review configuration** với [Config Review Checklist](../argocd/applications/CONFIG_REVIEW_CHECKLIST.md)
2. **Standardize configuration** theo [Config Standardization Checklist](../argocd/applications/CONFIG_STANDARDIZATION_CHECKLIST.md)
3. **Apply best practices** từ [Configuration Best Practices](./configuration-best-practices.md)
4. **Update dependencies** theo [Common Service Dependencies](./common-service-dependencies.md)
5. **Test và validate** changes

---

## 🔍 Configuration Review Process

### 1. Pre-Review Preparation
- [ ] Đọc [Service Configuration Guide](./service-configuration-guide.md)
- [ ] Chuẩn bị [Config Review Checklist](../argocd/applications/CONFIG_REVIEW_CHECKLIST.md)
- [ ] Identify service category (standard, high-traffic, worker)

### 2. Configuration Review
- [ ] Check file structure và naming conventions
- [ ] Review base configuration (values.yaml)
- [ ] Review environment-specific overrides
- [ ] Validate secrets và security settings
- [ ] Check resource allocations
- [ ] Verify health check configurations

### 3. Dependencies Review
- [ ] Verify database connections use FQDN
- [ ] Check Redis DB number assignments
- [ ] Validate Consul configuration
- [ ] Review external service endpoints
- [ ] Check init container configurations

### 4. Best Practices Validation
- [ ] Apply security best practices
- [ ] Validate resource management
- [ ] Check observability configuration
- [ ] Review deployment strategies
- [ ] Validate monitoring setup

### 5. Testing và Validation
- [ ] Run `helm template` validation
- [ ] Test với `kubectl apply --dry-run`
- [ ] Validate environment-specific configs
- [ ] Check ArgoCD application sync

---

## 🚨 Common Issues và Solutions

### 1. Configuration Issues
**Issue**: Service không start được  
**Solution**: Check [Service Configuration Guide](./service-configuration-guide.md) section "Common Issues"

**Issue**: Health checks fail  
**Solution**: Review health check configuration trong [Configuration Best Practices](./configuration-best-practices.md)

### 2. Dependency Issues
**Issue**: Cannot connect to database/Redis  
**Solution**: Check [Common Service Dependencies](./common-service-dependencies.md) section "Common Issues"

**Issue**: Service discovery không hoạt động  
**Solution**: Verify Consul configuration và FQDN usage

### 3. Resource Issues
**Issue**: Pod bị OOMKilled  
**Solution**: Review resource allocation trong [Configuration Best Practices](./configuration-best-practices.md)

**Issue**: CPU throttling  
**Solution**: Adjust CPU limits theo service category

---

## 📊 Configuration Standards Summary

### File Structure
```
argocd/applications/{service-name}/
├── Chart.yaml
├── values.yaml              # Base config
├── staging/
│   ├── values.yaml          # Staging overrides
│   ├── tag.yaml            # Image tag
│   └── secrets.yaml        # SOPS encrypted secrets
├── production/
│   ├── values.yaml          # Production overrides
│   ├── tag.yaml            # Image tag
│   └── secrets.yaml        # SOPS encrypted secrets
└── templates/              # Helm templates
```

### Key Standards
- **Health Check Path**: `/health` (preferred)
- **Service Ports**: `80` (HTTP), `81` (gRPC)
- **Pod Security**: `runAsNonRoot: true`, `runAsUser: 65532`
- **Resource Categories**: Standard (500m/1Gi), High-traffic (1000m/2Gi), Worker (300m/512Mi)
- **Dependencies**: Always use FQDN (e.g., `redis.infrastructure.svc.cluster.local:6379`)

### Required Components
- [ ] PodDisruptionBudget
- [ ] ServiceMonitor (config, disabled by default)
- [ ] NetworkPolicy (config, disabled by default)
- [ ] Init containers (for critical dependencies)
- [ ] Migration job (for database services)
- [ ] Worker deployment (if service has workers)

---

## 🔧 Tools và Scripts

### Validation Scripts
```bash
# Validate Helm templates
helm template . --debug --dry-run

# Validate with environment-specific values
helm template . -f staging/values.yaml | kubectl apply --dry-run=client -f -

# Check SOPS encryption
sops -d staging/secrets.yaml
```

### Useful Commands
```bash
# Check service status
kubectl get pods -l app={service-name}

# Check service logs
kubectl logs -l app={service-name} -f

# Check service configuration
kubectl describe configmap {service-name}-config

# Check service secrets
kubectl describe secret {service-name}-secret
```

---

## 📈 Metrics và Monitoring

### Key Metrics to Monitor
- **Resource Usage**: CPU, Memory utilization
- **Health Check Status**: Success rate, response time
- **Dependency Health**: Database, Redis, Consul connectivity
- **Application Metrics**: Business-specific metrics

### Alerting Rules
- CPU usage > 80%
- Memory usage > 85%
- Health check failures > 3 consecutive
- Pod restart count > 5 in 1 hour

---

## 🔄 Continuous Improvement

### Regular Reviews
- **Monthly**: Review resource usage và adjust limits
- **Quarterly**: Review configuration standards và update documentation
- **After incidents**: Update configuration based on lessons learned

### Feedback Loop
- Collect feedback từ development teams
- Update standards based on operational experience
- Share best practices across teams

---

## 📞 Support và Contact

### For Configuration Issues
- **Slack**: #devops-support
- **Email**: devops@company.com
- **Documentation**: This deployment docs

### For Service-specific Issues
- **Service Owner**: Check service README
- **Team Lead**: Contact respective team lead
- **Architecture**: #architecture-discussion

---

## 📚 Additional Resources

### Internal Documentation
- [System Architecture Overview](../../SYSTEM_ARCHITECTURE_OVERVIEW.md)
- [Common Package Documentation](../../common/README.md)
- [ArgoCD Applications](../../argocd/applications/)

### External Resources
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Helm Documentation](https://helm.sh/docs/)
- [Dapr Documentation](https://docs.dapr.io/)
- [12-Factor App](https://12factor.net/)

---

**Tác giả**: DevOps Team  
**Cập nhật**: December 27, 2025  
**Version**: 1.0