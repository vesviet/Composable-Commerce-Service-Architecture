# 🏛️ Outbox Pattern & Dapr Event Flow — Multi-Agent Meeting Review

> **Date**: 2026-03-14
> **Topic**: Review chuyên sâu toàn diện hệ thống Outbox Pattern & Dapr Pub/Sub (250-Round Deep Dive)
> **Scope**: Toàn bộ 18 services (Worker binaries, outbox workers, cronjobs, Dapr event publishers/consumers)
> **Panel**: 📐 Architect, 🛡️ Sec/Perf, 💻 Senior Dev, 📋 BA, 🛠️ DevOps

---

## 👥 Panel Members
| Icon | Agent | Vai trò trong buổi họp |
|------|-------|------------------------|
| 📐 | **Agent A (Architect)** | Đánh giá kiến trúc Event-Driven, tính nhất quán của hệ thống phân tán, Domain events. |
| 🛡️ | **Agent B (Sec/Perf)** | Phân tích race conditions, db locks, bottleneck tải trọng tại Worker pods. |
| 💻 | **Agent C (Senior Dev)** | Review code convention, clean architecture, DRY (phân tích sự phân mảnh của custom workers). |
| 📋 | **Agent D (BA/Domain)** | Đánh giá rủi ro business, các luồng event bị gãy (orphan events), tác động nếu fail. |
| 🛠️ | **Agent E (DevOps/SRE)** | Đánh giá khả năng scale của Dapr sidecars, resource contention trên Worker pods, k8s deployments. |

---

## 1. Kiến Trúc Tổng Thể: Sự phân mảnh của Outbox Pattern

### 📐 Agent A (Architect):
> Nhìn vào báo cáo tổng thể, tôi khá lo ngại về tính nhất quán kiến trúc. Chúng ta có 16 outbox workers, nhưng chỉ **7 services (44%)** tuân thủ dùng thư viện `common/outbox`. 9 services (user, payment, warehouse, shipping...) tự implement custom outbox worker. Điều này phá vỡ hoàn toàn DRY và tạo ra các dị bản về retry logic, backoff, và telemetry. Tại sao chúng ta chưa migrate toàn bộ sang `common/outbox`?

### 💻 Agent C (Senior Dev):
> Nguyên nhân là tốc độ phát triển. Các dev khi làm feature đã copy-paste file `outbox_worker.go` thay vì import từ `common`. Hậu quả là: 9 custom worker này **mất hoàn toàn OTel trace propagation**, không có `EventRouter`, và không có Prometheus metrics chuẩn (`prometheus.MustRegister` trong `init()` thay vì `WithMetrics`). Nó khiến code không thể maintain.

### 🛡️ Agent B (Sec/Perf):
> Tôi đồng ý với C. Thiếu OTel trace trong outbox là một "thảm họa" khi debug trên production. Event đi qua Dapr, sang consumer, nhưng trace_id bị đứt đoạn tại DB. Chưa kể một số custom worker không có `MaxRetries` (như service `review`), dẫn đến event fail sẽ retry vô tận (infinite loop), bào mòn tài nguyên CPU và DB kết nối.

### 🛠️ Agent E (DevOps):
> Vấn đề lớn hơn: Các service tự implement outbox như `shipping` lại hardcode cleanup retention là **7 ngày** (dòng 179). Trong khi storage của database có hạn, và mỗi service scale theo log volume khác nhau. Cần phải đưa retention vào config map (env vars) qua `common/outbox.WithCleanup()`.

---

## 2. 🚨 Issue P0: Race Condition kép trong Checkout & Loyalty

### Nhận định về Checkout (🚨 P0-OUTBOX-01)
**Vị trí**: `checkout/internal/worker/outbox/worker.go`

