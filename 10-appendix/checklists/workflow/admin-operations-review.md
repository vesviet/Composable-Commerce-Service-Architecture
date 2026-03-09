# Admin & Operations Flow — Business Logic Checklist

**Last Updated**: 2026-03-07
**Pattern Reference**: Shopify, Shopee, Lazada — `docs/10-appendix/ecommerce-platform-flows.md` §13
**Services Reviewed**: `admin/` (frontend), `common-operations/`, `analytics/`
**Reviewer**: Antigravity Agent (deep-review 2026-03-07)

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
| `common-operations/` | Go service: task queue, settings, audit, i18n messages, export/import | ✅ | ✅ worker-deployment.yaml |
| `analytics/` | Go service: 35 BI use cases, event processing, DLQ | ✅ | ✅ 4 cron jobs (aggregation, alert-checker, retention, reconciliation) |
| `gateway/` | BFF: routes admin API requests | ✅ | ❌ |

---

## 1. Task Management (`common-operations/internal/biz/task`)

### 1.1 Task Lifecycle & Data Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `CreateTask` uses `WithTransaction` — DB insert + event record in one transaction | ✅ | `task.go:194-210` |
| State machine validated on every transition | ✅ | `task.go:153-176` — `validateStateTransition` checks full FSM |
| Supported states: `pending → processing → completed/failed/cancelled`, `failed → pending` (retry), `scheduled → pending` | ✅ | `task.go:155-161` |
| Optimistic locking via `version` field on `UpdateTask` | ✅ | `task.go:272` — `task.Version = current.Version + 1` |
| MaxRetries enforced before retrying | ✅ | `task.go:332-334` — `RetryCount >= MaxRetries` check inside `RetryTask` |
| Filename sanitization via `security.FilenameSanitizer` | ✅ | `task.go:144-148` |
| `CancelTask` wrapped in `WithTransaction` — TOCTOU fixed | ✅ | `task.go:301` — reads + updates inside `txManager.WithTransaction` |
| `RetryTask` wrapped in `WithTransaction` — TOCTOU fixed | ✅ | `task.go:326` — same fix |
| `task_processor.go`: `processOrderTask`, `processNotificationTask`, `processDataSyncTask` are implemented | ⚠️ | `processOrderTask` ✅, `processNotificationTask` ✅, `processDataSyncTask` **stub — logs only, no real sync** |
| `consumer.go handleImport`: returns "not implemented" via `markNotImplemented()` | ⚠️ | `consumer.go:112-118` — marks task as failed (not retry storm); import still TODO |
| Customer and Product export: `markNotImplemented` used, not returning error | ⚠️ | `consumer.go:98-107` — only order export is live; others mark failed gracefully |
| `UpdateTask` publishes directly to Dapr (not via outbox) — event lost if Dapr unavailable | ⚠️ | `task.go:286-293` — `publishTaskEventSync` 30s timeout; no persistent outbox |
| `CreateTask` does NOT publish `task.created` event — relies on polling fallback | ⚠️ | `task.go:194-219` — task + event record saved in TX but no Dapr publish; polling fallback (5s latency) covers recovery |
| `DetectTimeoutsJob`: publishes `EventTaskFailed` event after marking stuck tasks | ✅ | `detect_timeouts.go:69-76` — publisher.PublishTaskEvent called |
| **`CancelTask` publishes event with outer `ctx` instead of `txCtx`** | ⚠️ 🟡 | `task.go:317` — `publishTaskEventSync(ctx, ...)` is called inside `txManager.WithTransaction` but uses outer `ctx`. If the TX rolls back, the event is already published. Should use `txCtx` or publish AFTER TX commit |
| **`RetryTask` publishes event with outer `ctx` instead of `txCtx`** | ⚠️ 🟡 | `task.go:347` — same issue as CancelTask. Event published even if TX rollback occurs |
| **Outbox Publisher Job does NOT exist** | ⚠️ 🟡 | `TaskEventRepo.ListUnpublished` and `MarkPublished` interfaces exist (`task.go:49-50`) but **NO job polls this table**. Event records saved in CreateTask TX are never published by outbox. Polling consumer is the ONLY recovery path |
| **`TaskProcessorWorker.Process` returns error for unknown types** | ⚠️ 🟡 | `task_processor.go:82-98` — unknown task type results in `processErr != nil`, UpdateTask marks it as `failed`, but `Process()` still returns `processErr` to the caller. If called from Dapr event handler, this causes a retry storm |

