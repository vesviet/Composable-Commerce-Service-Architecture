# 🔧 Maintenance Runbooks

**Purpose**: Regular maintenance procedures and operational tasks  
**Last Updated**: 2026-02-03  
**Status**: 🔄 In Progress - Procedures being documented

---

## 📋 Overview

This section contains runbooks for regular maintenance tasks, system updates, and operational procedures. These runbooks ensure consistent and reliable maintenance operations across the platform.

---

## 📅 Maintenance Schedule

### **Daily Tasks**

#### **🌅 Morning Checks (06:00 UTC)**
```bash
#!/bin/bash
# daily-health-check.sh

echo "=== Daily Health Check - $(date) ==="

# Check cluster health
echo "Checking cluster health..."
kubectl cluster-info
kubectl get nodes

# Check critical services
echo "Checking critical services..."
kubectl get pods -n production | grep -E "(gateway|auth|order|payment)"

# Check resource usage
echo "Checking resource usage..."
kubectl top nodes
kubectl top pods -n production

# Check backup status
echo "Checking backup status..."
./scripts/check-backup-status.sh

# Check security alerts
echo "Checking security alerts..."
./scripts/check-security-alerts.sh

echo "=== Daily Health Check Complete ==="
```

#### **🌙 Evening Checks (18:00 UTC)**
```bash
#!/bin/bash
# daily-evening-check.sh

echo "=== Evening Check - $(date) ==="

# Check system performance
echo "Checking system performance..."
./scripts/check-performance-metrics.sh

# Review error logs
echo "Reviewing error logs..."
kubectl logs --all-namespaces --since=12h | grep -i error | tail -20

# Check disk space
echo "Checking disk space..."
df -h

# Update monitoring dashboards
echo "Updating monitoring dashboards..."
./scripts/update-dashboards.sh

echo "=== Evening Check Complete ==="
```

### **Weekly Tasks**

#### **📊 Monday - System Review**
```bash
#!/bin/bash
# weekly-system-review.sh

echo "=== Weekly System Review - $(date) ==="

# Performance analysis
echo "Performance analysis..."
./scripts/analyze-performance.sh

# Security scan
echo "Security scan..."
./scripts/security-scan.sh

# Capacity planning
echo "Capacity planning..."
./scripts/capacity-planning.sh

# Update documentation
echo "Updating documentation..."
./scripts/update-documentation.sh

echo "=== Weekly System Review Complete ==="
```

#### **🔧 Wednesday - Maintenance Window**
```bash
#!/bin/bash
# weekly-maintenance.sh

echo "=== Weekly Maintenance - $(date) ==="

# Apply security patches
echo "Applying security patches..."
./scripts/apply-security-patches.sh

# Update dependencies
echo "Updating dependencies..."
./scripts/update-dependencies.sh

# Clean up old data
echo "Cleaning up old data..."
./scripts/cleanup-old-data.sh

# Test disaster recovery
echo "Testing disaster recovery..."
./scripts/test-disaster-recovery.sh

echo "=== Weekly Maintenance Complete ==="
```

#### **📈 Friday - Reporting**
```bash
#!/bin/bash
# weekly-reporting.sh

echo "=== Weekly Reporting - $(date) ==="

# Generate performance report
echo "Generating performance report..."
./scripts/generate-performance-report.sh

# Generate security report
echo "Generating security report..."
./scripts/generate-security-report.sh

# Generate availability report
echo "Generating availability report..."
./scripts/generate-availability-report.sh

# Send reports
echo "Sending reports..."
./scripts/send-reports.sh

echo "=== Weekly Reporting Complete ==="
```

### **Monthly Tasks**

#### **🔄 System Updates**
```bash
#!/bin/bash
# monthly-system-updates.sh

echo "=== Monthly System Updates - $(date) ==="

# Update Kubernetes
echo "Updating Kubernetes..."
./scripts/update-kubernetes.sh

# Update applications
echo "Updating applications..."
./scripts/update-applications.sh

# Update monitoring tools
echo "Updating monitoring tools..."
./scripts/update-monitoring-tools.sh

# Test updates
echo "Testing updates..."
./scripts/test-updates.sh

echo "=== Monthly System Updates Complete ==="
```

