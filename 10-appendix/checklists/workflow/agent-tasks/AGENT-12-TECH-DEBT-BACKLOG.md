# Agent 12 — Tech Debt Backlog (Known TODOs)

**Scope**: Low-priority tech debt across services — all have tracking tickets or documented migration paths  
**Total**: 13 P2 items (deferred)

---

| # | Issue | Service | Status | Tracking |
|---|-------|---------|--------|----------|
| P2-59 | Commission rate hardcoded at 10% | payment | ⚠️ OPEN | Jira `TA-1075` — future seller config |
| P2-09 | Dual `warehouseClient`/`warehouseInventoryService` interface | checkout | ⚠️ OPEN | Active migration with `[TECH_DEBT]` logging |
| P2-40 | `notification.*` events have zero consumers | notification | ⚠️ OPEN | Published for future observability dashboards |
| P2-61 | SmartCache metrics commented out — no cache hit/miss observability | gateway | ⚠️ OPEN | `smart_cache.go:177,192` — counters removed to fix data race (AGENT-13 Task 17). Re-enable with `atomic.Int64` or Prometheus counter when ready. |
| P2-62 | Triple CORS in BFF Handler | gateway | ⚠️ OPEN | AGENT-13 Task 8 — workaround at Ingress level, low priority. |
| P2-63 | Add password complexity validation (OWASP) | customer | ⚠️ OPEN | AGENT-15 Task 9 — uppercase, lowercase, number, special char |
| P2-64 | Extract duplicate registration logic (`CreateCustomer` vs `Register`) | customer | ⚠️ OPEN | AGENT-15 Task 10 — share `createCustomerInTx` |
| P2-65 | Extract retry/backoff logic in consumers to `common/events/retry.go` | common | ⚠️ OPEN | AGENT-15 Task 11 |
| P2-66 | Extract duplicate `isPermanentError`/`classifyError` to shared utility | common | ⚠️ OPEN | AGENT-15 Task 12 |
| P2-67 | Stats Worker gRPC timeout too long (10s → 3-5s) | loyalty-rewards | ⚠️ OPEN | AGENT-15 Task 13 |
| P2-68 | Add JWT secret hot-reload via Consul/Vault watcher | auth | ⚠️ OPEN | AGENT-15 Task 14 |
| P2-69 | Account Lockout on Distributed Brute-Force (N failed attempts) | auth | ⚠️ OPEN | Discovered in Auth 4-Agent Review |
| P2-70 | Add Prometheus metrics for `brute_force_blocked_total` in rate-limiter | user | ⚠️ OPEN | Discovered in User 4-Agent Review |
