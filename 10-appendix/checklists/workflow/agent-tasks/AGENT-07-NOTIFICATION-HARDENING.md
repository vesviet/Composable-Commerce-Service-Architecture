# AGENT-07: Notification Service Hardening

> **Created**: 2026-03-09
> **Priority**: P0 (Architectural Latency & Consistency)
> **Sprint**: Hardening Sprint
> **Services**: `notification`
> **Estimated Effort**: 4-6 days
> **Source**: Notification Service Intensive Meeting Review (50 Rounds)

---

## 📋 Overview

The Notification service requires hardening to fix a critical bug in webhook processing that prevents status updates, shift from DB polling to event-driven processing to reduce latency, and fix N+1 performance bottlenecks in template localization.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Webhook Notification ID Lookup Bug

**Files**: `internal/biz/delivery/delivery.go`, `internal/repository/notification/notification.go`
**Risk**: Data Corruption / Desync. Webhook status updates (delivered, bounced) are never propagated to the base `Notification` because of a data type mismatch in the lookup.
**Problem**: Line 218 uses `fmt.Sprintf("%d", deliveryLog.NotificationID)` where `deliveryLog.NotificationID` is an `int64` internal PK. `GetByID` expects the UUID `string` `notification_id`.
**Fix Applied**:
1. Added `GetByInternalID(ctx context.Context, id int64)` to the `NotificationRepo` interface and its GORM implementation.
2. Updated `ProcessWebhook` to call `uc.notificationRepo.GetByInternalID(ctx, deliveryLog.NotificationID)` instead of `GetByID(ctx, fmt.Sprintf(...))`.

---

### [x] Task 2: Event-Driven Processing vs Polling Latency

**Files**: `cmd/worker/notification_worker.go`, `cmd/worker/wire.go`, `internal/data/eventbus/notification_created_consumer.go`, `internal/data/provider.go`
**Risk**: Latency. Transactional emails (like OTPs) can take up to 30s to send because the worker polls the DB every 30 seconds.
**Problem**: The service publishes a `notification.created` outbox event but doesn't consume it.
**Fix Applied**:
1. Created `NotificationCreatedConsumer` in `internal/data/eventbus/notification_created_consumer.go` to consume `notification.created` events via Dapr PubSub.
2. Registered consumer in worker's Wire providers and `newWorkers` function.
3. Refactored the cron job to process only scheduled/stuck-pending and retry notifications; immediate delivery is now event-driven.

---

### [x] Task 3: Secure Webhook Processing

**Files**: `internal/biz/delivery/delivery.go`, `internal/config/config.go`, `configs/config.yaml`
**Risk**: Unauthorized state manipulation.
**Problem**: If `WebhookValidationEnabled` is false, anonymous internet traffic can alter notification statuses.
**Fix Applied**:
1. `validateWebhookSignature` now falls back to `validateWebhookSecretToken` when provider-specific validation is disabled, instead of returning nil.
2. Added `WebhookSecretToken` to `NotificationConfig` — requires a high-entropy secret token in the webhook URL/header.
3. If neither provider validation nor secret token is configured, returns a clear error.

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Fix N+1 Query in i18n Template Rendering

**Files**: `internal/biz/template/template.go`
**Risk**: High Latency & Resource Exhaustion.
**Problem**: `resolveI18nMessages` loops over regex matches and executes a synchronous RPC call for *every single key*.
**Fix Applied**:
1. Extracts all `{{i18n:key}}` matches and unique keys first.
2. Calls `messageUC.GetMessages` (existing bulk API) once with all keys.
3. Replaces keys in memory from the pre-fetched map — O(N) RPCs → O(1).

---

### [x] Task 5: Fix Idempotency Scope Collision

**Files**: `internal/biz/notification/notification_usecase.go`, `internal/repository/notification/notification.go`
**Risk**: Missing Notifications. If an order triggers an Email and an SMS using the same `CorrelationID` (e.g., `order-12345`), the second notification is silently swallowed as a duplicate.
**Fix Applied**: Updated `FindByCorrelationID` to accept a `channel` parameter and scope the query by `correlation_id + channel`.

---

## 🔧 Pre-Commit Checklist

```bash
cd notification && wire gen ./...
cd notification && go build ./...
cd notification && go test ./...
cd notification && golangci-lint run ./...
```

---

## 📝 Commit Format

```
fix(notification): resolve webhook id bug and implement event-driven processing

- fix: lookup notification by correct internal ID during webhook updates
- refactor: replace 30s DB polling with notification.created event consumer
- perf: eliminate template N+1 RPC queries by fetching i18n keys in bulk
- fix: scope idempotency correlation checks by delivery channel

Closes: AGENT-07
```
