# 👁️ Observability Architecture

**Purpose**: Monitoring, logging, tracing, and observability patterns for the microservices platform  
**Navigation**: [← Back to Architecture](README.md) | [Performance Architecture →](performance-architecture.md)

---

## 📋 Overview

This document describes the observability architecture of our microservices platform, including monitoring, logging, tracing, and alerting strategies. The observability stack provides comprehensive visibility into system health, performance, and business metrics.

---

## 🏗️ Observability Stack Architecture

### **Three Pillars of Observability**

```yaml
# Observability Components
observability_stack:
  metrics:
    collection: Prometheus
    visualization: Grafana
    alerting: AlertManager
    retention: 15 days
    
  logs:
    collection: Loki
    aggregation: Promtail
    visualization: Grafana
    retention: 30 days
    
  tracing:
    collection: Jaeger
    instrumentation: OpenTelemetry
    visualization: Jaeger UI
    retention: 7 days
```

### **Observability Architecture Diagram**

```
┌─────────────────────────────────────────────────────────────┐
│                    Applications                             │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Service   │  │   Service   │  │   Service   │         │
│  │     A       │  │     B       │  │     C       │         │
│  │             │  │             │  │             │         │
│  │ ┌─────────┐ │  │ ┌─────────┐ │  │ ┌─────────┐ │         │
│  │ │Metrics  │ │  │ │Metrics  │ │  │ │Metrics  │ │         │
│  │ │Logs     │ │  │ │Logs     │ │  │ │Logs     │ │         │
│  │ │Traces   │ │  │ │Traces   │ │  │ │Traces   │ │         │
│  │ └─────────┘ │  │ └─────────┘ │  │ └─────────┘ │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Collection Layer                          │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Prometheus  │  │   Promtail  │  │ OpenTelemetry│         │
│  │  Scrape     │  │   Agents    │  │   Collector  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Storage & Processing                      │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │ Prometheus  │  │     Loki    │  │   Jaeger    │         │
│  │   TSDB      │  │   Storage   │  │   Storage   │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌─────────────────────────────────────────────────────────────┐
│                   Visualization & Alerting                 │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Grafana   │  │AlertManager │  │  Jaeger UI  │         │
│  │ Dashboards  │  │  Alerts     │  │   Traces    │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
└─────────────────────────────────────────────────────────────┘
```

---

## 📊 Metrics Architecture

### **Prometheus Configuration**

```yaml
# Prometheus Server Configuration
prometheus:
  version: 2.47.0
  deployment: StatefulSet
  replicas: 2
  
  resources:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
      
  storage:
    size: 200Gi
    storage_class: gp3
    retention: 15 days
    
  configuration:
    global:
      scrape_interval: 15s
      evaluation_interval: 15s
      
    rule_files:
      - "/etc/prometheus/rules/*.yml"
      
    alerting:
      alertmanagers:
        - static_configs:
            - targets:
              - alertmanager:9093
              
    scrape_configs:
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
```

### **Custom Metrics**

```go
// Custom Metrics Implementation
package metrics

import (
    "github.com/prometheus/client_golang/prometheus"
    "github.com/prometheus/client_golang/prometheus/promauto"
)

var (
    // Business Metrics
    OrderTotal = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name: "order_total_amount",
        Help: "Total amount of orders",
        Buckets: []float64{10, 25, 50, 100, 250, 500, 1000, 2500, 5000, 10000},
    }, []string{"currency", "customer_type"})

    OrderProcessingDuration = promauto.NewHistogramVec(prometheus.HistogramOpts{
        Name: "order_processing_duration_seconds",
        Help: "Time spent processing orders",
        Buckets: []float64{0.1, 0.5, 1, 2, 5, 10, 30, 60, 120, 300},
    }, []string{"stage", "status"})

    // Technical Metrics
    DatabaseConnections = promauto.NewGauge(prometheus.GaugeOpts{
        Name: "database_connections_active",
        Help: "Number of active database connections",
    })

    CacheHitRate = promauto.NewGaugeVec(prometheus.GaugeOpts{
        Name: "cache_hit_rate",
        Help: "Cache hit rate percentage",
    }, []string{"cache_type"})
)

// Metric Recording Functions
func RecordOrderCreated(total float64, currency, customerType string) {
    OrderTotal.WithLabelValues(currency, customerType).Observe(total)
}

func RecordOrderProcessingStage(stage, status string, duration float64) {
    OrderProcessingDuration.WithLabelValues(stage, status).Observe(duration)
}
```

