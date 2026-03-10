# AGENT-14: Return & Refund Service Hardening

> **Created**: 2026-03-10
> **Priority**: P0 (2), P1 (2), P2 (1)
> **Sprint**: Tech Debt Sprint
> **Services**: `return`
> **Estimated Effort**: 3 days
> **Source**: [Return & Refund Flows Meeting Review Artifact](file:///home/user/.gemini/antigravity/brain/1f3dc9c7-4eac-42c6-925f-8247a7110022/return_refund_review.md)

---

## 📋 Overview

Đóng gói các issue phát hiện từ phiên họp review 50-round M+N Return. Tập trung vào việc vá lỗ hổng Over-Refund khi khách hàng gửi nhiều Return Requests, sửa lỗi nuốt Error khi sinh Event, sửa lỗi tính toán hạn đổi trả (30-day Timezone Bug), và gỡ bỏ Block Level Order khi đổi trả lẻ từng kiện hàng. 

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [ ] Task 1: Fix Partial Return Over-Refund Vulnerability

**File**: `return/internal/biz/return/return_creation.go`
**Lines**: `217-224`
**Risk**: Khách hàng có thể "bào" tiền của hệ thống do logic giới hạn `totalRefundAmount = order.TotalAmount` hiện tại chỉ có hiệu lực TRÊN MỘT REQUEST. Nếu khách tạo N request cho N item của order, họ có thể đòi refund vuợt quá giá trị thanh toán ban đầu của cả Order.
**Problem**: Logic chưa query tổng refund của các đợt đổi trả trước.

**Fix**:
Tích hợp hàm lấy tổng historical refund và trừ nó vào Total Amount gốc để bảo vệ.

```go
// BEFORE
// Over-refund guard: cap total refund at order total paid amount
if order != nil && order.TotalAmount > 0 && totalRefundAmount > order.TotalAmount {
    uc.log.WithContext(ctx).Warnf(
        "Refund amount %.2f exceeds order total %.2f — capping to order total",
        totalRefundAmount, order.TotalAmount)
    totalRefundAmount = order.TotalAmount
}

// AFTER
if order != nil && order.TotalAmount > 0 {
    // TÍNH TOÁN LỊCH SỬ REFUND BẰNG CÁCH LẤY CÁC RETURN CŨ
    var historicalRefund float64
    for _, r := range existingList { // Dùng biến existingList từ trên
        if r.Status == "completed" || r.Status == "approved" || r.Status == "processing" {
            historicalRefund += r.RefundAmount
        }
    }
    
    maxAllowedRefund := order.TotalAmount - historicalRefund
    if maxAllowedRefund < 0 {
        maxAllowedRefund = 0 // Incase of data anomaly
    }

    if totalRefundAmount > maxAllowedRefund {
        uc.log.WithContext(ctx).Warnf(
            "Refund amount %.2f + historical %.2f exceeds order total %.2f — capping to remaining: %.2f",
            totalRefundAmount, historicalRefund, order.TotalAmount, maxAllowedRefund)
        totalRefundAmount = maxAllowedRefund
    }
}
```

**Validation**:
```bash
cd return && go test ./internal/biz/return/... -run TestReturnCreationOverRefund -v
# Nếu chưa có test thì bổ sung Mock Order có existingList với RefundAmount = 50, thử xin thêm 60, expect bị cap.
```

---

### [ ] Task 2: Fix Missing Event Rò rỉ Transaction (Marshal Panic)

**File**: `return/internal/biz/return/return_creation.go`
**Lines**: `231-250`
**Risk**: Lỗi parse JSON payload không được báo lỗi ra ngoài, khiến Payload=nil, qua mặt dòng 240 và SKIP Outbox event nhưng DB Tranaction vẫn Commit. Ghost returns exist in DB nowhere else.
**Problem**: Bỏ qua `_` error.

**Fix**:
```go
// BEFORE
if req.ReturnType == "exchange" {
    reqEventType = "orders.exchange.requested"
    reqEventPayload, _ = json.Marshal(uc.buildExchangeRequestedEvent(returnRequest, orderNumber))
} else {
    reqEventType = "orders.return.requested"
    reqEventPayload, _ = json.Marshal(uc.buildReturnRequestedEvent(returnRequest, orderNumber))
}
if reqEventPayload != nil {
    // ...
}

// AFTER
var marshalErr error
if req.ReturnType == "exchange" {
    reqEventType = "orders.exchange.requested"
    reqEventPayload, marshalErr = json.Marshal(uc.buildExchangeRequestedEvent(returnRequest, orderNumber))
} else {
    reqEventType = "orders.return.requested"
    reqEventPayload, marshalErr = json.Marshal(uc.buildReturnRequestedEvent(returnRequest, orderNumber))
}

if marshalErr != nil {
    return fmt.Errorf("failed to marshal events for %s outbox: %w", reqEventType, marshalErr)
}

if reqEventPayload != nil {
    // outbox logic
```

**Validation**:
```bash
cd return && go build ./...
golangci-lint run ./...
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [ ] Task 3: Fix Eligibility 30-Day Window (Timezone EOD Bug)

**File**: `return/internal/biz/return/return_creation.go`
**Lines**: `308-316`
**Risk**: Tính số ngày EOD bằng Timezone UTC/Local không đồng bộ với Business spec, chặn khách hợp lệ (ví dụ: bị chặn vào chiều ngày thứ 30).
**Problem**: `time.Since(*order.CompletedAt) > 30*24*time.Hour`
**Fix**:
```go
// BEFORE
if time.Since(*order.CompletedAt) > 30*24*time.Hour {
    return &CheckReturnEligibilityResponse{Eligible: false, Reason: "Return window expired (30 days from delivery)"}, nil
}

// AFTER
expirationTime := order.CompletedAt.AddDate(0, 0, 30)
if time.Now().After(expirationTime) {
    return &CheckReturnEligibilityResponse{Eligible: false, Reason: "Return window expired (30 days from delivery)"}, nil
}
```

**Validation**:
```bash
cd return && go test ./internal/biz/return/... -run Eligibility
```

---

### [ ] Task 4: Chặn Hoàn Tiền nếu Restocking Fee > RefundAmount Sớm 

**File**: `return/internal/biz/return/refund.go` & `return_creation.go` 
**Risk**: RefundAmount <= 0 bị check lẳng lặng giấu lỗi ở worker (refund.go), user không biết và tiền không hoàn mà return vẫn Complete.
**Fix**:
Dùng `return_creation.go` (trong loop tạo Item) hoặc ở End of creation, check:
```go
// Chặn nếu refund fee đã tính bị rớt về <= 0
// Cần implement hàm validation RestockingFee trong creation thay vì để dành tới phase RefundWorker
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [ ] Task 5: Change "Active Return Request" Check from Order-Level to Item-Level

**File**: `return/internal/biz/return/return_creation.go`
**Lines**: `75-84`
**Risk**: Ngăn cản user tạo các yêu cầu Return khác nhau cho các mặt hàng (OrderItem) khác nhau nếu kiện gửi thành nhiều hộp.
**Problem**: Trả exception trực tiếp nếu order có any active `pending/approved/processing` request.
**Fix**:
- Lấy `ItemReq.OrderItemID` từ `req.Items`.
- Khi Query `existingRequests`, ta parse các `ReturnItems` của nó.
- Chỉ Block nếu `req.Items` có chứa `OrderItemID` nằm trong Active Existing Request nào đó.

**Validation**:
```bash
cd return && go build ./...
```

---

## 🔧 Pre-Commit Checklist

```bash
cd return && wire gen ./cmd/server/ ./cmd/worker/
cd return && go build ./...
cd return && go test -race ./...
cd return && golangci-lint run ./...
```

---

## 📝 Commit Format

```text
fix(return): address meeting review return-refund tech debt

- fix: partial return over-refund bug capping logic
- fix: silent panic marshal error inside txn causing ghost returns
- fix: 30-day eligibility logic using proper EOD dates
- feat: lift restocking fee cap validation to request creation
- refactor: narrow active return locking to order-item level

Closes: AGENT-14
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| M+N returns sum up previous refund items correctly to guard over-refund | DB Check OR Unit test with existing refunds |  |
| Event Marshal error correctly aborts the transaction | Simulation test |  |
| 30 days calculation is properly bounded | Date simulation |  |
| User can create multiple returns for DIFFERENT items | E2E or Unit Test |  |
