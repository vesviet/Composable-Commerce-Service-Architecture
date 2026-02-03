ies
CREATE PUBLICATION products_pub FOR TABLE products, categories, attributes;

-- Index optimization
CREATE INDEX CONCURRENTLY idx_products_category_status 
ON products (category_id, status) 
WHERE status = 'active';

CREATE INDEX CONCURRENTLY idx_orders_customer_created 
ON orders (customer_id, created_at DESC);

-- Partitioning for large tables
CREATE TABLE orders_2026 PARTITION OF orders 
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');
```

### **Connection Pool Management**
Optimized database connections:

```go
// Database connection pool configuration
type DatabasePool struct {
    WriteDB *sql.DB // Primary database
    ReadDB  *sql.DB // Read replica
    config  *PoolConfig
}

type PoolConfig struct {
    MaxOpenConns    int           `yaml:"max_open_conns"`
    MaxIdleConns    int           `yaml:"max_idle_conns"`
    ConnMaxLifetime time.Duration `yaml:"conn_max_lifetime"`
    ConnMaxIdleTime time.Duration `yaml:"conn_max_idle_time"`
}

func NewDatabasePool(config *PoolConfig) (*DatabasePool, error) {
    // Configure write database
    writeDB, err := sql.Open("postgres", config.WriteDBURL)
    if err != nil {
        return nil, err
    }
    
    writeDB.SetMaxOpenConns(config.MaxOpenConns)
    writeDB.SetMaxIdleConns(config.MaxIdleConns)
    writeDB.SetConnMaxLifetime(config.ConnMaxLifetime)
    writeDB.SetConnMaxIdleTime(config.ConnMaxIdleTime)
    
    // Configure read database
    readDB, err := sql.Open("postgres", config.ReadDBURL)
    if err != nil {
        return nil, err
    }
    
    readDB.SetMaxOpenConns(config.MaxOpenConns * 2) // More connections for reads
    readDB.SetMaxIdleConns(config.MaxIdleConns * 2)
    readDB.SetConnMaxLifetime(config.ConnMaxLifetime)
    readDB.SetConnMaxIdleTime(config.ConnMaxIdleTime)
    
    return &DatabasePool{
        WriteDB: writeDB,
        ReadDB:  readDB,
        config:  config,
    }, nil
}

// Smart query routing
func (p *DatabasePool) Query(ctx context.Context, query string, args ...interface{}) (*sql.Rows, error) {
    // Route read queries to read replica
    if isReadQuery(query) {
        return p.ReadDB.QueryContext(ctx, query, args...)
    }
    
    // Route write queries to primary
    return p.WriteDB.QueryContext(ctx, query, args...)
}
```

---

## 📊 **Scalability Patterns**

### **Horizontal Pod Autoscaling (HPA)**
Automatic scaling based on metrics:

```yaml
# HPA configuration for order service
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: order-service-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: order-service
  minReplicas: 3
  maxReplicas: 20
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70
  - type: Resource
    resource:
      name: memory
      target:
        type: Utilization
        averageUtilization: 80
  - type: Pods
    pods:
      metric:
        name: http_requests_per_second
      target:
        type: AverageValue
        averageValue: "100"
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 15
    scaleDown:
      stabilizationWindowSeconds: 300
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### **Vertical Pod Autoscaling (VPA)**
Resource optimization for pods:

```yaml
# VPA configuration
apiVersion: autoscaling.k8s.io/v1
kind: VerticalPodAutoscaler
metadata:
  name: catalog-service-vpa
spec:
  targetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: catalog-service
  updatePolicy:
    updateMode: "Auto"
  resourcePolicy:
    containerPolicies:
    - containerName: catalog-service
      minAllowed:
        cpu: 100m
        memory: 128Mi
      maxAllowed:
        cpu: 2
        memory: 4Gi
      controlledResources: ["cpu", "memory"]
```

### **Load Balancing Strategies**
Intelligent traffic distribution:

