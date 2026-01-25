# 📋 Loyalty-Rewards Service Refactor Checklist

This checklist is based on the [TEAM_LEAD_CODE_REVIEW_GUIDE.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md) and current code state of the Loyalty-Rewards service.

## 🚩 PENDING ISSUES (Unfixed)

### 🚨 P0 (Blocking) - Data Integrity & Stability
- [ ] **Missing Transactions (Multi-Write Atomicity)**:
    - [ ] `TransactionUsecase.EarnPoints`: Transaction creation + Balance update + Tier upgrade must be atomic.
    - [ ] `TransactionUsecase.RedeemPoints`: Transaction creation + Balance update must be atomic.
    - [ ] `AccountUsecase.CreateAccount`: Account creation + Initialization must be atomic.
- [ ] **Race Conditions (Balance Updates)**:
    - [ ] Use `gorm.Expr` or atomic increments for `CurrentPoints` and `LifetimePoints` to prevent data corruption during concurrent requests.
- [ ] **Unmanaged Goroutines**:
    - [ ] `AccountUsecase.awardReferralBonus`: Refactor to use `errgroup` or a managed worker pool/async task queue.

### 🟡 P1 (High) - Logic & Validation
- [ ] **Input Validation**:
    - [ ] Ensure all Biz layer entry points validate inputs using the common validation framework.
- [ ] **Context Propagation**:
    - [ ] Verify `context.Context` is correctly passed and respected in all repository calls and internal logic.

### 🔵 P2 (Normal) - Engineering Standards
- [ ] **Error Handling**:
    - [ ] Log caching errors instead of swallowing them.
    - [ ] Ensure proper error wrapping and mapping to gRPC/HTTP status codes.
- [ ] **Test Coverage**:
    - [ ] Add/Update tests to cover transaction logic and concurrent updates.

## ✅ RESOLVED / FIXED
- (None yet)
