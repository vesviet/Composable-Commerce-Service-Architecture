# 🗂️ Microservices Codebase Index

> **Last Updated**: 2026-11-22 (full workspace repo sync)  
> **Standard:** Shopify / Shopee / Lazada Architecture Patterns  
> **Stack**: Go 1.25.5 · Kratos v2 · Next.js 16 · React 18 · PostgreSQL · Redis · Dapr · Kubernetes  
> **Maturity**: 16/21 services 🟢 Production-ready · 5 services 🟡 Near-prod (see [SERVICE_INDEX.md](SERVICE_INDEX.md))

This file is the canonical repository and codebase map. For per-service maturity, versions, and ports, use [SERVICE_INDEX.md](SERVICE_INDEX.md). For deployment state and GitOps health, use [`gitops/README.md`](../gitops/README.md) and the [GitOps review checklist](10-appendix/checklists/gitops/review_checklist.md). Note: all 20 DB-backed Go services (all except `gateway`) also include a `cmd/migrate/` Goose migration CLI.

## 🏗️ Core Business Services
These form the backbone of the e-commerce transaction and user domains:
- **`auth`** — Identity & Authentication
  - API: HTTP/gRPC main server (`cmd/auth/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
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
  - Migrate & Tools: Goose migration CLI (`cmd/migrate/`), config test tool (`cmd/test_config/`)
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
- **`common`** — Shared Go Library `v1.35.3` (`gitlab.com/ta-microservices/common`)
- **`common-operations`** — Admin/Support Aggregation API
  - API: HTTP/gRPC main server (`cmd/common-operations/`)
  - Worker: Background processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`gitops`** — Kustomize, ArgoCD manifests, cluster config
- **`frontend`** — Customer Next.js 16 + Ant Design Web Application (`v1.0.1`)
- **`admin`** — Backoffice React 18 + Vite + Ant Design Application
- **`docs`** — Platform documentation, ADRs, OpenAPI/event specs, workflows, and runbooks
- **`gitlab-ci-templates`** — Shared GitLab CI/CD pipeline templates (`lint-test`, `build-image`, `update-gitops-image-tag`)
- **`microservices-agent-skills`** — 23 AI skills + 7 operational workflows ([MICROSERVICES_AGENT_SKILLS_INDEX.md](MICROSERVICES_AGENT_SKILLS_INDEX.md))

## 🧬 Common Architectural Patterns
1. **Clean Architecture:** `internal/biz` (Domain), `internal/data` (Repo), `internal/service` (API)
2. **CQRS & Events:** Dapr PubSub for async choreography
3. **Dual Binary:** Separate `cmd/<service>` and `cmd/worker` for independent scaling
4. **Transactional Outbox:** Event publishing via outbox table for guaranteed delivery
5. **Idempotency:** Event deduplication helpers to prevent duplicate processing
6. **DLQ (Dead-Letter Queue):** Failed event reprocessing via dedicated DLQ consumers
7. **Resiliency:** Circuit Breakers, Retries, Idempotence Keys
8. **Observability:** OpenTelemetry (Traces/Metrics) integrated via Kratos
