# Notification Service

## Overview
The `notification` service handles the delivery of messages across various channels (Email, SMS, Push, Telegram) for both internal systems and customers. It uses a robust, transactional outbox pattern to guarantee at-least-once delivery, handles idempotent requests, honors user notification preferences (e.g., quiet hours, opt-outs), and manages templates.

## Architecture & Core Components

1.  **Multi-Channel Delivery:** Supports email (SendGrid with SMTP fallback), SMS (Twilio), Push notifications (Firebase/APNS), and internal alerts (Telegram).
2.  **Transactional Outbox:** Ensures atomicity between business logic (e.g., creating an order) and notification publishing.
3.  **Circuit Breaker Protection:** Provider external calls are wrapped in circuit breakers to isolate failures and avoid cascading thread pool exhaustion.
4.  **Resilience & Retries:** Employs DLQ handling for permanently failed messages and exponential backoff strategies for rate limits.
5.  **Webhook Callbacks & Delivery Tracking:** Automatically synchronizes delivery statuses (`Delivered`, `Bounced`, `Failed`) using provider webhooks authenticated securely (e.g., `TwilioVerifier`).

## API Contracts (gRPC)

The service exposes the following main APIs:

*   **NotificationService:** `SendNotification`, `GetNotification`, `ListNotifications`
*   **TemplateService:** `CreateTemplate`, `UpdateTemplate`, `GetTemplate`, `DeleteTemplate`, `ListTemplates`
*   **PreferenceService:** `GetUserPreference`, `UpdateUserPreference`, `OptOut`
*   **SubscriptionService:** `Subscribe`, `Unsubscribe`, `ListSubscriptions`
*   **DeliveryService:** `ProcessWebhook` (HTTP only)

## Topics Subscribed

*   `system.errors`
*   `orders.order.status_changed`
*   `payment.payment.processed`
*   `payment.payment.failed`
*   `orders.return.approved`
*   `payment.payment.refunded`
*   `auth.login`

## Dependencies
*   **PostgreSQL**: Persistence layer for notifications, templates, and delivery logs.
*   **Redis**: Caching notification templates, preferences, and idempotency states.
*   **Dapr**: Message brokering (Pub/Sub) and state orchestration.
*   **Consul**: Service Discovery and external configurations.

## GitOps & Infrastructure
- **Port Allocation**: HTTP 8009, gRPC 9009
- **Health Probes**: Exposed at `/health/live`, `/health/ready`
- **Workers**: Managed by a secondary `worker` binary synced with HPA (sync-wave=3).

## Known Constraints
- The template rendering logic currently supports standard Handlebars-style replacements.
- Webhook endpoints require strict signature verification policies (e.g., Twilio HMAC SHA1).
