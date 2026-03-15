# AGENT-36: Loyalty-Rewards Service Hardening

Status: OPEN
Priority: HIGH

Based on the multi-agent meeting review report, the following issues MUST be fixed in `loyalty-rewards` service:

## P0: Critical Business Logic & DevOps Blockers
- [X] **Fix Redis CrashLoopBackOff (NOAUTH)**: `loyalty-rewards` Dev pod is crashing because of Redis connection error (`NOAUTH Authentication required`). The `LOYALTY_REWARDS_DATA_REDIS_PASSWORD` from environment variables is not being correctly mapped to Viper configuration in `configs/config.yaml`. Fix the config loading.
- [X] **Fix Stubbed Referral Bonus**: In `internal/biz/account/account.go`, the function `awardReferralBonus(ctx context.Context, referrerCustomerID string)` just logs a message. It needs to actually award points to the referrer and referee. This should be done via event publishing to the referral domain or by invoking the referral usecase directly.

## P1: Security & Race Condition Fixes
- [X] **Secure Random for Referral Codes**: In `internal/biz/account/account.go`, replace `math/rand` in `generateReferralCode` with `crypto/rand` or ULID generation to prevent code guessing and abuse.
- [X] **Secure Random for Redemption Codes**: In `internal/biz/redemption/redemption.go`, replace `math/rand` in `generateRedemptionCode` with `crypto/rand` or ULID generation.
- [X] **Atomic DB Stock deduction**: In `internal/biz/redemption/redemption.go` around line 156, the checking of `reward.Stock` and updating is prone to race conditions. Modify the repository logic or the GORM update to execute atomic SQL (`UPDATE rewards SET stock = stock - 1 WHERE id = ? AND stock > 0`).

## P2: Code Quality and Maintenance
- [X] **Handle Cache Errors Appropriately**: In `internal/biz/account/account.go`, cache functions like `SetAccount` are returning errors that are explicitly ignored (`_ = uc.accountCache.SetAccount`). Log these errors at a `Warn` or `Error` level so caching failures trigger monitors.
- [X] **Refactor `biz/loyalty.go`**: Clean up `internal/biz/loyalty.go`. Move any remaining active structs/interfaces to their proper bounded contexts (`biz/account`, `biz/transaction`) and deprecate the file.
- [X] **Use builtin min()**: Refactor custom `min(a, b int)` in `internal/biz/account/account.go` and utilize the `math` package or Go 1.21+ builtin.

## Completion Criteria
- [X] Unit tests pass with go test (`go test ./...`)
- [X] Pre-commit commands complete successfully (`wire gen ./...`, `go build ./...`, `golangci-lint run`)
- [X] No regressions in current loyalty functionality.
