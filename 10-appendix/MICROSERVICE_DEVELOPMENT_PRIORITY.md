# Microservice Development Priority Order — Cái Nào Dễ Làm Trước

> **Date**: 2026-03-12
> **Mục đích**: Sắp xếp 21 Go services theo **độ dễ phát triển** — service đơn giản nhất build trước
> **Tiêu chí**: LOC (ít = dễ), Dependencies (ít = dễ), Migrations (ít = đơn giản), Business complexity

---

## Bảng Tổng Hợp — Xếp Hạng Theo Độ Dễ

| Rank | Service | LOC | Go Files | Deps | Migrations | Complexity | Ghi chú |
|------|---------|-----|----------|------|------------|------------|---------|
| 🥇 1 | **location** | 2,317 | 23 | 5 | 7 | ⭐ | CRUD đơn giản, reference data (tỉnh/huyện/xã) |
| 🥈 2 | **user** | 6,670 | 41 | 2 | 10 | ⭐ | Admin RBAC, ít dependencies |
| 🥉 3 | **review** | 6,632 | 68 | 5 | 7 | ⭐⭐ | Rating + moderation, không phức tạp |
| 4 | **common-operations** | 6,242 | 65 | 9 | 11 | ⭐⭐ | Task orchestration, CRUD-heavy |
| 5 | **auth** | 6,861 | 57 | 4 | 6 | ⭐⭐ | JWT/OAuth2, security patterns đã chuẩn |
| 6 | **loyalty-rewards** | 10,212 | 121 | 5 | 12 | ⭐⭐ | Points/tiers, business rules trung bình |
| 7 | **notification** | 11,458 | 92 | 2 | 12 | ⭐⭐ | Multi-channel delivery, template engine |
| 8 | **promotion** | 12,331 | 65 | 7 | 13 | ⭐⭐⭐ | Complex rules engine (BOGO, tiered) |
| 9 | **pricing** | 14,230 | 106 | 5 | 10 | ⭐⭐⭐ | Dynamic pricing, money.Money type |
| 10 | **fulfillment** | 14,407 | 121 | 6 | 20 | ⭐⭐⭐ | Pick/pack/ship workflow, QC |
| 11 | **gateway** | 16,704 | 74 | 21 | 0 | ⭐⭐⭐ | Routing + middleware, nhưng 21 deps |
| 12 | **shipping** | 18,234 | 121 | 4 | 17 | ⭐⭐⭐ | External carrier integration (GHN, Grab) |
| 13 | **checkout** | 19,579 | 130 | 10 | 8 | ⭐⭐⭐⭐ | 10-step Saga, convergence point |
| 14 | **customer** | 21,889 | 139 | 6 | 24 | ⭐⭐⭐⭐ | Segmentation, GDPR, nhiều migrations |
| 15 | **analytics** | 24,057 | 106 | 2 | 14 | ⭐⭐⭐ | Event metrics, ít deps nhưng LOC cao |
| 16 | **order** | 24,118 | 161 | 11 | 41 | ⭐⭐⭐⭐⭐ | Saga orchestrator, 9 upstream, 41 migrations |
| 17 | **warehouse** | 24,985 | 165 | 7 | 33 | ⭐⭐⭐⭐ | Pessimistic locking, reservation TTL |
| 18 | **catalog** | 26,540 | 140 | 6 | 33 | ⭐⭐⭐⭐ | EAV pattern, 25K+ SKUs, 33 migrations |
| 19 | **payment** | 28,957 | 190 | 4 | 15 | ⭐⭐⭐⭐⭐ | Multi-gateway, PCI DSS, Saga guards |
| 20 | **search** | 30,043 | 165 | 5 | 14 | ⭐⭐⭐⭐⭐ | Elasticsearch, 4 binaries (API/Worker/Sync/DLQ) |

---

## Recommended Development Phases

### 📗 Phase 1 — Quick Wins (LOC < 7K, low complexity)

