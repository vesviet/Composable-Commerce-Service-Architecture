# Báo Cáo Phân Tích Worker (Senior TA Report)

**Dự án:** E-Commerce Microservices  
**Đối tượng phân tích:** Worker component (`cmd/worker/main.go` và `internal/worker`) của tất cả các services.

---

## 1. Hiện Trạng Cấu Hình Worker (How Workers are Configured)

Sau khi kiểm tra toàn bộ source code của các service (`analytics`, `search`, `location`, `customer`, `gateway`, `order`, `loyalty-rewards`, v.v.), có thể thấy cấu trúc Worker đang được tổ chức như sau:

*   **Chạy độc lập (Dual-Binary):** Worker được build và chạy như một process riêng biệt (`cmd/worker/main.go`), tách rời hoàn toàn với API server (`cmd/server/main.go`).
*   **Thư viện Core:** Hầu hết các service (15+ service) **đã sử dụng chung** một thư viện nền tảng là `gitlab.com/ta-microservices/common/worker`. Thư viện này cung cấp sẵn:
    *   `ContinuousWorkerRegistry` (để quản lý lifecycle: start/stop của nhiều worker).
    *   `BaseContinuousWorker` (chứa logic chung về context, error handling, health).
    *   `HealthServer` (để expose HTTP endpoint port 8081 cho K8s liveness/readiness probes).
*   **Cơ chế Dependency Injection:** Sử dụng `Wire` (`wireWorkers()`) để khởi tạo các Dependency và trả về một slice `[]commonWorker.ContinuousWorker`.
*   **Phân loại Worker (Mode):** Hỗ trợ cờ `--mode` với 3 giá trị: `cron` (chạy định kỳ), `event` (nghe message từ message broker/Dapr Sub), và `all` (chọn cả hai). Logic filter worker thường được hardcode bằng `strings.Contains(name, "event")`.
*   **Ngoại lệ:** Service `loyalty-rewards` đang bypass Wire, khởi tạo manually và không dùng `ContinuousWorkerRegistry` để loop start/stop các job, mà gọi `.Start()` trực tiếp cho từng worker trong hàm `main()`.

---

## 2. Đánh Giá: Có nên Common hoá không? (Should we commonize?)

**Câu trả lời:** CÓ, chúng ta CẦN common hoá triệt để hơn nữa. Mặc dù chúng ta đã có `common/worker` (Registry/Interface), nhưng phần **Bootstrap Logic (Boilerplate)** đang lặp lại y hệt nhau ở tất cả các services.

### 🚩 Các Vấn Đề (Smells) Hiện Tại:
1.  **Code Duplication ở `main.go`:** Từ khởi tạo Logger, cờ (flags), bind config Viper, setup Health check HTTP (port 8081), chờ signal `SIGINT/SIGTERM`, cho đến graceful shutdown... Tất cả khoảng `150 dòng code` boilerplate này bị copy-paste ra mười mấy service.
2.  **Logic Filter Mode lặp lại:** Hàm `shouldRunWorker(name, mode string)` copy-paste ở mọi service. Việc dựa vào string matching (`"event"`, `"consumer"`) để phân loại cron/event là không strongly-typed (dễ sai sót nếu đặt tên sai).
3.  **Thiếu tính nhất quán (Inconsistency):** Sự xuất hiện của các ngoại lệ như `loyalty-rewards` cho thấy framework worker chưa đủ dễ dãi (hoặc dev lười build Wire). Nếu có một `WorkerApp` chuẩn, mọi dev đều bị ép vào khuôn.

### ✅ Giải pháp Đề Xuất (Next Steps):
Thay vì lặp lại logic ở các `cmd/worker/main.go`, hãy xây dựng một Bootstrap/App struct nằm trong `common/worker`.

**Mục tiêu của hàm `main()` ở mỗi service sau khi Common hoá sẽ chỉ còn thế này:**

```go
func main() {
    // 1. Khởi tạo config
    cfg := config.Init(configPath)
    
    // 2. Wire các specific workers của domain này
    workers, cleanup, _ := wireWorkers(cfg, logger)
    defer cleanup()

    // 3. Sử dụng Common Worker App để run mọi thứ
    app := commonWorker.NewWorkerApp(
        commonWorker.WithName(Name),
        commonWorker.WithVersion(Version),
        commonWorker.WithLogger(logger),
        commonWorker.WithWorkers(workers...), // Đẩy mảng workers vào
    )

    // Run block lại và tự xử lý healthcheck, signals, shutdown
    if err := app.Run(); err != nil {
        log.Fatalf("Worker app failed: %v", err)
    }
}
```

### 📋 Action Items nếu tiến hành:
- [ ] Di chuyển toàn bộ logic setup registry, health server (8081), signal trap vào một file chung trong thư viện `common` (VD: `common/worker/app.go`).
- [ ] Định nghĩa Enum cho Mode thay vì dính vào string name (`cron.Worker` vs `event.Worker` struct tag/methods).
- [ ] Refactor đồng loạt `cmd/worker/main.go` trên toàn hệ thống để xóa sạch technical debt.
- [ ] Bắt buộc `loyalty-rewards` phải sử dụng chung pattern mới này.
