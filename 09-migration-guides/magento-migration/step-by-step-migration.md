# 🔄 Step-by-Step Magento Migration Process

**Purpose**: Detailed step-by-step migration procedures from Magento to microservices  
**Last Updated**: 2026-02-03  
**Status**: ✅ Ready for implementation  

---

## 📋 Migration Overview

This guide provides detailed step-by-step procedures for migrating from Magento to the new microservices platform using the **3-phase approach**. Each step includes prerequisites, commands, and validation procedures.

---

## 🚀 Phase 1: Read-Only Migration

### **Step 1.1: Deploy Read-Only Microservices**

#### **Prerequisites**
- Kubernetes cluster access
- Docker registry access
- Database credentials
- Monitoring tools configured

#### **Procedure**
```bash
# 1. Create namespace
kubectl create namespace migration-phase1

# 2. Deploy read-only services
kubectl apply -f configs/customer-service-readonly.yaml
kubectl apply -f configs/catalog-service-readonly.yaml
kubectl apply -f configs/order-service-readonly.yaml

# 3. Verify deployment
kubectl get pods -n migration-phase1
kubectl get services -n migration-phase1

# 4. Check health status
kubectl logs -f deployment/customer-service-readonly -n migration-phase1
```

#### **Validation**
```bash
# Test service health
curl -f http://customer-service-readonly:8080/health
curl -f http://catalog-service-readonly:8080/health
curl -f http://order-service-readonly:8080/health

# Check database connectivity
curl -f http://customer-service-readonly:8080/health/db
```

### **Step 1.2: Set Up Real-Time Sync Service**

#### **Procedure**
```bash
# 1. Deploy sync service
kubectl apply -f configs/sync-service.yaml

# 2. Configure environment variables
kubectl set env deployment/magento-sync-service \
  MAGENTO_DB_HOST=magento-db.production.svc.cluster.local \
  MICRO_DB_HOST=microservices-db.production.svc.cluster.local \
  SYNC_INTERVAL=1 \
  MAX_RETRIES=3 \
  -n migration-phase1

# 3. Start sync service
kubectl scale deployment magento-sync-service --replicas=1 -n migration-phase1

# 4. Monitor sync logs
kubectl logs -f deployment/magento-sync-service -n migration-phase1
```

#### **Validation**
```bash
# Check sync status
curl -s http://magento-sync-service:8080/api/v1/status | jq '.'

# Verify data sync
./scripts/validate-data-sync.sh --service=customer --sample-size=100
```

### **Step 1.3: Configure Feature Flag Service**

#### **Procedure**
```bash
# 1. Deploy feature flag service
kubectl apply -f configs/feature-flag-service.yaml

# 2. Configure initial flags
curl -X POST "http://feature-flag-service:8080/api/v1/flags" \
  -H "Content-Type: application/json" \
  -d '{
    "customer_read": {"enabled": true, "auto_disable": true},
    "catalog_read": {"enabled": true, "auto_disable": true},
    "order_read": {"enabled": true, "auto_disable": true}
  }'

# 3. Verify flag configuration
curl -s http://feature-flag-service:8080/api/v1/flags | jq '.'
```

### **Step 1.4: Configure API Gateway Routing**

#### **Procedure**
```bash
# 1. Update API Gateway configuration
kubectl apply -f configs/api-gateway-routing.yaml

# 2. Test routing rules
curl -H "Host: api.company.com" http://api-gateway/api/v1/customers/1
curl -H "Host: api.company.com" -X POST http://api-gateway/api/v1/customers \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","first_name":"Test","last_name":"User"}'

# 3. Verify routing behavior
kubectl logs -f deployment/api-gateway | grep "routing"
```

#### **Validation**
```bash
# Test read operations go to microservices
curl -s -w "%{time_total}\n" -o /dev/null "http://api.company.com/api/v1/customers"

# Test write operations go to Magento
curl -s -w "%{time_total}\n" -o /dev/null -X POST "http://api.company.com/api/v1/customers" \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com"}'
```

### **Step 1.5: Monitor and Validate**

#### **Monitoring Setup**
```bash
# 1. Deploy monitoring
kubectl apply -f configs/monitoring.yaml

# 2. Set up alerts
kubectl apply -f configs/alerts.yaml

# 3. Check metrics
curl -s http://prometheus:9090/api/v1/query?query=sync_success_total
```

