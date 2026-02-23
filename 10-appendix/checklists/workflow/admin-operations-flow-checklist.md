# Admin & Operations Flow — Business Logic Checklist

**Last Updated**: 2026-02-21
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §13
**Services Reviewed**: `admin/` (frontend), `common-operations/`, `analytics/`
**Reviewer**: Antigravity Agent

---

## Legend

| Symbol | Meaning |
|--------|---------|
| ✅ | Implemented correctly |
| ⚠️ | Risk / partial — needs attention |
| ❌ | Missing / broken |
| 🔴 | P0 — blocks production |
| 🟡 | P1 — reliability risk |
| 🔵 | P2 — improvement / cleanup |

---

## Architecture Overview

| Service | Role | Backend? | Worker? |
|---------|------|----------|---------|
| `admin/` | React/Vite admin UI served by nginx | ❌ Frontend only | ❌ |
| `common-operations/` | Go service: task queue, settings, export/import | ✅ | ✅ worker-deployment.yaml |
| `analytics/` | Go service: 35 BI use cases | ✅ | ❌ No worker |
| `gateway/` | BFF: routes admin API requests | ✅ | ❌ |

---

## 1. Task Management (`common-operations/internal/biz/task`)

### 1.1 Task Lifecycle & Data Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `CreateTask` uses `WithTransaction` — DB insert + event record in one transaction | ✅ | `task.go:192-208` |
| State machine validated on every transition | ✅ | `task.go:151-174` — `validateStateTransition` checks full FSM |
| Supported states: `pending → processing → completed/failed/cancelled`, `failed → pending` (retry), `scheduled → pending` | ✅ | `task.go:153-160` |
| Optimistic locking via `version` field on `UpdateTask` | ✅ | `task.go:277` — `task.Version = current.Version + 1` |
| MaxRetries enforced before retrying | ✅ | `task.go:335-337` — `RetryCount >= MaxRetries` check |
| Filename sanitization via `security.FilenameSanitizer` | ✅ | `task.go:143-146` |
| `CancelTask` reads task then updates without transaction — TOCTOU window | ⚠️ | `task.go:305-326` — read-then-update outside a transaction; separate from `UpdateTask`'s optimistic locking |
| `RetryTask` reads task then updates without transaction | ⚠️ | `task.go:328-356` — same issue as `CancelTask` |
| `task_processor.go`: `processOrderTask`, `processNotificationTask`, `processDataSyncTask` are all **stub no-ops** | 🔴 | `task_processor.go:103-120` — all return `nil` with just a log message; tasks marked `completed` but nothing actually done |
| `consumer.go handleImport`: import is stub returning "not implemented" → task always fails | 🟡 | `consumer.go:106-112` — RetryFailedTasksJob will retry indefinitely until MaxRetries reached |
| Customer and Product export also stubs | 🟡 | `consumer.go:92-101` — only order export is implemented |
| `UpdateTask` publishes directly to Dapr (not via outbox) — event lost if Dapr unavailable | 🟡 | `task.go:284-297` — `publishTaskEventSync` with 30s timeout; no persistent outbox |
| `CreateTask` publishes event AFTER transaction commit (outside InTx) | ⚠️ | `task.go:215-219` — event published after TX commits; if Dapr is down, task is created but `task.created` event is lost |
| `DetectTimeoutsJob`: marks tasks as `failed` without logging escalation or notification | ⚠️ | `cron/detect_timeouts.go:89-97` — admin notified via log only; no notification event published |
| `RetryFailedTasksJob`: calls `UpdateTask` which validates state transition `failed → pending` — correct | ✅ | `cron/retry_failed_tasks.go:94` |
| `RetryFailedTasksJob` directly sets `t.Status = "pending"` before calling `UpdateTask` | ⚠️ | `cron/retry_failed_tasks.go:87` — UpdateTask reads `current.Status` from DB and validates against `task.Status` supplied; sets version = current.Version+1; OK but mutates input object before call |

### 1.2 Scheduled Tasks

| Check | Status | Notes |
|-------|--------|-------|
| `ProcessScheduledTasksJob`: transitions `scheduled → pending` every 1 min | ✅ | `cron/process_scheduled_tasks.go:71-99` |
| Scheduled task is just moved to `pending` — actual processing delegated to consumer | ✅ | Correct design |
| No limit on how many scheduled tasks are processed per tick — if 10,000 tasks fire simultaneously, all transition to pending at once | ⚠️ | `cron/process_scheduled_tasks.go:71` — no `LIMIT` in `GetScheduledTasks` query |