**🛡️ Agent B (Sec/Perf)**:
> File `worker.go` của checkout dùng `ListPending(ctx, 50)` nhưng **không có** `FOR UPDATE SKIP LOCKED`. Điều này có nghĩa là nếu chúng ta scale checkout worker lên 2 replicas, cả 2 pod sẽ đọc cùng 1 lúc 50 event. System sẽ gửi `checkout.cart.converted` 2 lần vào Dapr!

**📋 Agent D (BA)**:
> Khoan đã, gửi 2 lần `cart.converted`? Tức là Order service sẽ nhận 2 event và tạo ra **2 đơn hàng cho cùng 1 giỏ hàng**, đồng thời trừ tiền khách hàng 2 lần? Đây là rủi ro tài chính (Financial Risk) cực kỳ nghiêm trọng, P0 là còn nhẹ.

**💻 Agent C (Senior Dev)**:
> Đáng buồn hơn là dev trước đây đã tự chế ra một cái in-memory dedup cache trong checkout worker để chống trùng lặp thay vì dùng DB-level idempotency (`SKIP LOCKED`). Nhưng cache in-memory chỉ chạy trên 1 pod, pod khác không biết. Phải lập tức thay thế cái custom repo này bằng `common/outbox.NewGormRepository()`.

### Nhận định về Loyalty (🚨 P0-OUTBOX-02)
**Vị trí**: `loyalty-rewards/internal/data/provider.go:44`

**💻 Agent C (Senior Dev)**:
> Service `loyalty-rewards` có wire cái `GormRepository`, lưu event vào DB hoàn hảo, nhưng... không có file Worker nào đi poll cái bảng đó cả. Event mãi mãi nằm ở trạng thái `pending`.

**📋 Agent D (BA)**:
> Thật phi lý. Tức là khách hàng mua hàng xong, hệ thống lưu event `points.earned` xuống DB, nhưng event đó không bao giờ được đẩy qua Dapr. Nghĩa là khách hàng thực tế **không bao giờ được cộng điểm**. Hàng ngàn ticket complaint sẽ bay về CSKH ngay khi lên production! Phải lập tức wire `outbox.NewWorker()` vào trong `cmd/worker/main.go`.

---

## 3. Kiến Trúc Event & Consumer: Gần 40% Event bị "Bốc Hơi"

**📐 Agent A (Architect)**:
> Theo `WORKER-EVENT-CRONJOB-REVIEW.md`, chúng ta đang publish khoảng ~50 topics vào Dapr, nhưng có tới **~20 topic (40%) không có bất kỳ consumer nào** subscribe!

**📋 Agent D (BA)**:
> Ví dụ cụ thể: `payment.payment.voided` được bắn ra, nhưng `order` service không hề lắng nghe. Nếu một payment gateway reject tự động sau khi void, Order vẫn ở trạng thái "Processing" thay vì "Cancelled" hoặc "Payment Failed". Lại kẹt đơn hàng.
> Và hệ thống `promotion` bắn ra 14 topics cho `campaign.*` và `coupon.*` nhưng không ai nghe?

**💻 Agent C (Senior Dev)**:
> Đó là Over-engineering. Dev có thói quen "cứ bắn event đi, sau này có ai cần thì dùng". Việc bắn rác vào Dapr làm chậm message broker, tăng I/O database vô ích. Đề xuất: Xóa bỏ các event publish không có consumer hiện hành, hoặc ghi chú rõ là `Dead Letter Events`.

**🛠️ Agent E (DevOps)**:
> Chúng ta đang bị nghẽn cổ chai tải trọng (Resource Contention) tại `warehouse` worker pod. Một cái pod duy nhất đang chạy 12 CronJobs, 6 Dapr Consumers, và 1 Outbox Worker. CronJob như `CapacityMonitorJob` hay `StockReconciliationJob` tốn rất nhiều RAM. Nếu OutOOM xảy ra, worker sập, toàn bộ luồng consumer Dapr của `warehouse` sẽ kẹt cứng. 
> Đề xuất: Tách Worker Command ra thành 2 mode: `--mode=cron` và `--mode=event` trên Kubernetes deployment (chạy 2 pods riêng biệt).

