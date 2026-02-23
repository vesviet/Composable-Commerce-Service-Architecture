# Common-Operations Flow - Issues Checklist

**Last Updated**: 2026-01-21

## Codebase Index (Common Package)
- common/worker: base & continuous workers, registry, metrics
- common/events: Dapr consumer/publisher (gRPC), helpers
- common/observability: health, metrics interfaces, tracing, rate-limit
- common/errors: structured error helpers
- common/config: service config loader
- common/utils: transaction, metadata, http, strings, time helpers

---

## 🚩 PENDING ISSUES (Unfixed)
- [High] [NEW ISSUE 🆕] COMMON-EVT-P1-01 Dapr Consumer Port Hardcoded: `NewConsumerClientWithLogger` binds to `:5005` without env/config override. Required: read from config/env to support dev/K8s variability. See `common/events/dapr_consumer.go`.
- [High] [NEW ISSUE 🆕] COMMON-EVT-P1-02 Dapr Disabled Returns Nil Publisher: `NewDaprEventPublisherGRPC` returns `(nil, nil)` when `DAPR_DISABLED=true`, risking nil deref in callers. Required: return NoOp publisher or explicit error. See `common/events/dapr_publisher_grpc.go`.
- [Medium] [NEW ISSUE 🆕] COMMON-EVT-P2-01 Subscription Concurrency Fixed to 1: Consumer sets `maxConcurrentMessages=1` with no config override. Required: make configurable per service. See `common/events/dapr_consumer.go`.

## 🆕 NEWLY DISCOVERED ISSUES
- [Reliability] [NEW ISSUE 🆕] COMMON-EVT-P1-01 Hardcoded Dapr consumer port prevents flexible deployment.
- [Reliability] [NEW ISSUE 🆕] COMMON-EVT-P1-02 Nil publisher on `DAPR_DISABLED` can crash at runtime.
- [Maintainability] [NEW ISSUE 🆕] COMMON-EVT-P2-01 Fixed concurrency for all subscriptions limits scaling.

## ✅ RESOLVED / FIXED
- ~~[FIXED ✅] Unmanaged goroutine (P0): TaskConsumer now uses `errgroup` for concurrency.~~
- ~~[FIXED ✅] CreateTask missing required fields: added validation.~~
- ~~[FIXED ✅] CreateTask ignored uploadUrl update error: now handled.~~
- ~~[FIXED ✅] UpdateTaskProgress forced status to processing: blocked for terminal states.~~
- ~~[FIXED ✅] Task event/log persistence ignored errors: now handled.~~

---

## Notes
- Consider documenting K8s debugging steps (logs/exec/port-forward) for common-operations.
