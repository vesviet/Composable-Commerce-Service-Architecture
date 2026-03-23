# Kế hoạch ưu tiên — `agent-tasks`

**Cập nhật**: 2026-03-23  
**Cách đọc**: Thứ tự từ trên xuống (1 = làm trước). Mỗi dòng trỏ tới file nguồn để chi tiết / bằng chứng.

---

## Tier 1 — Luồng tiền & discovery (ảnh hưởng user rộng)

| # | Nguồn | Task / nội dung | Status | Ghi chú |
|---|--------|-----------------|--------|---------|
| 1 | **AGENT-06** | Task 1 — Verify sort sau deploy (retest Price/Name sort, không 400) | ⬜ Pending | Code fix done (AGENT-05 T2), cần verify after deploy |
| 2 | **AGENT-06** | Task 3 — Facet category/brand: UUID → tên hiển thị | ⬜ Pending | Backend enrich hoặc ES; UX filter |
| 3 | **AGENT-11** | Issues 1–5 (Stripe message, checkout toasts, COD + shipping, admin key autofill, success page) | ⬜ Pending | Issues 6-7 **đã fix** (AGENT-09) |
| 4 | **AGENT-08** | Task 2 — Verify full checkout sau fix cart | ⬜ Pending | **Unblocked** — cart fix done |
| 5 | **AGENT-08** | Task 3 — Verify promo ở cart | ⬜ Pending | **Unblocked** — cart fix done |
| 6 | **AGENT-07** | Task 3–4 — Verify promo + tax tại checkout | ⬜ Pending | **Unblocked** — phụ thuộc cart/checkout |
| 7 | **AGENT-03** | Task 3 — Guest không thấy sản phẩm | ⬜ Pending | SEO / funnel |

---

## Tier 2 — Admin & vận hành (ổn định vận hành)

| # | Nguồn | Task / nội dung | Status | Ghi chú |
|---|--------|-----------------|--------|---------|
| 8 | **AGENT-07** | Task 2 — Admin login transient 500 (lần đầu fail) | ⬜ Pending | Flaky test + UX |
| 9 | **AGENT-09** | Task 6 — Admin crash "Something went wrong" (P1) | ⬜ Pending | Cần repro + stack |
| 10 | **AGENT-09** | Task 5 — Fulfillments / picklists / packages / shipments trống (P2) | ⬜ Pending | Data/API/seed |
| 11 | **AGENT-11** | Issue 3 — COD amount mismatch | ⬜ Pending | P2 frontend |
| 12 | **AGENT-07** | Task 7 — Toast khi add-to-cart fail | ⬜ Pending | UX |

---

## Tier 3 — Cải thiện & nợ kỹ thuật

| # | Nguồn | Task / nội dung | Status | Ghi chú |
|---|--------|-----------------|--------|---------|
| 13 | **AGENT-08** | Task 6 — MiniCart drawer không mở khi add | ⬜ Pending | P2 frontend |
| 14 | **AGENT-07** | Task 5 — Seed USD/EUR giá trên dev | ⬜ Pending | P2 QA đa tiền tệ |
| 15 | **AGENT-04** | Task 6 + 9 — Admin shipping method names + sidebar link | ⬜ Pending | P2 UX |
| 16 | **AGENT-11** | Issue 4–5 — Stripe autocomplete + checkout success page | ⬜ Pending | P3 UX |
| 17 | **AGENT-01** | Task 11 — `order` CacheHelper → `TypedCache[T]` | ⬜ Pending | P2 DRY; không chặn feature |
| 18 | **AGENT-10** | Task 2–4 — Inventory chỉ WH-MAIN / transfer trống / movement type | ⬜ Pending | P3 data & API |
| 19 | **AGENT-04** | Task 7–8, 10 — Carriers, zones, fulfillment seed data | ⬜ Pending | P3 seed data |
| 20 | **AGENT-12** | Issue 1, 3–4 — Playwright login timeout + empty states | ⬜ Pending | P3 test infra |

---

## Tier 4 — Epic / kiến trúc (không phải bug sprint)

| # | Nguồn | Nội dung |
|---|--------|----------|
| **E1** | **AGENT-02** (nhúng trong file) | Task 2–4 P0 **DEFERRED**: Maker-Checker config, CS refund quotas, double-entry seller ledger — tách RFC / roadmap |
| **E2** | **AGENT-02** + snapshot | `Task 75` audit logging cluster, AGENT-36 epics — theo **DevOps Execution Queue** trong `AGENT-02` |

---

## Thứ tự gợi ý theo sprint ngắn

1. **Sprint A (1–2 ngày)**: Tier 1 hàng 1, 4–6 (verification tasks — cart/checkout/promo/sort).
2. **Sprint B (2–3 ngày)**: Tier 1 hàng 2–3, 7 + Tier 2 hàng 8–9 (facet labels + Stripe/guest + admin fixes).
3. **Sprint C (2 ngày)**: Tier 2 còn lại + Tier 3 hàng 13–16 (UX polish).
4. **Song song / backlog**: Tier 3 hàng 17–20 + Tier 4 khi có slot kiến trúc.

---

## File đã đóng / cleanup (2026-03-23)

- **AGENT-04** Tasks 1–3: ✅ Superseded bởi AGENT-09 (đã đánh dấu).
- **AGENT-05**: 7/7 `[x]` — **100% complete**.
- **AGENT-11** Issues 6–7: ✅ Superseded bởi AGENT-09 (đã đánh dấu).
- **AGENT-06** Tasks 4–5: Superseded bởi AGENT-05 (đã ghi trong doc).
- **AGENT-10 Task 33** (GitOps DRY): Đã có decision doc.
