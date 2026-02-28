# 📋 Báo Cáo Phân Tích & Code Review: Kiến Trúc Worker

**Vai trò:** Senior Fullstack Engineer (Virtual Team Lead)  
**Dự án:** E-Commerce Microservices (Go 1.25+, Kratos v2.9.1, GORM)  
**Chủ đề:** Đánh giá cấu trúc Worker Component (Cronjobs, Event Consumers, Outbox Processors) của toàn bộ các services.  
**Trạng thái Review:** Đã Review - Cần Refactor Lập Tức  

---

## 🚩 PENDING ISSUES (Unfixed)
- **[🟡 P1] [Code Quality/Clean Code] Tồn Dư Logic Filter Mode Khá "Phèn":** Mặc dù Core Team đã release hàm `commonWorker.ParseMode()`, nhưng kiểm tra tại `order/cmd/worker/main.go` vẫn còn sót lại cái hàm phụ trợ `shouldRunWorker(name, mode string)` dùng chuỗi cứng (hardcode string matching `"event"`, `"consumer"`) để lọc worker. Việc này dễ dãn đến sai sót (Typo) khi thêm job mới. **Yêu cầu:** Xóa sạch hàm tự chế này. Sử dụng chuẩn Enum Mode của Kratos App hoặc áp dụng interface strongly-typed của framwork.

## 🆕 NEWLY DISCOVERED ISSUES
- *(Chưa có New Issues phát sinh thêm trong vòng Review này).*

## ✅ RESOLVED / FIXED
- **[FIXED ✅] [Architecture/DRY] Xóa Bỏ Phân Mảnh Bootstrap Logic Ở File `main.go`:** Thành tựu lớn của Core Team! Đã triển khai struct `commonWorker.NewWorkerApp` thành công tại 15+ service (`analytics`, `search`, `location`, `customer`, `payment`, v.v.). Hơn 150 dòng Boilerplate (Logger, Viper config, Signal trap, Healthcheck 8081) copy-paste bừa bãi ĐÃ BỊ XÓA BỎ.
- **[FIXED ✅] [Technical Debt] Rèn Giũa Service `loyalty-rewards` Chạy Lệch Chuẩn:** Kẻ nổi loạn duy nhất `loyalty-rewards` (trước đây bypass Wire, tự gọi `.Start()` manually cho từng job) đã quy hàng. Hiện tại service này đã được refactor hoàn chỉnh, sử dụng Wire DI và `NewWorkerApp` y chang các anh em cùng cha (Core Team) khác.

---

## 📋 Chi Tiết Phân Tích (Deep Dive)

### 1. Hiện Trạng Tốt (The Good)
Toàn bộ hệ thống kiến trúc theo chuẩn **Dual-Binary**:
- Worker được build thành một tiến trình (Process) độc lập (`cmd/worker/main.go`), không chạy chung lộn xộn với API Server. Cách ly hoàn toàn tài nguyên CPU/RAM, dễ dàng scale riêng rẽ trên K8s (HPA).
- Dùng chung bộ não `gitlab.com/ta-microservices/common/worker`. Cung cấp sẵn cơ chế vòng đời (`ContinuousWorkerRegistry`) cực kì ổn định để ngắt điện (Graceful Shutdown) mượt mà mà không ném lỗi Panic.

### 2. Hành Trình Tới Clean Architecture (Tại sao phải gò ép `NewWorkerApp`?)
Trước khi có `NewWorkerApp` nằm ở Lõi, hệ thống gặp các "Mùi Code" (Code Smells) nặng nề:
- **Code Duplication Khủng Khiếp:** Ở hàm `main()` của mỗi Worker, các anh Dev đều phải tốn 150 dòng mở port `8081` làm liveness/readiness probe cho K8s, đón tín hiệu `SIGINT/SIGTERM`. Dài dòng và vô nghĩa vì nó lặp lại y chang ở 20 dịch vụ.
- **Thiếu Tính Nhất Quán (Inconsistency):** Sự xuất hiện của các ngoại lệ như `loyalty-rewards` cho thấy framework worker version cũ quá dễ dãi.

**Giải Pháp Từ Core Team Rất Hoàn Hảo:**
Core Team đã ép mọi hàm `main()` của Worker rút gọn lại đúng chừng này:

```go
func main() {
    // 1. Load Cấu hình
    cfg := config.Init(configPath)
    
    // 2. Wire DI trích xuất mảng các Workers
    workers, cleanup, _ := wireWorkers(cfg, logger)
    defer cleanup()

    // 3. Khởi tạo Kẻ Quản Trò (App) từ Common
    app := commonWorker.NewWorkerApp(
        commonWorker.WithName(Name),
        commonWorker.WithLogger(logger),
        commonWorker.WithWorkers(workers...), // Truyền tất cả cấu trúc Job vào đây
    )

    // Run và phó thác sinh mệnh tiến trình cho Core Team xử lý!
    if err := app.Run(); err != nil {
        log.Fatalf("Worker app sập tivi: %v", err)
    }
}
```

### 3. Giải Pháp Chỉ Đạo Từ Senior (Final Polish)
- Tiếp tục rà soát `order` service để diệt cỏ tận gốc hàm `shouldRunWorker`. Framework đã cung cấp sẵn `ParseMode` thì đừng tự sáng chế xe kéo nữa.
- Lên kế hoạch định nghĩa Type Enum rõ ràng cho cờ `--mode`: `ModeCron`, `ModeEvent`, `ModeAll` thay vì đánh vần bằng string thuần `if string == "event"`. Nó tạo cảm giác rất non kém (Junior). Mọi thay đổi logic Worker ở PR tiếp theo cần phải dọn dẹp điểm này.
