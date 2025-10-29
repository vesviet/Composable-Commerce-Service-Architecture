# Monitoring and Observability Configurations

## Overview
This directory contains comprehensive monitoring and observability configurations for the e-commerce microservices platform using Prometheus, Grafana, Jaeger, and ELK stack.

## Structure
```
monitoring-configs/
├── prometheus/
│   ├── prometheus.yml              # Main Prometheus configuration
│   ├── alert-rules/                # Alerting rules
│   │   ├── infrastructure.yml      # Infrastructure alerts
│   │   ├── microservices.yml       # Application alerts
│   │   └── business-metrics.yml    # Business KPI alerts
│   └── service-discovery/          # Service discovery configs
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/            # Data source configurations
│   │   └── dashboards/             # Dashboard configurations
│   ├── dashboards/                 # Custom dashboard JSON files
│   │   ├── infrastructure/         # Infrastructure dashboards
│   │   ├── microservices/          # Service-specific dashboards
│   │   └── business/               # Business metrics dashboards
│   └── plugins/                    # Custom Grafana plugins
├── jaeger/
│   ├── jaeger-all-in-one.yml      # Jaeger deployment
│   └── jaeger-production.yml       # Production Jaeger setup
├── elasticsearch/
│   ├── elasticsearch.yml          # Elasticsearch configuration
│   ├── index-templates/            # Log index templates
│   └── ingest-pipelines/           # Log processing pipelines
├── logstash/
│   ├── logstash.yml               # Logstash configuration
│   ├── pipelines/                 # Log processing pipelines
│   └── patterns/                  # Custom Grok patterns
├── kibana/
│   ├── kibana.yml                 # Kibana configuration
│   └── saved-objects/             # Dashboards and visualizations
└── alertmanager/
    ├── alertmanager.yml           # Alert routing configuration
    └── templates/                 # Alert notification templates
```

## Prometheus Configuration

### Main Configuration (prometheus/prometheus.yml)
```yaml
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    cluster: 'ecommerce-production'
    replica: 'prometheus-1'

rule_files:
  - "alert-rules/*.yml"

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

scrape_configs:
  # Prometheus itself
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Kubernetes API Server
  - job_name: 'kubernetes-apiservers'
    kubernetes_sd_configs:
      - role: endpoints
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - source_labels: [__meta_kubernetes_namespace, __meta_kubernetes_service_name, __meta_kubernetes_endpoint_port_name]
        action: keep
        regex: default;kubernetes;https

  # Kubernetes Nodes
  - job_name: 'kubernetes-nodes'
    kubernetes_sd_configs:
      - role: node
    scheme: https
    tls_config:
      ca_file: /var/run/secrets/kubernetes.io/serviceaccount/ca.crt
    bearer_token_file: /var/run/secrets/kubernetes.io/serviceaccount/token
    relabel_configs:
      - action: labelmap
        regex: __meta_kubernetes_node_label_(.+)
      - target_label: __address__
        replacement: kubernetes.default.svc:443
      - source_labels: [__meta_kubernetes_node_name]
        regex: (.+)
        target_label: __metrics_path__
        replacement: /api/v1/nodes/${1}/proxy/metrics

  # Kubernetes Pods
  - job_name: 'kubernetes-pods'
    kubernetes_sd_configs:
      - role: pod
    relabel_configs:
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_scrape]
        action: keep
        regex: true
      - source_labels: [__meta_kubernetes_pod_annotation_prometheus_io_path]
        action: replace
        target_label: __metrics_path__
        regex: (.+)
      - source_labels: [__address__, __meta_kubernetes_pod_annotation_prometheus_io_port]
        action: replace
        regex: ([^:]+)(?::\d+)?;(\d+)
        replacement: $1:$2
        target_label: __address__
      - action: labelmap
        regex: __meta_kubernetes_pod_label_(.+)
      - source_labels: [__meta_kubernetes_namespace]
        action: replace
        target_label: kubernetes_namespace
      - source_labels: [__meta_kubernetes_pod_name]
        action: replace
        target_label: kubernetes_pod_name

  # Microservices
  - job_name: 'catalog-service'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: catalog-service
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        action: keep
        regex: http
    metrics_path: /metrics
    scrape_interval: 30s

  - job_name: 'order-service'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: order-service
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        action: keep
        regex: http
    metrics_path: /metrics
    scrape_interval: 15s  # More frequent for critical service

  - job_name: 'payment-service'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: payment-service
      - source_labels: [__meta_kubernetes_endpoint_port_name]
        action: keep
        regex: http
    metrics_path: /metrics
    scrape_interval: 15s  # More frequent for critical service

  # Infrastructure Services
  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis-exporter:9121']

  - job_name: 'kafka-exporter'
    static_configs:
      - targets: ['kafka-exporter:9308']

  - job_name: 'elasticsearch-exporter'
    static_configs:
      - targets: ['elasticsearch-exporter:9114']

  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres-exporter:9187']

  # Node Exporter
  - job_name: 'node-exporter'
    kubernetes_sd_configs:
      - role: endpoints
    relabel_configs:
      - source_labels: [__meta_kubernetes_service_name]
        action: keep
        regex: node-exporter
```

