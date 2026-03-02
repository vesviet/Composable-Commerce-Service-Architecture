# Order Flow Review (Last Phase)

## 1. Mức độ chuẩn hoá (Standardization)
Service **Order** đóng vai trò là core orchestrator phối hợp 4 domain siêu lớn: Inventory, Payment, Promotion, Shipping. Codebase được tổ chức cực kỳ tốt theo Clean Architecture:
- Tách bạch rõ ràng logic `order/create.go`, `order/payment.go`, `order/shipment.go`, `cancellation/cancellation.go`.
- File worker `internal/worker/event/event_worker.go` định tuyến Event từ Dapr -> RabbitMQ rõ ràng, đã tắt Handler HTTP rủi ro cũ (`DaprSubscribeHandler`).

## 2. Sự nhất quán dữ liệu (Data Consistency)
- **Validation Dữ Liệu**: Order Trust 100% dữ liệu từ **Checkout service** (Cart Session, Mức Giá, Disount). Hàm `validateOrderTotals` ở `create.go` đóng vai trò phòng thủ vòng 2 chống sai lệch toán học (chênh lệch `0.02` tolerance).
- **Idempotency**: Dùng `CartSessionID` để chặn duplicate order. Khi Create bị lỗi duplicate unique key, hệ thống tự catch và query lại order cũ trả về, giúp frontend không bị văng lỗi. Vô cùng an toàn!
- **Lifecycle Status**: Luồng trạng thái chuẩn chỉnh: `pending` -> `confirmed` (sau khi payment) -> `processing` (sau khi fulfillment) -> `shipped` -> `delivered`. 

## 3. Có trường hợp nào dữ liệu bị lệch (Mismatched) không?
- Hoàn toàn **KHÔNG CÓ TÌNH TRẠNG LEAK DATA CƠ BẢN**. Logic rollback và reservation cực kỳ chặt.
- Đã sửa triệt để lỗi Stock Leak (Double Confirmation / Double Release) cũ: 
  - `CreateOrder` chỉ tạo Reservation, KHÔNG DEDUCT STOCK.
  - Sự kiện `payment.confirmed` mới trigger `confirmReservationsForOrder` (Bỏ TTL).

## 4. Cơ chế Retry / Rollback / Saga / Outbox
Đây là Service chuẩn mẫu mực về **Distributed Transaction**:
1. **Outbox Pattern**: Mọi event (`order.status.changed`, `inventory.stock.committed`) đều được bọc trong hàm `uc.tm.WithTransaction`. Lưu DB Order và Outbox DB Table trên cùng 1 local transaction. Đảm bảo 100% không bị mất event.
2. **Saga Compensation (Rollback)**:
   - Khi `payment.failed`, hệ thống tự sinh event gọi hàm `CancelOrder`.
   - `CancelOrder` thay vì throw lỗi tung toé khi Warehouse sập, sẽ gọi `releaseReservationWithRetry` (3 lần Exponential Backoff).
3. **Dead Letter Queue (DLQ)**:
   - Nếu gọi bù (Retry 3 lần) mà Warehouse Service vẫn sập mạng, lệnh giải phóng kho đó bị ghi vào bảng `FailedCompensation`.
   - Service cung cấp REST API (`/api/v1/dlq/compensations/retry`) cho Ops team click nút Retry lại vào ngày hôm sau. Tuyệt vời!

## 5. Các rủi ro logic (Edge Cases) hiện hữu
Mặc dù kiến trúc xuất sắc, vẫn còn vài rủi ro về mặt Vận Hành (Ops) cần lưu ý:

### Rủi ro 1: Outbox Event Payload quá nhạy cảm với cấu trúc Database
- **Vấn đề**: `OrderStatusChangedEvent` parse trực tiếp toàn bộ dữ liệu cấu trúc Orders sang JSON Raw Payload của Event.
- **Hệ quả**: Nếu thêm/xoá cột ở Database Order, Payload thay đổi -> toàn bộ các service consume event này (Analytics, Loyalty, Fulfillment) có khả năng bị Deserialise error gây đứng luồng.

### Rủi ro 2: Missing Idempotency Key khi Ops Replay Compensation
- **Vấn đề**: Khi Ops call file API `/api/v1/failed_compensations/retry`, hệ thống order sẽ gọi gRPC sang `PaymentService.VoidPayment` hoặc `WarehouseService.ReleaseReservation` nhưng **không chèn Idempotency-Key**.
- **Hệ quả**: Nếu Admin lỡ bấm nút Retry 2 lần (do lag mạng), và Downstream service (Warehouse) không Idempotency cho operation ID đó, có thể 1 reservation bị release 2 lần (Phantom Restock).

### Rủi ro 3: Refund Stock Restoration (P1-5) 
- Vấn đề: Khi `refund.completed`, hệ thống gọi hàm `returnStockToInventory`. Hiện tại có gọi `writeRefundRestockDLQ` khi lỗi, nhưng ở `dlq_handler.go / failed_compensation_handler.go` chưa xử lý map logic `retryRefundStock` (chỉ mới có `void_authorization`, `release_reservations`, `refund`).
- **Hệ quả**: Cần bổ sung case `refund_restock` vào hàm `retryCompensationOperation` ở `failed_compensation_handler.go` để Ops có thể retry.

## 6. Checklist nghiệm thu Order Flow
- [x] Tiêu chuẩn hoá Code / Dependency Injection / Outbox local transaction
- [x] Đảm bảo Idempotency khi tạo Order
- [x] Kiểm tra toán học (Math consistency) UnitPrice, Discount, TotalAmount
- [x] Saga: Rollback Canceled Order (Release Warehouse stock)
- [x] DLQ: Log failed rollback vào Database để manual retry
- [x] Xác thực Lifecycle Flow: Payment -> Warehouse Deduction -> Fulfillment -> Shipped
- [x] P0: Route ALL status-changed events qua Outbox (order v1.1.4)
- [x] P0: Fix Exchange ReturnType không bị ghi đè thành "return" (return v1.0.7)
- [x] P1: Thêm secretRef order-secrets vào worker-deployment.yaml (gitops)
- [x] P1: DLQ release_reservations lưu reservation_ids vào CompensationMetadata (order v1.1.4)
- [x] P1: Thêm refund_restock handler vào DLQ retry switch (order v1.1.4)
- [x] P1: Dùng CompletedAt (fail-safe) thay UpdatedAt cho return window (return v1.0.7)
- [x] P2: COD auto-confirm job dùng offset-based pagination (order v1.1.4)
- [ ] P0: Thêm DLQ record khi processReturnRefund thất bại (return) — đã có outbox retry, đủ
- [ ] P2: Return events → outbox thay vì direct publish (return) — Risk 12
- [ ] P2: Per-warehouse idempotency cho fulfillment — Risk 4 (fulfillment service)