### 1.3 Task Consumer

| Check | Status | Notes |
|-------|--------|-------|
| `TaskConsumer.Start` polls every 5s, max concurrency 5 via errgroup | ✅ | `consumer.go:124,155` |
| `HandleTaskCreated` from Dapr pubsub routes to export/import — only these two types handled | ⚠️ | `consumer.go:73-82` — `process`, `delete`, `order_processing`, `notification_send`, `data_sync`, `report_generation`, `cleanup`, `migration`, `file_processing` all return "unknown task type" error |
| Returning error from Dapr subscription = Dapr will retry delivery — can cause infinite retry loop for unsupported types | 🟡 | `consumer.go:80` — `return fmt.Errorf("unknown task type: %s", ...)` causes Dapr retry storm for 8 out of 10 task types |
| No idempotency check on task processing — re-delivering same `task.created` event may double-process | ⚠️ | `consumer.go:48-82` — no `processed_at` check on task before routing |

---

## 2. Settings Management (`common-operations/internal/biz/settings`)

### 2.1 Settings Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `GetSettingByKey` — simple key-value retrieval | ✅ | `settings/usecase.go:20-26` |
| `UpdateSettingByKey` — simple key-value update | ✅ | `settings/usecase.go:28-35` |
| **No audit trail for settings changes** | 🟡 | `settings/usecase.go:28-35` — who changed what, when is not recorded. Admin changes to tax rules, promotion configs, fraud rules leave no history |
| **No event published when settings change** | 🟡 | `settings/usecase.go:28-35` — downstream services (pricing, promotion, tax) that cache settings won't know to invalidate their cache |
| **No validation on setting value** | ⚠️ | `settings/usecase.go:30` — accepts any `json.RawMessage`; no schema validation per key. Malformed config can break dependent services |
| **No version/optimistic locking on settings** | ⚠️ | Two concurrent admins updating the same setting — last write wins |
| **No RBAC check inside settings usecase** | ⚠️ | Relies entirely on HTTP middleware at gateway layer; no defense-in-depth validation |

---

## 3. Admin Frontend (`admin/`)

### 3.1 Admin UI Assessment