```go
// Custom load balancer with health checks
type LoadBalancer struct {
    backends []Backend
    strategy LoadBalancingStrategy
    health   HealthChecker
}

type Backend struct {
    URL      string
    Weight   int
    Healthy  bool
    Latency  time.Duration
    ActiveConns int
}

// Weighted round-robin with health checks
func (lb *LoadBalancer) SelectBackend(ctx context.Context) (*Backend, error) {
    healthyBackends := lb.getHealthyBackends()
    if len(healthyBackends) == 0 {
        return nil, ErrNoHealthyBackends
    }
    
    switch lb.strategy {
    case WeightedRoundRobin:
        return lb.weightedRoundRobin(healthyBackends), nil
    case LeastConnections:
        return lb.leastConnections(healthyBackends), nil
    case LatencyBased:
        return lb.latencyBased(healthyBackends), nil
    default:
        return lb.roundRobin(healthyBackends), nil
    }
}

// Latency-based routing for optimal performance
func (lb *LoadBalancer) latencyBased(backends []Backend) *Backend {
    var best *Backend
    var minLatency time.Duration = time.Hour
    
    for _, backend := range backends {
        if backend.Latency < minLatency {
            minLatency = backend.Latency
            best = &backend
        }
    }
    
    return best
}
```

---

## 🔍 **Performance Monitoring**

### **Application Performance Monitoring (APM)**
Comprehensive performance tracking:

```go
// Performance metrics collection
type PerformanceMetrics struct {
    RequestDuration   *prometheus.HistogramVec
    RequestCount      *prometheus.CounterVec
    ActiveConnections *prometheus.GaugeVec
    DatabaseLatency   *prometheus.HistogramVec
    CacheHitRate      *prometheus.GaugeVec
}

func NewPerformanceMetrics() *PerformanceMetrics {
    return &PerformanceMetrics{
        RequestDuration: prometheus.NewHistogramVec(
            prometheus.HistogramOpts{
                Name:    "http_request_duration_seconds",
                Help:    "HTTP request duration in seconds",
                Buckets: prometheus.DefBuckets,
            },
            []string{"method", "endpoint", "status"},
        ),
        RequestCount: prometheus.NewCounterVec(
            prometheus.CounterOpts{
                Name: "http_requests_total",
                Help: "Total number of HTTP requests",
            },
            []string{"method", "endpoint", "status"},
        ),
        ActiveConnections: prometheus.NewGaugeVec(
            prometheus.GaugeOpts{
                Name: "active_connections",
                Help: "Number of active connections",
            },
            []string{"service"},
        ),
        DatabaseLatency: prometheus.NewHistogramVec(
            prometheus.HistogramOpts{
                Name:    "database_query_duration_seconds",
                Help:    "Database query duration in seconds",
                Buckets: []float64{0.001, 0.005, 0.01, 0.05, 0.1, 0.5, 1.0},
            },
            []string{"operation", "table"},
        ),
        CacheHitRate: prometheus.NewGaugeVec(
            prometheus.GaugeOpts{
                Name: "cache_hit_rate",
                Help: "Cache hit rate percentage",
            },
            []string{"cache_type"},
        ),
    }
}

// Performance middleware
func (m *PerformanceMetrics) HTTPMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        start := time.Now()
        
        c.Next()
        
        duration := time.Since(start)
        status := strconv.Itoa(c.Writer.Status())
        
        m.RequestDuration.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
            status,
        ).Observe(duration.Seconds())
        
        m.RequestCount.WithLabelValues(
            c.Request.Method,
            c.FullPath(),
            status,
        ).Inc()
    }
}
```

### **Distributed Tracing**
End-to-end request tracing with OpenTelemetry:

```go
// Tracing configuration
func InitTracing(serviceName string) (*trace.TracerProvider, error) {
    exporter, err := jaeger.New(jaeger.WithCollectorEndpoint(
        jaeger.WithEndpoint("http://jaeger:14268/api/traces"),
    ))
    if err != nil {
        return nil, err
    }
    
    tp := trace.NewTracerProvider(
        trace.WithBatcher(exporter),
        trace.WithResource(resource.NewWithAttributes(
            semconv.SchemaURL,
            semconv.ServiceNameKey.String(serviceName),
            semconv.ServiceVersionKey.String("1.0.0"),
        )),
        trace.WithSampler(trace.TraceIDRatioBased(0.1)), // 10% sampling
    )
    
    otel.SetTracerProvider(tp)
    return tp, nil
}

// Tracing middleware for performance analysis
func TracingMiddleware(serviceName string) gin.HandlerFunc {
    tracer := otel.Tracer(serviceName)
    
    return func(c *gin.Context) {
        ctx, span := tracer.Start(c.Request.Context(), c.FullPath())
        defer span.End()
        
        // Add request attributes
        span.SetAttributes(
            attribute.String("http.method", c.Request.Method),
            attribute.String("http.url", c.Request.URL.String()),
            attribute.String("user.id", c.GetString("user_id")),
        )
        
        c.Request = c.Request.WithContext(ctx)
        c.Next()
        
        // Add response attributes
        span.SetAttributes(
            attribute.Int("http.status_code", c.Writer.Status()),
            attribute.Int("http.response_size", c.Writer.Size()),
        )
        
        if c.Writer.Status() >= 400 {
            span.SetStatus(codes.Error, "HTTP Error")
        }
    }
}
```