#### **🔒 Security Maintenance**
```bash
#!/bin/bash
# monthly-security-maintenance.sh

echo "=== Monthly Security Maintenance - $(date) ==="

# Security audit
echo "Security audit..."
./scripts/security-audit.sh

# Update certificates
echo "Updating certificates..."
./scripts/update-certificates.sh

# Review access controls
echo "Reviewing access controls..."
./scripts-review-access-controls.sh

# Penetration testing
echo "Penetration testing..."
./scripts/penetration-testing.sh

echo "=== Monthly Security Maintenance Complete ==="
```

---

## 🔧 Database Maintenance

### **PostgreSQL Maintenance**

#### **Daily Tasks**
```bash
#!/bin/bash
# postgres-daily-maintenance.sh

echo "=== PostgreSQL Daily Maintenance - $(date) ==="

# Check database health
echo "Checking database health..."
kubectl exec -it postgres-pod -- pg_isready

# Check database size
echo "Checking database size..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    datname,
    pg_size_pretty(pg_database_size(datname)) as size
  FROM pg_database 
  WHERE datname NOT IN ('template0', 'template1');
"

# Check active connections
echo "Checking active connections..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    count(*) as active_connections,
    state,
    wait_event_type
  FROM pg_stat_activity 
  GROUP BY state, wait_event_type;
"

# Check slow queries
echo "Checking slow queries..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    query,
    calls,
    total_time,
    mean_time,
    rows
  FROM pg_stat_statements 
  ORDER BY mean_time DESC 
  LIMIT 10;
"

echo "=== PostgreSQL Daily Maintenance Complete ==="
```

#### **Weekly Tasks**
```bash
#!/bin/bash
# postgres-weekly-maintenance.sh

echo "=== PostgreSQL Weekly Maintenance - $(date) ==="

# Update statistics
echo "Updating database statistics..."
kubectl exec -it postgres-pod -- psql -U postgres -c "ANALYZE;"

# Rebuild indexes
echo "Rebuilding indexes..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) as index_size
  FROM pg_stat_user_indexes 
  WHERE pg_relation_size(indexrelid) > 100 * 1024 * 1024; -- > 100MB
"

# Check table bloat
echo "Checking table bloat..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) as table_size,
    pg_size_pretty(pg_relation_size(schemaname||'.'||tablename)) as data_size
  FROM pg_tables 
  WHERE schemaname NOT IN ('information_schema', 'pg_catalog');
"

# Vacuum analyze
echo "Running vacuum analyze..."
kubectl exec -it postgres-pod -- psql -U postgres -c "VACUUM ANALYZE;"

echo "=== PostgreSQL Weekly Maintenance Complete ==="
```

#### **Monthly Tasks**
```bash
#!/bin/bash
# postgres-monthly-maintenance.sh

echo "=== PostgreSQL Monthly Maintenance - $(date) ==="

# Full backup
echo "Creating full backup..."
kubectl exec -it postgres-pod -- pg_dumpall -U postgres > backup-$(date +%Y%m%d).sql

# Check database consistency
echo "Checking database consistency..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    schemaname,
    tablename,
    attname,
    n_distinct,
    correlation
  FROM pg_stats 
  WHERE schemaname NOT IN ('information_schema', 'pg_catalog');
"

# Optimize configuration
echo "Optimizing configuration..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT name, setting, unit, short_desc 
  FROM pg_settings 
  WHERE name IN ('shared_buffers', 'work_mem', 'maintenance_work_mem', 'effective_cache_size');
"

# Review query performance
echo "Reviewing query performance..."
kubectl exec -it postgres-pod -- psql -U postgres -c "
  SELECT 
    query,
    calls,
    total_exec_time,
    mean_exec_time,
    stddev_exec_time,
    rows
  FROM pg_stat_statements 
  WHERE calls > 100 
  ORDER BY mean_exec_time DESC 
  LIMIT 20;
"

echo "=== PostgreSQL Monthly Maintenance Complete ==="
```