### Alert Rules

#### Infrastructure Alerts (prometheus/alert-rules/infrastructure.yml)
```yaml
groups:
  - name: infrastructure
    rules:
      # Node alerts
      - alert: NodeDown
        expr: up{job="node-exporter"} == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Node {{ $labels.instance }} has been down for more than 5 minutes."

      - alert: NodeHighCPU
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 10 minutes."

      - alert: NodeHighMemory
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 10 minutes."

      - alert: NodeDiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk space is below 10% on {{ $labels.device }}."

      # Kubernetes alerts
      - alert: KubernetesPodCrashLooping
        expr: rate(kube_pod_container_status_restarts_total[15m]) > 0
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} is crash looping"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} is restarting frequently."

      - alert: KubernetesPodNotReady
        expr: kube_pod_status_ready{condition="false"} == 1
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Pod {{ $labels.pod }} not ready"
          description: "Pod {{ $labels.pod }} in namespace {{ $labels.namespace }} has been not ready for more than 10 minutes."

      # Database alerts
      - alert: PostgreSQLDown
        expr: pg_up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "PostgreSQL instance {{ $labels.instance }} is down"
          description: "PostgreSQL instance {{ $labels.instance }} has been down for more than 5 minutes."

      - alert: PostgreSQLHighConnections
        expr: pg_stat_database_numbackends / pg_settings_max_connections * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High PostgreSQL connections on {{ $labels.instance }}"
          description: "PostgreSQL connection usage is above 80%."

      # Redis alerts
      - alert: RedisDown
        expr: redis_up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Redis instance {{ $labels.instance }} is down"
          description: "Redis instance {{ $labels.instance }} has been down for more than 5 minutes."

      - alert: RedisHighMemoryUsage
        expr: redis_memory_used_bytes / redis_memory_max_bytes * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High Redis memory usage on {{ $labels.instance }}"
          description: "Redis memory usage is above 90%."

      # Kafka alerts
      - alert: KafkaDown
        expr: kafka_server_brokertopicmetrics_messagesin_total == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Kafka broker {{ $labels.instance }} is down"
          description: "Kafka broker {{ $labels.instance }} appears to be down."

      - alert: KafkaHighLag
        expr: kafka_consumer_lag_sum > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High Kafka consumer lag"
          description: "Kafka consumer lag is above 1000 messages for topic {{ $labels.topic }}."
```