### **Service Metrics**

```yaml
# Service-Level Metrics Configuration
service_metrics:
  checkout_service:
    http_requests_total:
      labels: [method, endpoint, status]
      
    http_request_duration_seconds:
      labels: [method, endpoint]
      buckets: [0.1, 0.5, 1, 2, 5]
      
    checkout_started_total:
      labels: [customer_type, payment_method]
      
    checkout_completed_total:
      labels: [customer_type, payment_method, status]
      
    checkout_duration_seconds:
      labels: [stage]
      buckets: [1, 5, 10, 30, 60, 120]
      
  order_service:
    order_created_total:
      labels: [customer_type, order_type]
      
    order_processing_duration_seconds:
      labels: [stage]
      buckets: [1, 5, 10, 30, 60]
      
    order_status_changes_total:
      labels: [from_status, to_status]
```

---

## 📝 Logging Architecture

### **Loki Configuration**

```yaml
# Loki Server Configuration
loki:
  version: 2.9.0
  deployment: StatefulSet
  replicas: 3
  
  resources:
    requests:
      cpu: "1"
      memory: 4Gi
    limits:
      cpu: "2"
      memory: 8Gi
      
  storage:
    size: 200Gi
    storage_class: gp3
    retention: 30 days
    
  configuration:
    auth_enabled: false
    
    server:
      http_listen_port: 3100
      grpc_listen_port: 9096
      
    ingester:
      lifecycler:
        address: 127.0.0.1
        ring:
          kvstore:
            store: consul
            consul:
              host: consul:8500
          replication_factor: 3
              
    schema_config:
      configs:
        - from: 2020-10-24
          store: boltdb-shipper
          object_store: s3
          schema: v11
          index:
            prefix: index_
            period: 24h
            
    storage_config:
      boltdb_shipper:
        active_index_directory: /loki/boltdb-shipper-active
        cache_location: /loki/boltdb-shipper-cache
        shared_store: s3
      s3:
        s3: null
        bucket_names: loki-chunks
        endpoint: s3.amazonaws.com
```

### **Promtail Configuration**

```yaml
# Promtail Agent Configuration
promtail:
  version: 2.9.0
  deployment: DaemonSet
  
  resources:
    requests:
      cpu: "100m"
      memory: 128Mi
    limits:
      cpu: "500m"
      memory: 512Mi
      
  configuration:
    server:
      http_listen_port: 3101
      grpc_listen_port: 9080
      
    positions:
      filename: /tmp/positions.yaml
      
    clients:
      - url: http://loki:3100/loki/api/v1/push
        
    scrape_configs:
      - job_name: containers
        static_configs:
          - targets:
              - localhost
            labels:
              job: containerlogs
              __path__: /var/log/containers/*log
              
        pipeline_stages:
          - json:
              expressions:
                output: log
                stream: stream
                attrs:
          - json:
              expressions:
                level:
                timestamp:
                trace_id:
                span_id:
              source: attrs
          - timestamp:
              format: RFC3339Nano
              source: timestamp
          - labels:
              level:
              trace_id:
              span_id:
          - output:
              source: output
```

### **Structured Logging**

```go
// Structured Logging Implementation
package logging

import (
    "context"
    "time"
    
    "github.com/go-kratos/kratos/v2/log"
    "go.opentelemetry.io/otel/trace"
)

type Logger struct {
    log *log.Helper
}

func NewLogger(logger log.Logger) *Logger {
    return &Logger{
        log: log.NewHelper(logger),
    }
}

func (l *Logger) WithContext(ctx context.Context) *Logger {
    span := trace.SpanFromContext(ctx)
    if span.SpanContext().IsValid() {
        return &Logger{
            log: l.log.WithFields(
                log.Field("trace_id", span.SpanContext().TraceID().String()),
                log.Field("span_id", span.SpanContext().SpanID().String()),
            ),
        }
    }
    return l
}

func (l *Logger) Info(ctx context.Context, msg string, fields ...log.Field) {
    l.WithContext(ctx).log.Infow(msg, fields...)
}

func (l *Logger) Error(ctx context.Context, msg string, err error, fields ...log.Field) {
    allFields := append([]log.Field{log.Field("error", err.Error())}, fields...)
    l.WithContext(ctx).log.Errorw(msg, allFields...)
}

func (l *Logger) OrderEvent(ctx context.Context, event string, orderID string, fields ...log.Field) {
    allFields := append([]log.Field{
        log.Field("event_type", "order"),
        log.Field("event_name", event),
        log.Field("order_id", orderID),
        log.Field("timestamp", time.Now().UTC()),
    }, fields...)
    l.WithContext(ctx).log.Infow("Order event", allFields...)
}

// Usage Example
func (uc *UseCase) CreateOrder(ctx context.Context, req *CreateOrderRequest) (*Order, error) {
    logger.Info(ctx, "Creating order", 
        log.Field("customer_id", req.CustomerID),
        log.Field("items_count", len(req.Items)),
    )
    
    order, err := uc.orderRepo.Create(ctx, req)
    if err != nil {
        logger.Error(ctx, "Failed to create order", err,
            log.Field("customer_id", req.CustomerID),
        )
        return nil, err
    }
    
    logger.OrderEvent(ctx, "order_created", order.ID,
        log.Field("total_amount", order.TotalAmount),
        log.Field("currency", order.Currency),
    )
    
    return order, nil
}
```

