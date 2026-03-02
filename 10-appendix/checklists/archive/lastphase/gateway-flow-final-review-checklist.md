# Gateway Flow Review (Last Phase)

## 1. Mức độ chuẩn hoá (Standardization)
Service API Gateway đã được **chuẩn hoá hoàn toàn** theo pattern hiện đại:
- **Routing**: Chuyển từ hardcode sang Configuration-Driven Routing (định nghĩa cực kỳ rõ ràng trong `gateway.yaml` phần `routing.patterns`). Có chia nhóm rõ ràng (Public, Authenticated, Admin, Webhook).
- **Middleware Manager**: Khởi tạo và pre-build các middleware chains phổ biến (e.g., `rate_limit_user -> auth -> warehouse_detection`) giúp tối ưu hiệu năng (tránh loop mỗi request).
- **Core Middlewares Đầy Đủ**: Áp dụng chuẩn đầy đủ các lớp bảo mật: Rate Limit, Circuit Breaker, CSRF, Anti-Panic, Response Sanitizer, Audit Log, Smart Cache.

## 2. GitOps Config
Cấu hình GitOps ở `gitops/apps/gateway/base` **đạt chuẩn**:
- Deployment khai báo đúng annotations của Dapr (`dapr.io/enabled: "true"`).
- `gateway.yaml` ConfigMap được mount đúng chuẩn Kustomize.
- Probes (`/health/live`, `/health/ready`), Resources (512Mi/500m), SecurityContext (non-root) đều được cấu hình Best Practices của K8s.

## 3. Sự nhất quán dữ liệu (Data Consistency)
- **Truyền tải Request Context**: Gateway làm rất tốt việc parse và truyền tải các headers quan trọng xuống downstream (`X-User-ID`, `X-Warehouse-ID`, `X-Gateway-Version`), đảm bảo các service phía sau có đủ context để xử lý logic nhất quán.
- **Cache Invalidation**: `SmartCacheMiddleware` chủ động cấu hình xoá cache (pattern based) khi có bất kỳ mutation (POST/PUT/DELETE) nào đi qua các route được target. Ngăn chặn việc hiển thị dữ liệu cũ cho UI sau khi update.

## 4. Có trường hợp nào dữ liệu bị lệch (Mismatched) không?
Nhìn chung là **RẤT AN TOÀN**, tuy nhiên có 1 edge case nhỏ về Cache:
- **Nguy cơ Cache Content-Type**: Khi `SmartCacheMiddleware` sử dụng Singleflight API để chống bão request (Thundering Herd), nếu cache bị miss, nó fetch data và set cứng header `Content-Type: application/json` trước khi trả về cho các goroutine đang đợi. Nếu API trả về định dạng khác (Text, CSV, File Stream), dữ liệu phía client sẽ bị lệch/không parse được.

## 5. Cơ chế Retry / Rollback / Saga / Outbox
Gateway không có DB nên hoàn toàn không sử dụng Outbox, thay vào đó:
- **Retry An Toàn**: Cơ chế retry sử dụng Exponential Backoff + Jitter chỉ áp dụng cho các request **Idempotent** (GET, HEAD, OPTIONS) hoặc các request có kèm header `Idempotency-Key`.
- **Custom Dead Letter Queue (DLQ)**: Khi một Mutation request (POST/PUT/PATCH/DELETE) bị thất bại (`err != nil`), Gateway tự động ghi log request đó vào **Redis DLQ** (`gateway:dlq:failed_mutations`). Điều này cho phép phía Ops có thể replay lại request bị lỗi mạng.

## 6. Các rủi ro logic (Edge Cases) cần chú ý
Dù code gateway rất tốt, mô hình distributed có 2 rủi ro hiện hữu:

### Rủi ro 1: Replay DLQ gây trùng lặp dữ liệu (Duplicate Mutations)
- **Vấn đề**: Gateway ghi log vào Redis DLQ khi có lỗi. Nhưng nếu lỗi đó là **Network Timeout (504)** từ phía Gateway -> Upstream (trong khi Upstream thực tế đã xử lý và commit DB thành công), Gateway vẫn ghi nhận là failed mutation.
- **Hệ quả**: Nếu System Admin / Ops team thấy DLQ và bấm nút "Replay", lệnh đó sẽ được chạy lại lần 2. Nếu logic ở Upstream không bắt buộc Idempotency-Key, dữ liệu sẽ bị duplicate (VD: trừ tiền 2 lần, tạo 2 đơn hàng).
- **Khắc phục**: Quy định hoặc ép buộc mọi Mutation APIs ở downstream bắt buộc phải check Idempotency-Key, hoặc cẩn trọng khi replay DLQ.

### Rủi ro 2: Cache Invalidation bắn "nhầm còn hơn bỏ sót"
- **Vấn đề**: `SmartCacheMiddleware` luôn trigger hàm xoá Redis Pattern nếu r.Method là POST/PUT/DELETE, bất chấp upstream trả về HTTP 200 SUCCESS hay HTTP 500 ERROR.
- **Hệ quả**: Bị tốn I/O vô ích xuống Redis khi request update thất bại. Nhưng về mặt Data Consistency, thà xoá nhầm còn hơn để lưu Cache cũ. 

## 7. Checklist nghiệm thu Gateway Flow
- [x] Tiêu chuẩn hoá Routing (Chuyển sang Declarative patterns)
- [x] Tiêu chuẩn hoá GitOps K8s manifest
- [x] Singleflight / Chống bão Cache Stampede
- [x] An toàn Retry (Chỉ retry Idempotent)
- [x] Gateway DLQ cho failed mutations
- [x] Khắc phục rủi ro hardcode `application/json` trong Singleflight Cache
- [x] (Kiến trúc) Xác nhận 100% downstream microservices đã handle Idempotency Key an toàn để chống Replay Attack từ ops.
  > ✅ Audit hoàn tất: 11/18 SAFE, 6/18 PARTIAL, **1/18 MISSING** (`promotion` cần fix — rủi ro apply coupon 2 lần).
  > Chi tiết: xem [`idempotency-audit-report.md`](./idempotency-audit-report.md)
  > Action items: P0 fix `promotion/ApplyCoupon` dedup check; P1 verify `loyalty-rewards` + `review` DB constraints.
