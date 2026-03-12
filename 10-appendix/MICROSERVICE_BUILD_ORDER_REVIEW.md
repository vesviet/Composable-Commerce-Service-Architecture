# Microservice Build & Deploy Order — Meeting Review Summary

> **Date**: 2026-03-12
> **Panel**: 7 AI Specialist Agents (Architect, Security, DevOps, Senior Dev, BA, Data Engineer, QA)
> **Rounds**: 250 (consolidated)
> **Status**: ✅ Final Consensus Achieved

---

## Platform Overview

- **23 services** (21 Go backends + 2 frontends)
- **10 deployment waves** (Wave 0 → Wave 9)
- **3 circular dependencies** detected & resolved
- **Full deploy time**: ~42 minutes
- **Tech**: Go/Kratos, Dapr PubSub, PostgreSQL, Redis, Elasticsearch, ArgoCD GitOps

---

## Deployment Wave Order

### Wave 0 — Shared Library
| Service | Lý do |
|---------|-------|
| **common** (v1.23.1) | Tất cả 21 Go services depend — deploy trước tuyệt đối |

### Wave 1 — Leaf Services (no outbound gRPC)
| Service | Lý do |
|---------|-------|
| **user** | Auth cần User API → ưu tiên trước |
| **notification** | Cần ready nhận events từ Wave 2+ |
| **analytics** | Pure event consumer, không block ai |

### Wave 2 — Core Domain
| Service | Lý do |
|---------|-------|
| **auth** | Security gateway, JWT infrastructure |
| **customer** | Auth cần customer profile lookup |
| **payment** | Cần auth + customer context |

### Wave 3 — Commerce Primitives
| Service | Lý do |
|---------|-------|
| **location** | Reference data (63 provinces, 11K+ wards), cần seed trước |
| **shipping** | Cần location, export API cho downstream |
| **pricing** | Dynamic pricing engine, cần cho catalog + checkout |

### Wave 4 — Catalog & Warehouse
| Service | Lý do |
|---------|-------|
| **catalog** | Core product data, resolves circular dep với warehouse |
| **warehouse** | Inventory management, optional catalog dependency |

### Wave 5 — Order, Promotion & Review
| Service | Lý do |
|---------|-------|
| **promotion** | Cần cho checkout pricing, resolves circular dep với catalog |
| **order** | Orchestrator (9 upstream deps), cần tất cả previous waves |
| **review** | Non-critical enhancement |

### Wave 6 — Fulfillment & Supporting
| Service | Lý do |
|---------|-------|
| **search** | Critical discovery path, cần sync time |
| **fulfillment** | Post-order pick/pack/ship workflow |
| **return** | Post-purchase refund/restock flows |
| **loyalty-rewards** | Points & tiers system |
| **common-operations** | Admin task orchestration |

### Wave 7 — Checkout
| Service | Lý do |
|---------|-------|
| **checkout** | Convergence point — 10-step Saga cần ALL upstream ready |

### Wave 8 — Gateway
| Service | Lý do |
|---------|-------|
| **gateway** | Single entry point, routes to all 19 backend services |

### Wave 9 — Frontends
| Service | Lý do |
|---------|-------|
| **admin** | Deploy trước cho ops team verify |
| **frontend** | Customer-facing storefront, deploy last |

---

## Circular Dependencies — Resolution

| Dependency | Resolution |
|-----------|------------|
| **catalog ↔ warehouse** | Catalog first (Wave 4); warehouse optional dep |
| **catalog ↔ promotion** | Catalog first (Wave 4); promotion enrichment optional |
| **customer ↔ order** | Customer first (Wave 2); order has stronger dependency |

> Proto API packages published independently → no build-level circular imports. Circuit breaker handles runtime graceful degradation.

---

## Deployment Timeline

```
0:00  W0  common                                    ~3 min
0:03  W1  user, notification, analytics             ~5 min
0:08  W2  auth, customer, payment                   ~5 min
0:13  W3  location, shipping, pricing               ~5 min
0:18  W4  catalog → warehouse                       ~5 min
0:23  W5  promotion, order, review                  ~5 min
0:28  W6  search, fulfillment, return,              ~8 min
          loyalty-rewards, common-operations
0:36  W7  checkout                                  ~3 min
0:39  W8  gateway                                   ~3 min
0:42  W9  admin, frontend                           ~3 min
────────────────────────────────────────────────────────────
TOTAL                                               ~42 min
```

---

## CI/CD Pipeline Stages

```yaml
stages:
  - wave-0   # common
  - wave-1   # notification, analytics, user
  - wave-2   # auth, customer, payment
  - wave-3   # location, shipping, pricing
  - wave-4   # catalog, warehouse
  - wave-5   # promotion, order, review
  - wave-6   # search, fulfillment, return, loyalty-rewards, common-operations
  - wave-7   # checkout
  - wave-8   # gateway
  - wave-9   # admin, frontend
```

---

## Key Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Common breaking change | All 21 services affected | Semantic versioning + backward compat tests |
| Auth delayed | All authenticated APIs fail | Circuit breaker + local JWT validation fallback |
| Search sync burst | Slow search after deploy | Monitor Elasticsearch indexing rate |
| Checkout biz coverage 48.3% | Potential revenue bugs | Increase test coverage before production |
| Promotion not ready at catalog | Products show base price only | Minimize Wave 4→5 gap time |

---

*Generated: 2026-03-12 — 7-agent panel, 250 rounds consolidated*