#### Microservices Alerts (prometheus/alert-rules/microservices.yml)
```yaml
groups:
  - name: microservices
    rules:
      # General service alerts
      - alert: ServiceDown
        expr: up{job=~".*-service"} == 0
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.job }} is down"
          description: "Service {{ $labels.job }} has been down for more than 2 minutes."

      - alert: ServiceHighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) * 100 > 5
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate for {{ $labels.job }}"
          description: "Error rate is above 5% for service {{ $labels.job }}."

      - alert: ServiceHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency for {{ $labels.job }}"
          description: "95th percentile latency is above 1 second for service {{ $labels.job }}."

      # Order Service specific alerts
      - alert: OrderServiceHighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket{job="order-service"}[5m])) > 2
        for: 3m
        labels:
          severity: critical
        annotations:
          summary: "Order Service high latency"
          description: "Order Service 95th percentile latency is above 2 seconds."

      - alert: OrderProcessingFailure
        expr: rate(order_processing_failures_total[5m]) > 0.1
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "Order processing failures detected"
          description: "Order processing failure rate is above 0.1 per second."

      # Payment Service specific alerts
      - alert: PaymentServiceDown
        expr: up{job="payment-service"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Payment Service is down"
          description: "Payment Service has been down for more than 1 minute."

      - alert: PaymentFailureRate
        expr: rate(payment_failures_total[5m]) > 0.05
        for: 2m
        labels:
          severity: critical
        annotations:
          summary: "High payment failure rate"
          description: "Payment failure rate is above 0.05 per second."

      # Catalog Service specific alerts
      - alert: CatalogServiceHighMemory
        expr: container_memory_usage_bytes{pod=~"catalog-service-.*"} / container_spec_memory_limit_bytes * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Catalog Service high memory usage"
          description: "Catalog Service memory usage is above 85%."

      # Inventory alerts
      - alert: InventoryServiceLag
        expr: kafka_consumer_lag_sum{topic="inventory.updated"} > 100
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Inventory Service consumer lag"
          description: "Inventory Service has high consumer lag on inventory.updated topic."
```

#### Business Metrics Alerts (prometheus/alert-rules/business-metrics.yml)
```yaml
groups:
  - name: business-metrics
    rules:
      # Revenue alerts
      - alert: LowOrderVolume
        expr: rate(orders_created_total[1h]) < 10
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Low order volume detected"
          description: "Order creation rate is below 10 orders per hour for the last 30 minutes."

      - alert: HighOrderCancellationRate
        expr: rate(orders_cancelled_total[1h]) / rate(orders_created_total[1h]) * 100 > 20
        for: 15m
        labels:
          severity: warning
        annotations:
          summary: "High order cancellation rate"
          description: "Order cancellation rate is above 20% for the last 15 minutes."

      # Conversion alerts
      - alert: LowConversionRate
        expr: rate(orders_created_total[1h]) / rate(product_views_total[1h]) * 100 < 2
        for: 30m
        labels:
          severity: warning
        annotations:
          summary: "Low conversion rate detected"
          description: "Conversion rate is below 2% for the last 30 minutes."

      # Inventory alerts
      - alert: LowStockAlert
        expr: inventory_quantity < 10
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low stock for product {{ $labels.product_id }}"
          description: "Product {{ $labels.product_id }} has low stock ({{ $value }} units remaining)."

      - alert: OutOfStockAlert
        expr: inventory_quantity == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Product {{ $labels.product_id }} is out of stock"
          description: "Product {{ $labels.product_id }} is completely out of stock."

      # Customer alerts
      - alert: HighCustomerChurnRate
        expr: rate(customer_churn_total[24h]) / rate(customer_registrations_total[24h]) * 100 > 50
        for: 1h
        labels:
          severity: warning
        annotations:
          summary: "High customer churn rate"
          description: "Customer churn rate is above 50% in the last 24 hours."
```

## Grafana Configuration

### Data Sources (grafana/provisioning/datasources/prometheus.yml)
```yaml
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: true
    jsonData:
      timeInterval: "15s"
      queryTimeout: "60s"
      httpMethod: "POST"

  - name: Jaeger
    type: jaeger
    access: proxy
    url: http://jaeger:16686
    editable: true

  - name: Elasticsearch
    type: elasticsearch
    access: proxy
    url: http://elasticsearch:9200
    database: "logstash-*"
    editable: true
    jsonData:
      interval: "Daily"
      timeField: "@timestamp"
      esVersion: "7.10.0"
```

### Dashboard Provisioning (grafana/provisioning/dashboards/dashboards.yml)
```yaml
apiVersion: 1

providers:
  - name: 'infrastructure'
    orgId: 1
    folder: 'Infrastructure'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/infrastructure

  - name: 'microservices'
    orgId: 1
    folder: 'Microservices'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/microservices

  - name: 'business'
    orgId: 1
    folder: 'Business Metrics'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 10
    allowUiUpdates: true
    options:
      path: /var/lib/grafana/dashboards/business
```

