# Notification Flow - Code Review Issues

**Last Updated**: 2026-01-18

This document lists issues found during the review of the Notification Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

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