### **Redis Maintenance**

#### **Daily Tasks**
```bash
#!/bin/bash
# redis-daily-maintenance.sh

echo "=== Redis Daily Maintenance - $(date) ==="

# Check Redis health
echo "Checking Redis health..."
kubectl exec -it redis-pod -- redis-cli ping

# Check memory usage
echo "Checking memory usage..."
kubectl exec -it redis-pod -- redis-cli INFO memory

# Check connected clients
echo "Checking connected clients..."
kubectl exec -it redis-pod -- redis-cli INFO clients

# Check slow queries
echo "Checking slow queries..."
kubectl exec -it redis-pod -- redis-cli SLOWLOG GET 10

echo "=== Redis Daily Maintenance Complete ==="
```

#### **Weekly Tasks**
```bash
#!/bin/bash
# redis-weekly-maintenance.sh

echo "=== Redis Weekly Maintenance - $(date) ==="

# Memory optimization
echo "Optimizing memory..."
kubectl exec -it redis-pod -- redis-cli MEMORY PURGE

# Check fragmentation
echo "Checking fragmentation..."
kubectl exec -it redis-pod -- redis-cli MEMORY STATS

# Clean up expired keys
echo "Cleaning up expired keys..."
kubectl exec -it redis-pod -- redis-cli --scan --pattern "expired:*" | xargs redis-cli DEL

# Backup Redis data
echo "Backing up Redis data..."
kubectl exec -it redis-pod -- redis-cli BGSAVE

echo "=== Redis Weekly Maintenance Complete ==="
```

---

## 🚀 Application Maintenance

### **Service Health Checks**

#### **Automated Health Check**
```bash
#!/bin/bash
# service-health-check.sh

SERVICES=("gateway" "auth" "order" "payment" "catalog" "customer")

for service in "${SERVICES[@]}"; do
    echo "Checking $service service..."
    
    # Check deployment status
    kubectl get deployment $service -n production
    
    # Check pod status
    kubectl get pods -l app=$service -n production
    
    # Check service health
    kubectl exec -it deployment/$service -n production -- curl -f http://localhost:8080/health
    
    # Check metrics
    kubectl exec -it deployment/$service -n production -- curl -f http://localhost:8080/metrics
    
    echo "---"
done
```

#### **Service Restart Procedures**
```bash
#!/bin/bash
# service-restart.sh

SERVICE=$1
NAMESPACE=${2:-production}

if [ -z "$SERVICE" ]; then
    echo "Usage: $0 <service-name> [namespace]"
    exit 1
fi

echo "Restarting $service in $namespace..."

# Check current status
echo "Current status:"
kubectl get deployment $service -n $namespace

# Restart service
echo "Restarting service..."
kubectl rollout restart deployment/$service -n $namespace

# Wait for restart
echo "Waiting for restart..."
kubectl rollout status deployment/$service -n $namespace --timeout=300s

# Verify health
echo "Verifying health..."
kubectl exec -it deployment/$service -n $namespace -- curl -f http://localhost:8080/health

echo "Service $service restarted successfully"
```

### **Configuration Updates**

#### **Environment Configuration**
```bash
#!/bin/bash
# update-config.sh

SERVICE=$1
CONFIG_FILE=$2
NAMESPACE=${3:-production}

if [ -z "$SERVICE" ] || [ -z "$CONFIG_FILE" ]; then
    echo "Usage: $0 <service-name> <config-file> [namespace]"
    exit 1
fi

echo "Updating configuration for $service..."

# Backup current config
echo "Backing up current configuration..."
kubectl get configmap $service-config -n $namespace -o yaml > backup-$service-config-$(date +%Y%m%d).yaml

# Apply new configuration
echo "Applying new configuration..."
kubectl apply -f $CONFIG_FILE -n $namespace

# Restart service to apply config
echo "Restarting service to apply configuration..."
kubectl rollout restart deployment/$service -n $namespace

# Wait for restart
echo "Waiting for restart..."
kubectl rollout status deployment/$service -n $namespace --timeout=300s

# Verify configuration
echo "Verifying configuration..."
kubectl exec -it deployment/$service -n $namespace -- curl -f http://localhost:8080/health

echo "Configuration updated successfully"
```

