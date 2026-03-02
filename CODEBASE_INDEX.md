# 🗂️ Microservices Codebase Index

> **Last Updated**: 2026-03-02 (post P0/P1 service maturity audit)  
> **Standard:** Shopify / Shopee / Lazada Architecture Patterns  
> **Stack**: Go 1.25 · Kratos v2 · PostgreSQL · Redis · Dapr · Kubernetes  
> **Maturity**: 15/21 services 🟢 Production-ready · 6 services 🟡 Near-prod (see [SERVICE_INDEX.md](SERVICE_INDEX.md))

## 🏗️ Core Business Services
These form the backbone of the e-commerce transaction and user domains:
- **`auth`** — Identity & Authentication
  - API: HTTP/gRPC main server (`cmd/auth/`)
  - Worker: Async event processing (`cmd/worker/`)
- **`user`** — Admin User Management & RBAC
  - API: HTTP/gRPC main server (`cmd/user/`)
  - Worker: Async Outbox processing (`cmd/worker/`)
- **`customer`** — Customer Profiles, Segments, GDPR
  - API: HTTP/gRPC main server (`cmd/customer/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
- **`catalog`** — Product Catalog (EAV, 25k+ SKUs)
  - API: HTTP/gRPC main server (`cmd/catalog/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`order`** — Order Lifecycle & Cart
  - API: HTTP/gRPC main server (`cmd/order/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`payment`** — Multi-Gateway Payment Processing
  - API: HTTP/gRPC main server (`cmd/payment/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`checkout`** — Cart Management & Checkout Orchestration
  - API: HTTP/gRPC main server (`cmd/server/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)

## 📦 Operations & Logistics
- **`warehouse`** — Multi-Warehouse Inventory & Stock Reservations
  - API: HTTP/gRPC main server (`cmd/warehouse/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`fulfillment`** — Pick/Pack/Ship Workflow
  - API: HTTP/gRPC main server (`cmd/fulfillment/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`shipping`** — Multi-Carrier Integration (GHN, Grab)
  - API: HTTP/gRPC main server (`cmd/shipping/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`location`** — Geographic Data & Delivery Zones
  - API: HTTP/gRPC main server (`cmd/location/`)
  - Worker: Async Outbox processing (`cmd/worker/`)
- **`return`** — Returns, Exchanges, Refund Processing
  - API: HTTP/gRPC main server (`cmd/return/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)

## 📈 Growth & Intelligence
- **`pricing`** — Dynamic Pricing Engine & Tax
  - API: HTTP/gRPC main server (`cmd/pricing/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`promotion`** — Campaigns, Coupons, Tiered Discounts
  - API: HTTP/gRPC main server (`cmd/promotion/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
- **`loyalty-rewards`** — Points, Tiers, Rewards, Referrals
  - API: HTTP/gRPC main server (`cmd/loyalty-rewards/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
- **`review`** — Product Reviews, Ratings, Moderation
  - API: HTTP/gRPC main server (`cmd/review/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
- **`search`** — AI-Powered Product Search & Discovery
  - API: HTTP/gRPC main server (`cmd/search/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - DLQ Worker: Dead-letter reprocessing (`cmd/dlq-worker/`)
  - Sync: Index sync tool (`cmd/sync/`)
- **`analytics`** — Business Intelligence & Metrics
  - API: HTTP/gRPC main server (`cmd/server/`)
  - Worker: Async event/cron processing (`cmd/worker/`)
- **`notification`** — Multi-Channel Notifications (Email, SMS, Push)
  - API: HTTP/gRPC main server (`cmd/notification/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)

## 🌉 Infrastructure & Platform
- **`gateway`** — API Gateway (Routing, Auth, Rate Limiting, Circuit Breaker)
  - API: HTTP main server (`cmd/gateway/`)
  - Worker: Background processing (`cmd/worker/`)
- **`common`** — Shared Go Library v1.23.0 (`gitlab.com/ta-microservices/common`)
- **`common-operations`** — Admin/Support Aggregation API
  - API: HTTP/gRPC main server (`cmd/operations/`)
  - Worker: Background processing (`cmd/worker/`)
- **`gitops`** — Kustomize, ArgoCD manifests, cluster config
- **`frontend`** — Customer Next.js Web Application
- **`admin`** — Backoffice React Application

## 🧬 Common Architectural Patterns
1. **Clean Architecture:** `internal/biz` (Domain), `internal/data` (Repo), `internal/service` (API)
2. **CQRS & Events:** Dapr PubSub for async choreography
3. **Dual Binary:** Separate `cmd/<service>` and `cmd/worker` for independent scaling
4. **Transactional Outbox:** Event publishing via outbox table for guaranteed delivery
5. **Idempotency:** Event deduplication helpers to prevent duplicate processing
6. **DLQ (Dead-Letter Queue):** Failed event reprocessing via dedicated DLQ consumers
7. **Resiliency:** Circuit Breakers, Retries, Idempotence Keys
8. **Observability:** OpenTelemetry (Traces/Metrics) integrated via Kratos
