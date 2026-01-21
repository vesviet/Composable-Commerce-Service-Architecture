# Common Package Flow - Issues Checklist

**Last Updated**: 2026-01-20

## Codebase Index (Common Package)
- common/events: Dapr consumer/publisher (gRPC), topic handling
- common/repository: generic repository + filtering + pagination
- common/worker: base & continuous workers, registry, metrics
- common/observability: health checks, metrics interfaces, tracing
- common/middleware: auth, logging, recovery, rate limit, context
- common/config: config loader and env overrides
- common/errors: structured error types
- common/utils: shared helpers (pagination, time, slices)

---

## 🚩 PENDING ISSUES (Unfixed)
- _None._

## 🆕 NEWLY DISCOVERED ISSUES
- [Security] [NEW ISSUE 🆕] COMMON-REPO-P1-02 Unsafe ORDER BY if `Filter.Sort` is user-controlled.

## ✅ RESOLVED / FIXED
- [FIXED ✅] COMMON-EVT-P1-01 Dapr consumer port configurable via env. See [common/events/dapr_consumer.go](common/events/dapr_consumer.go).
- [FIXED ✅] COMMON-EVT-P1-02 `DAPR_DISABLED` no longer returns nil publisher. See [common/events/dapr_publisher_grpc.go](common/events/dapr_publisher_grpc.go).
- [FIXED ✅] COMMON-EVT-P2-01 Subscription concurrency now configurable via env. See [common/events/dapr_consumer.go](common/events/dapr_consumer.go).
- [FIXED ✅] COMMON-EVT-P0-03 Default DLQ metadata added for subscriptions (auto `<topic>.dlq`). See [common/events/dapr_consumer.go](common/events/dapr_consumer.go).
- [FIXED ✅] COMMON-REPO-P2-01 `List()` now nil-safe for filter. See [common/repository/base_repository.go](common/repository/base_repository.go).
- [FIXED ✅] COMMON-OBS-P2-01 Added no-op metrics defaults. See [common/observability/metrics/noop.go](common/observability/metrics/noop.go).
- [FIXED ✅] COMMON-REPO-P1-02 ORDER BY now validated and allowlist-supported. See [common/repository/base_repository.go](common/repository/base_repository.go).
- [FIXED ✅] COMMON-LOG-P2-01 Added Kratos logger helpers and deprecated Logrus wrapper. See [common/kratos_logger.go](common/kratos_logger.go), [common/logger.go](common/logger.go).
- [FIXED ✅] COMMON-OBS-P2-02 Added metrics usage guidance in observability README. See [common/observability/README.md](common/observability/README.md).

---

## 🔁 CANDIDATES TO MOVE INTO COMMON
- Retry helper (exponential backoff + jitter) currently in catalog; consider `common/utils/retry`: [catalog/internal/utils/retry/retry.go](catalog/internal/utils/retry/retry.go).
- Duplicate circuit breaker implementations in analytics/notification; prefer `common/client/circuitbreaker`: [analytics/internal/pkg/circuitbreaker/circuit_breaker.go](analytics/internal/pkg/circuitbreaker/circuit_breaker.go), [notification/internal/pkg/circuitbreaker/circuit_breaker.go](notification/internal/pkg/circuitbreaker/circuit_breaker.go).
- Context extraction helpers (IP/UserAgent/ActorID) in payment; consider `common/utils/ctx` or `common/middleware/context`: [payment/internal/utils/context_helper.go](payment/internal/utils/context_helper.go).
- Encryption helper (AES-GCM + PBKDF2) in payment; consider aligning into `common/utils/crypto` with secure KDF: [payment/internal/utils/encryption.go](payment/internal/utils/encryption.go).
- Simple `ValueOrDefault` + `Abs` in warehouse; could be replaced by `common/utils/pointer` and `common/utils/math` extensions: [warehouse/internal/utils/utils.go](warehouse/internal/utils/utils.go).
- UUID generator in gateway; consider `common/utils/uuid` (new) or reuse a shared helper: [gateway/internal/utils/uuid_pool.go](gateway/internal/utils/uuid_pool.go).
- JSON log helpers in shipping; consider `common/utils/strings` (JSON helpers) or new `common/utils/json`: [shipping/pkg/utils/utils.go](shipping/pkg/utils/utils.go).

## Notes
- Ensure changes are reflected in service configs and deployment manifests.
- Service-level event consumers should still pass explicit `deadLetterTopic` where a non-default name is required.

---

## 🔄 SERVICES NEED COMMON v1.6.0 UPDATE

**Current target**: v1.6.0 (released)

- [High] [NEW ISSUE 🆕] COMMON-UPG-P1-01 Services pinned to v1.4.8 need upgrade to v1.6.0:
	- analytics, review, common-operations, payment, promotion, location, notification, shipping, loyalty-rewards.
- [Medium] [NEW ISSUE 🆕] COMMON-UPG-P2-01 Services still on pre-release tags need upgrade to v1.6.0:
	- order (v1.6.0-dev.9), search (v1.6.0-dev.9), warehouse (v1.6.0-dev.9), gateway (v1.6.0-dev.9), catalog (v1.6.0-dev.9), pricing (v1.6.0-dev.9), fulfillment (v1.6.0-dev.8), auth (v1.6.0-dev.7), user (v1.6.0-dev.7), customer (v1.6.0-dev.7).
