# AGENT-16: Order Lifecycle Hardening

> **Created**: 2026-03-09
> **Priority**: P0 (2), P1 (1), P2 (1)
> **Sprint**: Tech Debt Sprint
> **Services**: `order`, `fulfillment`
> **Estimated Effort**: 3 days
> **Source**: [10-Round Order Lifecycle Flows Meeting Review](file:///Users/tuananh/.gemini/antigravity/brain/1c5f3407-0d62-454d-a4b8-5f2e02595222/artifacts/order_lifecycle_meeting_review.md)

---

## 📋 Overview

Đóng gói các issue phát hiện từ phiên họp review Order Lifecycle Flows tập trung vào xử lý lỗi nghiêm trọng P0 Phantom Stock trong hàm CancelOrder, và sửa lỗi trùng lặp/sai lệch trạng thái Saga ở quá trình xử lý Capture Payment. Khắc phục thêm các rủi ro Auto-Complete và làm sạch cấu trúc Dapr topic.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix Phantom Stock Leak in `CancelOrder` (Order Service)

**File**: `order/internal/biz/order/cancel.go`
**Focus**: Dòng xử lý khi `releaseErr` chứa `"not active"`

**Requirements**:
- Hàm `CancelOrder` hiện tại có fallback: nếu `ReleaseReservation` trả về lỗi "not active" (đã trả hàng/giao hàng thành công), nó lập tức gọi `RestockItem` để nạp kho lại.
- **Lỗi**: Nếu một lần Retry của Dapr gọi lại CancelOrder do DB Update bị timeout, nó gặp lỗi "not active" (do lần trước THỰC SỰ ĐÃ giải phóng thành công), sau đó nó mù quáng gọi `RestockItem`, vô tình in ra x2 tồn kho ảo.
- **Solution**: Xóa bỏ cụm logic "blind fallback" gọi `RestockItem`. Chỉ gọi `RestockItem` nếu chắc chắn Reservation đó "không còn active" VÀ đơn hàng đã THỰC SỰ chuyển sang Fulfillment chứ không phải bị retry.
- Tốt nhất: Check kỹ trạng thái Fulfillment của đơn hàng trước khi Restock. Nếu order chưa có Fulfillment, việc `"not active"` đồng nghĩa với ĐÃ RELEASE THÀNH CÔNG, KHÔNG ĐƯỢC RESTOCK.

---

### [ ] Task 2: Fix Saga State Divergence Post-Capture (Order Service)

**File**: `order/internal/data/eventbus/payment_consumer.go`
**Focus**: `processPaymentCaptureRequested`

**Requirements**:
- Khi `CapturePayment` thành công nhưng `orderRepo.Update()` bị lỗi, Event sẽ bị báo lỗi và redeliver.
- Ở lần Retry, hệ thống THU THẦN gửi lại Request `CapturePayment` lên Gateway/Payment Service một lần nữa, đây là cực kỳ nguy hiểm.
- **Solution**: Thêm một bước kiểm tra trạng thái capture trước khi gọi `CapturePayment`. Tra cứu Payment qua RPC xem authorization_id này đã thực sự bị capture hay chưa. Nếu Payment Gateway báo "Đã Capture", bỏ qua bước `CapturePayment` và ngay lập tức update DB Order thành `captured`.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Verify Payment Status before Auto-Complete (Fulfillment Service)

**File**: `fulfillment/internal/worker/cron/auto_complete.go` (hoặc chức năng tương tự quét auto-completion)
**Focus**: `AutoCompleteShippedWorker`

**Requirements**:
- Worker hiện tại dựa vào ngày ship (7 ngày) để auto-complete, nhưng KHÔNG check tình trạng bắt giữ tiền (`PaymentSagaState == captured` / `PaymentStatus == completed`).
- **Lỗi**: Nếu đơn hàng COD hoặc Digital ship nhanh, nhưng tiền chưa thực thu, hệ thống Complete order sẽ mở khóa Escrow cho seller, trong khi sàn chưa nhận được tiền.
- **Solution**: Khi `AutoCompleteShippedWorker` muốn đổi Order status thành Complete, cần verify `PaymentStatus == completed` của Order. Nếu chưa capture tiền, Skip!

---

## 🔵 Checklist — P2 Issues (Nice To Have)

### [ ] Task 4: Dapr Topic Refactoring for Capture Requested

**File**: `order/internal/biz/order/process.go` hoặc luồng phát sinh request capture
**Focus**: Consolidate `orders.payment.capture_requested`

**Requirements**:
- Gửi trực tiếp Outbox Event `payment.capture_requested` tới Payment thay vì tự subscribe chính mình rồi gọi qua gRPC, để hệ thống gọn gàng hơn.

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/order/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...

cd fulfillment && wire gen ./cmd/fulfillment/ ./cmd/worker/
cd fulfillment && go build ./...
cd fulfillment && go test -race ./...
```

---

## 📝 Commit Format

```text
fix(order): resolve phantom inventory and payment saga bugs (AGENT-16)

- fix(cancel): remove greedy RestockItem on missing reservation
- fix(saga): verify gateway capture state on retry in payment consumer
- feat(fulfillment): guard AutoComplete shipped orders with payment check
- refactor: streamline payment capture topic routing

Closes: AGENT-16
```