---

## 🔍 Tracing Architecture

### **Jaeger Configuration**

```yaml
# Jaeger Configuration
jaeger:
  version: 1.50
  deployment: Production
  
  collector:
    replicas: 2
    resources:
      requests:
        cpu: "500m"
        memory: 1Gi
      limits:
        cpu: "1"
        memory: 2Gi
        
    configuration:
      collector:
        zipkin:
          host_port: 0.0.0.0:9411
        otlp:
          grpc:
            host_port: 0.0.0.0:4317
          http:
            host_port: 0.0.0.0:4318
            
  query:
    replicas: 2
    resources:
      requests:
        cpu: "500m"
        memory: 1Gi
      limits:
        cpu: "1"
        memory: 2Gi
        
    configuration:
      query:
        base_path: /
        
  agent:
    daemonset: true
    configuration:
      agent:
        reporter:
          grpc:
            host_port: jaeger-collector:14250
```

### **OpenTelemetry Configuration**

```go
// OpenTelemetry Setup
package tracing

import (
    "context"
    "fmt"
    "time"
    
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/exporters/jaeger"
    "go.opentelemetry.io/otel/propagation"
    "go.opentelemetry.io/otel/sdk/resource"
    "go.opentelemetry.io/otel/sdk/trace"
    semconv "go.opentelemetry.io/otel/semconv/v1.4.0"
)

func InitTracer(serviceName, jaegerEndpoint string) (*trace.TracerProvider, error) {
    // Create Jaeger exporter
    exp, err := jaeger.New(jaeger.WithCollectorEndpoint(jaeger.WithEndpoint(jaegerEndpoint)))
    if err != nil {
        return nil, fmt.Errorf("failed to create Jaeger exporter: %w", err)
    }

    // Create tracer provider
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exp),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String(serviceName),
            semconv.ServiceVersionKey.String("1.0.0"),
        )),
    )

    // Register as global tracer provider
    otel.SetTracerProvider(tp)
    otel.SetTextMapPropagator(propagation.NewCompositeTextMapPropagator(
        propagation.TraceContext{},
        propagation.Baggage{},
    ))

    return tp, nil
}

// Tracing Helper Functions
func StartSpan(ctx context.Context, name string) (context.Context, trace.Span) {
    return otel.Tracer("").Start(ctx, name)
}

func AddSpanAttributes(span trace.Span, attributes map[string]interface{}) {
    for key, value := range attributes {
        span.SetAttributes(attribute.String(key, fmt.Sprintf("%v", value)))
    }
}

func AddSpanEvent(span trace.Span, name string, attributes map[string]interface{}) {
    var attrs []trace.EventOption
    for key, value := range attributes {
        attrs = append(attrs, trace.WithAttributes(attribute.String(key, fmt.Sprintf("%v", value))))
    }
    span.AddEvent(name, attrs...)
}
```

### **Distributed Tracing Implementation**