### **Real User Monitoring (RUM)**
Frontend performance monitoring:

```javascript
// Frontend performance monitoring
class PerformanceMonitor {
    constructor(apiEndpoint) {
        this.apiEndpoint = apiEndpoint;
        this.metrics = {
            pageLoad: {},
            userInteractions: [],
            apiCalls: []
        };
        
        this.initializeMonitoring();
    }
    
    initializeMonitoring() {
        // Core Web Vitals
        this.measureCoreWebVitals();
        
        // API call monitoring
        this.monitorAPIRequests();
        
        // User interaction monitoring
        this.monitorUserInteractions();
        
        // Send metrics periodically
        setInterval(() => this.sendMetrics(), 30000);
    }
    
    measureCoreWebVitals() {
        // Largest Contentful Paint (LCP)
        new PerformanceObserver((list) => {
            const entries = list.getEntries();
            const lastEntry = entries[entries.length - 1];
            this.metrics.pageLoad.lcp = lastEntry.startTime;
        }).observe({ entryTypes: ['largest-contentful-paint'] });
        
        // First Input Delay (FID)
        new PerformanceObserver((list) => {
            const entries = list.getEntries();
            entries.forEach((entry) => {
                this.metrics.pageLoad.fid = entry.processingStart - entry.startTime;
            });
        }).observe({ entryTypes: ['first-input'] });
        
        // Cumulative Layout Shift (CLS)
        let clsValue = 0;
        new PerformanceObserver((list) => {
            const entries = list.getEntries();
            entries.forEach((entry) => {
                if (!entry.hadRecentInput) {
                    clsValue += entry.value;
                }
            });
            this.metrics.pageLoad.cls = clsValue;
        }).observe({ entryTypes: ['layout-shift'] });
    }
    
    monitorAPIRequests() {
        const originalFetch = window.fetch;
        window.fetch = async (...args) => {
            const start = performance.now();
            const response = await originalFetch(...args);
            const duration = performance.now() - start;
            
            this.metrics.apiCalls.push({
                url: args[0],
                method: args[1]?.method || 'GET',
                status: response.status,
                duration: duration,
                timestamp: Date.now()
            });
            
            return response;
        };
    }
}
```

---

## 🚀 **Performance Optimization Techniques**

### **Database Query Optimization**
Advanced query optimization strategies:

```sql
-- Query optimization examples
-- Use covering indexes
CREATE INDEX idx_orders_covering 
ON orders (customer_id, status, created_at) 
INCLUDE (total_amount, shipping_address);

-- Optimize complex queries with CTEs
WITH recent_orders AS (
    SELECT customer_id, COUNT(*) as order_count
    FROM orders 
    WHERE created_at >= NOW() - INTERVAL '30 days'
    GROUP BY customer_id
),
high_value_customers AS (
    SELECT customer_id
    FROM recent_orders
    WHERE order_count >= 5
)
SELECT c.*, ro.order_count
FROM customers c
JOIN high_value_customers hvc ON c.id = hvc.customer_id
JOIN recent_orders ro ON c.id = ro.customer_id;

-- Use partial indexes for better performance
CREATE INDEX idx_active_products 
ON products (category_id, price) 
WHERE status = 'active' AND inventory_count > 0;
```

### **API Response Optimization**
Efficient data serialization and compression:

```go
// Response optimization middleware
func ResponseOptimizationMiddleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Enable compression
        if strings.Contains(c.GetHeader("Accept-Encoding"), "gzip") {
            c.Header("Content-Encoding", "gzip")
            c.Header("Vary", "Accept-Encoding")
        }
        
        // Set cache headers for static content
        if isStaticContent(c.Request.URL.Path) {
            c.Header("Cache-Control", "public, max-age=31536000") // 1 year
            c.Header("ETag", generateETag(c.Request.URL.Path))
        }
        
        c.Next()
    }
}

// Efficient JSON serialization
type OptimizedResponse struct {
    Data interface{} `json:"data"`
    Meta *MetaData   `json:"meta,omitempty"`
}

func (r *OptimizedResponse) MarshalJSON() ([]byte, error) {
    // Use faster JSON library for better performance
    return jsoniter.Marshal(struct {
        Data interface{} `json:"data"`
        Meta *MetaData   `json:"meta,omitempty"`
    }{
        Data: r.Data,
        Meta: r.Meta,
    })
}

// Pagination optimization
type PaginatedResponse struct {
    Items      interface{} `json:"items"`
    Pagination *Pagination `json:"pagination"`
}

type Pagination struct {
    Page       int  `json:"page"`
    PerPage    int  `json:"per_page"`
    Total      int  `json:"total"`
    TotalPages int  `json:"total_pages"`
    HasNext    bool `json:"has_next"`
    HasPrev    bool `json:"has_prev"`
}

// Cursor-based pagination for better performance
func (s *ProductService) ListProductsCursor(ctx context.Context, cursor string, limit int) (*CursorResponse, error) {
    query := `
        SELECT id, name, price, created_at
        FROM products
        WHERE created_at > $1
        ORDER BY created_at ASC
        LIMIT $2
    `
    
    var afterTime time.Time
    if cursor != "" {
        decodedCursor, err := base64.StdEncoding.DecodeString(cursor)
        if err != nil {
            return nil, ErrInvalidCursor
        }
        afterTime, _ = time.Parse(time.RFC3339, string(decodedCursor))
    }
    
    products, err := s.repository.Query(ctx, query, afterTime, limit+1)
    if err != nil {
        return nil, err
    }
    
    hasNext := len(products) > limit
    if hasNext {
        products = products[:limit]
    }
    
    var nextCursor string
    if hasNext && len(products) > 0 {
        lastProduct := products[len(products)-1]
        nextCursor = base64.StdEncoding.EncodeToString(
            []byte(lastProduct.CreatedAt.Format(time.RFC3339)),
        )
    }
    
    return &CursorResponse{
        Items:      products,
        NextCursor: nextCursor,
        HasNext:    hasNext,
    }, nil
}
```

### **Memory Optimization**
Efficient memory usage patterns:

```go
// Object pooling for frequent allocations
var requestPool = sync.Pool{
    New: func() interface{} {
        return &Request{
            Headers: make(map[string]string),
            Body:    make([]byte, 0, 1024),
        }
    },
}

func HandleRequest(w http.ResponseWriter, r *http.Request) {
    // Get object from pool
    req := requestPool.Get().(*Request)
    defer requestPool.Put(req)
    
    // Reset object state
    req.Reset()
    
    // Use the object
    req.ParseRequest(r)
    // ... handle request
}

// Streaming for large datasets
func (s *ProductService) ExportProducts(ctx context.Context, w io.Writer) error {
    encoder := json.NewEncoder(w)
    
    // Stream products in batches
    offset := 0
    batchSize := 1000
    
    for {
        products, err := s.repository.GetProductsBatch(ctx, offset, batchSize)
        if err != nil {
            return err
        }
        
        if len(products) == 0 {
            break
        }
        
        for _, product := range products {
            if err := encoder.Encode(product); err != nil {
                return err
            }
        }
        
        offset += batchSize
        
        // Prevent memory buildup
        if offset%10000 == 0 {
            runtime.GC()
        }
    }
    
    return nil
}
```

---

## 📊 **Performance Testing**

### **Load Testing Strategy**
Comprehensive performance testing approach:

```yaml
# K6 load testing configuration
load_testing:
  scenarios:
    - name: "baseline_load"
      executor: "constant-vus"
      vus: 50
      duration: "10m"
      
    - name: "peak_load"
      executor: "ramping-vus"
      stages:
        - duration: "2m"
          target: 100
        - duration: "5m"
          target: 500
        - duration: "2m"
          target: 1000
        - duration: "5m"
          target: 1000
        - duration: "2m"
          target: 0
          
    - name: "stress_test"
      executor: "ramping-arrival-rate"
      start_rate: 50
      time_unit: "1s"
      pre_allocated_vus: 100
      max_vus: 2000
      stages:
        - duration: "2m"
          target: 100
        - duration: "5m"
          target: 500
        - duration: "2m"
          target: 1000
        - duration: "1m"
          target: 2000
        - duration: "2m"
          target: 0
```

### **Performance Testing Scripts**
Automated performance validation:

```javascript
// K6 performance test script
import http from 'k6/http';
import { check, sleep } from 'k6';
import { Rate, Trend } from 'k6/metrics';

// Custom metrics
const errorRate = new Rate('errors');
const responseTime = new Trend('response_time');

export const options = {
    stages: [
        { duration: '2m', target: 100 },
        { duration: '5m', target: 500 },
        { duration: '2m', target: 0 },
    ],
    thresholds: {
        http_req_duration: ['p(95)<200'], // 95% of requests under 200ms
        http_req_failed: ['rate<0.01'],   // Error rate under 1%
        errors: ['rate<0.01'],
    },
};

export default function() {
    // Test product search
    const searchResponse = http.get('https://api.example.com/products?q=laptop');
    check(searchResponse, {
        'search status is 200': (r) => r.status === 200,
        'search response time < 200ms': (r) => r.timings.duration < 200,
    });
    
    errorRate.add(searchResponse.status !== 200);
    responseTime.add(searchResponse.timings.duration);
    
    // Test order creation
    const orderPayload = {
        items: [{ product_id: '123', quantity: 1 }],
        customer_id: '456',
    };
    
    const orderResponse = http.post(
        'https://api.example.com/orders',
        JSON.stringify(orderPayload),
        { headers: { 'Content-Type': 'application/json' } }
    );
    
    check(orderResponse, {
        'order status is 201': (r) => r.status === 201,
        'order response time < 500ms': (r) => r.timings.duration < 500,
    });
    
    sleep(1);
}
```

---

## 📈 **Performance Dashboards**

### **Grafana Dashboard Configuration**
Comprehensive performance monitoring:

```json
{
  "dashboard": {
    "title": "Microservices Performance Dashboard",
    "panels": [
      {
        "title": "Request Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{service}}"
          }
        ]
      },
      {
        "title": "Response Time P95",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "{{service}} P95"
          }
        ]
      },
      {
        "title": "Error Rate",
        "type": "graph",
        "targets": [
          {
            "expr": "sum(rate(http_requests_total{status=~\"5..\"}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service)",
            "legendFormat": "{{service}} Error Rate"
          }
        ]
      },
      {
        "title": "Database Performance",
        "type": "graph",
        "targets": [
          {
            "expr": "histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le, service))",
            "legendFormat": "{{service}} DB P95"
          }
        ]
      }
    ]
  }
}
```

### **Alert Rules**
Performance-based alerting:

```yaml
# Prometheus alert rules
groups:
- name: performance.rules
  rules:
  - alert: HighResponseTime
    expr: histogram_quantile(0.95, sum(rate(http_request_duration_seconds_bucket[5m])) by (le, service)) > 0.5
    for: 2m
    labels:
      severity: warning
    annotations:
      summary: "High response time detected"
      description: "Service {{ $labels.service }} has P95 response time > 500ms"
      
  - alert: HighErrorRate
    expr: sum(rate(http_requests_total{status=~"5.."}[5m])) by (service) / sum(rate(http_requests_total[5m])) by (service) > 0.01
    for: 1m
    labels:
      severity: critical
    annotations:
      summary: "High error rate detected"
      description: "Service {{ $labels.service }} has error rate > 1%"
      
  - alert: DatabaseSlowQueries
    expr: histogram_quantile(0.95, sum(rate(database_query_duration_seconds_bucket[5m])) by (le, service)) > 0.1
    for: 5m
    labels:
      severity: warning
    annotations:
      summary: "Slow database queries detected"
      description: "Service {{ $labels.service }} has slow database queries (P95 > 100ms)"
```

---

## 🛣️ **Performance Roadmap**

### **Q1 2026 Priorities**
- ✅ Implement comprehensive caching strategy
- ✅ Deploy database read replicas
- ✅ Optimize critical API endpoints
- ✅ Set up performance monitoring dashboards

### **Q2 2026 Goals**
- 🔄 Implement advanced load balancing
- 🔄 Deploy CDN for static assets
- 🔄 Optimize database queries and indexes
- 🔄 Implement response compression

### **Q3 2026 Vision**
- 🎯 Achieve sub-100ms P95 response times
- 🎯 Implement predictive scaling
- 🎯 Deploy edge computing capabilities
- 🎯 Optimize for mobile performance

---

## 🔗 **Related Documentation**

- **[System Overview](system-overview.md)** - Overall system architecture
- **[Microservices Design](microservices-design.md)** - Service design patterns
- **[Operations Monitoring](../06-operations/monitoring/)** - Operational monitoring
- **[Development Performance](../07-development/performance/)** - Development performance guidelines

---

**Last Updated**: January 29, 2026  
**Performance Review**: Weekly performance review  
**Maintained By**: Performance Team & Architecture Team  
**SLA Review**: Monthly SLA assessment