| Check | Status | Notes |
|-------|--------|-------|
| Admin frontend is React/Vite served by nginx | ✅ | Pure SPA — no backend logic |
| All API calls go through gateway BFF | ✅ | `VITE_API_GATEWAY_URL` from ConfigMap |
| Health probes on nginx (liveness + readiness) | ✅ | `deployment.yaml:55-66` |
| Security context: non-root nginx (uid 101) | ✅ | `deployment.yaml:26-33` |
| `readOnlyRootFilesystem: false` needed for nginx tmp writes | ✅ | Expected for nginx |
| No secrets in admin deployment — only configmap | ✅ | Correct (frontend should not have secrets) |
| No Dapr sidecar on admin (frontend doesn't need pubsub) | ✅ | Correct |

---

## 4. Analytics Service (`analytics/`)

### 4.1 Analytics Assessment

| Check | Status | Notes |
|-------|--------|-------|
| 35 business use cases covering: revenue, customer, fulfillment, inventory, order, product, real-time, A/B testing, alerts | ✅ | Comprehensive coverage |
| Has HPA (Horizontal Pod Autoscaler) | ✅ | `gitops/apps/analytics/base/hpa.yaml` — scales on load |
| Has Prometheus alerting rules | ✅ | `gitops/apps/analytics/base/prometheusrule.yaml` |
| **No worker-deployment.yaml** — analytics has no async worker | ⚠️ | `gitops/apps/analytics/base/` — 12 files, no worker. If analytics needs background event consumption (e.g., consuming order events to build dashboards), there's no worker to do so |
| Analytics service subscribes to no events (no consumer worker) | ⚠️ | All 35 usecases read from DB on demand (synchronous queries). High-volume reports (daily GMV, cohort analysis) may timeout on large datasets. No pre-aggregation |
| `event_processing_usecase.go` exists — may have consumer logic | ⚠️ | Need to verify if analytics actually needs event-driven ingestion or only pulls from data warehouse |

---

## 5. Events Assessment

### 5.1 Events Published by Admin/Operations Services

| Event | Publisher | Topic | Needed? | Via Outbox? | Status |
|-------|-----------|-------|---------|-------------|--------|
| `task.created` | common-operations | `task.created` | ⚠️ Internal only — to trigger async processing | ❌ Direct Dapr | ⚠️ Lost on Dapr downtime |
| `task.completed` | common-operations | `task.operations` | ⚠️ Notify admin user | ❌ Direct Dapr | ⚠️ Lost on Dapr downtime |
| `task.failed` | common-operations | `task.operations` | ⚠️ Notify admin user | ❌ Direct Dapr | ⚠️ Lost on Dapr downtime |
| `settings.changed` | common-operations | — | ✅ Yes — pricing/tax/promotion cache invalidation | ❌ **Never published** | ❌ Missing |
| `admin.action.audit` | — | — | ✅ Yes — compliance audit trail | ❌ **Never published** | ❌ Missing |

### 5.2 Events That Should Be Subscribed To

| Event | Service | Currently Subscribed | Needed? | Assessment |
|-------|---------|---------------------|---------|------------|
| `orders.order_status_changed` | analytics | ❌ | ⚠️ Optional — streaming for real-time dashboard | ❌ No worker |
| `payment.payment_processed` | analytics | ❌ | ⚠️ Optional — streaming GMV | ❌ No worker |
| `task.created` | common-operations consumer | ✅ (via Dapr pubsub + polling fallback) | ✅ Yes | ✅ |

---

## 6. GitOps Configuration

### 6.1 common-operations GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/common-operations/base/worker-deployment.yaml` |
| MinIO credentials injected via `secretKeyRef` | ✅ | `worker-deployment.yaml:69-78` |
| DB credentials via `overlays-config` configmap only | ⚠️ | No `secretRef`, relies on overlays-config for DB DSN. Verify overlays-config doesn't embed plaintext DB password |
| Worker Dapr: HTTP protocol, port 8018 | ✅ | `worker-deployment.yaml:26-27` — HTTP not gRPC (different from other services) |
| No liveness/readiness probes on worker | ⚠️ | `worker-deployment.yaml` — no health probes defined |
| `revisionHistoryLimit: 1` | ✅ | `worker-deployment.yaml:13` |
| Config mounted as volume | ✅ | `worker-deployment.yaml:86-93` |

### 6.2 Analytics GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `secret.yaml` exists | ✅ | `gitops/apps/analytics/base/secret.yaml` |
| `hpa.yaml` exists | ✅ | Proper autoscaling for query load |
| `prometheusrule.yaml` exists | ✅ | Alerting rules configured |
| **No `worker-deployment.yaml`** | ⚠️ | No async worker; all processing is synchronous per request |

### 6.3 Admin GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Frontend only — nginx deployment | ✅ | Correct architecture |
| No secrets (frontend gets API url from configmap) | ✅ | Secure — no credentials in frontend |
| Health probes configured | ✅ | `deployment.yaml:55-66` |
| No Dapr | ✅ | Correct |

---

## 7. Worker & Cron Summary

### common-operations Workers

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `TaskConsumer` (polling) | Polling fallback | 5s, batch 10, concurrency 5 | Process pending tasks | ✅; ⚠️ 8/10 task types return error causing Dapr retry storm |
| `TaskConsumer` (Dapr push) | Event-driven | Push | Handle `task.created` from Dapr | ✅; ⚠️ same routing issue |
| `ProcessScheduledTasksJob` | Cron | 1 min | Move `scheduled → pending` | ✅; ⚠️ no limit |
| `RetryFailedTasksJob` | Cron | 5 min | Retry failed tasks within MaxRetries | ✅ |
| `DetectTimeoutsJob` | Cron | 1 hour | Mark 2h+ processing tasks as `failed` | ✅; ⚠️ no notification event |
| `CleanupOldTasksJob` | Cron | Daily? | Purge old completed tasks + files | ✅ (verify schedule) |
| `CleanupOldFilesJob` | Cron | Daily? | Purge old export files from MinIO | ✅ (verify schedule) |
| `TaskProcessorWorker` | Event-driven | Push | Handle task routing (order/notification/data_sync) | 🔴 All subtypes are stubs |

---

## 8. Edge Cases & Risk Items

| # | Risk | Severity | Location |
|---|------|----------|----------|
| E1 | **Task processor subtypes are all stub no-ops** — `order_processing`, `notification_send`, `data_sync`, `import` all return `nil` or "not implemented"; tasks are marked `completed` without doing any work | 🔴 P0 | `task_processor.go:103-120`, `consumer.go:106-119` |
| E2 | **`HandleTaskCreated` returns error for 8 of 10 task types** — Dapr will retry, creating infinite retry storm for `process`, `delete`, `report_generation`, `migration`, `file_processing`, `cleanup` task types | 🟡 P1 | `consumer.go:73-82` |
| E3 | **`settings.UpdateSettingByKey` publishes no event** — dependent services (pricing, promotion, tax) never invalidate their config cache when admin changes platform settings | 🟡 P1 | `settings/usecase.go:28-35` |
| E4 | **No audit trail for settings changes** — no record of who changed which setting and when; compliance/SOX risk | 🟡 P1 | `settings/usecase.go:28-35` |
| E5 | **`CreateTask` publishes `task.created` event after transaction commit (outside InTx)** — if Dapr is down at publish time, task exists in DB but consumer never processes it; only recovered by polling fallback | 🟡 P1 | `task.go:214-219` |
| E6 | **`CancelTask` and `RetryTask` have TOCTOU window** — read task, check state, update without transaction; concurrent cancel+retry could corrupt state | 🟡 P1 | `task.go:305-326, 328-356` |
| E7 | **`DetectTimeoutsJob` does not notify admin** — stuck tasks silently moved to failed; only log output | 🔵 P2 | `cron/detect_timeouts.go:89-97` |
| E8 | **`ProcessScheduledTasksJob` has no LIMIT** — 10,000 scheduled tasks firing simultaneously would all move to pending, overwhelming the consumer | 🔵 P2 | `cron/process_scheduled_tasks.go:71` |
| E9 | **`settings.UpdateSettingByKey` has no value schema validation** — malformed JSON config stored directly, breaking dependent services | 🔵 P2 | `settings/usecase.go:30` |
| E10 | **Analytics has no event consumer** — real-time dashboards read stale data; no streaming ingestion of order/payment/fulfillment events | 🔵 P2 | `gitops/apps/analytics/base/` — no worker |
| E11 | **Settings has no optimistic locking / version control** — concurrent admin users updating same setting: last write wins | 🔵 P2 | `settings/usecase.go` |
| E12 | **No admin action audit log** — admin overrides (manual refund, order cancel, account unlock) leave no immutable trace in the system | 🔵 P2 | Missing across all services |
| E13 | **Worker deployment has no liveness/readiness probes** — container crash not detected by Kubernetes | 🔵 P2 | `worker-deployment.yaml` — no probes |
| E14 | **Task consumer idempotency not enforced** — redelivery of `task.created` event may trigger double processing of the same task | 🔵 P2 | `consumer.go:48-82` |

---

## 9. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 1 | E1: All task processor subtypes are stub no-ops — tasks complete without doing anything |
| 🟡 P1 | 5 | E2: Dapr retry storm for unsupported task types; E3: Settings changes not published; E4: No settings audit trail; E5: task.created event outside transaction; E6: TOCTOU in cancel/retry |
| 🔵 P2 | 8 | E7–E14: Timeouts not notified, scheduled tasks unbounded, settings validation, analytics no streaming, settings no locking, no admin audit log, no worker probes, no idempotency |

---

## 10. Action Items

- [ ] **[P0]** Implement actual task processing logic for `order_processing`, `notification_send`, `data_sync`, and `import` in `task_processor.go` and `consumer.go`
- [ ] **[P1]** Fix `HandleTaskCreated`: return `nil` (not error) for unsupported task types to prevent Dapr retry storm; use DLQ or mark task as failed instead
- [ ] **[P1]** Add `settings.changed` event publishing to `UpdateSettingByKey` to trigger cache invalidation in pricing/promotion/tax
- [ ] **[P1]** Add audit log to `UpdateSettingByKey` — record admin user ID, timestamp, old and new values
- [ ] **[P1]** Move `CreateTask` event publishing inside the transaction (write to outbox table, not direct Dapr)
- [ ] **[P1]** Wrap `CancelTask` and `RetryTask` in `WithTransaction` with optimistic locking
- [ ] **[P2]** Add timeout notification event in `DetectTimeoutsJob` (publish to notification topic)
- [ ] **[P2]** Add `LIMIT` to `GetScheduledTasks` query (e.g., max 100 per tick)
- [ ] **[P2]** Add JSON schema validation per settings key in `UpdateSettingByKey`
- [ ] **[P2]** Consider analytics event consumer worker for real-time ingestion of order/payment events
- [ ] **[P2]** Add version/ETag to settings for optimistic concurrency control
- [ ] **[P2]** Implement admin action audit log (immutable append-only table or event stream)
- [ ] **[P2]** Add liveness/readiness probes to common-operations worker deployment
- [ ] **[P2]** Add idempotency check in task consumer before processing (check `task.Status != pending` before routing)
