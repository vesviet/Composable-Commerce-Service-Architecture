# 🗂️ Microservices Codebase Index

> **Last Updated**: 2026-11-23 (full 30-repository codebase index)  
> **Standard:** Shopify / Shopee / Lazada Architecture Patterns  
> **Stack**: Go 1.27.4 (21/21 Go services + `common`) · Kratos v2.9.2 · `common` v1.37.0 · OpenTelemetry · Next.js 16 · React 18 · PostgreSQL · Redis · Elasticsearch · Dapr · Kubernetes  
> **Maturity**: 16/21 services 🟢 Production-ready · 5 services 🟡 Near-prod (see [SERVICE_INDEX.md](SERVICE_INDEX.md))

This file is the canonical repository and codebase map. For per-service maturity, versions, and ports, use [SERVICE_INDEX.md](SERVICE_INDEX.md). For deployment state and GitOps health, use [`gitops/README.md`](../gitops/README.md) and the [GitOps review checklist](10-appendix/checklists/gitops/review_checklist.md). Note: all 20 DB-backed Go services (all except `gateway`) also include a `cmd/migrate/` Goose migration CLI.

## 📊 Workspace Snapshot (30 Repositories)

- **21 Go Services** (`100%` on Go `1.27.4`, Kratos `v2.9.2`, `common v1.37.0`, OpenTelemetry, `go-redis/v9`, `0` legacy Gin)
- **525 Proto RPCs** across 21 Go services · **341 Goose SQL migrations** across 20 DB-backed services
- **1 Shared Go Library**: `common v1.37.1` (`23` packages; services currently pin `v1.37.0`)
- **2 Frontend Apps**: `frontend` (`v1.0.1`, Next.js 16 + React 18) · `admin` (`main`, React 18 + Vite)
- **6 Supporting Repos**: `gitops`, `gitlab-ci-templates`, `docs`, `qa-auto`, `microservices-agent-skills` (`v5.10.0`), `vesviet`