### 1.2 Scheduled Tasks

| Check | Status | Notes |
|-------|--------|-------|
| `ProcessScheduledTasksJob`: transitions `scheduled → pending` every 1 min | ✅ | `cron/process_scheduled_tasks.go:22-55` |
| Scheduled task is just moved to `pending` — actual processing delegated to consumer | ✅ | Correct design |
| **No limit on how many scheduled tasks are processed per tick** | ✅ | ~~Potential issue~~ — `GetScheduledTasks` repo already has `LIMIT(100)` at DB layer |

### 1.3 Task Consumer

| Check | Status | Notes |
|-------|--------|-------|
| `TaskConsumer.Start` polls every 5s, max concurrency 5 via errgroup | ✅ | `consumer.go:129,162` |
| `HandleTaskCreated` from Dapr pubsub routes to export/import — unsupported types handled gracefully | ✅ | `consumer.go:77-87` — returns `nil` + marks failed via `markNotImplemented` |
| Returning error for unsupported types — fixed, no longer retry storm | ✅ | `consumer.go:84-87` — returns `nil` (ACK to Dapr) |
| Idempotency check on task processing — status guard in place | ✅ | `consumer.go:72-75`, `consumer.go:182-185` — skips tasks not in pending status |

---

## 2. Settings Management (`common-operations/internal/biz/settings`)

### 2.1 Settings Consistency

| Check | Status | Notes |
|-------|--------|-------|
| `GetSettingByKey` — simple key-value retrieval | ✅ | `settings/usecase.go:35-41` |
| `UpdateSettingByKey` — validates value, writes audit record, publishes event | ✅ | `settings/usecase.go:46-53` |
| **Audit trail for settings changes** | ✅ | `usecase.go:101-118` — `recordAuditAndPublish()` records old/new value with `updatedBy` |
| **`settings.changed` event published on update** | ✅ | `PublishSettingsChanged()` called from `recordAuditAndPublish()` |
| **Schema validation per setting key** | ✅ | `settings.go:64-87` — `schemaRegistry` with `requireBool`/`requireNonEmptyString` for payment keys |
| **Optimistic locking on settings** | ✅ | `UpdateSettingByKeyWithVersion()` — CAS via `UpdateWithVersion()`, returns `ErrVersionConflict` on mismatch |
| **No RBAC check inside settings usecase** | ⚠️ | Relies entirely on HTTP middleware at gateway layer |
| **Settings audit + event publish are non-transactional with the DB write** | ⚠️ 🔵 | `usecase.go:100-101` comment: "non-fatal: failures are logged but do not roll back the DB write". If audit/event fail silently, admin has no visibility |

---

## 3. Admin Audit (`common-operations/internal/biz/audit`)

### 3.1 Admin Audit Log

| Check | Status | Notes |
|-------|--------|-------|
| `AdminAuditUseCase.RecordAction` — immutable append-only audit log | ✅ | `audit/admin_audit.go:44-71` — records actorID, actorRole, action, entity, old/new state, metadata |
| `ListByActor` and `ListByEntity` queries | ✅ | `admin_audit.go:74-81` — pagination support |
| **Audit repo enforces append-only** | ✅ | Interface comment: "no UPDATE/DELETE" semantics per `admin_audit.go:17` |
| **No event published on audit record creation** | ⚠️ 🔵 | `RecordAction()` only writes to DB. No event for external alerting/compliance systems |

---

## 4. Message (i18n) Management (`common-operations/internal/biz/message`)

### 4.1 Message System

| Check | Status | Notes |
|-------|--------|-------|
| `GetMessage` with language fallback | ✅ | `message.go:40-60` — returns key as fallback if translation missing |
| `GetMessages` batch retrieval | ✅ | `message.go:63-109` — batch with per-key variable replacement |
| `UpsertMessage` with event publish | ✅ | `message.go:112-161` — publishes `message_updated` event |
| `DeleteMessage` with event publish | ✅ | `message.go:169-184` — publishes `message_deleted` event |
| **Template variable injection — no escaping** | ⚠️ 🔵 | `message.go:187-194` — `strings.ReplaceAll` without HTML escaping. If admin-provided templates are rendered in HTML, XSS risk |
| **No RBAC on message CRUD** | ⚠️ | Same as settings — relies on gateway middleware |

