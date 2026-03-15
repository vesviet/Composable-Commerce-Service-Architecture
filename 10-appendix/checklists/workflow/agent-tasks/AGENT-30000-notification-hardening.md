# AGENT-30000: Notification Service Meeting Review Hardening

## 1. Context
This task encapsulates the P1 and P2 improvements identified during the Multi-Agent Meeting Review (`notification_review.md`).
The goal is to harden the worker throughput and ensure distributed safety for Rate Limiting.

## 2. Issues to Fix

### [ ] P1: Remove Blocking Sleep in Event Consumer
**File:** `internal/data/eventbus/notification_created_consumer.go`
- Consumer is currently performing `time.Sleep()` during max 3 retries.
- **Action:** Remove the `time.Sleep` loop. If processing/sending fails, we should let the existing continuous cron `NotificationWorker` pick it up from the DB `failed` state and retry it asynchronously with backoff. We just mark it processed in the outbox so Dapr doesn't re-deliver the same payload over and over.

### [ ] P1: Atomic Redis Counter for Rate Limiting
**File:** `internal/biz/notification/notification_usecase.go` or `internal/data/postgres/notification_repo.go` -> update to Redis.
- **Action:** Enhance `CountDailyNotifications` to utilize Redis `INCR` with an expiry instead of a `SELECT COUNT(*)` on PostgreSQL to avoid race conditions when multiple worker goroutines evaluate the same user's rate limits simultaneously.

### [ ] P2: Refactor Circuit Breaker String Literals to Constants
**File:** `internal/biz/notification/sender.go`
- **Action:** Define constants like `CBKeyEmailSendGrid`, `CBKeySMSTwilio`, `CBKeyPushFirebase`, etc., and replace the hardcoded strings in `s.cbManager.GetOrCreate(...)`.

## 3. Validation
- Run `go test ./... -v`
- Run `golangci-lint run`
- Use Mock Redis to test atomic increments if writing tests.
