# Báo Cáo Phân Tích & Code Review: Kiến Trúc Worker (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Chủ đề:** Review mã nguồn implementation của các Worker (Cron, Event Consumer, DLQ, Outbox) nằm trong thư mục `internal/worker/*` của các services.
**Trạng thái Review:** Lần 1 (Pending Refactor - Theo chuẩn Senior Fullstack Engineer)

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🔴 P1] [Architecture / DRY] Copy-Paste Outbox Worker Pattern:** Kiểm tra codebase cho thấy file `order/internal/worker/outbox/worker.go` vẫn thản nhiên tồn tại với 160 dòng code copy y hệt từ thư viện lõi. Code rác rưởi lặp lại logic vòng lặp Ticker, select channel, retry... *Yêu cầu: Xóa ngay lập tức folder local này ở tất cả các service. Mọi Outbox Worker phải inject trực tiếp từ thư viện `common/outbox` qua Wire.*
- **[🔴 P1] [Architecture / Maintainability] Boilerplate Khủng Khiếp Ở Từng Cron Job:** Trong thư viện `common/worker` vẫn chưa hề xây dựng struct `CronWorker` để bọc lại vòng lặp `select...ticker`. Hậu quả là mọi Job như `AggregationCronJob`, `OrderCleanupJob` vẫn đang phải tự gõ chay vòng lặp channel, tiềm ẩn rủi ro Goroutine Leak nếu dev code ẩu. *Yêu cầu: Core team phải khẩn cấp bổ sung `commonWorker.NewCronWorker(interval, logicFunc)`.*
- **[🔵 P2] [Clean Code] DLQ Worker Thiếu Trừu Tượng:** Chưa có generic DLQ Worker cho toàn dự án.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm ngoài scope của TA report ban đầu)*

## ✅ RESOLVED / FIXED
- *(Hiện tại các vấn đề về Worker vẫn chưa được team dev tiến hành refactor).*

## 1. Hiện Trạng Tổng Quan (Codebase Topology)

Hệ thống đang triển khai mô hình Asynchronous Background Processing rất đồ sộ, chia thành các dạng worker chính:
- **Cron Jobs:** Chạy định kỳ (VD: `aggregation_cron` ở analytics, `order_cleanup` ở order).
- **Event Consumers:** Lắng nghe PubSub via Dapr.
- **Outbox Workers:** Quét DB và đẩy sự kiện (Transactional Outbox Pattern).
- **DLQ Reprocessor:** Xử lý lại các failed events từ Dead Letter Queue (đặc thù ở Search và Order).

Mọi worker đều đang implement `commonWorker.ContinuousWorker` interface và nhúng `*commonWorker.BaseContinuousWorker` để tái sử dụng logic Start/Stop/HealthCheck.

---

## 2. Các Vấn Đề Lớn Phát Hiện Được (Critical Smells) 🚩

Dù đã có thư viện `common/worker` và `common/outbox`, việc áp dụng vào code thực tế của các service lại đang **vi phạm nghiêm trọng nguyên tắc DRY (Don't Repeat Yourself)**.

### 🚩 2.1. Copy-Paste Outbox Worker Pattern (P1)
**Vấn đề:** 
Đội ngũ kiến trúc đã cất công xây dựng thư viện xịn xò `gitlab.com/ta-microservices/common/outbox` chứa sẵn `worker.go` hỗ trợ Push sự kiện chuẩn Dapr, lock record DB, và cleanup. 
Nhưng tại service **Order** (và một vài service khác), dev lại tiếp tục tạo thủ công thư mục `order/internal/worker/outbox/worker.go` và copy-paste lại y hệt 160 dòng logic Start/Stop, quét DB batch 50 records, publish event.

**Hệ luỵ:**
Nếu sau này `common/outbox` được cập nhật tính năng mới (ví dụ: metric Prometheus, tối ưu batch size), `Order` service sẽ bị rớt lại phía sau vì code của nó đang fork tĩnh bằng copy-paste.

### 🚩 2.2. Boilerplate Khủng Khiếp Ở Từng Cron Job (P1)
**Vấn đề:**
Bất kỳ một Cronjob mới nào được tạo ra (Ví dụ: `AggregationCronJob`, `OrderCleanupJob`), dev cũng phải gõ lại một cấu trúc hàm `Start()` dài ngoằng:
```go
func (j *MyCronJob) Start(ctx context.Context) error {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop()
	for {
		select {
		case <-ticker.C:
			j.process()
		case <-ctx.Done(): ...
		case <-j.StopChan(): ...
		}
	}
}
```
**Hệ luỵ:**
Logic loop `ticker + select/ctx.Done/StopChan` lặp lại cả trăm lần ở hàng chục file cron. Rất dễ sinh bug rò rỉ (leak) goroutine nếu dev quên `defer ticker.Stop()` hoặc quên bắt case `ctx.Done()`.

### 🚩 2.3 DLQ Worker Thiếu Trừu Tượng (P2)
- Service `search` có một `dlq_reprocessor_worker.go` xử lý retry logic. Chắc chắn Service `order` cũng sẽ có đoạn mã tương tự do cần xử lý DLQ. Nếu không đóng gói nó thành một `commonWorker.NewDLQWorker(repo, retryService)`, thì sớm muộn cũng thành Technical Debt.

---

## 3. Bản Chỉ Đạo Refactor Từ Senior (Clean Architecture Roadmap)

### ✅ Giải pháp 1: Ép Bỏ Outbox Local, Dùng 100% Core Library
Tại mọi service, xoá thư mục `internal/worker/outbox/`. Thay vì code tay, tại file Dependency Injection (Wire Provider), chỉ cần khởi tạo trực tiếp từ Common:
```go
// Trong internal/worker/provider.go
import "gitlab.com/ta-microservices/common/outbox"

func NewOutboxWorker(...) commonWorker.ContinuousWorker {
    return outbox.NewWorker("order-service", outboxRepo, publisher, logger)
}
```

### ✅ Giải pháp 2: Xây Dựng `CronWorker` Wrapper 
Yêu cầu DevOps hoặc Core Team mở rộng thư viện `common/worker`, thêm hàm bọc sẵn vòng lặp Ticker.

Thay vì bắt dev viết vòng lặp `select { channel }` dễ lỗi, hãy cung cấp interface đơn giản:
```go
// Dev chỉ cần khai báo struct và hàm logic lõi (Do)
type OrderCleanupLogic struct { repo Repo }

func (l *OrderCleanupLogic) Do(ctx context.Context) error {
    // Logic dọn DB
    return nil
}

// Tại Wire, khởi tạo bọc qua Common:
func ProvideWorker() commonWorker.ContinuousWorker {
    return commonWorker.NewCronWorker(
        "order-cleanup",     // Tên worker
        15 * time.Minute,    // Chu kỳ
        logger,
        &OrderCleanupLogic{},// Implementer
    )
}
```
Cách này giúp giấu nhẹm đi 90% boilerplate start/stop/channel logic xuống core. Developer sau này chỉ cần tập trung hàm `Do()` chứa Business Logic.
