# 📋 Documentation Audit Report — 2026-03-02

**Scope**: `docs/CODEBASE_INDEX.md` · `docs/SERVICE_INDEX.md`  
**Status**: ✅ Fixed — All issues resolved in this audit

---

## 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 1 | ✅ Fixed |
| P1 (High) | 5 | ✅ Fixed |
| P2 (Normal) | 5 | ✅ Fixed |

---

## 🔴 P0 Issues (Blocking)

1. **[PORT SWAP]** `SERVICE_INDEX.md` — Analytics and Common Ops ports were **swapped**.
   - Doc said: Analytics `8018/9018`, Common Ops `8019/9019`
   - Actual (per `PORT_ALLOCATION_STANDARD.md` + gitops configmaps):
     - **Analytics**: `8019/9019`
     - **Common Ops**: `8018/9018`
   - **Impact**: Developers routing requests to wrong ports.

---

## 🟡 P1 Issues (High)

1. **[MISSING WORKERS]** `CODEBASE_INDEX.md` — 8 services listed without Worker but actually have `cmd/worker/`:
   - `auth`, `user`, `location`, `loyalty-rewards`, `review`, `gateway`, `common-operations`
   - Also missing: `search/cmd/dlq-worker/` and `search/cmd/sync/`

2. **[STALE VERSION]** `SERVICE_INDEX.md` — Common library listed as `v1.10.0`, actual latest tag is **`v1.23.0`**.

3. **[INCORRECT DAPR]** `SERVICE_INDEX.md` Infrastructure Dependencies — Multiple services marked `—` for Dapr PubSub but actually use it:
   - `auth` (6 files), `user` (5 files), `payment` (37 files), `location` (2 files), `gateway` (1 file)

4. **[INCORRECT OUTBOX/IDEM/DLQ]** `SERVICE_INDEX.md` — Several columns inaccurate:
   - `user`: was missing Outbox ✅ and Idempotency ✅
   - `location`: was missing Outbox ✅
   - `analytics`: was listed with Outbox ❌ but doesn't have it; does have Idempotency ✅ + DLQ ✅
   - `review`: was listed without DLQ but actually has none (correct now)
   - `common-ops`: was listed without Idempotency but actually has ✅
   - `gateway`: was listed without DLQ but actually has ✅
   - `auth`: correctly has no Outbox/Idempotency/DLQ

5. **[MISSING COMMON PACKAGES]** `SERVICE_INDEX.md` — Only 5 packages listed, but `common/` has **21 packages** including critical ones: `events`, `client`, `errors`, `middleware`, `security`, `worker`, `models`, `geoip`, `grpc`, etc.

---

## 🔵 P2 Issues (Normal)

1. **[STALE DATE]** `SERVICE_INDEX.md` header said "Last Updated: 2026-02-14" → updated to 2026-03-02.

2. **[MISSING HEADER]** `CODEBASE_INDEX.md` had no Last Updated timestamp or stack summary.

3. **[MISSING WORKER COLUMN]** `SERVICE_INDEX.md` Service Catalog table had no Worker column. Since **all 21 services** now have a worker binary, added explicit Worker column.

4. **[CMD PATH VARIANTS]** `CODEBASE_INDEX.md` didn't document that some services use non-standard cmd names:
   - `checkout` → `cmd/server/` (not `cmd/checkout/`)
   - `analytics` → `cmd/server/` (not `cmd/analytics/`)
   - `common-operations` → `cmd/operations/` (not `cmd/common-operations/`)

5. **[STALE MAINTAINER LINK]** `SERVICE_INDEX.md` footer linked to `10-appendix/checklists/v5/master-checklist.md` → updated to `PORT_ALLOCATION_STANDARD.md` as authoritative source.

---

## 💡 Suggestions for Future

1. **Auto-generation**: Consider a script that scans `*/cmd/*/main.go` and `*/configs/config.yaml` to keep these indexes synced automatically.

2. **Common lib CHANGELOG**: The common lib jumped from documented v1.10.0 to actual v1.23.0 — 13 minor versions undocumented in the service index. Recommend tagging common lib releases in SERVICE_INDEX proactively.

3. **Search service complexity**: The `search` service has **4 binaries** (`server`, `worker`, `dlq-worker`, `sync`) which is unique. Consider documenting this in the search service doc as well.

4. **Frontend Outbox column**: SERVICE_INDEX previously had Frontend/Admin marked with ✅ Outbox which makes no sense for JS apps — corrected to `—`.

---

## ✅ Changes Made

| File | Action |
|------|--------|
| `docs/CODEBASE_INDEX.md` | Full rewrite — accurate workers, cmd paths, service descriptions, common lib version, expanded patterns |
| `docs/SERVICE_INDEX.md` | Full rewrite — corrected ports, added Worker column, fixed Outbox/Idempotency/DLQ/Dapr, updated common packages, corrected infrastructure deps |
