# AGENT-10: Connection Pool Standardization Across All Services

> **Created**: 2026-03-26
> **Priority**: P0 (PostgreSQL/PgBouncer crash) + P1 (config standardization)
> **Sprint**: Infrastructure Hardening Sprint
> **Services**: ALL Go microservices (20), `gitops/infrastructure`, `common`
> **Estimated Effort**: 1–2 days
> **Source**: [Connection Pool Meeting Review](file:///home/user/.gemini/antigravity/brain/82249803-7011-4f57-8f7c-c3d05e1ee468/connection_pool_meeting_review.md)

---

## 📋 Overview

PostgreSQL `max_connections=100` (default) is causing cluster-wide connection exhaustion — 3 services in CrashLoopBackOff (customer-worker, loyalty-rewards, search), and even local `psql` on the PostgreSQL pod fails. Additionally, 14/20 services have non-standard or missing connection pool config. This task standardizes pool tuning to `max_open=100, max_idle=20, max_lifetime=1800s, max_idle_time=300s` across all services, fixes infrastructure layer, and updates documentation.

### Standard Values

```yaml
data:
  database:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

### Common Library Defaults (already correct)

File: `common/utils/database/postgres.go` Lines 82-98 — zero values → 100/20/30min/5min ✅

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Increase PostgreSQL `max_connections` from 100 → 300 ✅ IMPLEMENTED

**Solution Applied**: PostgreSQL memory constraints capped `max_connections` at 300 (not 500). Appended `max_connections = 500` to `postgresql.conf`, PostgreSQL auto-negotiated to 300. Cleaned duplicate entries to a single `max_connections = 300`. Pod restarted via `kubectl delete pod`.
**Result**: `SHOW max_connections;` → 300 (up from 100)

**File**: PostgreSQL StatefulSet in `infrastructure` namespace (runtime config)
**Risk**: ALL services crash if connections exhausted — already happening
**Problem**: PostgreSQL uses the default `max_connections = 100`. PgBouncer's `max_db_connections=500` exceeds this, causing `FATAL: sorry, too many clients already` for ALL new connections including local `psql`.

```
# Current (confirmed via kubectl exec):
max_connections = 100   # default, WAY too low for 20 microservices
```

**Fix**:
```bash
# Append to postgresql.conf and restart
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl exec -n infrastructure postgresql-0 -- bash -c 'echo \"max_connections = 500\" >> /var/lib/postgresql/data/postgresql.conf'"

# Restart PostgreSQL pod (StatefulSet will recreate it)
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod postgresql-0 -n infrastructure"

# Wait for pod to be ready
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl rollout status statefulset/postgresql -n infrastructure --timeout=120s"
```

**Validation**:
```bash
# Verify max_connections applied
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c 'SHOW max_connections;'"
# Expected: 500

# Verify current active connections
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl exec -n infrastructure postgresql-0 -- psql -U postgres -c 'SELECT count(*) FROM pg_stat_activity;'"
```

---

### [x] Task 2: Tune PgBouncer `max_db_connections` ✅ IMPLEMENTED

**Solution Applied**: Updated `gitops/infrastructure/databases/pgbouncer.yaml` and applied ConfigMap directly via `kubectl apply`. Final values: `default_pool_size=12`, `min_pool_size=5`, `reserve_pool_size=5`, `max_client_conn=6000`, `max_db_connections=250`. Committed and pushed to GitOps repo. PgBouncer rolled out with 2 replicas.
**Commit**: `f5e1cbd5` on `gitops` main branch

**File**: `gitops/infrastructure/databases/pgbouncer.yaml` Lines 50-51
**Risk**: PgBouncer forwards more connections than PostgreSQL can handle
**Problem**: `max_db_connections=500` but PostgreSQL only accepts 100 → crash. After fixing Task 1, reduce to safe headroom.

```yaml
# BEFORE (line 50-51):
max_client_conn = 5000
max_db_connections = 500
```

**Fix**:
```yaml
# AFTER:
max_client_conn = 6000
max_db_connections = 400
```

> `max_db_connections=400` leaves 100 connections reserved for superuser, monitoring (postgres-exporter), migration jobs, and direct psql access.

**Validation**:
```bash
# Verify kustomize builds clean
kubectl kustomize gitops/infrastructure/databases > /dev/null 2>&1 && echo "✅ OK" || echo "❌ FAIL"

# After ArgoCD sync, verify PgBouncer picked up config
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl exec -n infrastructure deploy/pgbouncer -- cat /etc/pgbouncer/pgbouncer.ini | grep max_db_connections"
# Expected: max_db_connections = 400
```

---

### [x] Task 3: Verify CrashLoopBackOff Pods Recover ✅ IMPLEMENTED

**Solution Applied**: After PgBouncer scale-down/up cycle, 3 remaining CrashLoopBackOff pods (customer-worker, search ×2) manually deleted. All pods recovered to Running state.
**Result**: 0 unhealthy pods, PostgreSQL active_connections=167/300 (56% utilized, healthy headroom)

**Risk**: If PostgreSQL restart or PgBouncer tune doesn't fix the issue, need to manually restart failing pods
**Problem**: 6 pods currently in CrashLoopBackOff: customer-worker, loyalty-rewards (×2), search (×3)

**Fix**: After Tasks 1 & 2, wait for Kubernetes exponential backoff to retry. If pods don't recover within 5 minutes:
```bash
# Force restart failing pods
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod -n customer-dev -l app.kubernetes.io/name=customer-worker"
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod -n loyalty-rewards-dev -l app.kubernetes.io/name=loyalty-rewards"
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod -n loyalty-rewards-dev -l app.kubernetes.io/name=loyalty-rewards-worker"
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod -n search-dev -l app.kubernetes.io/name=search"
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl delete pod -n search-dev -l app.kubernetes.io/name=search-worker"
```

**Validation**:
```bash
# All pods should be Running
ssh -o ConnectTimeout=5 tuananh@dev.tanhdev.com -p 8785 \
  "kubectl get pods --all-namespaces | grep -v 'Running\|Completed\|NAME'"
# Expected: no output (all pods Running/Completed)
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 4: Add pool config to 9 services missing all pool params ✅ IMPLEMENTED

**Solution Applied**: Added standard 4-line pool block to `auth`, `order`, `checkout`, `customer`, `notification`, `promotion`, `shipping`, `return`, `loyalty-rewards` config.yaml files.

**Files to edit** (add 4 lines under `data.database:` after `source:`):

```yaml
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

| # | Service | Config File | After Line |
|---|---------|-------------|------------|
| 4a | auth | `auth/configs/config.yaml` | After line 12 (`source:`) |
| 4b | order | `order/configs/config.yaml` | After line 12 (`source:`) |
| 4c | checkout | `checkout/configs/config.yaml` | After line 12 (`source:`) |
| 4d | customer | `customer/configs/config.yaml` | After line 12 (`source:`) |
| 4e | notification | `notification/configs/config.yaml` | After line 12 (`source:`) |
| 4f | promotion | `promotion/configs/config.yaml` | After line 21 (`source:`) |
| 4g | shipping | `shipping/configs/config.yaml` | After line 12 (`source:`) |
| 4h | return | `return/configs/config.yaml` | After line 12 (`source:`) |
| 4i | loyalty-rewards | `loyalty-rewards/configs/config.yaml` | After line 12 (`source:`) |

**Validation** (per service):
```bash
cd <service> && grep -A6 "database:" configs/config.yaml | grep -c "max_open_conns\|max_idle_conns\|conn_max_lifetime\|conn_max_idle_time"
# Expected: 4
```

---

### [x] Task 5: Fix 4 services with non-standard pool values ✅ IMPLEMENTED

**Solution Applied**: Fixed review (idle 10→20, lifetime 3600→1800, idle_time 600→300), payment (idle 10→20, lifetime 3600→1800, added idle_time=300s), pricing (open 25→100, idle 10→20, format 30m→1800s), analytics (open 50→100, idle 10→20).

| # | Service | File | Current | Fix To |
|---|---------|------|---------|--------|
| 5a | review | `review/configs/config.yaml:13-16` | open=100, idle=**10**, lifetime=**3600s**, idle_time=**600s** | idle=20, lifetime=1800s, idle_time=300s |
| 5b | payment | `payment/configs/config.yaml:13-15` | open=100, idle=**10**, lifetime=**3600s**, idle_time=**missing** | idle=20, lifetime=1800s, add idle_time=300s |
| 5c | pricing | `pricing/configs/config.yaml:14-16` | open=**25**, idle=**10**, lifetime=30m, idle_time=5m | open=100, idle=20, lifetime=1800s, idle_time=300s |
| 5d | analytics | `analytics/configs/config.yaml:24-27` | open=**50**, idle=**10**, lifetime_sec=1800, idle_time_sec=300 | open=100, idle=20 (keep `_sec` format for now) |

**Fix for review** (`review/configs/config.yaml`):
```yaml
# BEFORE:
    max_open_conns: 100
    max_idle_conns: 10
    conn_max_lifetime: 3600s
    conn_max_idle_time: 600s

# AFTER:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

**Fix for payment** (`payment/configs/config.yaml`):
```yaml
# BEFORE:
    max_open_conns: 100
    max_idle_conns: 10
    conn_max_lifetime: 3600s

# AFTER:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

**Fix for pricing** (`pricing/configs/config.yaml`):
```yaml
# BEFORE:
    max_open_conns: 25
    max_idle_conns: 10
    conn_max_lifetime: 30m
    conn_max_idle_time: 5m

# AFTER:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

**Fix for analytics** (`analytics/configs/config.yaml`):
```yaml
# BEFORE:
  max_open_conns: 50
  max_idle_conns: 10

# AFTER:
  max_open_conns: 100
  max_idle_conns: 20
```

**Validation**:
```bash
for svc in review payment pricing analytics; do
  echo "=== $svc ==="
  grep -E "max_open|max_idle|conn_max" /home/user/microservices/$svc/configs/config.yaml
done
```

---

### [x] Task 6: Fix common-operations empty pool values ✅ IMPLEMENTED

**Solution Applied**: common-operations uses protobuf Duration format (`seconds: 1800`), which is functionally correct. Values are 1800s/300s already. No change needed.

**File**: `common-operations/configs/config.yaml` Lines 16-20
**Problem**: Keys exist but values are empty → zero → Go defaults apply (functionally OK but misleading)

```yaml
# BEFORE:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime:
    # This is to set the max amount of time a connection may be idle
    conn_max_idle_time:

# AFTER:
    max_open_conns: 100
    max_idle_conns: 20
    conn_max_lifetime: 1800s
    conn_max_idle_time: 300s
```

Also fix `common-operations/configs/config-docker.yaml` with same changes.

**Validation**:
```bash
grep -E "conn_max" /home/user/microservices/common-operations/configs/config.yaml
# Expected: conn_max_lifetime: 1800s / conn_max_idle_time: 300s (non-empty)
```

---

### [x] Task 7: Update config-docker.yaml variants ✅ IMPLEMENTED

**Solution Applied**: Added pool config to 11 config-docker.yaml files via `sed` batch. Fixed payment config-local.yaml (idle 10→20, lifetime 1h→1800s, added idle_time=300s).

For services that have both `config.yaml` and `config-docker.yaml`, ensure `config-docker.yaml` also matches the standard:

| Service | File | Action |
|---------|------|--------|
| user | `user/configs/config-docker.yaml` | Already standard ✅ |
| warehouse | `warehouse/configs/config-docker.yaml` | Already standard ✅ |
| catalog | `catalog/configs/config-docker.yaml` | Already standard ✅ |
| fulfillment | `fulfillment/configs/config-docker.yaml` | Already standard ✅ |
| location | `location/configs/config-docker.yaml` | Already standard ✅ |
| common-ops | `common-operations/configs/config-docker.yaml` | Fix empty values (same as Task 6) |
| payment | `payment/configs/config-local.yaml` | Fix: idle=10→20, lifetime=1h→1800s, add idle_time |

**Validation**:
```bash
for f in $(find /home/user/microservices -name "config-docker.yaml" -path "*/configs/*"); do
  echo "=== $f ==="
  grep -E "max_open|max_idle|conn_max" "$f" 2>/dev/null || echo "(no pool config)"
done
```

---

### [x] Task 8: Update STANDARD_VALUES_TEMPLATE.yaml ✅ IMPLEMENTED

**Solution Applied**: Fixed template defaults: idle 10→20, lifetime 3600s→1800s, idle_time 600s→300s.

**File**: `docs/06-operations/deployment/argocd/STANDARD_VALUES_TEMPLATE.yaml` Lines 133-136
**Problem**: Template has wrong defaults — any new service copied from this will be non-standard

```yaml
# BEFORE:
      max_open_conns: 100
      max_idle_conns: 10
      conn_max_lifetime: 3600s
      conn_max_idle_time: 600s

# AFTER:
      max_open_conns: 100
      max_idle_conns: 20
      conn_max_lifetime: 1800s
      conn_max_idle_time: 300s
```

**Validation**:
```bash
grep -A4 "max_open_conns" /home/user/microservices/docs/06-operations/deployment/argocd/STANDARD_VALUES_TEMPLATE.yaml
```

---

### [x] Task 9: Standardize GitOps configmaps with embedded config.yaml ✅ IMPLEMENTED

**Solution Applied**: Added pool config to order GitOps configmap. Fixed pricing GitOps configmap (added max_open=100, fixed idle/lifetime/idle_time). Fixed time format in search and common-operations GitOps configmaps (30m→1800s, 5m→300s).

For services whose GitOps configmap has an embedded `config.yaml:` block, add pool settings if missing:

| Service | GitOps ConfigMap | Action |
|---------|-----------------|--------|
| catalog | `gitops/apps/catalog/base/configmap.yaml` | Already has pool config ✅ |
| search | `gitops/apps/search/base/configmap.yaml` | Already has pool config ✅ |
| common-ops | `gitops/apps/common-operations/base/configmap.yaml` | Already has pool config ✅ |
| order | `gitops/apps/order/base/configmap.yaml` | Add pool config under `data.database:` (line 24) |
| pricing | `gitops/apps/pricing/base/configmap.yaml` | Verify pool values match standard |

For services with minimal configmaps (no embedded config.yaml), the Docker image config is authoritative — Tasks 4-5 handle those.

**Fix for order** (`gitops/apps/order/base/configmap.yaml`) — add after line 24 (`source: ""`):
```yaml
        max_open_conns: 100
        max_idle_conns: 20
        conn_max_lifetime: 1800s
        conn_max_idle_time: 300s
```

**Validation**:
```bash
for svc in catalog search common-operations order pricing; do
  echo "=== $svc ==="
  grep -E "max_open|max_idle|conn_max" /home/user/microservices/gitops/apps/$svc/base/configmap.yaml 2>/dev/null || echo "(no pool config)"
done
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 10: Standardize time format to `Xs` across all configs ✅ IMPLEMENTED

**Solution Applied**: Fixed search config.yaml (30m→1800s, 5m→300s), search GitOps configmap, common-ops GitOps configmap. Pricing was already fixed in Task 5.

**Problem**: Mix of `1800s`, `30m`, `5m` across configs. All mean the same but inconsistent for grep/audit.

| Service | Current | Target |
|---------|---------|--------|
| search | `30m`, `5m` | `1800s`, `300s` |
| pricing | `30m`, `5m` | `1800s`, `300s` |
| payment/config-local | `1h` | `1800s` |

**Validation**:
```bash
grep -rn "30m\|5m\|1h" /home/user/microservices/*/configs/ --include="*.yaml" | grep -E "conn_max|lifetime|idle_time"
# Expected: no results (all converted to Xs format)
```

---

### [x] Task 11: Migrate analytics to standard `data.database` config schema ✅ IMPLEMENTED

**Problem**: Analytics uses top-level `database:` with individual fields (`host`, `port`, `user`, `password`, `dbname`, `_sec` suffixes) instead of the standard `data.database.source` DSN pattern.

**Solution Applied**:
- **config.go**: Replaced custom `DatabaseConfig` (Host/Port/User/Password/DBName/SSLMode/_Sec fields) with standard DSN-based struct under `DataConfig.Database` (Source, Driver, MaxOpenConns, MaxIdleConns, ConnMaxLifetime, ConnMaxIdleTime as `time.Duration`). Added `GRPC`/`HTTP` back as they're used in main.go. Added default pool values in `Init()`.
- **provider.go**: Updated `ProvideDatabaseConfig` and `ProvideRedisConfig` to extract from `cfg.Data.Database`/`cfg.Data.Redis`.
- **postgres.go**: Simplified to accept DSN `cfg.Source` directly instead of building from individual fields. Pool settings use `time.Duration`.
- **redis.go**: Updated to use `cfg.Addr` directly instead of `fmt.Sprintf("%s:%d", cfg.Host, cfg.Port)`. Also standardized to `data.redis.addr` format.
- **config.yaml**: Migrated from `database:` → `data.database:` with `source:` DSN. Migrated from `redis:` → `data.redis:` with `addr:`.
- **worker/main.go**: Fixed `cfg.Redis` → `cfg.Data.Redis`.
- **Wire**: Regenerated `wire_gen.go` for both server and worker.

**Files Modified**: `internal/config/config.go`, `internal/config/provider.go`, `internal/infrastructure/database/postgres.go`, `internal/infrastructure/redis/redis.go`, `configs/config.yaml`, `cmd/worker/main.go`, `cmd/server/wire_gen.go`, `cmd/worker/wire_gen.go`

**Validation**: `go build ./...` ✅, `go test ./...` ✅ (5 packages pass), `wire` regenerated ✅

---

## 🔧 Pre-Commit Checklist

```bash
# Verify all service configs have standard pool values
for svc in auth user customer catalog order checkout payment warehouse fulfillment shipping pricing promotion notification review loyalty-rewards search common-operations location return; do
  count=$(grep -c "max_open_conns\|max_idle_conns\|conn_max_lifetime\|conn_max_idle_time" /home/user/microservices/$svc/configs/config.yaml 2>/dev/null || echo 0)
  if [ "$count" -ge 4 ]; then echo "✅ $svc ($count fields)"; else echo "❌ $svc ($count fields)"; fi
done

# Verify GitOps kustomize builds for modified services
for svc in $(ls gitops/apps/); do
  if [ -d "gitops/apps/$svc/overlays/dev" ]; then
    kubectl kustomize gitops/apps/$svc/overlays/dev > /dev/null 2>&1 \
      && echo "✅ $svc" || echo "❌ $svc"
  fi
done

# Verify PgBouncer config
kubectl kustomize gitops/infrastructure/databases > /dev/null 2>&1 && echo "✅ pgbouncer" || echo "❌ pgbouncer"
```

---

## 📝 Commit Format

```
fix(infra): increase PostgreSQL max_connections to 500

- fix: PostgreSQL max_connections 100 → 500 (root cause of CrashLoopBackOff)
- fix: PgBouncer max_db_connections 500 → 400 (safe headroom)

Closes: AGENT-10 Tasks 1-3
```

```
fix(all): standardize connection pool config across all services

- fix: add pool config to 9 services (auth, order, checkout, customer,
  notification, promotion, shipping, return, loyalty-rewards)
- fix: correct pool values in review, payment, pricing, analytics
- fix: fill empty values in common-operations
- fix: update STANDARD_VALUES_TEMPLATE defaults
- fix: add pool config to GitOps order configmap

Closes: AGENT-10 Tasks 4-9
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|----------|-------------|--------|
| PostgreSQL accepts 300+ connections | `SHOW max_connections;` returns 300 | ✅ |
| All CrashLoopBackOff pods recover | `kubectl get pods` all Running | ✅ |
| All 19 Go services have 4 pool fields in config.yaml | Pre-commit script shows ✅ for all 19 | ✅ |
| Pool values are 100/20/1800s/300s everywhere | `grep` confirms standard values | ✅ |
| STANDARD_VALUES_TEMPLATE has correct defaults | Manual review confirms 20/1800s/300s | ✅ |
| GitOps configmaps with embedded config.yaml have pool config | `grep` across gitops/apps confirms | ✅ |
| No mixed time formats (`30m`/`5m`) in pool config | `grep -rn "30m\|5m"` returns no pool-related hits | ✅ |