| # | Service | LOC | Thời gian ước tính | Rationale |
|---|---------|-----|--------------------|----|
| 1 | **location** | 2,317 | 1–2 ngày | CRUD thuần, seed data tỉnh/huyện/xã |
| 2 | **user** | 6,670 | 2–3 ngày | Admin RBAC, ít deps, test coverage 100% |
| 3 | **common-operations** | 6,242 | 2–3 ngày | Task CRUD, file management |
| 4 | **review** | 6,632 | 2–3 ngày | Rating aggregation, auto-moderation |
| 5 | **auth** | 6,861 | 3–4 ngày | JWT/OAuth2, MFA — patterns đã chuẩn hóa |

> **Tổng Phase 1**: ~5 services, ~10–15 ngày

### 📙 Phase 2 — Medium Complexity (LOC 10K–15K)

| # | Service | LOC | Thời gian ước tính | Rationale |
|---|---------|-----|--------------------|----|
| 6 | **loyalty-rewards** | 10,212 | 3–5 ngày | Points, tiers, referrals |
| 7 | **notification** | 11,458 | 3–5 ngày | Multi-channel, template engine, webhooks |
| 8 | **promotion** | 12,331 | 5–7 ngày | Rules engine phức tạp (BOGO, stacking) |
| 9 | **pricing** | 14,230 | 5–7 ngày | Dynamic pricing, tax, money type |
| 10 | **fulfillment** | 14,407 | 5–7 ngày | Pick/pack/ship workflow |

> **Tổng Phase 2**: ~5 services, ~21–31 ngày

### 📕 Phase 3 — High Complexity (LOC 16K–22K)

| # | Service | LOC | Thời gian ước tính | Rationale |
|---|---------|-----|--------------------|----|
| 11 | **gateway** | 16,704 | 5–7 ngày | 21 upstream deps, middleware stack |
| 12 | **shipping** | 18,234 | 5–7 ngày | External carrier APIs (GHN, Grab) |
| 13 | **checkout** | 19,579 | 7–10 ngày | 10-step Saga, 10 deps |
| 14 | **customer** | 21,889 | 7–10 ngày | Segmentation, GDPR, 24 migrations |

> **Tổng Phase 3**: ~4 services, ~24–34 ngày

### 📛 Phase 4 — Highest Complexity (LOC 24K+)

| # | Service | LOC | Thời gian ước tính | Rationale |
|---|---------|-----|--------------------|----|
| 15 | **analytics** | 24,057 | 5–7 ngày | High LOC nhưng ít deps |
| 16 | **order** | 24,118 | 10–14 ngày | Saga orchestrator, 11 deps, 41 migrations |
| 17 | **warehouse** | 24,985 | 7–10 ngày | Pessimistic locking, reconciliation |
| 18 | **catalog** | 26,540 | 10–14 ngày | EAV pattern, 33 migrations |
| 19 | **payment** | 28,957 | 10–14 ngày | Multi-gateway PCI, Saga guards |
| 20 | **search** | 30,043 | 10–14 ngày | Elasticsearch, 4 binaries |

> **Tổng Phase 4**: ~6 services, ~52–73 ngày

---

## Tổng Ước Tính

| Phase | Services | Ngày | Tỷ lệ LOC |
|-------|----------|------|-----------|
| Phase 1 (Quick Wins) | 5 | 10–15 | 9% tổng LOC |
| Phase 2 (Medium) | 5 | 21–31 | 20% tổng LOC |
| Phase 3 (High) | 4 | 24–34 | 24% tổng LOC |
| Phase 4 (Highest) | 6 | 52–73 | 47% tổng LOC |
| **TOTAL** | **20 services** | **107–153 ngày** | **100%** |

> **Lưu ý**: Chưa tính `common` library (Wave 0) và 2 frontends (admin + frontend).

---

## ⚠️ Lưu Ý Quan Trọng

> Thứ tự phát triển (cái nào dễ làm trước) **KHÁC** với thứ tự deployment (dependency graph).
>
> - **Development order**: location → user → review → auth → ... → search
> - **Deployment order**: common → user → auth → customer → ... → gateway → frontend
>
> Khi dev xong, vẫn phải **deploy theo dependency wave** (Wave 0–9) để đảm bảo hệ thống hoạt động đúng.

---

*Generated: 2026-03-12*
