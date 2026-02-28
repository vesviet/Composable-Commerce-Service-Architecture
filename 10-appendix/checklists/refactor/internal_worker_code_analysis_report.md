# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Internal Worker

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Review mã nguồn implementation của các Worker (Cron, Event Consumer, DLQ, Outbox) nằm trong thư mục `internal/worker/*`.  
**Trạng thái Review:** Đã Review - Cần Refactor Khẩn Cấp  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🚨 P1] [Architecture/DRY] Copy-Paste Outbox Worker Pattern:** Kiểm tra codebase cho thấy file `order/internal/worker/outbox/worker.go` vẫn thản nhiên tồn tại với 160 dòng code copy y hệt từ thư viện lõi. Code rác rưởi lặp lại logic vòng lặp Ticker, select channel, retry... **Yêu cầu:** Xóa ngay lập tức folder local này ở tất cả các service. Mọi Outbox Worker phải inject trực tiếp từ thư viện `common/outbox` qua Wire.
- **[🚨 P1] [Architecture/Maintainability] Boilerplate Khủng Khiếp Ở Từng Cron Job:** Trong thư viện `common/worker` vẫn chưa hề xây dựng struct `CronWorker` để bọc lại vòng lặp `select...ticker`. Hậu quả là mọi Job như `AggregationCronJob`, `OrderCleanupJob` vẫn đang phải tự gõ chay vòng lặp channel, tiềm ẩn rủi ro Goroutine Leak nếu dev code ẩu. **Yêu cầu:** Core team phải khẩn cấp bổ sung `commonWorker.NewCronWorker(interval, logicFunc)`.
- **[🔵 P2] [Clean Code/DRY] DLQ Worker Thiếu Trừu Tượng:** Chưa có Generic DLQ Worker cho toàn dự án, dẫn đến nguy cơ mỗi service lại tự code một vòng lặp nhặt Dead Letter Queue riêng.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- *(Hiện tại các vấn đề về Internal Worker Code vẫn chưa được team dev tiến hành refactor).*

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tổng Quan (Codebase Topology)
Hệ thống đang triển khai mô hình Asynchronous Background Processing rất đồ sộ, chia thành các dạng worker chính:
- **Cron Jobs:** Chạy định kỳ (VD: `aggregation_cron` ở analytics, `order_cleanup` ở order).
- **Event Consumers:** Lắng nghe PubSub via Dapr.
- **Outbox Workers:** Quét DB và đẩy sự kiện (Transactional Outbox Pattern).
- **DLQ Reprocessor:** Xử lý lại các failed events từ Dead Letter Queue (đặc thù ở Search và Order).

Mọi worker đều đang implement `commonWorker.ContinuousWorker` interface và nhúng `*commonWorker.BaseContinuousWorker` để tái sử dụng logic Start/Stop/HealthCheck. (Điều này Rất Tốt).

### 2. Các Lỗ Hổng Implementation Cần Lên Án (P1) 🚩
Dù đã có thư viện `common/worker` và `common/outbox`, việc áp dụng vào code thực tế của các service lại đang **vi phạm nghiêm trọng nguyên tắc DRY (Don't Repeat Yourself)**.

#### 🚩 2.1. Tật Sao Chép Bừa Bãi Outbox Worker
Đội ngũ kiến trúc đã cất công xây dựng thư viện xịn xò `gitlab.com/ta-microservices/common/outbox` hỗ trợ Pull DB batch, publish event và lock record an toàn. Nhưng tại service **Order** (và một vài service khác), dev lại lười đọc Docs, tự copy-paste 160 dòng mã nguồn ra file local.
- **Hậu quả:** Nếu Core Team tối ưu hóa Batch Size hoặc thêm Metric theo dõi độ trễ Outbox, Order Service sẽ "mù" tính năng do đang xài đồ giả cầy tách nhánh.

#### 🚩 2.2. Boilerplate Hủy Diệt Ở Từng Cron Job
Bất kỳ một Cronjob mới nào được tạo ra, dev cũng phải gõ lại cấu trúc vòng lặp vô tận chết người:
```go
func (j *MyCronJob) Start(ctx context.Context) error {
	ticker := time.NewTicker(15 * time.Minute)
	defer ticker.Stop() // Quên dòng này là OOM Leak RAM!
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
Việc phó thác sinh mệnh Goroutine (chống leak) cho hàng chục tay Dev khác nhau tự gõ vòng lặp là quyết định tồi của kiến trúc sư.

### 3. Giải Pháp Chỉ Đạo Từ Senior
Ngừng dung túng cho các file rác sinh sôi.

#### ✅ Ép Bỏ Outbox Local, Dùng 100% Core Library
Tại mọi service, xoá sạch thư mục `internal/worker/outbox/`. Tại file Dependency Injection (Wire Provider), chỉ cần trỏ thẳng về Common:
```go
// Truyền repo và publisher vào ngõ Factory đã bọc sẵn 100% logic vòng lặp
func NewOutboxWorker(...) commonWorker.ContinuousWorker {
    return outbox.NewWorker("order-service", outboxRepo, publisher, logger)
}
```

#### ✅ Xây Dựng `CronWorker` Wrapper 
Yêu cầu DevOps hoặc Core Team mở rộng thư viện `common/worker`, thêm hàm bọc sẵn vòng lặp Ticker. Dev làm nghiệp vụ giờ đây cực kỳ nhàn nhã:
```go
// Dev chỉ cần khai báo struct và hàm logic lõi (Do)
type OrderCleanupLogic struct { repo Repo }

func (l *OrderCleanupLogic) Do(ctx context.Context) error {
    // Chỉ code Business Logic ở đây. Vòng lặp Ticker đã có Core lo!
    return nil
}

// Bơm vào Wire cực gọn:
func ProvideWorker() commonWorker.ContinuousWorker {
    return commonWorker.NewCronWorker(
        "order-cleanup", 15 * time.Minute, logger, &OrderCleanupLogic{},
    )
}
```
Cách này giấu nhẹm đi 90% boilerplate start/stop/channel logic xuống core. Developer không dính dáng tới Goroutines Ticker, chấm dứt hoàn toàn rủi ro Memory Leak.
