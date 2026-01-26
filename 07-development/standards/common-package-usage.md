# Common Package Flow

**Last Updated**: 2026-01-20
**Domain**: Platform
**Service**: Common Package (Shared Library)

## 🎯 Scope
This flow describes how services typically use the shared `common` package: configuration, logging, observability, repositories, events, middleware, and workers.

## 🔄 High-Level Service Bootstrap Flow
```mermaid
flowchart TD
    A[Service Start] --> B[Load Config]
    B --> C[Init Logger]
    C --> D[Init Observability]
    D --> E[Init DB/Redis]
    E --> F[Init Repositories]
    F --> G[Init Event Publisher]
    G --> H[Init Middleware]
    H --> I[Init Workers]
    I --> J[Start HTTP/gRPC Servers]
```

## 🧱 Core Modules and Responsibilities
- Config loading: [common/config](common/config)
- Structured errors: [common/errors](common/errors)
- Event publishing/consuming: [common/events](common/events)
- HTTP/gRPC middleware: [common/middleware](common/middleware)
- Observability (health/metrics/tracing): [common/observability](common/observability)
- Generic repository layer: [common/repository](common/repository)
- Worker framework: [common/worker](common/worker)
- Utilities and validation: [common/utils](common/utils), [common/validation](common/validation)

## 📦 Typical Runtime Flow (Request → Business → Data)
```mermaid
sequenceDiagram
    participant Client
    participant API as HTTP/gRPC Server
    participant MW as Middleware
    participant Svc as Service Layer
    participant Biz as Biz Layer
    participant Repo as Repository
    participant DB as Database
    Client->>API: Request
    API->>MW: Auth/Logging/Recovery
    MW->>Svc: Context with user + trace
    Svc->>Biz: Validate + Orchestrate
    Biz->>Repo: CRUD / Query
    Repo->>DB: GORM Query
    DB-->>Repo: Result
    Repo-->>Biz: Domain Model
    Biz-->>Svc: Response Model
    Svc-->>Client: Response
```

## 📣 Event Publishing Flow
```mermaid
sequenceDiagram
    participant Biz as Biz Layer
    participant Events as Event Publisher
    participant Dapr as Dapr Sidecar
    participant Broker as Pub/Sub
    Biz->>Events: PublishEvent(ctx, topic, payload)
    Events->>Dapr: gRPC Publish
    Dapr->>Broker: Publish to topic
```

## 📥 Event Consumption Flow
```mermaid
sequenceDiagram
    participant Dapr as Dapr Sidecar
    participant Consumer as common/events Consumer
    participant Handler as Service Handler
    Dapr->>Consumer: TopicEvent (CloudEvents)
    Consumer->>Handler: ConsumeFn(ctx, Message)
    Handler-->>Consumer: error or nil
    Consumer-->>Dapr: retry | ack
```

## ⚙️ Worker Flow (Cron / Continuous)
```mermaid
sequenceDiagram
    participant Registry as WorkerRegistry
    participant Worker as BaseWorker/ContinuousWorker
    Registry->>Worker: Start(ctx)
    Worker->>Worker: Run loop / Start()
    Worker-->>Registry: Metrics + Health
```

## 🔍 Key Entry Points
- Event consumer: [common/events/dapr_consumer.go](common/events/dapr_consumer.go)
- Event publisher (gRPC): [common/events/dapr_publisher_grpc.go](common/events/dapr_publisher_grpc.go)
- Repository base: [common/repository/base_repository.go](common/repository/base_repository.go)
- Worker base: [common/worker/base_worker.go](common/worker/base_worker.go)
- Continuous worker: [common/worker/continuous_worker.go](common/worker/continuous_worker.go)
- Metrics interfaces: [common/observability/metrics/interfaces.go](common/observability/metrics/interfaces.go)

## ✅ Recommended Usage Checklist (Per Service)
- Use `config.Loader` to initialize config once during startup.
- Use `middleware.RequestID()`, `middleware.Logging()`, `middleware.Recovery()` as baseline.
- Use `health.Manager` for liveness/readiness endpoints.
- Use `repository.GormRepository` for CRUD and pagination.
- Prefer `events.DaprEventPublisher` for pub/sub (gRPC).
- Use `worker.WorkerRegistry` or `ContinuousWorkerRegistry` for background tasks.
