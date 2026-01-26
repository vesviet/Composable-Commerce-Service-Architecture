# Event Consumer Migration Checklist - Step by Step Guide

**Mục đích**: Step-by-step checklist để migrate event consumers từ main service sang worker  
**Cập nhật**: December 27, 2025  
**Pattern**: Follow Warehouse/Pricing/Search service architecture

---

## 📋 **Pre-Migration Checklist**

### **Prerequisites:**
- [ ] Service hiện tại có HTTP-based Dapr subscriptions trong main service
- [ ] Service đã có worker configuration trong ArgoCD (nếu chưa có thì tạo)
- [ ] Backup current event handler logic
- [ ] Document current event flows và dependencies

### **Preparation:**
- [ ] Identify tất cả event subscriptions hiện tại
- [ ] List tất cả event handlers và business logic
- [ ] Check dependencies (database, cache, external services)
- [ ] Plan rollback strategy

---

## 🏗️ **Step 1: Create Worker Structure**

### **1.1 Create Worker Directories:**
```bash
# Tạo worker directories
mkdir -p {service-name}/cmd/worker
mkdir -p {service-name}/internal/data/eventbus
```

### **1.2 Create Worker Main File:**
**File**: `{service-name}/cmd/worker/main.go`
```go
package main

import (
    "context"
    "flag"
    "os"
    "os/signal"
    "syscall"

    "github.com/go-kratos/kratos/v2/log"
    "gitlab.com/ta-microservices/{service-name}/internal/config"
    commonWorker "gitlab.com/ta-microservices/common/worker"
)

var (
    flagconf = flag.String("conf", "../../configs", "config path, eg: -conf config.yaml")
)

func main() {
    flag.Parse()
    
    // Load config
    cfg, err := config.LoadConfig(*flagconf)
    if err != nil {
        panic(err)
    }
    
    // Initialize logger
    logger := log.NewStdLogger(os.Stdout)
    
    // Initialize workers
    workers, cleanup, err := wireWorkers(cfg, logger)
    if err != nil {
        panic(err)
    }
    defer cleanup()
    
    // Start workers
    ctx, cancel := context.WithCancel(context.Background())
    defer cancel()
    
    for _, worker := range workers {
        go func(w commonWorker.ContinuousWorker) {
            if err := w.Start(ctx); err != nil {
                log.NewHelper(logger).Errorf("Worker failed: %v", err)
            }
        }(worker)
    }
    
    // Wait for shutdown signal
    c := make(chan os.Signal, 1)
    signal.Notify(c, syscall.SIGTERM, syscall.SIGINT)
    <-c
    
    log.NewHelper(logger).Info("{Service} worker shutting down...")
}
```

### **1.3 Create Wire Configuration:**
**File**: `{service-name}/cmd/worker/wire.go`
```go
//go:build wireinject
// +build wireinject

package main

import (
    "context"
    "github.com/go-kratos/kratos/v2/log"
    "github.com/google/wire"
    
    "gitlab.com/ta-microservices/{service-name}/internal/config"
    "gitlab.com/ta-microservices/{service-name}/internal/data"
    "gitlab.com/ta-microservices/{service-name}/internal/data/eventbus"
    commonWorker "gitlab.com/ta-microservices/common/worker"
)

func wireWorkers(*config.AppConfig, log.Logger) ([]commonWorker.ContinuousWorker, func(), error) {
    panic(wire.Build(
        data.ProviderSet,
        eventbus.ProviderSet,
        newWorkers,
    ))
}

func newWorkers(
    eventbusClient eventbus.Client,
    // Add your consumers here
    exampleConsumer eventbus.ExampleConsumer,
) []commonWorker.ContinuousWorker {
    var workers []commonWorker.ContinuousWorker
    
    // Add eventbus server worker (starts gRPC server once)
    workers = append(workers, &eventbusServerWorker{client: eventbusClient})
    
    // Add event consumer workers (only add subscriptions)
    workers = append(workers, &exampleConsumerWorker{consumer: exampleConsumer})
    
    return workers
}

// eventbusServerWorker starts the gRPC server for eventbus
type eventbusServerWorker struct {
    client eventbus.Client
}

func (w *eventbusServerWorker) Start(ctx context.Context) error {
    return w.client.Start(ctx)
}

// exampleConsumerWorker handles example events
type exampleConsumerWorker struct {
    consumer eventbus.ExampleConsumer
}

func (w *exampleConsumerWorker) Start(ctx context.Context) error {
    return w.consumer.ConsumeExampleEvents(ctx)
}
```

