# AGENT-05: Order Lifecycle Flows Hardening

> **Created**: 2026-03-10
> **Priority**: P0 (2), P1 (1), P2 (1)
> **Sprint**: Tech Debt Sprint
> **Services**: `order`
> **Estimated Effort**: 4 days
> **Source**: [Order Lifecycle Review Artifact](file:///home/user/.gemini/antigravity/brain/1f3dc9c7-4eac-42c6-925f-8247a7110022/order_lifecycle_review.md)

---

## 📋 Overview

Quy chuẩn hóa và vá lỗ hổng luồng dữ liệu Lifecycle của Dịch vụ Order. Khắc phục triệt để lỗi "Hủy 1 phần Fulfillment -> Hủy Toàn Đơn", khôi phục Atomicity cho Outbox Pattern trong các Event Consumers (Payment, Refund), chống rò rỉ hàng (Ghost/Leaked Stock) và xử lý hiện tượng "Out-of-order Events Deadlock" do sự kiện thanh toán trễ.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Ngăn Chặn Hủy Toàn Đơn do Split Shipment (Hủy 1 kiện hàng)

**File**: `order/internal/data/eventbus/fulfillment_consumer.go`
**Lines**: `136-154` (`processFulfillmentStatusChanged`)
**Risk**: Hệ thống đang gọi `uc.orderUc.CancelOrder()` ngay lập tức khi NHẬN ĐƯỢC MỘT event Fulfillment bị hủy. Nếu Đơn Hàng (Order) được tách ra làm 2 gói hàng (Shipment) xuất từ 2 kho, việc gói hàng 1 bị hư hỏng/hủy bỏ sẽ kích hoạt HỦY TOÀN BỘ ĐƠN HÀNG (gồm cả gói hàng 2 đang giao).
**Problem**: Logic thiếu phân rã `Partial Cancel`.

**Fix Phương Án B**: (An toàn nhất để tránh nhầm)
1. Thêm hàm `CancelOrPartialCancelOrder` trong `order/internal/biz/order/cancel.go`.
2. Truy vấn số lượng `Fulfillment/Shipment` còn lại của Đơn Hàng.
3. Nếu Đơn có > 1 gói hàng (Shipment), chỉ đánh dấu `status = partially_cancelled` trên Order, trừ lại `TotalAmount` bằng đúng giá trị Item của kiện hàng vừa hủy, và chỉ `ReleaseReservation/Restock` những món hàng thuôc Kiện Hàng Hủy đó (dựa vào `fulfillment_id`). 
4. Nếu Đơn chỉ có duy nhất 1 gói hàng, gọi `CancelOrder` bình thường.
5. Apply vào `fulfillment_consumer.go:143`.

**Validation**:
```bash
cd order && go build ./...
cd order && go test ./internal/data/eventbus -run Fulfillment
```

---

### [ ] Task 2: Cứu Vãn Transactional Outbox Bị Vỡ Tại Payment/Refund Consumers

**File 1**: `order/internal/data/eventbus/payment_consumer.go` (Method `processPaymentCaptureRequested`, Lines `348-372`)
**File 2**: `order/internal/data/eventbus/payment_consumer.go` (Method `processRefundCompleted`, Lines `472-488`)
**Risk**: Event Sourcing vi phạm nghiêm trọng. Dữ liệu đổi trong Postgres Order DB và Outbox Table KHÔNG nằm trong cùng 1 Request/Transaction. Gặp lỗi mạng giữa 2 dòng code, Hệ thống sẽ ghi nhận Order là `Completed/Refunded` nhưng Báo cáo Kho, Điểm Thưởng, Affiliate sẽ vĩnh viễn không nhận được Event Outbox. Kho hàng bị rò rỉ memory stock nếu API Refund timeout.
**Problem**: Bỏ quên `uc.tm.WithTransaction`.

**Fix Phương Án**:
Bao bọc TẤT CẢ các Repository Update (Order + Outbox/DLQ) vào trong `uc.tm.WithTransaction`.
Di dời các lệnh cắp mạng ra ngoài (`c.paymentService.CapturePayment`, `c.warehouseClient.RestockItem`) LÊN PHÍA TRƯỚC Transaction.
```go
// IN processPaymentCaptureRequested:
// 1. API Call c.paymentService.CapturePayment (Mạng)
// 2. Wrap inside Transaction (DB Atomicity)
err = c.orderUc.tm.WithTransaction(ctx, func(txCtx context.Context) error {
    if updateErr := c.orderRepo.Update(txCtx, ord, nil); updateErr != nil {
        return updateErr
    }
    return c.outboxRepo.Save(txCtx, outboxEvent) 
})

// IN processRefundCompleted:
// ... Wrap update status + writeRefundRestockDLQ inside WithTransaction
```

**Validation**:
```bash
cd order && go build ./...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Chống Deadlock "Payment Event Đến Trễ" (Out-Of-order Event)

**File**: `order/internal/biz/order/status_helpers.go`
**Lines**: `30-34` (`isValidStatusTransition`)
**Risk**: Hệ thống Kafka/RabbitMQ không bảo đảm thứ tự event (out-of-order) khi đi từ 2 service khác nhau (Payment và Fulfillment). Webhook thanh toán ngân hàng (chậm/retries) đến SAU event Warehouse Packing đóng gói nhanh. Order đã sang trạng thái `processing`. Do LUẬT cấm nhảy ngược `processing -> confirmed`, event `payment.confirmed` bị HỦY, đơn hàng nghẽn mạch vĩnh viễn ở trạng thái "Chưa thanh toán nhưng Đang Xử Lý".
**Problem**: State machine của Order đang trói buộc PaymentStatus vào OrderStatus.

**Fix**:
Tách cột `PaymentStatus` Cập nhật Độc Lập hoàn toàn khỏi State Transition của `OrderStatus`, hoặc Bypass quá trình kiểm tra nếu `Event` thuộc nhóm `Payment`.
```go
// update.go (UpdateOrderStatus function)
// NẾU là event xác nhận thanh toán (có lý do Payment Confirmed)
// VÀ status hiện tại ĐÃ LÀ processing/shipped (vượt quá confirmed)
// THÌ CHỈ update PaymentStatus = completed / PaymentSagaState = captured
// CHỨ KHÔNG update lại OrderStatus = confirmed (Tránh tụt lùi)

if req.Status == "confirmed" && (currentOrder.Status == "processing" || currentOrder.Status == "shipped" || currentOrder.Status == "partially_shipped") {
    // Bypass order status change, only update payment states
    currentOrder.PaymentStatus = constants.PaymentStatusCompleted
    return uc.orderRepo.Update(ctx, currentOrder)
}
```

**Validation**:
```bash
cd order && go test ./internal/biz/order -run OutOfOrder
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 4: Nối Dài Nhãn (SubStatus) Báo Cáo Fulfillment

**File**: `order/internal/data/eventbus/fulfillment_consumer.go`
**Lines**: `193-214`
**Problem**: Sự kiện `planning`, `picking`, `packing` từ Kho Hàng đổ về bị "nuốt chửng" quy hết làm 1 cục Order Status `"processing"`. Khách hàng bị mù mờ trạng thái suốt 2 ngày (Customer Experience kém).
**Fix**: 
Bổ sung trường `SubStatus` (string) vào Database `Order`. 
Trong `processFulfillmentStatusChanged`, ghi đè `SubStatus` bằng `event.NewStatus`. (Ví dụ `status="processing"`, `sub_status="packing"`).

---

## 🔧 Pre-Commit Checklist

```bash
cd order && wire gen ./cmd/server/ ./cmd/worker/
cd order && go build ./...
cd order && go test -race ./...
cd order && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
fix(order): harden order lifecycle against split shipment and outbox leaks

- fix: prevent whole order cancellation when a single split shipment is cancelled
- fix: wrap payment capture update and outbox save in atomic database transaction
- fix: wrap refund restock DLQ save in atomic transaction 
- fix: bypass processing->confirmed state rule to solve payment event deadlock
- feat: add sub_status to track granular fulfillment steps 

Closes: AGENT-05
```