---

## 4. 🚩 PENDING ISSUES (Consolidated Action Plan)

### 🚨 Critical (P0) - Rủi Trong Business / Tech
| # | Vấn đề | Impact | Hành Động Cần Thiết (Action) |
|---|---|---|---|
| 1 | **Checkout Outbox thiếu `SKIP LOCKED`** | 2 replica worker sinh ra double đơn hàng, double trừ tiền. | Lập tức thay thế custom repo bằng `common/outbox.NewGormRepository()` có `SKIP LOCKED`. |
| 2 | **Loyalty không có Outbox Worker** | Khách mua hàng nhưng không bao giờ được cộng điểm. Data nằm chết ở `pending`. | Inject `common/outbox.NewWorker` vào file `cmd/worker/wire.go` của loyalty-rewards. |

### 🟡 High Priority (P1) - Technical Debt Chặn Nguồn Scale
| # | Vấn đề | Impact | Action Required |
|---|---|---|---|
| 3 | **9 Services dùng Custom Outbox** | Mất OTel Trace propagation, không metrics. Khó debug. | Thống nhất migrate sang `common/outbox`, ưu tiên migration cho `shipping`, `warehouse`, `payment`, `review`. |
| 4 | **Sót Consumer cho Critical Biz Events** | Đơn hàng kẹt trạng thái khi payment void; User không nhận notify khi update Tier. | Viết consumer tại `Order` cho `payment.payment.voided`; Consumer tại `Notification` cho `loyalty.*`. |
| 5 | **Review Worker thiếu Cleanup/Metrics** | Bảng Outbox của Review phình to liên tục và sẽ gây Full Disk Space PostgreSQL. | Bổ sung `WithCleanup()` hoặc migrate sang `common/outbox.Worker`. |

### 🔵 Nice to Have (P2) - Kiến trúc & Vận Hành
| # | Vấn đề | Action Required |
|---|---|---|
| 6 | **Tách Worker Pods cho Warehouse** | Tách helm chart của warehouse worker thành 2 deployments: 1 cho `cron`, 1 cho `event-consumer`. |
| 7 | **Dọn dẹp Over-engineering Events** | Loại bỏ 14 events của component `promotion` nếu không có service nào consume. |
| 8 | **Catalog EventProcessor Monolith** | Refactor `Catalog` event processor sang standard consumers giống `common-operations`. |

---

## 🎯 Executive Summary

### 📐 Agent A (Architect): 
"Tổng thể Dapr event flow của chúng ta bị sa lầy vào việc 'tự chế bánh xe'. Việc không chuẩn hóa thư viện common tạo ra fragmentation cục bộ ở telemetry và reliability. Mọi service phải quy về `common/outbox.Worker` để scale lớn hơn."

### 🛡️ Agent B (Sec/Perf): 
"Tôi cảnh báo đỏ (Red Alert) về Checkout (race condition vì thiếu SKIP LOCKED). Không thể lên Production chừng nào lỗi này chưa fix. Lỗi concurrency này đâm trực diện vào túi tiền công ty."

### 💻 Agent C (Senior Dev): 
"Việc migrate các service còn lại về `common/outbox` sẽ giải quyết 80% nợ kỹ thuật hiện tại (tracking, retries, metrics). Mã nguồn sẽ giảm cả ngàn dòng code boilerplate (150 lines/service), dễ review và dễ test."

### 📋 Agent D (BA): 
"Payment void và Loyalty earn bị bốc hơi do sót hoặc chết worker. Đây là luồng 'sinh tử' đối với Customer Experience. Code phải phản ánh đúng Use-case."

### 🛠️ Agent E (DevOps/SRE): 
"Warehouse worker pod hiện đang là một 'quả bom nổ chậm'. Một pod gánh 19 worker jobs hạng siêu nặng sẽ đè chết Outbox processing. Cần scale riêng biệt logic Event và Cronjob."