---

## 🔧 **Step 2: Create Event Consumers**

### **2.1 Create EventBus Provider:**
**File**: `{service-name}/internal/data/eventbus/provider.go`
```go
package eventbus

import (
    "github.com/google/wire"
    commonEvents "gitlab.com/ta-microservices/common/events"
)

// ProviderSet is eventbus providers.
var ProviderSet = wire.NewSet(
    commonEvents.NewConsumerClient,
    NewExampleConsumer,
    // Add more consumers here
)

// Client alias for common eventbus client
type Client = commonEvents.ConsumerClient
```

### **2.2 Create Event Consumer:**
**File**: `{service-name}/internal/data/eventbus/example_consumer.go`
```go
package eventbus

import (
    "context"
    "encoding/json"
    "fmt"

    "github.com/go-kratos/kratos/v2/log"
    commonEvents "gitlab.com/ta-microservices/common/events"
    "gitlab.com/ta-microservices/{service-name}/internal/biz/{domain}"
)

type ExampleConsumer struct {
    client commonEvents.ConsumerClient
    usecase *{domain}.{Domain}Usecase
    log *log.Helper
}

func NewExampleConsumer(
    client commonEvents.ConsumerClient,
    usecase *{domain}.{Domain}Usecase,
    logger log.Logger,
) ExampleConsumer {
    return ExampleConsumer{
        client: client,
        usecase: usecase,
        log: log.NewHelper(logger),
    }
}

func (c ExampleConsumer) ConsumeExampleEvents(ctx context.Context) error {
    pubsub := "pubsub-redis"
    
    // Subscribe to events
    if err := c.client.AddConsumer("example.event.topic", pubsub, c.HandleExampleEvent); err != nil {
        return err
    }
    
    return nil
}

func (c ExampleConsumer) HandleExampleEvent(ctx context.Context, e commonEvents.Message) error {
    var event ExampleEvent
    if err := json.Unmarshal(e.Data, &event); err != nil {
        c.log.WithContext(ctx).Errorf("Failed to unmarshal example event: %v", err)
        return fmt.Errorf("failed to unmarshal example event: %w", err)
    }
    
    c.log.WithContext(ctx).Infof("Processing example event: id=%s", event.ID)
    
    // Call business logic (copy from current HTTP handler)
    return c.usecase.HandleExampleEvent(ctx, &event)
}

// Event structures
type ExampleEvent struct {
    ID   string `json:"id"`
    Data string `json:"data"`
    // Add fields based on your current event structure
}
```

---

## ⚙️ **Step 3: Update ArgoCD Configuration**

### **3.1 Add Worker Configuration:**
**File**: `argocd/applications/{service-name}/values.yaml`
```yaml
# Add worker configuration
worker:
  enabled: true
  replicaCount: 1
  image:
    repository: registry-api.tanhdev.com/{service-name}
    pullPolicy: IfNotPresent
    tag: ""  # Uses same tag as main service
  args:
    - "-conf"
    - "/app/configs/config.yaml"
  podAnnotations:
    dapr.io/enabled: "true"
    dapr.io/app-id: "{service-name}-worker"
    dapr.io/app-port: "5005"      # Standard gRPC port for Dapr
    dapr.io/app-protocol: "grpc"  # Workers use gRPC
  resources:
    limits:
      cpu: 300m
      memory: 512Mi
    requests:
      cpu: 100m
      memory: 256Mi
```

