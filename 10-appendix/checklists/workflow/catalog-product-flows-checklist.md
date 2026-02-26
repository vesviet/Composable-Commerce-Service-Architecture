# Catalog & Product Flows Checklist (P0/P1/P2)

This checklist covers the review of **2. Catalog & Product Flows** from `ecommerce-platform-flows.md`, focusing on data consistency, Saga/Outbox patterns, edge cases, and GitOps configurations across `catalog` and `review` services.

## 1. Catalog Service Findings

### [ ] Issue 1: Side-Effects After Outbox Publish
- **Severity**: P2
- **Description**: In `catalog/internal/worker/outbox_worker.go`, side-effects (like cache updates or view refreshes via `uc.ProcessProductUpdated`) are executed "best effort" *after* marking the outbox event as `COMPLETED`. 
- **Risk**: If the side-effect fails, it logs a warning but never retries, potentially leaving local caches temporarily stale despite the event being published successfully.
- **Fix**: Either execute side-effects before marking `COMPLETED` (idempotent side-effects required) or move them to be consumed normally.

## 2. Search Service Findings

### [ ] Issue 2: Missing Rating Update Event Consumer
- **Severity**: P1
- **Description**: The `Search` service listens to `catalog.product.*` events but completely lacks logic to consume `review.rating.updated` events from the Review service.
- **Risk**: "Average Rating" and "Rating Count" fields on the product in the Elasticsearch index will never be dynamically updated when customers leave reviews.
- **Fix**: Create a `ReviewConsumer` in `search/internal/data/eventbus` that subscribes to `rating.updated` (using gRPC `AddConsumerWithMetadata`), and updates the `product` index accordingly.

---

## 3. Review Service Critical Findings (High Risk)

### [ ] Issue 3: Missing Outbox Pattern in Review Service
- **Severity**: P0
- **Description**: `createReview()` in `biz/review.go` publishes `review.created` directly via an asynchronous goroutine (`go func()`) without using the Outbox pattern.
- **Risk**: If Dapr is unavailable or the pod crashes mid-request, the event is permanently lost. Downstream services (e.g. `notification`, `search`) will safely never know a review was posted.
- **Fix**: Implement the complete Outbox pattern repository and worker for the Review service (similar to `catalog` and `order`). Store the event in the DB transaction when creating the review.

### [ ] Issue 4: "Dead Code" Workers (Rating Aggregation NEVER Runs)
- **Severity**: P0
- **Description**: Review service has `RatingAggregationWorker`, `ModerationWorker`, and `AnalyticsWorker` defined in `internal/worker/registry.go`. However, this registry is **never instantiated** in `cmd/review/main.go` or `wire.go`.
- **Risk**: Product average ratings are *never* calculated, moderation is bypassed, and analytics are lost. The review process is fundamentally broken in production.
- **Fix**: Instantiate and start the worker registry in `server.go` or as a separate Kratos binary (`cmd/review/main.go` or `cmd/worker`), and add `worker.ProviderSet` to wire.

### [ ] Issue 5: Missing Event Subscription for Shipment Delivered
- **Severity**: P1
- **Description**: The review service correctly implements a Dapr HTTP endpoint (`POST /events/shipment-delivered`) to call `MarkOrderEligibleForReview`. However, there is no declarative `dapr-subscription.yaml` for this in the GitOps configuration.
- **Risk**: The Review service will never receive programmatic callback events from Dapr since Kratos doesn't expose a `/dapr/subscribe` endpoint by default.
- **Fix**: Add a Declarative Dapr Subscription (`dapr-subscription.yaml`) for the Review service to subscribe to the delivery topic and map it to the `/events/shipment-delivered` endpoint.

### [ ] Issue 6: Missing Worker Deployment in GitOps
- **Severity**: P1
- **Description**: The `apps/review/base` GitOps folder lacks a `worker-deployment.yaml`.
- **Risk**: If the workers are meant to run separately from the API, they will not be deployed.
- **Fix**: Once workers are wired, verify if they should be bundled into the API binary (`cmd/review/main.go`) via background goroutines, or if they need a `worker-deployment.yaml` in GitOps (similar to Catalog/Order).

---

## 4. General Architecture Checks

- **Checklist Questions Answered:**
  - **Mismatched Data**: Ratings on Search will mismatch with Review DB because rating aggregation doesn't run, and Search doesn't listen to ratings anyway.
  - **Saga/Outbox implementation**: Missing completely in Review service. Catalog is mostly fine.
  - **Publish Events necessary**: Yes (Search needs catalog and review updates).
  - **Subscribe Events necessary**: Yes (Review needs shipment/order notifications).
  - **Worker/Cron configured**: Catalog is cleanly hooked up. Review is thoroughly broken in terms of orchestration.