#### **Validation Scripts**
```bash
#!/bin/bash
# validate-phase1.sh

echo "Validating Phase 1 migration..."

# Check service health
for service in customer catalog order; do
    health=$(curl -s "http://${service}-service-readonly:8080/health" | jq -r '.status')
    if [ "$health" = "healthy" ]; then
        echo "✅ $service service healthy"
    else
        echo "❌ $service service unhealthy: $health"
        exit 1
    fi
done

# Check data consistency
./scripts/validate-data-consistency.sh --all-services

# Check feature flags
for flag in customer_read catalog_read order_read; do
    enabled=$(curl -s "http://feature-flag-service:8080/api/v1/flags/$flag" | jq -r '.enabled')
    if [ "$enabled" = "true" ]; then
        echo "✅ $flag enabled"
    else
        echo "❌ $flag disabled"
        exit 1
    fi
done

echo "Phase 1 validation completed successfully"
```

---

## 🚀 Phase 2: Read-Write Migration

### **Step 2.1: Deploy Event Bus Infrastructure**

#### **Procedure**
```bash
# 1. Deploy Kafka cluster
kubectl apply -f configs/kafka-cluster.yaml

# 2. Create event topics
kubectl apply -f configs/event-topics.yaml

# 3. Verify Kafka deployment
kubectl get pods -l strimzi.io/cluster=migration-event-bus
kubectl get kafkatopics

# 4. Test Kafka connectivity
kubectl exec -it migration-event-bus-kafka-0 -- kafka-topics.sh --bootstrap-server localhost:9092 --list
```

#### **Validation**
```bash
# Test topic creation
kubectl exec -it migration-event-bus-kafka-0 -- kafka-topics.sh --bootstrap-server localhost:9092 --create --topic test-topic --partitions 3 --replication-factor 3

# Test producer/consumer
kubectl exec -it migration-event-bus-kafka-0 -- kafka-console-producer.sh --bootstrap-server localhost:9092 --topic test-topic
```

### **Step 2.2: Deploy Event Processor Service**

#### **Procedure**
```bash
# 1. Deploy event processor
kubectl apply -f configs/event-processor.yaml

# 2. Configure environment
kubectl set env deployment/event-processor \
  KAFKA_BOOTSTRAP_SERVERS=migration-event-bus-bootstrap:9092 \
  MAGENTO_DB_HOST=magento-db.production.svc.cluster.local \
  MICRO_DB_HOST=microservices-db.production.svc.cluster.local \
  CONFLICT_RESOLUTION=magento-wins

# 3. Start event processing
kubectl scale deployment event-processor --replicas=2

# 4. Monitor event processing
kubectl logs -f deployment/event-processor | grep "event"
```

#### **Validation**
```bash
# Check event processor health
curl -s http://event-processor:8080/health | jq '.'

# Monitor event metrics
curl -s http://event-processor:8080/metrics | grep event_processing
```

### **Step 2.3: Update Microservices for Dual-Write**

#### **Customer Service Update**
```bash
# 1. Update customer service with event publishing
kubectl apply -f configs/customer-service-dual-write.yaml

# 2. Add Kafka producer configuration
kubectl set env deployment/customer-service \
  KAFKA_BOOTSTRAP_SERVERS=migration-event-bus-bootstrap:9092 \
  EVENT_TOPIC=customer-events

# 3. Restart service
kubectl rollout restart deployment/customer-service

# 4. Verify event publishing
kubectl logs -f deployment/customer-service | grep "event"
```

#### **Test Dual-Write**
```bash
#!/bin/bash
# test-dual-write.sh

echo "Testing dual-write functionality..."

# Create customer via microservices
RESPONSE=$(curl -s -X POST "http://api.company.com/api/v1/customers" \
  -H "Content-Type: application/json" \
  -d '{"email":"dualwrite@test.com","first_name":"Dual","last_name":"Write"}')

CUSTOMER_ID=$(echo $RESPONSE | jq -r '.id')

# Wait for event processing
sleep 5

# Check Magento
MAGENTO_RECORD=$(mysql -h $MAGENTO_DB_HOST -u $MAGENTO_DB_USER -p$MAGENTO_DB_PASS $MAGENTO_DB_NAME -e "
  SELECT * FROM customer_entity WHERE entity_id = $CUSTOMER_ID
")

if [ -n "$MAGENTO_RECORD" ]; then
    echo "✅ Dual-write working: Customer synced to Magento"
else
    echo "❌ Dual-write failed: Customer not found in Magento"
    exit 1
fi
```

### **Step 2.4: Gradual Service Migration**

#### **Customer Service Migration**
```bash
#!/bin/bash
# migrate-customer-service-phase2.sh

echo "Starting Customer Service Phase 2 Migration..."

# Enable write feature flag
curl -X POST "http://feature-flag-service:8080/api/v1/flags/customer_write" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "auto_disable_on_failure": true,
    "health_check_interval": 30
  }'

# Monitor for 30 minutes
echo "Monitoring customer service for 30 minutes..."
for minute in {1..30}; do
    # Check service health
    health=$(curl -s "http://customer-service:8080/health" | jq -r '.status')
    if [ "$health" != "healthy" ]; then
        echo "⚠️ Customer service unhealthy at minute $minute: $health"
    fi
    
    # Check dual-write consistency
    ./scripts/validate-dual-write.sh --service=customer --sample-size=10
    
    sleep 60
done

echo "Customer Service Phase 2 Migration completed"
```