## Jaeger Configuration

### Production Jaeger (jaeger/jaeger-production.yml)
```yaml
apiVersion: jaegertracing.io/v1
kind: Jaeger
metadata:
  name: jaeger-production
spec:
  strategy: production
  
  collector:
    replicas: 3
    resources:
      requests:
        memory: "512Mi"
        cpu: "500m"
      limits:
        memory: "1Gi"
        cpu: "1000m"
  
  query:
    replicas: 2
    resources:
      requests:
        memory: "256Mi"
        cpu: "250m"
      limits:
        memory: "512Mi"
        cpu: "500m"
  
  storage:
    type: elasticsearch
    elasticsearch:
      nodeCount: 3
      resources:
        requests:
          memory: "2Gi"
          cpu: "1000m"
        limits:
          memory: "4Gi"
          cpu: "2000m"
      storage:
        size: 100Gi
        storageClassName: "gp2"
  
  ingress:
    enabled: true
    annotations:
      kubernetes.io/ingress.class: nginx
      cert-manager.io/cluster-issuer: letsencrypt-prod
    hosts:
      - jaeger.ecommerce.com
    tls:
      - secretName: jaeger-tls
        hosts:
          - jaeger.ecommerce.com
```

## ELK Stack Configuration

### Elasticsearch (elasticsearch/elasticsearch.yml)
```yaml
cluster.name: "ecommerce-logs"
network.host: 0.0.0.0

discovery.seed_hosts: ["elasticsearch-master-headless"]
cluster.initial_master_nodes: ["elasticsearch-master-0", "elasticsearch-master-1", "elasticsearch-master-2"]

bootstrap.memory_lock: false

xpack.security.enabled: true
xpack.security.transport.ssl.enabled: true
xpack.security.transport.ssl.verification_mode: certificate
xpack.security.transport.ssl.keystore.path: certs/elastic-certificates.p12
xpack.security.transport.ssl.truststore.path: certs/elastic-certificates.p12

xpack.security.http.ssl.enabled: true
xpack.security.http.ssl.keystore.path: certs/elastic-certificates.p12

xpack.monitoring.collection.enabled: true
```

### Logstash Pipeline (logstash/pipelines/microservices.conf)
```ruby
input {
  beats {
    port => 5044
  }
}

filter {
  if [kubernetes][container][name] =~ /.*-service/ {
    # Parse JSON logs from microservices
    json {
      source => "message"
    }
    
    # Add service name from container name
    mutate {
      add_field => { "service_name" => "%{[kubernetes][container][name]}" }
    }
    
    # Parse timestamp
    date {
      match => [ "timestamp", "ISO8601" ]
    }
    
    # Extract trace information
    if [traceId] {
      mutate {
        add_field => { "trace_id" => "%{traceId}" }
        add_field => { "span_id" => "%{spanId}" }
      }
    }
    
    # Categorize log levels
    if [level] == "ERROR" {
      mutate {
        add_tag => [ "error" ]
      }
    } else if [level] == "WARN" {
      mutate {
        add_tag => [ "warning" ]
      }
    }
  }
  
  # Parse Nginx access logs
  if [kubernetes][container][name] == "nginx" {
    grok {
      match => { "message" => "%{NGINXACCESS}" }
    }
  }
  
  # Parse PostgreSQL logs
  if [kubernetes][container][name] =~ /postgres/ {
    grok {
      match => { "message" => "%{POSTGRESQL}" }
    }
  }
}

output {
  elasticsearch {
    hosts => ["elasticsearch:9200"]
    index => "logstash-%{[kubernetes][namespace]}-%{+YYYY.MM.dd}"
    user => "elastic"
    password => "${ELASTICSEARCH_PASSWORD}"
  }
  
  # Send errors to dead letter queue
  if "_grokparsefailure" in [tags] {
    elasticsearch {
      hosts => ["elasticsearch:9200"]
      index => "logstash-failures-%{+YYYY.MM.dd}"
      user => "elastic"
      password => "${ELASTICSEARCH_PASSWORD}"
    }
  }
}
```

