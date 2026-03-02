# 🗂️ Microservices Codebase Index

> **Standard:** Shopify / Shopee / Lazada Architecture Patterns

## 🏗️ Core Business Services
These form the backbone of the e-commerce transaction and user domains:
- **`auth`**
  - API: HTTP/gRPC main server
- **`user`**
  - API: HTTP/gRPC main server
- **`customer`**
  - API: HTTP/gRPC main server
- **`catalog`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`order`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`payment`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`checkout`**
  - API: HTTP/gRPC main server

## 📦 Operations & Logistics
- **`warehouse`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`fulfillment`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`shipping`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`location`**
  - API: HTTP/gRPC main server
- **`return`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing

## 📈 Growth & Intelligence
- **`pricing`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`promotion`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`loyalty-rewards`**
  - API: HTTP/gRPC main server
- **`review`**
  - API: HTTP/gRPC main server
- **`search`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`analytics`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing
- **`notification`**
  - API: HTTP/gRPC main server
  - Worker: Async Outbox/Cron processing

## 🌉 Infrastructure & Platform
- **`gateway`**: API Gateway (KrakenD/Envoy/Kratos-based)
- **`common`**: Shared Library (Utils, Models, Proto, Middleware)
- **`common-operations`**: Admin/Support aggregation API
- **`gitops`**: Kustomize, ArgoCD manifests, and cluster config
- **`frontend`**: Customer Next.js Web Application
- **`admin`**: Backoffice React Application

## 🧬 Common Architectural Patterns
1. **Clean Architecture:** `internal/biz` (Domain), `internal/data` (Repo), `internal/service` (API)
2. **CQRS & Events:** Dapr PubSub for async choreography
3. **Dual Binary:** Separate `cmd/server` and `cmd/worker` for independent scaling
4. **Resiliency:** Circuit Breakers, Retries, Idempotence Keys
5. **Observability:** OpenTelemetry (Traces/Metrics) integrated via Kratos