#### **Catalog Service Migration**
```bash
#!/bin/bash
# migrate-catalog-service-phase2.sh

echo "Starting Catalog Service Phase 2 Migration..."

curl -X POST "http://feature-flag-service:8080/api/v1/flags/catalog_write" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "auto_disable_on_failure": true}'

# Monitor for 30 minutes
for minute in {1..30}; do
    ./scripts/validate-dual-write.sh --service=catalog --sample-size=5
    sleep 60
done

echo "Catalog Service Phase 2 Migration completed"
```

#### **Order Service Migration**
```bash
#!/bin/bash
# migrate-order-service-phase2.sh

echo "Starting Order Service Phase 2 Migration (High Risk)..."

# Create backup
./scripts/backup-order-data.sh

# Enable with stricter monitoring
curl -X POST "http://feature-flag-service:8080/api/v1/flags/order_write" \
  -H "Content-Type: application/json" \
  -d '{
    "enabled": true,
    "auto_disable_on_failure": true,
    "health_check_interval": 10,
    "strict_validation": true
  }'

# Extended monitoring
for minute in {1..60}; do
    ./scripts/validate-dual-write.sh --service=order --sample-size=3
    ./scripts/check-order-integrity.sh
    sleep 60
done

echo "Order Service Phase 2 Migration completed"
```

---

## 🚀 Phase 3: Full Cutover

### **Step 3.1: Deploy Archive Service**

#### **Procedure**
```bash
# 1. Deploy archive service
kubectl apply -f configs/archive-service.yaml

# 2. Configure archive settings
kubectl set env deployment/archive-service \
  ARCHIVE_INTERVAL=3600 \
  COMPRESSION_ENABLED=true \
  BATCH_SIZE=1000

# 3. Start archive service
kubectl scale deployment archive-service --replicas=2

# 4. Test archive functionality
curl -X POST "http://archive-service:8080/api/v1/test-archive" \
  -H "Content-Type: application/json" \
  -d '{"service": "customer", "limit": 10}'
```

### **Step 3.2: Gradual Service Cutover**

#### **Customer Service Cutover**
```bash
#!/bin/bash
# cutover-customer-service-phase3.sh

echo "Starting Customer Service Phase 3 Cutover..."

# Enable 100% cutover
curl -X POST "http://feature-flag-service:8080/api/v1/flags/customer_cutover" \
  -H "Content-Type: application/json" \
  -d '{"enabled": true, "percentage": 100}'

# Disable dual-write
curl -X POST "http://event-processor:8080/api/v1/disable-service" \
  -H "Content-Type: application/json" \
  -d '{"service": "customer"}'

# Start archive service
curl -X POST "http://archive-service:8080/api/v1/start-archive" \
  -H "Content-Type: application/json" \
  -d '{"service": "customer", "interval": 3600}'

# Monitor for 7 days
for day in {1..7}; do
    echo "Day $day monitoring..."
    ./scripts/monitor-service-health.sh --service=customer --duration=86400
    ./scripts/validate-performance.sh --service=customer --target-rps=1000
done

echo "Customer Service Phase 3 Cutover completed"
```

#### **Order Service Gradual Cutover**
```bash
#!/bin/bash
# cutover-order-service-gradual.sh

echo "Starting Order Service Gradual Cutover..."

percentages=(25 50 75 100)
durations=(3 3 4 4) # days per step

for i in "${!percentages[@]}"; do
    percentage=${percentages[$i]}
    duration=${durations[$i]}
    
    echo "Increasing order service traffic to $percentage% for $duration days..."
    
    curl -X POST "http://feature-flag-service:8080/api/v1/flags/order_cutover" \
      -H "Content-Type: application/json" \
      -d "{\"enabled\": true, \"percentage\": $percentage}"
    
    # Monitor for specified duration
    for day in $(seq 1 $duration); do
        echo "Day $day at $percentage% traffic..."
        ./scripts/monitor-service-health.sh --service=order --duration=86400
        ./scripts/validate-performance.sh --service=order --target-rps=500
        
        # Check if stable
        if ! ./scripts/check-service-stability.sh --service=order; then
            echo "⚠️ Service unstable at $percentage%, rolling back..."
            curl -X POST "http://feature-flag-service:8080/api/v1/flags/order_cutover" \
              -H "Content-Type: application/json" \
              -d '{"enabled": false}'
            exit 1
        fi
    done
done

echo "Order Service Phase 3 Cutover completed"
```

### **Step 3.3: Performance Optimization**

