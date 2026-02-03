# 🔧 Operations Runbooks

**Purpose**: Comprehensive runbooks for incident response and system operations  
**Last Updated**: 2026-02-03  
**Status**: ✅ Active - 18 service runbooks available

---

## 📋 Overview

This section contains comprehensive runbooks for managing and troubleshooting the microservices platform. Runbooks provide step-by-step procedures for common operational tasks, incident response, and system maintenance.

### 🎯 What You'll Find Here

- **[SRE Runbooks](./sre-runbooks/)** - Service-specific troubleshooting guides
- **[Incident Response Runbooks](./incident-response/)** - Security incident procedures
- **[Maintenance Runbooks](./maintenance/)** - Regular maintenance procedures
- **[Emergency Procedures](./emergency/)** - Critical incident response

---

## 🚨 Quick Access

### **Most Common Issues**
- **[Service Won't Start](./sre-runbooks/README.md#service-wont-start)** - General troubleshooting
- **[High Error Rate](./sre-runbooks/README.md#high-error-rate)** - Performance issues
- **[Database Issues](./sre-runbooks/README.md#database-issues)** - Database troubleshooting
- **[Event Processing](./sre-runbooks/README.md#event-processing-issues)** - Dapr event issues

### **Critical Services**
- **[Gateway](./sre-runbooks/gateway-runbook.md)** - API gateway issues
- **[Auth Service](./sre-runbooks/auth-service-runbook.md)** - Authentication problems
- **[Order Service](./sre-runbooks/order-service-runbook.md)** - Order processing issues
- **[Payment Service](./sre-runbooks/payment-service-runbook.md)** - Payment processing problems

---

## 📊 Runbook Categories

### **🔧 Service-Specific Runbooks**

#### **Core Infrastructure**
| Service | Port | Health Check | Status | Runbook |
|---------|------|--------------|--------|---------|
| **Gateway** | 8080 | `GET /health` | ✅ | [gateway-runbook.md](./sre-runbooks/gateway-runbook.md) |
| **Auth Service** | 8000, 9000 | `GET /health` | ✅ | [auth-service-runbook.md](./sre-runbooks/auth-service-runbook.md) |

#### **Business Services**
| Service | Port | Health Check | Status | Runbook |
|---------|------|--------------|--------|---------|
| **Order Service** | 8004, 9004 | `GET /health` | ✅ | [order-service-runbook.md](./sre-runbooks/order-service-runbook.md) |
| **Customer Service** | 8007, 9007 | `GET /health` | ✅ | [customer-service-runbook.md](./sre-runbooks/customer-service-runbook.md) |
| **Catalog Service** | 8015, 9015 | `GET /api/v1/catalog/health` | ✅ | [catalog-service-runbook.md](./sre-runbooks/catalog-service-runbook.md) |
| **Payment Service** | 8005, 9005 | `GET /api/v1/payments/health` | ✅ | [payment-service-runbook.md](./sre-runbooks/payment-service-runbook.md) |

#### **Operational Services**
| Service | Port | Health Check | Status | Runbook |
|---------|------|--------------|--------|---------|
| **Warehouse Service** | 8008, 9008 | `GET /health` | ✅ | [warehouse-service-runbook.md](./sre-runbooks/warehouse-service-runbook.md) |
| **Fulfillment Service** | 8010, 9010 | `GET /health` | ✅ | [fulfillment-service-runbook.md](./sre-runbooks/fulfillment-service-runbook.md) |
| **Shipping Service** | 8006, 9006 | `GET /health` | ✅ | [shipping-service-runbook.md](./sre-runbooks/shipping-service-runbook.md) |
| **Notification Service** | 8009, 9009 | `GET /health` | ✅ | [notification-service-runbook.md](./sre-runbooks/notification-service-runbook.md) |

---

## 🎯 Runbook Structure

### **Standard Runbook Format**

Each runbook follows a consistent structure:

#### **📋 Quick Reference**
- **Service Overview**: Brief description and dependencies
- **Health Checks**: How to verify service health
- **Key Metrics**: Important monitoring metrics
- **Emergency Contacts**: Who to contact for help

#### **🔧 Common Issues**
- **Issue Description**: What the problem looks like
- **Symptoms**: How to identify the issue
- **Root Causes**: Common causes of the issue
- **Quick Fixes**: Immediate resolution steps

#### **🚨 Incident Response**
- **Severity Assessment**: How to determine impact
- **Containment Steps**: How to prevent further damage
- **Recovery Procedures**: How to restore service
- **Verification Steps**: How to confirm resolution

#### **📊 Monitoring & Alerting**
- **Key Metrics**: What to monitor
- **Alert Thresholds**: When to trigger alerts
- **Dashboard Links**: Where to find more information
- **Log Locations**: Where to find detailed logs

---

## 🔍 Quick Troubleshooting Guide

### **Service Won't Start**
```bash
# 1. Check health endpoint
curl http://localhost:PORT/health

# 2. Check service logs
kubectl logs -f deployment/SERVICE-NAME -n production

# 3. Check resource usage
kubectl top pods -l app=SERVICE-NAME -n production

# 4. Check configuration
kubectl describe deployment SERVICE-NAME -n production
```

### **High Error Rate**
```bash
# 1. Check recent errors
kubectl logs deployment/SERVICE-NAME -n production --since=5m | grep ERROR

# 2. Check database connectivity
kubectl exec -it SERVICE-NAME-pod -- nc -zv DATABASE-HOST 5432

# 3. Check external services
curl -I https://external-service.com/health

# 4. Check resource limits
kubectl describe pod SERVICE-NAME-pod -n production
```

### **Slow Performance**
```bash
# 1. Check response times
curl -w "@curl-format.txt" http://localhost:PORT/api/endpoint

# 2. Check database queries
kubectl exec -it DATABASE-POD -- psql -U USER -d DB -c "SELECT * FROM pg_stat_activity;"

# 3. Check cache performance
kubectl exec -it REDIS-POD -- redis-cli INFO stats

# 4. Check network latency
kubectl exec -it POD -- ping EXTERNAL-SERVICE
```

---

## 📞 Emergency Contacts

### **🚨 Critical Incidents**
- **On-Call Engineer**: Check PagerDuty schedule
- **Incident Commander**: incident-commander@company.com
- **Platform Team**: platform-team@company.com
- **SRE Team**: sre@company.com

### **🔧 Technical Support**
- **Database Admin**: dba@company.com
- **Network Team**: network-team@company.com
- **Security Team**: security@company.com
- **DevOps Team**: devops@company.com

### **📞 Communication Channels**
- **Incidents**: #incidents (Slack)
- **Platform**: #platform-engineering (Slack)
- **Security**: #security-incidents (Slack)
- **On-Call**: #on-call (Slack)

---

## 🔧 Common Recovery Commands

### **Service Management**
```bash
# Restart service
kubectl rollout restart deployment/SERVICE-NAME -n production

# Scale service
kubectl scale deployment SERVICE-NAME --replicas=3 -n production

# Check rollout status
kubectl rollout status deployment/SERVICE-NAME -n production

# Rollback deployment
kubectl rollout undo deployment/SERVICE-NAME -n production
```

### **Database Operations**
```bash
# Check database connection
kubectl exec -it DATABASE-POD -- pg_isready

# Backup database
kubectl exec -it DATABASE-POD -- pg_dump -U USER DB_NAME > backup.sql

# Restore database
kubectl exec -i DATABASE-POD -- psql -U USER DB_NAME < backup.sql

# Check database size
kubectl exec -it DATABASE-POD -- psql -U USER -d DB -c "SELECT pg_size_pretty(pg_database_size('DB_NAME'));"
```

### **Cache Operations**
```bash
# Check Redis status
kubectl exec -it REDIS-POD -- redis-cli ping

# Clear cache
kubectl exec -it REDIS-POD -- redis-cli FLUSHDB

# Check memory usage
kubectl exec -it REDIS-POD -- redis-cli INFO memory

# Monitor Redis
kubectl exec -it REDIS-POD -- redis-cli MONITOR
```

---

## 📈 Monitoring Integration

### **Key Metrics to Monitor**

#### **Service Metrics**
- **Request Rate**: `{service}_requests_total`
- **Error Rate**: `{service}_errors_total`
- **Latency**: `{service}_request_duration_seconds`
- **Active Connections**: `{service}_active_connections`

#### **Infrastructure Metrics**
- **CPU Usage**: `node_cpu_seconds_total`
- **Memory Usage**: `node_memory_MemAvailable_bytes`
- **Disk Usage**: `node_filesystem_avail_bytes`
- **Network I/O**: `node_network_receive_bytes_total`

#### **Business Metrics**
- **Order Rate**: `orders_created_total`
- **Payment Success**: `payment_success_rate`
- **User Activity**: `active_users_total`
- **Revenue**: `revenue_total`

### **Alert Thresholds**

#### **Critical Alerts**
- Service down > 1 minute
- Error rate > 10%
- Response time > 2 seconds
- CPU usage > 90%

#### **Warning Alerts**
- Error rate > 5%
- Response time > 1 second
- CPU usage > 80%
- Memory usage > 85%

---

## 🔄 Runbook Maintenance

### **Update Schedule**

#### **Regular Updates**
- **Monthly**: Review and update runbooks
- **Quarterly**: Major updates and improvements
- **After Incidents**: Update based on lessons learned
- **Service Changes**: Update when services change

#### **Review Process**
1. **Accuracy Check**: Verify procedures are correct
2. **Completeness Review**: Ensure all scenarios covered
3. **Clarity Assessment**: Make sure instructions are clear
4. **Testing**: Validate procedures work as expected

### **Runbook Quality Standards**

#### **Content Requirements**
- ✅ Clear, step-by-step instructions
- ✅ Common issues and solutions
- ✅ Emergency contact information
- ✅ Monitoring and alerting details
- ✅ Log locations and debugging steps

#### **Format Requirements**
- ✅ Consistent structure and formatting
- ✅ Code blocks for commands
- ✅ Tables for quick reference
- ✅ Links to related documentation
- ✅ Version control and change tracking

---

## 📚 Related Documentation

### **Platform Documentation**
- [Monitoring Overview](../monitoring/README.md) - Monitoring and alerting
- [Security Operations](../security/README.md) - Security incident response
- [GitOps Overview](../deployment/gitops/GITOPS_OVERVIEW.md) - Deployment procedures

### **Service Documentation**
- [Service Documentation](../../03-services/README.md) - Detailed service information
- [API Documentation](../../04-apis/README.md) - API specifications
- [Architecture Decisions](../../08-architecture-decisions/README.md) - Design decisions

### **External Resources**
- [Kubernetes Troubleshooting](https://kubernetes.io/docs/tasks/debug-application-cluster/)
- [Docker Troubleshooting](https://docs.docker.com/config/troubleshoot/)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)

---

## 🎯 Getting Started

### **For New Team Members**
1. **Read the Overview**: Start with this README
2. **Review Common Issues**: Understand frequent problems
3. **Practice Procedures**: Try recovery commands in dev environment
4. **Join On-Call**: Shadow experienced team members

### **For Incident Response**
1. **Assess Severity**: Determine incident impact
2. **Follow Runbook**: Use appropriate service runbook
3. **Communicate**: Keep stakeholders informed
4. **Document**: Record actions and outcomes

### **For Maintenance**
1. **Schedule Downtime**: Plan maintenance windows
2. **Backup Data**: Create system backups
3. **Follow Procedures**: Use maintenance runbooks
4. **Verify Recovery**: Ensure systems are working

---

**Last Updated**: 2026-02-03  
**Review Cycle**: Monthly  
**Maintained By**: SRE & Platform Engineering Teams  
**Total Runbooks**: 18 service runbooks + incident response procedures
