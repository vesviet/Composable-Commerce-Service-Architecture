# Notification Flow

**Last Updated**: 2026-01-18
**Status**: Verified vs Code

## Overview

This document describes the flow for sending transactional notifications (email, SMS, etc.) to users. The system uses a centralized `notification` service that is called by other microservices.

**Key Files:**
- **Usecase**: `notification/internal/biz/notification/notification.go`
- **Sender Logic**: `notification/internal/biz/notification/sender.go`
- **Example Callers**:
    - `order/internal/biz/status/status.go`
    - `customer/internal/biz/customer/auth.go`

---

## Key Flows

### 1. Notification Triggering (Direct Call)

The current architecture uses a direct-call pattern to trigger notifications.

1.  **Initiator**: A source service (e.g., `order`, `customer`) needs to send a notification.
2.  **API Call**: The source service makes a direct, synchronous gRPC/HTTP call to the `notification` service's `SendNotification` endpoint.
3.  **Payload**: The request includes all necessary information, such as recipient details (email, phone), channel (email, sms), and content or a template ID with data.

### 2. Notification Processing (in `notification` service)

- **Function**: `SendNotification` in `notification.go`
- **Logic**:
  1.  **User Preferences Check**: If a `recipient_id` is provided, the service first checks the user's notification preferences. If the user has globally unsubscribed or disabled the specific channel, the process is aborted silently (which is correct behavior to respect user settings).
  2.  **DB Record Creation**: A `Notification` record is created in the database with a `pending` status. This provides an audit trail for all notification attempts.
  3.  **Asynchronous Sending**: The service then launches a **detached, unmanaged goroutine** (`go func()`) to perform the actual sending via the `NotificationSender`.
  4.  **Immediate Response**: The `SendNotification` API call returns a successful response to the calling service as soon as the record is created in the database, without waiting for the actual delivery to complete.

### 3. Notification Delivery

- **File**: `sender.go` (`SendNotification` function)
- **Logic**:
  1.  The `NotificationSender` acts as a dispatcher.
  2.  It selects a provider based on the notification's `Channel` (e.g., "telegram", "email").
  3.  It calls the provider's sending method (e.g., an adapter for the SendGrid API).
  4.  **Delivery Logging**: After the provider call completes, a `DeliveryLog` record is created to log the outcome (e.g., `sent` or `failed`), including any response from the provider.
  5.  The status of the original `Notification` record is updated to `sent` or `failed`.

---

## Identified Issues & Gaps

### P1 - Concurrency / Reliability: Unmanaged Goroutine for Sending

- **Issue**: The `notification` service uses a "fire and forget" approach by launching an unmanaged goroutine to send the notification. 
- **Impact**: This provides no guarantee of delivery. If the application crashes after the API call returns but before the goroutine completes, the notification is lost forever. There is no built-in mechanism for retrying failed sends.
- **Recommendation**: Replace the goroutine with a durable job queue. The `SendNotification` API should only be responsible for creating the `Notification` record. A separate, persistent background worker should poll the database for `pending` notifications, attempt to send them, and implement a retry strategy with exponential backoff for transient failures.

### P2 - Architecture: Tightly Coupled Integration

- **Issue**: Source services (like `order` and `customer`) trigger notifications via direct, synchronous API calls.
- **Impact**: This creates tight coupling between services. If the `notification` service is slow or unavailable, it can degrade the performance and availability of the calling service. For example, an `order` status update could be delayed waiting for the `notification` service to respond.
- **Recommendation**: Decouple the services using an event-driven approach. Instead of making direct calls, source services should publish business events (e.g., `order.status_changed`). The `notification` service should then subscribe to these events and contain its own logic to decide if a notification needs to be sent. This makes the entire system more resilient and scalable.

### P2 - Incomplete Implementation

- **Issue**: The `NotificationSender` only has a working implementation for the "telegram" channel. The logic for "email", "sms", and "push" are `TODO` placeholders.
- **Impact**: The service cannot fulfill its primary function for the most common notification channels.
- **Recommendation**: Implement the sender logic for the remaining channels by integrating with third-party providers (e.g., SendGrid for email, Twilio for SMS).