## 🏗️ Core Business Services
These form the backbone of the e-commerce transaction and user domains:
- **`auth`** — Identity & Authentication (`v1.4.1` · 16 RPCs · 8 migrations)
  - API: HTTP/gRPC main server (`cmd/auth/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`user`** — Admin User Management & RBAC (`v1.1.0` · 23 RPCs · 12 migrations)
  - API: HTTP/gRPC main server (`cmd/user/`)
  - Worker: Async Outbox processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`customer`** — Customer Profiles, Segments, GDPR (`v1.4.1` · 42 RPCs · 26 migrations)
  - API: HTTP/gRPC main server (`cmd/customer/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`catalog`** — Product Catalog (EAV, 25k+ SKUs) (`v1.5.1` · 72 RPCs · 35 migrations)
  - API: HTTP/gRPC main server (`cmd/catalog/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`order`** — Order Lifecycle & Cart (`v1.4.0` · 16 RPCs · 42 migrations)
  - API: HTTP/gRPC main server (`cmd/order/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`payment`** — Multi-Gateway Payment Processing (`v1.3.1` · 24 RPCs · 19 migrations)
  - API: HTTP/gRPC main server (`cmd/payment/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`checkout`** — Cart Management & Checkout Orchestration (`v1.6.1` · 18 RPCs · 9 migrations)
  - API: HTTP/gRPC main server (`cmd/server/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)

## 📦 Operations & Logistics
- **`warehouse`** — Multi-Warehouse Inventory & Stock Reservations (`v1.3.1` · 67 RPCs · 42 migrations)
  - API: HTTP/gRPC main server (`cmd/warehouse/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`fulfillment`** — Pick/Pack/Ship Workflow (`v1.3.1` · 39 RPCs · 24 migrations)
  - API: HTTP/gRPC main server (`cmd/fulfillment/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`shipping`** — Multi-Carrier Integration (GHN, Grab) (`v1.3.1` · 33 RPCs · 18 migrations)
  - API: HTTP/gRPC main server (`cmd/shipping/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`location`** — Geographic Data & Delivery Zones (`v1.1.1` · 11 RPCs · 9 migrations)
  - API: HTTP/gRPC main server (`cmd/location/`)
  - Worker: Async Outbox processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`return`** — Returns, Exchanges, Refund Processing (`v1.2.1` · 10 RPCs · 6 migrations)
  - API: HTTP/gRPC main server (`cmd/return/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)

## 📈 Growth & Intelligence
- **`pricing`** — Dynamic Pricing Engine & Tax (`v1.3.1` · 38 RPCs · 11 migrations)
  - API: HTTP/gRPC main server (`cmd/pricing/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`promotion`** — Campaigns, Coupons, Tiered Discounts (`v1.4.1` · 25 RPCs · 17 migrations)
  - API: HTTP/gRPC main server (`cmd/promotion/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`loyalty-rewards`** — Points, Tiers, Rewards, Referrals (`v1.3.1` · 22 RPCs · 13 migrations)
  - API: HTTP/gRPC main server (`cmd/loyalty-rewards/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate & Tools: Goose migration CLI (`cmd/migrate/`), config test tool (`cmd/test_config/`)
- **`review`** — Product Reviews, Ratings, Moderation (`v1.4.1` · 18 RPCs · 8 migrations)
  - API: HTTP/gRPC main server (`cmd/review/`)
  - Worker: Async Outbox/Event processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`search`** — AI-Powered Product Search & Discovery (`v1.1.0` · 19 RPCs · 14 migrations)
  - API: HTTP/gRPC main server (`cmd/search/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - DLQ Worker: Dead-letter reprocessing (`cmd/dlq-worker/`)
  - Migrate & Sync: Goose DB migration CLI (`cmd/migrate/`), index sync tool (`cmd/sync/`)
- **`analytics`** — Business Intelligence & Metrics (`v1.3.1` · 25 RPCs · 14 migrations)
  - API: HTTP/gRPC main server (`cmd/server/`)
  - Worker: Async event/cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`notification`** — Multi-Channel Notifications (Email, SMS, Push) (`v1.2.0` · 32 RPCs · 13 migrations)
  - API: HTTP/gRPC main server (`cmd/notification/`)
  - Worker: Async Outbox/Cron processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)

## 🌉 Infrastructure & Platform
- **`gateway`** — API Gateway (Routing, Auth, Rate Limiting, Circuit Breaker, OpenTelemetry tracing) (`v1.2.1` · 4 RPCs · 0 migrations)
  - API: HTTP main server (`cmd/gateway/`)
  - Worker: Background processing (`cmd/worker/`)
- **`common`** — Shared Go Library `v1.37.1` (`gitlab.com/ta-microservices/common`; Go 1.27.4, 23 packages, legacy Gin removed, `.golangci.yml` v2 standardized; services pin `v1.37.0`)
- **`common-operations`** — Admin/Support Aggregation API (`v1.3.1` · 11 RPCs · 11 migrations)
  - API: HTTP/gRPC main server (`cmd/common-operations/`)
  - Worker: Background processing (`cmd/worker/`)
  - Migrate: Goose DB migration CLI (`cmd/migrate/`)
- **`gitops`** — Kustomize, ArgoCD manifests, cluster config (`6fbcb24c`: Go 1.27.4 rollout ConfigMaps, NetworkPolicies, and overlays)
- **`frontend`** — Customer Next.js 16 + Ant Design Web Application (`v1.0.1`)
- **`admin`** — Backoffice React 18 + Vite + Ant Design Application (`main`)
- **`qa-auto`** — Automated E2E / QA test suite (Playwright)
- **`docs`** — Platform documentation, ADRs, OpenAPI/event specs, workflows, and runbooks
- **`gitlab-ci-templates`** — Shared GitLab CI/CD pipeline templates (`lint-test` on `golang:1.27.4-alpine`, `build-image`, `update-gitops-image-tag`)
- **`microservices-agent-skills`** — Global Engineering Pack `v5.10.0` (39 roles, 184 skills, 25 workflows, 21 overlays including rule-only `ecommerce-microservices`; paired with workspace [`.agent/`](../.agent/) 23 microservices skills & 7 workflows — see [MICROSERVICES_AGENT_SKILLS_INDEX.md](MICROSERVICES_AGENT_SKILLS_INDEX.md))
- **`vesviet`** — Content / marketing website repository (Hugo/Astro knowledge base & radar)

## 🧬 Common Architectural Patterns
1. **Clean Architecture:** `internal/biz` (Domain), `internal/data` (Repo), `internal/service` (API)
2. **CQRS & Events:** Dapr PubSub for async choreography
3. **Dual Binary:** Separate `cmd/<service>` and `cmd/worker` for independent scaling
4. **Transactional Outbox:** Event publishing via outbox table for guaranteed delivery
5. **Idempotency:** Event deduplication helpers to prevent duplicate processing
6. **DLQ (Dead-Letter Queue):** Failed event reprocessing via dedicated DLQ consumers
7. **Resiliency:** Circuit Breakers, Retries, Idempotence Keys
8. **Observability:** OpenTelemetry (Traces/Metrics) integrated via Kratos
