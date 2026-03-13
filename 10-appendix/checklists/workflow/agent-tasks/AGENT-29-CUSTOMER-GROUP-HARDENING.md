# AGENT-29: Customer Service & Group Expansion Hardening

> **Created**: 2026-03-13
> **Priority**: P0 & P1
> **Sprint**: Tech Debt & Feature Sprint
> **Services**: `customer`
> **Estimated Effort**: 2-3 days
> **Source**: [Customer Service Meeting Review Report](../../../../../../.gemini/antigravity/brain/86efccc2-4278-4505-952e-382b4ba93683/customer_service_group_review.md)

---

## 📋 Overview

Định nghĩa Domain Model và Proto cho bảng thiết lập `StableCustomerGroup` mở rộng hỗ trợ môi trường e-commerce chuyên nghiệp (B2B, Khách VIP) đã được hoàn tất. Giờ đây cần triển khai mã nguồn ở mức infrastructure (Database Migrations), Outbox & Event-driven design cùng refactor kiến trúc caching.

### Architecture/Flow Context Diagram
* Customer Service cần tạo thêm Schema Table.
* Dapr Event Subscriber ở Worker Consumer đóng vai trò auto-upgrade Customer lên Group mới (VIP/Wholesales) khi `TotalSpent` đạt tiêu chuẩn. 
* Context Middleware để luân chuyển metadata Group vào Redis nhằm loại bỏ N+1 Cache Invalidation.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Generate & Apply DB Migration for Customer Group

**File**: `customer/migrations/0000X_add_b2b_fields_to_customer_group.sql`
**Risk**: Data model được define trong struct Go và Proto bị lỗi OutOfSync nếu không có migration tương ứng, gây panic hoặc silent failures khi create/update qua GORM.
**Problem**: Bảng `customer_groups` hiện tại thiếu các cột `is_tax_exempt`, `pricing_tier`, `requires_approval`, `payment_terms`, `max_credit_limit`.
**Fix**:
Tạo migration file mới dùng lệnh Goose:
```sql
-- +goose Up
-- SQL in section 'Up' is executed when this migration is applied
ALTER TABLE customer_groups
    ADD COLUMN is_tax_exempt BOOLEAN DEFAULT false,
    ADD COLUMN pricing_tier VARCHAR(100) DEFAULT '',
    ADD COLUMN requires_approval BOOLEAN DEFAULT false,
    ADD COLUMN payment_terms VARCHAR(50) DEFAULT '',
    ADD COLUMN max_credit_limit BIGINT DEFAULT 0;

-- +goose Down
-- SQL section 'Down' is executed when this migration is rolled back
ALTER TABLE customer_groups
    DROP COLUMN is_tax_exempt,
    DROP COLUMN pricing_tier,
    DROP COLUMN requires_approval,
    DROP COLUMN payment_terms,
    DROP COLUMN max_credit_limit;
```

**Validation**:
```bash
cd customer && make migrate-up
# Verify Database changes
```

### [ ] Task 2: Caching Key Isolation cho CustomerGroup

**File**: `customer/internal/biz/customer_group/cache.go` (Cần tạo hoặc refactor)
**Risk**: Invalidate customer cache chứa group config sẽ gây cache storm (N+1 invalidate) khi 10,000 customers có trong 1 group đổi config.
**Problem**: Logic attach Customer Group attributes thẳng vào Customer Hash Cache dẫn tới blocking operations ở Redis khi update Group.
**Fix**:
1. Tách logic caching của Customer Group thành prefix độc lập: `customer_group:{id}` thay vì lưu gộp trong `customer:{id}`.
2. Thiết lập Kratos Middleware đọc Header Request (có JWT chứa `group_id`), lookup giá trị từ cache `customer_group:{id}` và inject vào context (`context.WithValue()`).
3. Khi `CustomerGroup` thay đổi (Admin Update), CHỈ invalidate / update khoá `customer_group:{id}`. 

**Validation**:
```bash
cd customer && go test ./internal/biz/customer_group/... -run TestCustomerGroupCacheIsolation -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 3: Auto-Upgrade Worker qua Dapr + Outbox

**File**: `customer/internal/worker/event_consumer.go` và Event Handler tương ứng.
**Risk**: KHÔNG TỰ ĐỘNG UPGRADE khách hàng. Ảnh hưởng trực tiếp đến CX (Trải nghiệm người mua) khi đạt `TotalSpent` nhưng không được upgrade.
**Problem**: `OrderCompletedEvent` không kích hoạt auto-upgrade.  Thiếu Consumer từ Outbox flow.
**Fix**:
1. Đăng ký Dapr subscription Topic `order.completed`.
2. Hứng event ở `CustomerWorker`. Cộng dồn số tiền vào field `TotalSpent`.
3. Trong cùng 1 Transaction (`InTx`), kiểm tra rule "Nếu TotalSpent > 100k -> Update CustomerGroupID -> Insert `CustomerGroupChangedEvent` vào Outbox_repo". 

**Validation**:
```bash
cd customer && go test ./internal/worker/... -run TestAutoUpgradeWorkerTx -v
```

### [x] Task 4: Regenerate Proto Code & Implementation Updates

**File**: `customer/internal/service/customer_group.go` (Hoặc file handler tương ứng)
**Risk**: Code Service Layer không map các fields mới được định nghĩa từ Protobuf vào Domain Entity dẫn đến DB không được persist.
**Problem**: Logic của gRPC handlers API như `CreateCustomerGroup` và `UpdateCustomerGroup` chưa bind các trường: `IsTaxExempt`, `PricingTier`, `MaxCreditLimit` (int64) sang model.
**Fix**:
1. Chạy sinh code `protoc` (hoặc `make proto`)
2. Bổ sung việc map các fields mới bên trong `Create` và `Update` logic (e.g. `req.MaxCreditLimit` -> `domain.MaxCreditLimit`). 
3. Thêm log Info khi Group Entity thay đổi ở hệ thống (Dùng Kratos structured logger).

**Validation**:
```bash
cd customer && make proto && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd customer && wire gen ./cmd/server/ ./cmd/worker/
cd customer && make proto
cd customer && go build ./...
cd customer && go test -race ./...
cd customer && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
feat(customer): implement B2B extended customer group domain

- fix(customer): add schema migrations for 5 b2b customer group fields
- refactor(customer): isolate group cache keys to avoid cache storm
- feat(customer): add dapr subscriber for automatic tier upgrade outbox flow
- feat(customer): regenerate pb files and map extended fields in service

Closes: AGENT-29
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| PostgreSQL table `customer_groups` updated with B2B fields | Migrate Up thành công | |
| Cập nhật group không gây chậm trên Redis | Chạy benchmark / test logic cache in isolation | |
| User đạt tổng mua > 100k được đổi ID Group tự động | Trigger unit test giả lập order completed | |
| Proto Service map đúng dữ liệu vào Domain Entity | `go build` không lỗi type mismatch và API test thành công | |