---

## 5. Admin Frontend (`admin/`)

### 5.1 Admin UI Assessment

| Check | Status | Notes |
|-------|--------|-------|
| Admin frontend is React/Vite served by nginx | ✅ | Pure SPA — no backend logic |
| All API calls go through gateway BFF | ✅ | `VITE_API_GATEWAY_URL` from ConfigMap |
| Health probes on nginx (liveness + readiness) | ✅ | `deployment.yaml:55-66` |
| Security context: non-root nginx (uid 101) | ✅ | `deployment.yaml:26-33` |
| No secrets in admin deployment — only configmap | ✅ | Correct (frontend should not have secrets) |
| No Dapr sidecar on admin (frontend doesn't need pubsub) | ✅ | Correct |

---

## 6. Analytics Service (`analytics/`)

### 6.1 Analytics Assessment

| Check | Status | Notes |
|-------|--------|-------|
| 35 business use cases covering: revenue, customer, fulfillment, inventory, order, product, real-time, A/B testing, alerts | ✅ | Comprehensive coverage |
| Has HPA (Horizontal Pod Autoscaler) | ✅ | `gitops/apps/analytics/base/hpa.yaml` |
| Has Prometheus alerting rules | ✅ | `gitops/apps/analytics/base/prometheusrule.yaml` |
| **Worker binary exists** | ✅ | `analytics/cmd/worker/main.go` — runs 4 cron jobs |
| **Worker GitOps configured** | ✅ | `patch-worker.yaml`, `worker-pdb.yaml`, `common-worker-deployment-v2` component |
| `event_processing_usecase.go` — full event processing with idempotency + DLQ | ✅ | `event_processing_usecase.go:32-138` — dedup by event ID and data hash, DLQ after 3 retries |
| **Analytics event processing is API-driven, not event-driven** | ⚠️ 🔵 | `ProcessIncomingEvent()` is a usecase method called via gRPC/HTTP API. No Dapr consumer subscribes to platform events (order, payment, etc.) to feed analytics in real-time. Reports rely on DB queries |
| **Worker runs cron jobs only — no event consumers** | ⚠️ | Worker has 4 cron jobs: `AggregationCronJob`, `AlertCheckerCronJob`, `RetentionCronJob`, `ReconciliationCronJob`. No Dapr event subscriptions |

### 6.2 Analytics Worker Cron Jobs

| Worker | Type | Purpose | Status |
|--------|------|---------|--------|
| `AggregationCronJob` | Cron | Pre-aggregate metrics for dashboards | ✅ |
| `AlertCheckerCronJob` | Cron | Check alert thresholds, fire notifications | ✅ |
| `RetentionCronJob` | Cron | Purge old analytics data | ✅ |
| `ReconciliationCronJob` | Cron | Reconcile analytics data across sources | ✅ |

---

## 7. Events Assessment

### 7.1 Events Published by Admin/Operations Services

| Event | Publisher | Topic | Needed? | Via Outbox? | Status |
|-------|-----------|-------|---------|-------------|--------|
| `task.created` | common-operations | `operations.task.created` | ⚠️ Internal only — to trigger async processing | ❌ Event record saved in TX but NOT published by outbox job | ⚠️ Polling fallback (5s) is the primary path |
| `task.completed` | common-operations | `task.operations` | ⚠️ Notify admin user | ❌ Direct Dapr (publishTaskEventSync) | ⚠️ Lost on Dapr downtime |
| `task.failed` | common-operations | `task.operations` | ⚠️ Notify admin user | ❌ Direct Dapr | ⚠️ Lost on Dapr downtime |
| `settings.changed` | common-operations | `settings.changed` | ✅ Yes — pricing/tax/promotion cache invalidation | ❌ Direct Dapr | ✅ Published |
| `message_updated` | common-operations | message events | ✅ Yes — i18n cache invalidation | ❌ Direct Dapr | ✅ Published |
| `message_deleted` | common-operations | message events | ✅ Yes — i18n cache invalidation | ❌ Direct Dapr | ✅ Published |
| `admin.action.audit` | — | — | 🔵 Optional — compliance alerting | ❌ **Never published** | 🔵 DB-only audit is sufficient for now |

### 7.2 Events That Should Be Subscribed To

| Event | Service | Currently Subscribed | Needed? | Assessment |
|-------|---------|---------------------|---------|------------|
| `orders.order_status_changed` | analytics | ❌ | 🔵 Optional — streaming for real-time dashboard | Analytics uses cron aggregation instead (batch approach) |
| `payment.payment_processed` | analytics | ❌ | 🔵 Optional — streaming GMV | Same — batch aggregation cron |
| `task.created` | common-operations consumer | ✅ (via Dapr pubsub + polling fallback) | ✅ Yes | ✅ DaprHandler subscribes to `operations.task.created` |

### 7.3 Verdict: Do These Services Actually NEED PubSub?

| Service | Publish Events? | Subscribe Events? | Verdict |
|---------|----------------|-------------------|---------|
| **common-operations** | ✅ Yes (task state, settings, messages) | ✅ Yes (task.created for async processing) | ✅ Correct use of PubSub |
| **analytics** | ❌ Does not publish | ❌ Does not subscribe | ⚠️ Currently batch-only approach via cron jobs. Real-time event consumption is deferred (P2). Acceptable if SLA allows minutes-level data freshness |
| **admin** | ❌ N/A (frontend) | ❌ N/A | ✅ Correct — no PubSub needed for SPA |

---

## 8. GitOps Configuration

### 8.1 common-operations GitOps

| Check | Status | Notes |
|-------|--------|-------|
| `worker-deployment.yaml` exists | ✅ | `gitops/apps/common-operations/base/worker-deployment.yaml` |
| MinIO credentials injected via `secretKeyRef` | ✅ | `worker-deployment.yaml:72-81` |
| Worker Dapr: HTTP protocol, app-port 8019 | ✅ | `worker-deployment.yaml:26-27` |
| Liveness/readiness probes on worker | ✅ | `worker-deployment.yaml:95-112` — `/healthz` on port 8019 |
| `revisionHistoryLimit: 1` | ✅ | `worker-deployment.yaml:13` |
| Config mounted as volume | ✅ | `worker-deployment.yaml:90-93,114-117` |
| Security context: non-root (uid 65532) | ✅ | `worker-deployment.yaml:30-33,47-48` |
| Init containers wait for console/redis/postgres | ✅ | `worker-deployment.yaml:34-43` |
| **Worker runs all modes**: `/app/bin/worker -mode all` | ✅ | `worker-deployment.yaml:54` |
| **Health port mismatch with Dapr app-port** | ⚠️ 🔵 | `app-port=8019` (Dapr), health probes on `port 8019`. OK — both use the same internal HTTP server. But `containerPort: 8081` (line 60) is declared for health but probes target 8019. **Dead port declaration** — port 8081 is never used |

### 8.2 Analytics GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Worker deployment via `common-worker-deployment-v2` component | ✅ | `kustomization.yaml:17` |
| `patch-worker.yaml` exists | ✅ | Adds configmap/secret envFrom and resource limits |
| `worker-pdb.yaml` exists | ✅ | `minAvailable: 1` — ensures availability during disruptions |
| Worker command: `/app/bin/worker -conf /app/configs/config.yaml` | ✅ | `kustomization.yaml:63-64` |
| HPA configured | ✅ | `hpa.yaml` |
| ServiceMonitor configured | ✅ | Prometheus scraping |
| PrometheusRule configured | ✅ | Alerting rules |
| Secret configured | ✅ | `secret.yaml` |
| Dapr enabled with app-id `analytics-worker` | ✅ | `kustomization.yaml:193-200` |

### 8.3 Admin GitOps

| Check | Status | Notes |
|-------|--------|-------|
| Frontend only — nginx deployment | ✅ | Correct architecture |
| No secrets (frontend gets API url from configmap) | ✅ | Secure — no credentials in frontend |
| Health probes configured | ✅ | `deployment.yaml:55-66` |
| No Dapr | ✅ | Correct |

---

## 9. Worker & Cron Summary

### common-operations Workers

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `TaskConsumer` (polling) | Polling fallback | 5s, batch 10, concurrency 5 | Process pending tasks | ✅ routing + idempotency guard |
| `TaskConsumer` (Dapr push) | Event-driven | Push | Handle `task.created` from Dapr | ✅ unsupported types ACK + mark failed |
| `TaskProcessorWorker` | Event-driven | Push | Process order/notification/data-sync tasks | ⚠️ data_sync is stub; returns error for unknown types |
| `ProcessScheduledTasksJob` | Cron | 1 min | Move `scheduled → pending` | ✅ |
| `RetryFailedTasksJob` | Cron | 5 min | Retry failed tasks within MaxRetries | ✅ delegates to `RetryTask()` UseCase |
| `DetectTimeoutsJob` | Cron | 1 hour | Mark 2h+ tasks as failed + publish event | ✅ |
| `CleanupOldTasksJob` | Cron | Daily | Purge old completed tasks | ✅ |
| `CleanupOldFilesJob` | Cron | Daily | Purge old export files from MinIO | ✅ |

### analytics Workers

| Worker | Type | Interval | Purpose | Status |
|--------|------|----------|---------|--------|
| `AggregationCronJob` | Cron | Periodic | Pre-aggregate metrics for dashboards | ✅ |
| `AlertCheckerCronJob` | Cron | Periodic | Check alert thresholds, fire notifications | ✅ |
| `RetentionCronJob` | Cron | Periodic | Purge old analytics data | ✅ |
| `ReconciliationCronJob` | Cron | Periodic | Reconcile analytics data across sources | ✅ |

---

## 10. Edge Cases & Risk Items

### 🚩 PENDING ISSUES (Unfixed)

| # | Risk | Severity | Location |
|---|------|----------|----------|
| E16 | **`CancelTask`/`RetryTask` publish event with outer `ctx` not `txCtx`** — event may be published even if TX rolls back | 🟡 P1 | `task.go:317,347` — `publishTaskEventSync(ctx, ...)` uses `ctx` from outer scope, not `txCtx` from `WithTransaction`. Should either use `txCtx` or move publish AFTER TX commit |
| E17 | **Outbox Publisher Job NOT implemented** — `TaskEventRepo.ListUnpublished`/`MarkPublished` interfaces defined but no cron job polls them. Event records saved in `CreateTask` TX are orphaned. Checklist previously marked this resolved — reverting | 🟡 P1 | `task.go:46-51` defines interface; `find outbox` returns 0 results in codebase. No `outbox_publisher.go` file exists |
| E18 | **`TaskProcessorWorker.Process()` returns error for unknown types** — may cause Dapr retry storm | 🟡 P1 | `task_processor.go:82-98` — unknown type sets `processErr`, marks task as `failed` via `UpdateTask`, but `Process()` returns `processErr`. If this handler is invoked by a Dapr event push, returning error = infinite retry |
| E19 | **`processDataSyncTask` is stub** — only logs, no real data synchronization | 🔵 P2 | `task_processor.go:220-234` — logs "Data sync requested" but does nothing. Task is marked completed despite no actual work |
| E20 | **Message template variable injection has no HTML escaping** | 🔵 P2 | `message.go:187-194` — `strings.ReplaceAll` without escaping. XSS risk if admin-defined templates rendered in browser |
| E21 | **Worker deployment declares unused port 8081** | 🔵 P2 | `worker-deployment.yaml:59-61` — `containerPort: 8081 (health)` is declared but probes use port 8019. Dead declaration — harmless but confusing |
| E22 | **Settings + Audit publish are non-transactional** | 🔵 P2 | `settings/usecase.go:100-101` — audit and event publish are fire-and-forget after DB write. If both fail, settings change is invisible to audit trail and downstream caches |
| E23 | **No RBAC enforcement inside biz layer** | 🔵 P2 | Settings, messages, and audit rely entirely on gateway middleware for authorization. If any internal service calls these usecases directly (e.g., via gRPC), RBAC is bypassed |
| E5 | **`CreateTask` does NOT publish `task.created` event** via Dapr — polling fallback is the only path | 🔵 P2 low | `task.go:194-219` — polling every 5s compensates; acceptable latency for admin tasks |
| E10 | **Analytics event consumers are deferred** — worker runs cron jobs (aggregation, alerting, retention, reconciliation) but no event-driven real-time ingestion | 🔵 P2 deferred | `analytics/cmd/worker/main.go:67-78` — batch approach is valid if SLA allows minutes-level freshness |

### ✅ RESOLVED / Fixed

| # | Resolution |
|---|-----------|
| E1 | Task processor subtypes implemented — `processOrderTask` calls `order.CancelOrder`, `processNotificationTask` calls `notification.SendNotification` |
| E2 | `HandleTaskCreated` unsupported types → ACK + mark failed — no Dapr retry storm |
| E3 | `settings.UpdateSettingByKey` publishes `settings.changed` event |
| E4 | Settings audit trail implemented — old/new value, updated_by, timestamp persisted |
| E6 | `CancelTask` and `RetryTask` TOCTOU fixed — both wrapped in `WithTransaction` |
| E7 | `DetectTimeoutsJob` publishes event — `EventTaskFailed` sent via publisher |
| E8 | `ProcessScheduledTasksJob` has `LIMIT(100)` at repo layer |
| E9 | Settings value schema validation — `ValidateSettingValue` with `schemaRegistry` |
| E11 | Settings optimistic locking — `UpdateSettingByKeyWithVersion` + `version` column |
| E12 | Admin action audit log — `admin_audit_log` table + `AdminAuditUseCase.RecordAction` |
| E13 | Worker deployment liveness/readiness probes added on port 8019 `/healthz` |
| E14 | Task consumer idempotency guard — status check before routing |
| E15 | `RetryFailedTasksJob` delegates to `taskUsecase.RetryTask()` — MaxRetries enforced |

---

## 11. Summary of Findings

| Priority | Count | Key Items |
|----------|-------|-----------|
| 🔴 P0 | 0 | All P0 items resolved ✅ |
| 🟡 P1 | 3 | E16 (event publish outside TX), E17 (outbox job missing), E18 (TaskProcessor returns error) |
| 🔵 P2 | 6 | E5, E10, E19, E20, E21, E22, E23 |

---

## 12. Action Items

### Resolved
- [x] **E1** Task processor subtypes implemented
- [x] **E2** HandleTaskCreated returns nil for unsupported types
- [x] **E3** `settings.changed` event published
- [x] **E4** Settings audit trail implemented
- [x] **E6** CancelTask/RetryTask TOCTOU fixed
- [x] **E7** DetectTimeoutsJob publishes event
- [x] **E8** GetScheduledTasks has LIMIT(100)
- [x] **E9** Settings value schema validation
- [x] **E11** Settings optimistic locking
- [x] **E12** Admin action audit log
- [x] **E13** Worker probes added
- [x] **E14** Task consumer idempotency guard
- [x] **E15** RetryFailedTasksJob delegates to UseCase

### Open
- [ ] **[🟡 P1] E16**: Move `publishTaskEventSync` calls in `CancelTask`/`RetryTask` to AFTER `WithTransaction` returns, or pass `txCtx`
- [ ] **[🟡 P1] E17**: Implement `OutboxPublisherJob` cron that polls `TaskEventRepo.ListUnpublished()` and publishes via Dapr, then marks published
- [ ] **[🟡 P1] E18**: `TaskProcessorWorker.Process()` should return `nil` after marking unknown types as failed (prevent Dapr retry)
- [ ] **[🔵 P2] E19**: Implement real data sync logic in `processDataSyncTask` or remove the feature
- [ ] **[🔵 P2] E20**: Add HTML escaping to message template variable replacement
- [ ] **[🔵 P2] E21**: Remove unused port 8081 declaration from worker-deployment.yaml
- [ ] **[🔵 P2] E22**: Wrap settings update + audit + event publish in a transaction
- [ ] **[🔵 P2] E23**: Add RBAC validation inside biz-layer usecases (defense in depth)
- [ ] **[🔵 P2] E5**: Add outbox pattern for `CreateTask` events (currently polling only)
- [ ] **[🔵 P2] E10**: Add event consumers to analytics worker for real-time dashboard data ingestion
