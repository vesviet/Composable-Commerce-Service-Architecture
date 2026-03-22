# Kế hoạch ưu tiên — `agent-tasks`

**Cập nhật**: 2026-03-22  
**Cách đọc**: Thứ tự từ trên xuống (1 = làm trước). Mỗi dòng trỏ tới file nguồn để chi tiết / bằng chứng.

---

## Tier 1 — Luồng tiền & discovery (ảnh hưởng user rộng)

| # | Nguồn | Task / nội dung | Ghi chú |
|---|--------|------------------|---------|
| 1 | **AGENT-06** | Task 1 — Verify sort sau deploy (retest Price/Name sort, không 400) | Chặn QA search; phụ thuộc frontend đã deploy |
| 2 | **AGENT-06** | Task 3 — Facet category/brand: UUID → tên hiển thị | Backend enrich hoặc ES; UX filter |
| 3 | **AGENT-11** | Issues 1–7 (Stripe message, checkout toasts, COD + shipping, admin key autofill, success page, order summary ₫0, addresses N/A) | Gom theo issue trong file; ưu tiên message/toast + COD + mapping |
| 4 | **AGENT-08** | Task 2 — Verify full checkout sau fix cart | Xác nhận E2E |
| 5 | **AGENT-08** | Task 3 — Verify promo ở cart | Sau khi checkout ổn định |
| 6 | **AGENT-07** | Task 3–4 — Verify promo + tax tại checkout | Phụ thuộc cart/checkout; đóng Task 2 admin nếu còn flaky |
| 7 | **AGENT-03** | Task 3 — Guest không thấy sản phẩm | SEO / funnel |

---

## Tier 2 — Admin & vận hành (ổn định vận hành)

| # | Nguồn | Task / nội dung | Ghi chú |
|---|--------|------------------|---------|
| 8 | **AGENT-07** | Task 2 — Admin login transient 500 (lần đầu fail) | Flaky test + UX |
| 9 | **AGENT-09** | Task 6 — Admin crash “Something went wrong” (P1) | Cần repro + stack |
| 10 | **AGENT-09** | Task 5 — Fulfillments / picklists / packages / shipments trống (P2) | Data/API/seed |
| 11 | **AGENT-07** | Task 7 — Toast khi add-to-cart fail | UX |

---

## Tier 3 — Cải thiện & nợ kỹ thuật

| # | Nguồn | Task / nội dung | Ghi chú |
|---|--------|------------------|---------|
| 12 | **AGENT-08** | Task 6 — MiniCart drawer không mở khi add | P2 frontend |
| 13 | **AGENT-07** | Task 5 — Seed USD/EUR giá trên dev | P2 QA đa tiền tệ |
| 14 | **AGENT-01** | Task 11 — `order` CacheHelper → `TypedCache[T]` | P2 DRY; không chặn feature |
| 15 | **AGENT-10** | Task 2–4 — Inventory chỉ WH-MAIN / transfer trống / movement type | P3 data & API |

---

## Tier 4 — Epic / kiến trúc (không phải bug sprint)

| # | Nguồn | Nội dung |
|---|--------|----------|
| **E1** | **AGENT-02** (nhúng trong file) | Task 2–4 P0 **DEFERRED**: Maker-Checker config, CS refund quotas, double-entry seller ledger — tách RFC / roadmap |
| **E2** | **AGENT-02** + snapshot | `Task 75` audit logging cluster, AGENT-36 epics — theo **DevOps Execution Queue** trong `AGENT-02` |

---

## Thứ tự gợi ý theo sprint ngắn

1. **Sprint A**: Tier 1 hàng 1–3 (search verify + facet + payment/checkout issues chính).  
2. **Sprint B**: Tier 1 hàng 4–7 + Tier 2 hàng 8–9.  
3. **Sprint C**: Tier 2 còn lại + Tier 3.  
4. **Song song / backlog**: Tier 4 khi có slot kiến trúc.

---

## File đã đóng gần đây (không nằm trong backlog trên)

- **AGENT-04**, **AGENT-05**: checklist chính `[x]`.  
- **AGENT-06** Task 4–5: superseded bởi AGENT-05 (đã ghi trong doc).  
- **AGENT-10 Task 33** (GitOps DRY): đã có implementation component labels.