#### **Remove Dual-Write Overhead**
```bash
# 1. Stop event processor
kubectl scale deployment event-processor --replicas=0

# 2. Update services to optimized version
kubectl apply -f configs/optimized-services.yaml

# 3. Scale resources for full load
kubectl apply -f configs/optimized-scaling.yaml

# 4. Configure caching
kubectl apply -f configs/cache-config.yaml
```

#### **Performance Testing**
```bash
#!/bin/bash
# performance-test.sh

echo "Running performance tests..."

# Load test all services
./scripts/load-test-all-services.sh --concurrent=1000 --duration=3600

# Validate performance targets
./scripts/validate-performance-targets.sh

# Generate performance report
./scripts/generate-performance-report.sh
```

---

## 🔧 Common Scripts

### **Data Validation Script**
```bash
#!/bin/bash
# validate-data-consistency.sh

SERVICE=$1
SAMPLE_SIZE=${2:-100}

echo "Validating data consistency for $SERVICE..."

# Get sample from microservices
MICRO_DATA=$(curl -s "http://api.company.com/api/v1/$SERVICE?limit=$SAMPLE_SIZE")

# Compare with Magento
echo "$MICRO_DATA" | jq -r '.data[].id' | while read -r id; do
    if [ "$id" != "null" ]; then
        MICRO_RECORD=$(curl -s "http://api.company.com/api/v1/$SERVICE/$id")
        MAGENTO_RECORD=$(mysql -h $MAGENTO_DB_HOST -u $MAGENTO_DB_USER -p$MAGENTO_DB_PASS $MAGENTO_DB_NAME -e "
          SELECT * FROM ${SERVICE}_table WHERE entity_id = $id
        ")
        
        if [ -n "$MAGENTO_RECORD" ]; then
            echo "✅ Record $id consistent"
        else
            echo "❌ Record $id inconsistent"
        fi
    fi
done
```

### **Health Check Script**
```bash
#!/bin/bash
# health-check-all-services.sh

services=("customer" "catalog" "order")
all_healthy=true

for service in "${services[@]}"; do
    health=$(curl -s "http://$service-service:8080/health" | jq -r '.status')
    if [ "$health" = "healthy" ]; then
        echo "✅ $service service healthy"
    else
        echo "❌ $service service unhealthy: $health"
        all_healthy=false
    fi
done

if [ "$all_healthy" = true ]; then
    echo "✅ All services healthy"
    exit 0
else
    echo "❌ Some services unhealthy"
    exit 1
fi
```

---

## 🚨 Troubleshooting

### **Common Issues**

#### **Sync Service Issues**
```bash
# Check sync service logs
kubectl logs -f deployment/magento-sync-service -n migration-phase1

# Restart sync service
kubectl rollout restart deployment/magento-sync-service -n migration-phase1

# Check database connectivity
kubectl exec -it magento-sync-service -- nc -z $MAGENTO_DB_HOST 3306
```

#### **Event Processing Issues**
```bash
# Check event processor logs
kubectl logs -f deployment/event-processor

# Check Kafka topics
kubectl exec -it migration-event-bus-kafka-0 -- kafka-topics.sh --bootstrap-server localhost:9092 --list

# Reset consumer offsets
kubectl exec -it migration-event-bus-kafka-0 -- kafka-consumer-groups.sh --bootstrap-server localhost:9092 --reset-offsets --to-latest --group event-processor
```

#### **Feature Flag Issues**
```bash
# Check feature flag service
curl -s http://feature-flag-service:8080/health | jq '.'

# Reset feature flags
curl -X POST "http://feature-flag-service:8080/api/v1/reset" \
  -H "Content-Type: application/json" \
  -d '{"confirm": true}'
```

---

## 📋 Migration Checklists

### **Phase 1 Checklist**
- [ ] Read-only microservices deployed
- [ ] Real-time sync service working
- [ ] Feature flag service configured
- [ ] API Gateway routing configured
- [ ] Data consistency validated
- [ ] Monitoring systems active

### **Phase 2 Checklist**
- [ ] Event bus infrastructure deployed
- [ ] Event processor service running
- [ ] Dual-write implemented
- [ ] All services write-enabled
- [ ] Conflict resolution working
- [ ] Data consistency validated

### **Phase 3 Checklist**
- [ ] Archive service deployed
- [ ] All services 100% cutover
- [ ] Performance optimized
- [ ] Event processing disabled
- [ ] Magento hot standby active
- [ ] Rollback procedures tested

---

## 📞 Support

- **Migration Team**: migration-team@company.com
- **Infrastructure**: infra-team@company.com
- **Database**: dba-team@company.com
- **Emergency**: migration-emergency@company.com

---

**Last Updated**: February 3, 2026  
**Review Cycle: Weekly during migration  
**Maintained By**: Migration Team & Platform Engineering