---

## 🔒 Security Maintenance

### **Certificate Management**

#### **Certificate Renewal**
```bash
#!/bin/bash
# renew-certificates.sh

echo "=== Certificate Renewal - $(date) ==="

# Check certificate expiry
echo "Checking certificate expiry..."
kubectl get certificates --all-namespaces

# Renew expiring certificates
echo "Renewing expiring certificates..."
kubectl get certificates --all-namespaces -o json | jq '.items[] | select(.status.conditions[]?.reason=="Ready") | .metadata.name' | while read cert; do
    if [ -n "$cert" ]; then
        echo "Renewing certificate: $cert"
        kubectl annotate certificate $cert cert-manager.io/renew-before="30d" --all-namespaces
    fi
done

# Verify certificate status
echo "Verifying certificate status..."
kubectl get certificates --all-namespaces

echo "=== Certificate Renewal Complete ==="
```

### **Security Updates**

#### **Security Patch Management**
```bash
#!/bin/bash
# security-patch-management.sh

echo "=== Security Patch Management - $(date) ==="

# Check for security vulnerabilities
echo "Checking for security vulnerabilities..."
./scripts/security-vulnerability-scan.sh

# Apply security patches
echo "Applying security patches..."
./scripts/apply-security-patches.sh

# Update security configurations
echo "Updating security configurations..."
./scripts/update-security-configs.sh

# Test security patches
echo "Testing security patches..."
./scripts/test-security-patches.sh

echo "=== Security Patch Management Complete ==="
```

---

## 📊 Monitoring Maintenance

### **Dashboard Updates**

#### **Grafana Dashboard Maintenance**
```bash
#!/bin/bash
# grafana-maintenance.sh

echo "=== Grafana Maintenance - $(date) ==="

# Backup dashboards
echo "Backing up dashboards..."
./scripts/backup-grafana-dashboards.sh

# Update dashboard templates
echo "Updating dashboard templates..."
./scripts/update-dashboard-templates.sh

# Validate dashboards
echo "Validating dashboards..."
./scripts/validate-grafana-dashboards.sh

# Import new dashboards
echo "Importing new dashboards..."
./scripts/import-grafana-dashboards.sh

echo "=== Grafana Maintenance Complete ==="
```

### **Alert Management**

#### **Alert Rule Maintenance**
```bash
#!/bin/bash
# alert-maintenance.sh

echo "=== Alert Maintenance - $(date) ==="

# Backup alert rules
echo "Backing up alert rules..."
kubectl get prometheusrules --all-namespaces -o yaml > backup-alert-rules-$(date +%Y%m%d).yaml

# Update alert thresholds
echo "Updating alert thresholds..."
./scripts/update-alert-thresholds.sh

# Test alert rules
echo "Testing alert rules..."
./scripts/test-alert-rules.sh

# Validate alert configuration
echo "Validating alert configuration..."
./scripts/validate-alert-config.sh

echo "=== Alert Maintenance Complete ==="
```

---

## 📚 Related Documentation

### **Operational Documentation**
- [Monitoring Overview](../monitoring/README.md) - Monitoring and alerting
- [Security Operations](../security/README.md) - Security procedures
- [Incident Response](../incident-response/README.md) - Incident procedures

### **Service Documentation**
- [Service Runbooks](../sre-runbooks/README.md) - Service-specific procedures
- [Service Documentation](../../03-services/README.md) - Service details

---

**Last Updated**: 2026-02-03  
**Review Cycle**: Monthly  
**Maintained By**: SRE & Platform Engineering Teams