```go
// Service Tracing Implementation
package service

import (
    "context"
    "time"
    
    "go.opentelemetry.io/otel"
    "go.opentelemetry.io/otel/trace"
)

func (s *CheckoutService) StartCheckout(ctx context.Context, req *StartCheckoutRequest) (*StartCheckoutResponse, error) {
    // Start span for checkout process
    ctx, span := otel.Tracer("checkout-service").Start(ctx, "StartCheckout")
    defer span.End()
    
    // Add span attributes
    span.SetAttributes(
        attribute.String("customer_id", req.CustomerID),
        attribute.String("cart_id", req.CartID),
        attribute.Int("items_count", len(req.Items)),
    )
    
    // Log checkout start
    span.AddEvent("checkout_started", trace.WithAttributes(
        attribute.String("timestamp", time.Now().UTC().Format(time.RFC3339)),
    ))
    
    // Process checkout
    response, err := s.processCheckout(ctx, req)
    if err != nil {
        span.SetAttributes(
            attribute.String("error", err.Error()),
            attribute.Bool("success", false),
        )
        span.AddEvent("checkout_failed", trace.WithAttributes(
            attribute.String("error_message", err.Error()),
        ))
        return nil, err
    }
    
    // Log checkout completion
    span.SetAttributes(
        attribute.String("checkout_id", response.CheckoutID),
        attribute.Bool("success", true),
    )
    span.AddEvent("checkout_completed", trace.WithAttributes(
        attribute.String("checkout_id", response.CheckoutID),
    ))
    
    return response, nil
}

func (s *CheckoutService) processCheckout(ctx context.Context, req *StartCheckoutRequest) (*StartCheckoutResponse, error) {
    // Start child span for validation
    ctx, validationSpan := otel.Tracer("checkout-service").Start(ctx, "ValidateCheckout")
    
    if err := s.validateRequest(ctx, req); err != nil {
        validationSpan.SetAttributes(attribute.String("error", err.Error()))
        validationSpan.End()
        return nil, err
    }
    validationSpan.End()
    
    // Start child span for order creation
    ctx, orderSpan := otel.Tracer("checkout-service").Start(ctx, "CreateOrder")
    
    order, err := s.orderService.CreateOrder(ctx, &orderpb.CreateOrderRequest{
        CustomerID: req.CustomerID,
        Items:      req.Items,
    })
    if err != nil {
        orderSpan.SetAttributes(attribute.String("error", err.Error()))
        orderSpan.End()
        return nil, err
    }
    orderSpan.End()
    
    return &StartCheckoutResponse{
        CheckoutID: order.OrderID,
        Status:     "pending",
    }, nil
}
```

---

## 🚨 Alerting Architecture

### **AlertManager Configuration**

```yaml
# AlertManager Configuration
alertmanager:
  version: 0.26.0
  deployment: StatefulSet
  replicas: 3
  
  resources:
    requests:
      cpu: "100m"
      memory: 256Mi
    limits:
      cpu: "500m"
      memory: 512Mi
      
  storage:
    size: 10Gi
    storage_class: gp3
    
  configuration:
    global:
      smtp_smarthost: 'smtp.example.com:587'
      smtp_from: 'alerts@example.com'
      
    route:
      group_by: ['alertname']
      group_wait: 10s
      group_interval: 10s
      repeat_interval: 1h
      receiver: 'web.hook'
      routes:
        - match:
            severity: critical
          receiver: 'critical-alerts'
        - match:
            severity: warning
          receiver: 'warning-alerts'
          
    receivers:
      - name: 'web.hook'
        webhook_configs:
          - url: 'http://127.0.0.1:5001/'
            
      - name: 'critical-alerts'
        email_configs:
          - to: 'oncall@example.com'
            subject: '[CRITICAL] {{ .GroupLabels.alertname }}'
            body: |
              {{ range .Alerts }}
              Alert: {{ .Annotations.summary }}
              Description: {{ .Annotations.description }}
              {{ end }}
        slack_configs:
          - api_url: 'https://hooks.slack.com/services/...'
            channel: '#alerts'
            title: 'Critical Alert'
            text: '{{ range .Alerts }}{{ .Annotations.summary }}{{ end }}'
            
      - name: 'warning-alerts'
        email_configs:
          - to: 'team@example.com'
            subject: '[WARNING] {{ .GroupLabels.alertname }}'
```

### **Alerting Rules**

```yaml
# Infrastructure Alerting Rules
groups:
  - name: infrastructure.rules
    rules:
      - alert: NodeDown
        expr: up{job="node-exporter"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "Node {{ $labels.instance }} has been down for more than 1 minute"
          
      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (irate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes"
          
      - alert: HighMemoryUsage
        expr: (node_memory_MemTotal_bytes - node_memory_MemAvailable_bytes) / node_memory_MemTotal_bytes * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes"
          
  - name: application.rules
    rules:
      - alert: ServiceDown
        expr: up{job="kubernetes-pods"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Service {{ $labels.pod }} is down"
          description: "Service {{ $labels.pod }} has been down for more than 1 minute"
          
      - alert: HighErrorRate
        expr: rate(http_requests_total{status=~"5.."}[5m]) / rate(http_requests_total[5m]) > 0.05
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High error rate for {{ $labels.service }}"
          description: "Error rate is above 5% for more than 5 minutes"
          
      - alert: HighLatency
        expr: histogram_quantile(0.95, rate(http_request_duration_seconds_bucket[5m])) > 1
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High latency for {{ $labels.service }}"
          description: "95th percentile latency is above 1 second for more than 5 minutes"
```

