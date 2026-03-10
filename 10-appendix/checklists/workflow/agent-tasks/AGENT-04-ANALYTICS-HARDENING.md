# AGENT-04: Analytics & Reporting Hardening

> **Created**: 2026-03-10
> **Priority**: P0 (2), P1 (2), P2 (1)
> **Sprint**: Tech Debt Sprint
> **Services**: `analytics`
> **Estimated Effort**: 3 days
> **Source**: [Analytics & Reporting Review Artifact](file:///home/user/.gemini/antigravity/brain/1f3dc9c7-4eac-42c6-925f-8247a7110022/analytics_reporting_review.md)

---

## 📋 Overview

Đóng gói các issue phát hiện từ phiên họp review Analytics & Reporting. Tập trung vào việc vá lỗi Cache trên Redis (sập hệ thống vì lệnh KEYS, Go Panic do dùng Interface {}), tối ưu hóa Transaction và SQL Locking cho Aggregation Jobs (Conversion Funnel, Staging Data) để ngăn rác ổ cứng Postgres.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Thay thế nguy cơ sập Redis `KEYS` bằng `SCAN`

**File**: `analytics/internal/data/metrics_repository.go`
**Lines**: `64-70`
**Risk**: Lệnh `KEYS *` sẽ block Single-Thread của Redis trên production khi số lượng keys lớn (O(N) operations), gây connection timeout cho toàn bộ microservices khác.
**Problem**: Hàm `InvalidateCache` đang dùng `KEYS`.

**Fix**:
Sử dụng hàm Iterate/SCAN phân trang của Redis client để quét key an toàn hơn.
```go
// BEFORE:
keys, err := r.redis.Keys(ctx, pattern).Result()
if err != nil {
    // ...
}
if len(keys) > 0 {
    err = r.redis.Del(ctx, keys...).Err()
}

// AFTER:
iter := r.redis.Scan(ctx, 0, pattern, 100).Iterator()
var keys []string
for iter.Next(ctx) {
    keys = append(keys, iter.Val())
    // Xóa theo batch nhỏ để tránh command vượt quá buffer của Redis
    if len(keys) >= 100 {
        if err := r.redis.Del(ctx, keys...).Err(); err != nil {
            r.log.Errorf("Failed to delete batch keys: %v", err)
        }
        keys = []string{}
    }
}
if err := iter.Err(); err != nil {
    return fmt.Errorf("failed to scan keys: %w", err)
}
if len(keys) > 0 {
    if err := r.redis.Del(ctx, keys...).Err(); err != nil {
        return fmt.Errorf("failed to delete remaining keys: %w", err)
    }
}
```

**Validation**:
```bash
cd analytics && go test ./internal/data/... -run Cache
```

---

### [ ] Task 2: Fix lỗi Panic Type Assertion do `json.Unmarshal` vào `interface{}`

**File**: `analytics/internal/data/metrics_repository.go` (Method `GetCachedMetrics`)
**Risk**: Struct JSON lưu ở Redis chứa các properties như `float64` hoặc nested structs. Khi gọi `json.Unmarshal` vào biến có kiểu trung gian `interface{}`, cấu trúc nguyên thủy sẽ biến thành `map[string]interface{}`. Khi phía logic Usecase gọi ép kiểu ngược về `*biz.DailyMetrics` sẽ gây Panic (Crash tiến trình Go).
**Problem**: Hàm `GetCachedMetrics` trả về `interface{}`.

**Fix**:
Đổi Signature của Interface `biz.MetricsRepository` và struct triển khai, cho phép truyền con trỏ kiểu Dữ liệu mong muốn.
```go
// BEFORE
func (r *metricsRepository) GetCachedMetrics(ctx context.Context, key string) (interface{}, error) {
    // ...
    var result interface{}
    if err := json.Unmarshal([]byte(data), &result); err != nil { ... }
    return result, nil
}

// AFTER
func (r *metricsRepository) GetCachedMetrics(ctx context.Context, key string, dest interface{}) error {
    data, err := r.redis.GetString(ctx, key)
    if err != nil {
        if err.Error() == "redis: nil" {
            return nil // Hoặc define custom ErrCacheMiss
        }
        return fmt.Errorf("failed to get cached metrics: %w", err)
    }

    if err := json.Unmarshal([]byte(data), dest); err != nil {
        return fmt.Errorf("failed to unmarshal cached metrics: %w", err)
    }

    return nil
}
```
*Lưu ý: Sau khi sửa `GetCachedMetrics`, developer phải quét các file ở tầng `internal/biz/` đang dùng hàm này để cập nhật lại cách gọi. (VD: truyền `&dailyMetrics` thay vì nhận `result`).*

**Validation**:
```bash
cd analytics && go build ./...
golangci-lint run ./...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Cấp DB Transaction DB cho Process Tính Toán Của Warehouse (Product Performance Staging)

**File**: `analytics/internal/data/repo_aggregation.go`
**Lines**: `159-232`
**Risk**: Hàm `AggregateProductPerformance` chia làm 3 blocks SQL độc lập (`execWithTimeout`): INSERT Staging, UPSERT vào Report chính, DELETE Staging. Nếu khối lệnh Upsert bị đứt gãy/timeout giữa chừng, đoạn DELETE cuối cùng sẽ không chạy. Bảng Staging sẽ kẹt file rác mãi mãi, cứ qua mỗi ngày càng làm sình DB.
**Problem**: Bỏ qua sức mạnh của Transaction trong ETL job.

**Fix**:
Gom lệnh `Exec` thành block lệnh Transaction `tx`.
```go
// BEFORE
if err := r.execWithTimeout(ctx, stageQuery, date); err != nil { ... }
if err := r.execWithTimeout(ctx, upsertQuery, date); err != nil { ... }
if err := r.execWithTimeout(ctx, cleanupQuery, date); err != nil { ... }

// AFTER
tx, err := r.db.BeginTx(ctx, nil)
if err != nil { return fmt.Errorf("failed to start staging transaction: %w", err) }
defer func() { _ = tx.Rollback() }()

if _, err := tx.ExecContext(ctx, stageQuery, date); err != nil { return err }
if _, err := tx.ExecContext(ctx, upsertQuery, date); err != nil { return err }
if _, err := tx.ExecContext(ctx, cleanupQuery, date); err != nil { return err }

if err := tx.Commit(); err != nil { return err }
// ...
```

**Validation**:
```bash
cd analytics && go test ./internal/data/... -run ProductPerformance -v
```

---

### [ ] Task 4: Fix Consistency Update Conversion Funnel (Xây tường Transaction)

**File**: `analytics/internal/data/repo_aggregation.go`
**Lines**: `494-571`
**Risk**: Hàm `UpdateConversionFunnel` dùng một vòng lặp `for` chạy tuần tự 5 stage. Nếu có lỗi mạng xảy ra ở vòng nhảy stage 3, Funnel của ngày hôm đó sẽ lưu được nửa vời. Dashboard sẽ bị méo mó số liệu.
**Problem**: Tương tự như trên, vòng map của Go `for _, stage := range stages` đang không được lock bảo vệ.

**Fix**:
Thêm Transaction `BeginTx` bọc NGOÀI/XUYÊN SUỐT vòng lặp `for`. Ensure data Atomicity.

**Validation**:
```bash
cd analytics && go build ./...
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 5: Parametrize (Tham Số Hóa) Trọng Số Tính Điểm Popularity

**File**: `analytics/internal/data/repo_aggregation.go`
**Lines**: `201-204`
**Problem**: Tiêu chí `popularity_score` đang bị khóa cứng mã trong SQL `(views * 0.1 + cart_adds * 0.3 + ... + purchase * 1.0)`. Usecase không thể tùy biến điểm khi Business cần.
**Fix**: Sửa Struct đầu vào truyền thêm `weights` parameter map xuống Repository Query Args để cho phép linh hoạt thay đổi trọng số trong bảng Settings sau này.

---

## 🔧 Pre-Commit Checklist

```bash
cd analytics && wire gen ./cmd/server/ ./cmd/worker/
cd analytics && go build ./...
cd analytics && go test -race ./...
cd analytics && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
fix(analytics): address meeting review analytics tech debt

- fix: replace redis KEYS wildcard with SCAN pagination to prevent blockage inside invalidateCache
- fix: panic on unmarshal to interface{} in cache get by switching to ptr dest
- fix: wrap product performance staging logic into single atomic database transaction
- fix: wrap conversion funnel stages computation array loop in transaction
- refactor: decoupling weights coefficients in popularity calculation

Closes: AGENT-04
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Mảng InvalidateCache xử lý bằng SCAN loop an toàn | Code Review chứng minh không còn `redis.Keys()` | |
| Metric Cache được Unmarshal đúng Data type | Gõ lệnh Go Build toàn bộ service không có conflict Type Cast | |
| ETL Staging xử lý bằng 1 Transaction duy nhất | Code Analysis - `BeginTx()` usage | |
