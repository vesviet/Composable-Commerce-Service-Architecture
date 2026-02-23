# Notification Flow - Code Review Issues

**Last Updated**: 2026-01-21

This document lists issues found during the review of the Notification Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [NOTIF-P1-01 Fire-and-forget send]: `SendNotification` uses unmanaged goroutine. Required: persist pending notifications and process via worker with retries. See `notification/internal/biz/notification/notification.go`.
- [Medium] [NOTIF-P2-01 Direct synchronous calls to notification]: Services call notification directly and synchronously. Required: decouple via events and subscribe in notification service. See `order/internal/biz/status/status.go`.
- [Medium] [NOTIF-P2-02 Sender implementations incomplete]: `email`, `sms`, `push` are TODO. Required: implement providers + retry/error mapping. See `notification/internal/biz/notification/sender.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- None

## ✅ RESOLVED / FIXED
- None

## Resolution Plan (Actionable Checklist)

### 1) Durability & Retries for Notification Sends (P1)

- [ ] **Add persistent queueing**: store a `pending` notification record and process via a background worker.
- [ ] **Retry strategy**: exponential backoff with jitter; cap retries and mark `failed` with reason.
- [ ] **Idempotency**: ensure repeated delivery attempts do not duplicate external sends.
- [ ] **Observability**: metrics for `pending`, `sent`, `failed`, `retry_count`, and latency.

**Acceptance Criteria**:
- API returns after record creation only; delivery happens in worker.
- If the service crashes after API returns, pending notifications are still delivered.
- Transient failures are retried; permanent failures are surfaced with reason.

### 2) Decouple via Events (P2)

- [ ] **Publish events**: emit domain events from source services (e.g., `order.status_changed`).
- [ ] **Subscribe**: notification service subscribes and determines if a notification is required.
- [ ] **Schema**: add JSON schema under `docs/json-schema/` for each event.

**Acceptance Criteria**:
- Source services no longer call notification synchronously for status changes.
- Notification service processes events asynchronously and independently.

### 3) Complete Sender Implementations (P2)

- [ ] **Email**: integrate provider (e.g., SendGrid) with retries and provider error mapping.
- [ ] **SMS**: integrate provider (e.g., Twilio) with rate limits and failover handling.
- [ ] **Push**: integrate provider (e.g., FCM/APNs) with token hygiene.

**Acceptance Criteria**:
- `email`, `sms`, `push` channels are fully implemented and tested.
- Failures return actionable error types and are retried when transient.

---

---

## P1 - Concurrency / Reliability

- **Issue**: Notification sending is "fire and forget" using an unmanaged goroutine.
  - **Service**: `notification`
  - **Location**: `notification/internal/biz/notification/notification.go` (`SendNotification` function)
  - **Impact**: This provides no guarantee of delivery. If the application crashes after the API call returns but before the goroutine completes, the notification is lost forever. There is no built-in mechanism for retrying failed sends, which is critical for transactional notifications like order confirmations.
  - **Recommendation**: Replace the goroutine with a durable job queue. The `SendNotification` API should only be responsible for creating the `Notification` record with a `pending` status. A separate, persistent background worker should poll the database for `pending` notifications, attempt to send them, and implement a retry strategy with exponential backoff for transient failures.

---

## P2 - Architecture

- **Issue**: Tightly coupled integration via direct, synchronous API calls.
  - **Services**: `notification`, `order`, `customer`, etc.
  - **Location**: e.g., `order/internal/biz/status/status.go`
  - **Impact**: This creates tight coupling. If the `notification` service is slow or unavailable, it can degrade the performance and availability of the calling service (e.g., an `order` status update could be delayed).
  - **Recommendation**: Decouple the services using an event-driven approach. Instead of making direct calls, source services should publish business events (e.g., `order.status_changed`). The `notification` service should then subscribe to these events and contain its own logic to decide if a notification needs to be sent. This makes the entire system more resilient and scalable.

---

## P2 - Incomplete Implementation

- **Issue**: The `NotificationSender` is incomplete.
  - **Service**: `notification`
  - **Location**: `notification/internal/biz/notification/sender.go`
  - **Impact**: The service cannot fulfill its primary function for the most common notification channels, as the logic for "email", "sms", and "push" are `TODO` placeholders.
  - **Recommendation**: Implement the sender logic for the remaining channels by integrating with third-party providers (e.g., SendGrid for email, Twilio for SMS).