## AlertManager Configuration

### Main Configuration (alertmanager/alertmanager.yml)
```yaml
global:
  smtp_smarthost: 'smtp.gmail.com:587'
  smtp_from: 'alerts@ecommerce.com'
  smtp_auth_username: 'alerts@ecommerce.com'
  smtp_auth_password: 'your-app-password'

route:
  group_by: ['alertname', 'cluster', 'service']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'web.hook'
  routes:
    - match:
        severity: critical
      receiver: 'critical-alerts'
      group_wait: 5s
      repeat_interval: 30m
    
    - match:
        alertname: 'PaymentServiceDown'
      receiver: 'payment-team'
      group_wait: 1s
      repeat_interval: 5m
    
    - match:
        alertname: 'OrderProcessingFailure'
      receiver: 'order-team'
      group_wait: 1s
      repeat_interval: 5m

receivers:
  - name: 'web.hook'
    webhook_configs:
      - url: 'http://webhook-service:8080/alerts'
        send_resolved: true

  - name: 'critical-alerts'
    email_configs:
      - to: 'oncall@ecommerce.com'
        subject: 'CRITICAL: {{ .GroupLabels.alertname }}'
        body: |
          {{ range .Alerts }}
          Alert: {{ .Annotations.summary }}
          Description: {{ .Annotations.description }}
          Labels: {{ range .Labels.SortedPairs }}{{ .Name }}={{ .Value }} {{ end }}
          {{ end }}
    slack_configs:
      - api_url: 'https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK'
        channel: '#critical-alerts'
        title: 'Critical Alert: {{ .GroupLabels.alertname }}'
        text: '{{ range .Alerts }}{{ .Annotations.description }}{{ end }}'

  - name: 'payment-team'
    email_configs:
      - to: 'payment-team@ecommerce.com'
        subject: 'Payment Service Alert: {{ .GroupLabels.alertname }}'
    pagerduty_configs:
      - service_key: 'your-pagerduty-service-key'
        description: 'Payment Service Alert: {{ .GroupLabels.alertname }}'

  - name: 'order-team'
    email_configs:
      - to: 'order-team@ecommerce.com'
        subject: 'Order Service Alert: {{ .GroupLabels.alertname }}'
    pagerduty_configs:
      - service_key: 'your-pagerduty-service-key'
        description: 'Order Service Alert: {{ .GroupLabels.alertname }}'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'cluster', 'service']
```

## Deployment Scripts

### Deploy Monitoring Stack (scripts/deploy-monitoring.sh)
```bash
#!/bin/bash

set -e

NAMESPACE=${1:-monitoring}
ENVIRONMENT=${2:-production}

echo "🚀 Deploying monitoring stack to namespace: $NAMESPACE"

# Create namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Deploy Prometheus
echo "📊 Deploying Prometheus..."
kubectl apply -f prometheus/ -n $NAMESPACE

# Deploy Grafana
echo "📈 Deploying Grafana..."
kubectl apply -f grafana/ -n $NAMESPACE

# Deploy Jaeger
echo "🔍 Deploying Jaeger..."
kubectl apply -f jaeger/jaeger-$ENVIRONMENT.yml -n $NAMESPACE

# Deploy ELK Stack
echo "📋 Deploying ELK Stack..."
kubectl apply -f elasticsearch/ -n $NAMESPACE
kubectl apply -f logstash/ -n $NAMESPACE
kubectl apply -f kibana/ -n $NAMESPACE

# Deploy AlertManager
echo "🚨 Deploying AlertManager..."
kubectl apply -f alertmanager/ -n $NAMESPACE

echo "✅ Monitoring stack deployed successfully!"
echo ""
echo "🌐 Access URLs (after port-forwarding):"
echo "  Prometheus: http://localhost:9090"
echo "  Grafana: http://localhost:3000"
echo "  Jaeger: http://localhost:16686"
echo "  Kibana: http://localhost:5601"
echo "  AlertManager: http://localhost:9093"
```

This comprehensive monitoring configuration provides full observability for the e-commerce microservices platform with proper alerting, dashboards, and log aggregation.