### **3.2 Create Worker Deployment Template:**
**File**: `argocd/applications/{service-name}/templates/worker-deployment.yaml`
```yaml
{{- if .Values.worker.enabled }}
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ include "{service-name}.fullname" . }}-worker
  labels:
    {{- include "{service-name}.labels" . | nindent 4 }}
    app.kubernetes.io/component: worker
spec:
  replicas: {{ .Values.worker.replicaCount }}
  selector:
    matchLabels:
      {{- include "{service-name}.selectorLabels" . | nindent 6 }}
      app.kubernetes.io/component: worker
  template:
    metadata:
      annotations:
        {{- with .Values.worker.podAnnotations }}
        {{- toYaml . | nindent 8 }}
        {{- end }}
      labels:
        {{- include "{service-name}.selectorLabels" . | nindent 8 }}
        app.kubernetes.io/component: worker
    spec:
      {{- with .Values.imagePullSecrets }}
      imagePullSecrets:
        {{- toYaml . | nindent 8 }}
      {{- end }}
      securityContext:
        {{- toYaml .Values.podSecurityContext | nindent 8 }}
      containers:
        - name: worker
          image: "{{ .Values.worker.image.repository }}:{{ .Values.worker.image.tag | default .Values.image.tag }}"
          imagePullPolicy: {{ .Values.worker.image.pullPolicy }}
          command: ["/app/bin/worker"]
          args:
            {{- toYaml .Values.worker.args | nindent 12 }}
          env:
            - name: DATABASE_URL
              valueFrom:
                secretKeyRef:
                  name: {{ include "{service-name}.fullname" . }}-secret
                  key: databaseUrl
            - name: REDIS_ADDR
              value: {{ .Values.env.redisAddr }}
            - name: CONSUL_ADDR
              value: {{ .Values.env.consulAddr }}
          resources:
            {{- toYaml .Values.worker.resources | nindent 12 }}
          livenessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - "pgrep -f worker"
            initialDelaySeconds: 30
            periodSeconds: 10
          readinessProbe:
            exec:
              command:
                - /bin/sh
                - -c
                - "pgrep -f worker"
            initialDelaySeconds: 5
            periodSeconds: 5
{{- end }}
```

---

## 🔨 **Step 4: Update Build Configuration**

### **4.1 Update Dockerfile:**
**File**: `{service-name}/Dockerfile`
```dockerfile
# Add worker binary build
FROM golang:1.21-alpine AS builder
WORKDIR /src
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o bin/server cmd/server/main.go
RUN CGO_ENABLED=0 GOOS=linux go build -o bin/worker cmd/worker/main.go  # Add this line

FROM alpine:latest
RUN apk --no-cache add ca-certificates tzdata
WORKDIR /app
COPY --from=builder /src/bin/server .
COPY --from=builder /src/bin/worker .  # Add this line
COPY --from=builder /src/configs ./configs
CMD ["./server"]
```

### **4.2 Update Makefile:**
**File**: `{service-name}/Makefile`
```makefile
# Add worker build target
.PHONY: build-worker
build-worker:
	go build -o bin/worker cmd/worker/main.go

.PHONY: wire-worker
wire-worker:
	cd cmd/worker && wire

.PHONY: build-all
build-all: build build-worker  # Update this target
```

---

## 🧪 **Step 5: Testing & Validation**

### **5.1 Generate Wire Code:**
```bash
cd {service-name}/cmd/worker
wire
```

### **5.2 Build Worker:**
```bash
cd {service-name}
make build-worker
```

### **5.3 Test Locally:**
```bash
# Test worker binary
./bin/worker -conf configs/config.yaml
```

### **5.4 Validate Helm Template:**
```bash
cd argocd/applications/{service-name}
helm template . --debug --dry-run
```

---

## 🚀 **Step 6: Deployment**

### **6.1 Deploy Worker (Keep Main Service):**
```bash
# Deploy with worker enabled
cd argocd/applications/{service-name}
helm upgrade {service-name} . -f staging/values.yaml
```

### **6.2 Verify Worker Deployment:**
```bash
# Check worker pod status
kubectl get pods -l app={service-name},app.kubernetes.io/component=worker

# Check worker logs
kubectl logs -l app={service-name},app.kubernetes.io/component=worker -f

# Verify event processing
kubectl logs -l app={service-name},app.kubernetes.io/component=worker | grep "Processing.*event"
```

### **6.3 Monitor Both Services:**
```bash
# Monitor main service (should still handle events via HTTP)
kubectl logs -l app={service-name},app.kubernetes.io/component!=worker -f

# Monitor worker service (should handle events via gRPC)
kubectl logs -l app={service-name},app.kubernetes.io/component=worker -f
```

---

## 🔄 **Step 7: Migration & Cleanup**