---

## 📈 Business Metrics

### **Business KPIs**

```yaml
# Business Metrics Definition
business_metrics:
  order_metrics:
    - name: order_total_amount
      type: histogram
      description: "Total amount of orders"
      labels: [currency, customer_type, payment_method]
      
    - name: order_processing_duration
      type: histogram
      description: "Time to process orders"
      labels: [stage, status]
      
    - name: orders_created_total
      type: counter
      description: "Total number of orders created"
      labels: [customer_type, order_type]
      
  customer_metrics:
    - name: customer_registration_total
      type: counter
      description: "Total customer registrations"
      labels: [registration_source]
      
    - name: active_customers_total
      type: gauge
      description: "Number of active customers"
      labels: [time_period]
      
  payment_metrics:
    - name: payment_success_rate
      type: gauge
      description: "Payment success rate"
      labels: [payment_method, currency]
      
    - name: payment_amount_total
      type: counter
      description: "Total payment amount processed"
      labels: [payment_method, currency, status]
```

### **Business Dashboard Configuration**

```yaml
# Grafana Business Dashboard
dashboard:
  title: "Business Metrics Dashboard"
  panels:
    - title: "Order Volume"
      type: graph
      targets:
        - expr: sum(rate(orders_created_total[5m])) by (customer_type)
          legendFormat: "{{ customer_type }}"
          
    - title: "Order Value Distribution"
      type: heatmap
      targets:
        - expr: sum(rate(order_total_amount_bucket[5m])) by (le, currency)
          
    - title: "Payment Success Rate"
      type: stat
      targets:
        - expr: sum(rate(payment_amount_total{status="success"}[5m])) / sum(rate(payment_amount_total[5m])) * 100
          
    - title: "Order Processing Time"
      type: graph
      targets:
        - expr: histogram_quantile(0.95, rate(order_processing_duration_seconds_bucket[5m]))
          legendFormat: "95th percentile"
        - expr: histogram_quantile(0.50, rate(order_processing_duration_seconds_bucket[5m]))
          legendFormat: "50th percentile"
```

---

## 🔧 Observability Best Practices

### **Metrics Best Practices**

1. **Metric Design**
   - Use consistent naming conventions
   - Include relevant labels
   - Choose appropriate metric types
   - Document metric definitions

2. **Performance Considerations**
   - Limit number of time series
   - Use appropriate retention periods
   - Optimize scrape intervals
   - Monitor Prometheus performance

3. **Alerting Strategy**
   - Define clear alert thresholds
   - Use appropriate severity levels
   - Include actionable alert messages
   - Implement proper escalation

### **Logging Best Practices**

1. **Log Structure**
   - Use structured logging (JSON)
   - Include correlation IDs
   - Add relevant context
   - Use consistent log levels

2. **Log Management**
   - Implement log rotation
   - Use appropriate retention
   - Monitor log storage costs
   - Implement log sampling

3. **Security Considerations**
   - Avoid logging sensitive data
   - Implement log access controls
   - Use encrypted log storage
   - Audit log access

### **Tracing Best Practices**

1. **Span Design**
   - Use meaningful span names
   - Add relevant attributes
   - Include important events
   - Implement proper span boundaries

2. **Performance Impact**
   - Use sampling strategies
   - Optimize trace collection
   - Monitor tracing overhead
   - Use appropriate retention

3. **Trace Analysis**
   - Implement trace correlation
   - Use trace aggregation
   - Monitor trace quality
   - Implement trace alerts

---

## 🔗 Related Documentation

- **[Performance Architecture](performance-architecture.md)** - Performance monitoring and optimization
- **[Security Architecture](security-architecture.md)** - Security monitoring and compliance
- **[Infrastructure Architecture](infrastructure-architecture.md)** - Infrastructure components and setup
- **[Deployment Architecture](deployment-architecture.md)** - Deployment patterns and strategies
- **[Operations Guide](../06-operations/README.md)** - Operational procedures and runbooks

---

**Last Updated**: February 1, 2026  
**Review Cycle**: Quarterly  
**Maintained By**: Observability Team
