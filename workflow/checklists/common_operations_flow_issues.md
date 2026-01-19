# Common-Operations Flow - Issues Checklist

## ✅ Reviewed Areas
- Service APIs
- Task usecase
- Worker/consumer pipeline

## 🔎 Re-review (2026-01-19)

### Fixed
- [x] **Unmanaged goroutine (P0)**: TaskConsumer dùng `go` trực tiếp khi process pending tasks → đã dùng `errgroup` quản lý concurrency. [common-operations/internal/worker/consumer.go](common-operations/internal/worker/consumer.go#L139-L176)
- [x] **CreateTask không validate required fields**: thêm check `task_type`, `entity_type`, `requested_by`. [common-operations/internal/service/operations.go](common-operations/internal/service/operations.go#L32-L50)
- [x] **CreateTask ignore error khi UpdateTask uploadUrl**: handle lỗi từ `UpdateTask`. [common-operations/internal/service/operations.go](common-operations/internal/service/operations.go#L66-L78)
- [x] **UpdateTaskProgress ép status=processing**: chặn update khi task ở trạng thái terminal. [common-operations/internal/service/operations.go](common-operations/internal/service/operations.go#L155-L177)
- [x] **Task event/log persistence không check error**: handle lỗi `eventRepo.Create` và publish event. [common-operations/internal/biz/task/task.go](common-operations/internal/biz/task/task.go#L48-L111)

## 🧩 Issues / Gaps
- None in this pass.

## Notes
- Cần policy state machine (pending → running → completed/failed/cancelled).
- Worker nên dùng errgroup/worker pool để quản lý concurrency.