### **7.1 Verify Worker Event Processing:**
- [ ] Worker receives events correctly
- [ ] Event handlers execute business logic
- [ ] Database updates work correctly
- [ ] No duplicate event processing
- [ ] Performance metrics look good

### **7.2 Remove HTTP Subscriptions from Main Service:**
**File**: `{service-name}/internal/server/http.go`
```go
// Remove these lines:
// srv.HandleFunc("/dapr/subscribe", handler.GetSubscriptionRoutes)
// srv.HandleFunc("/events/example-event", handler.HandleExampleEvent)
// etc.
```

### **7.3 Remove Event Handler from Main Service:**
- [ ] Remove HTTP event handler functions
- [ ] Remove Dapr subscription endpoints
- [ ] Remove event handler dependencies if not used elsewhere
- [ ] Clean up unused imports

### **7.4 Redeploy Main Service:**
```bash
# Redeploy main service without HTTP subscriptions
cd argocd/applications/{service-name}
helm upgrade {service-name} . -f staging/values.yaml
```

---

## ✅ **Step 8: Post-Migration Validation**

### **8.1 Functional Testing:**
- [ ] Trigger events and verify worker processes them
- [ ] Check database for correct updates
- [ ] Verify cache invalidation (if applicable)
- [ ] Test error handling and retries

### **8.2 Performance Testing:**
- [ ] Measure API response time improvement
- [ ] Check event processing latency
- [ ] Monitor resource usage (CPU, memory)
- [ ] Verify independent scaling works

### **8.3 Monitoring Setup:**
```bash
# Check event processing metrics
kubectl logs -l app={service-name},app.kubernetes.io/component=worker | grep "event.*processed"

# Monitor API performance
curl -w "@curl-format.txt" -o /dev/null -s http://{service-name}/health
```

---

## 🚨 **Rollback Plan**

### **If Issues Occur:**

#### **Step R1: Re-enable HTTP Subscriptions:**
```bash
# Revert main service code
git checkout HEAD~1 -- {service-name}/internal/server/http.go

# Redeploy main service
kubectl rollout restart deployment/{service-name}
```

#### **Step R2: Disable Worker:**
```bash
# Scale down worker
kubectl scale deployment {service-name}-worker --replicas=0

# Or disable in values.yaml
# worker.enabled: false
```

#### **Step R3: Verify Rollback:**
```bash
# Check main service handles events again
kubectl logs -l app={service-name},app.kubernetes.io/component!=worker | grep "event"

# Verify API still works
curl http://{service-name}/health
```

---

## 📊 **Success Criteria**

### **Performance Metrics:**
- [ ] API response time improved by 60-70%
- [ ] Event processing latency < 100ms
- [ ] No duplicate event processing
- [ ] Worker scales independently

### **Functional Metrics:**
- [ ] All events processed correctly
- [ ] Business logic works as before
- [ ] Database updates correct
- [ ] Error handling works

### **Operational Metrics:**
- [ ] Worker deployment stable
- [ ] Logs clean and informative
- [ ] Monitoring and alerts working
- [ ] Documentation updated

---

## 📝 **Service-Specific Notes**

### **For Customer Service:**
- Events: order.completed, order.cancelled, order.returned, auth.login, auth.password_changed
- Business Logic: Update customer stats, last_login_at, security events
- Dependencies: Customer usecase, database

### **For Catalog Service:**
- Events: stock_changed, stock_reserved, stock_released, low_stock, price_updated
- Business Logic: Cache invalidation, product updates
- Dependencies: Cache manager, product usecase
- Note: Re-enable price events (currently disabled)

### **For Other Services:**
- Follow same pattern
- Identify current HTTP subscriptions
- Map to appropriate business logic
- Consider dependencies and data flow

---

## 🎯 **Final Checklist**

- [ ] Worker structure created
- [ ] Event consumers implemented
- [ ] ArgoCD configuration updated
- [ ] Build configuration updated
- [ ] Worker deployed and tested
- [ ] HTTP subscriptions removed from main service
- [ ] Performance validated
- [ ] Monitoring setup
- [ ] Documentation updated
- [ ] Team trained on new architecture

---

**Estimated Time per Service**: 4-8 hours  
**Pattern**: Follow Warehouse/Pricing/Search architecture  
**Support**: Reference existing worker implementations for guidance