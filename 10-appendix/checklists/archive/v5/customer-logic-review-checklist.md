# Customer Service Business Logic Review Checklist

> **Service**: `customer/` — Customer lifecycle management (Registration, Auth, Address, Segments, Preferences, GDPR, Wishlist, Analytics, Audit)
> **Reviewed**: 2026-02-19 | **Reviewer**: AI Senior Architect (v2 — code-validated)
> **Scope**: 119 Go files · 20 SQL migrations · 8 biz domains · worker binary with 3 cron jobs + outbox worker
> **Compared vs**: Shopify, Shopee, Lazada patterns

---

## Changelog vs Previous Review (2026-02-18)

| # | Old Status | New Status | What Changed |
|---|-----------|-----------|--------------|
| Social login creates profile+prefs | 🔴 P0 | ✅ FIXED | `social_login.go:116-142` now creates `CustomerProfile` + `CustomerPreferences` |
| `UpdateCustomer` uses outbox | 🔴 P0 | ✅ FIXED | `customer.go:427-442` writes `customer.updated` outbox event inside tx |
| `DeleteCustomer` uses outbox | 🔴 P0 | ✅ FIXED | `customer.go:783-803` writes `customer.deleted` outbox event inside tx |
| `VerifyEmailToken` sets `EmailVerified` | 🔴 P0 | ✅ FIXED | `verification.go:268` sets `customer.EmailVerified = true` |
| `Register` creates profile+prefs | ⚠️ P1 | ✅ FIXED | `auth.go:188-214` atomically creates profile + preferences in tx |
| Password reset token predictable | 🔴 P0 | ✅ FIXED | `auth.go:823-828` uses `crypto/rand` 32-byte hex token |
| Reset token in API response | 🔴 P0 | ✅ FIXED | `auth.go:742` Token field omitted from `PasswordResetResponse` |
| Address delete event before delete | 🔴 P0 | ✅ FIXED | `address.go:558-560` publishes event AFTER `DeleteByID` |
| Order stats read-modify-write race | 🔴 P0 | ✅ FIXED | `customer.go:955,969` now use atomic `repo.IncrementOrderStats/DecrementOrderStats` |
| `isValidCountryCode` only checks length | ⚠️ P2 | ✅ FIXED | `address.go:604-618` now uses ISO 3166-1 alpha-2 allowlist |
| Outbox infinite retries | ⚠️ P1 | ✅ FIXED | `outbox.go:53,73-78` max 10 retries + exponential backoff |
| `isValidJSON` fake validation | ⚠️ P1 | Can't verify | Not seen in current codebase scan |

---

## 1. Sự nhất quán dữ liệu giữa các service (Data Consistency)

### 1.1 Customer ↔ Profile ↔ Preferences

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 1.1.1 | `CreateCustomer` atomically creates customer + profile + preferences | ✅ OK | `customer.go:170-271` | All 3 in single `uc.transaction()` + outbox event |
| 1.1.2 | `UpdateCustomer` atomically updates + writes outbox event | ✅ OK | `customer.go:333-445` | Transaction wraps all updates + `customer.updated` outbox |
| 1.1.3 | `DeleteCustomer` soft-deletes + writes outbox | ✅ OK | `customer.go:782-808` | Transaction wraps delete + `customer.deleted` outbox |
| 1.1.4 | Social login creates profile + preferences | ⚠️ P1 | `social_login.go:112-143` | Creates customer → profile → prefs → outbox in sequence **without a transaction**. If profile or prefs create fails, customer record exists without them |
| 1.1.5 | `Register` creates profile + preferences | ✅ OK | `auth.go:183-241` | Wrapped in `uc.transaction()` |
| 1.1.6 | `VerifyEmailToken` sets `EmailVerified` | ✅ OK | `verification.go:268-274` | Sets `customer.EmailVerified = true` + status transition |
| 1.1.7 | `DeleteCustomer` cascades to profile/preferences/addresses | ⚠️ P1 | `customer.go:772-818` | Only soft-deletes customer. Profile, preferences, and addresses are NOT soft-deleted. Query `WHERE deleted_at IS NULL` on customer does not apply to sub-tables |
| 1.1.8 | `ActivateCustomer` / `DeactivateCustomer` / `SuspendCustomer` | ⚠️ P1 | `customer.go:1108-1210` | Status change + fire-and-forget event publish — no outbox. If Dapr publish fails, downstream never learns of status change |

### 1.2 Customer ↔ Address

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 1.2.1 | `CreateAddress` + `SetDefaultAddress` is atomic | ⚠️ P1 | `address.go:146-163` | `repo.Create` + `repo.SetDefaultAddress` are two separate non-transactional calls. If SetDefault fails, address exists but is not the default |
| 1.2.2 | `UpdateAddress` + `SetDefaultAddress` is atomic | ⚠️ P1 | `address.go:293-314` | `SetDefaultAddress` + `Update` are separate calls — potential inconsistent default state |
| 1.2.3 | `DeleteAddress` prevents deleting last address | ✅ OK | `address.go:518-524` | Guard: `len(addresses) <= 1` returns error |
| 1.2.4 | `DeleteAddress` auto-reassigns default | ✅ OK | `address.go:528-550` | Finds first other address and sets as default |
| 1.2.5 | `DeleteAddress` event after actual delete | ✅ OK | `address.go:552-560` | `PublishAddressDeleted` fires AFTER `repo.DeleteByID` succeeds |
| 1.2.6 | Address pagination at DB level | ⚠️ P2 | `address.go:414-444` | `FindByCustomerID` fetches ALL addresses, applies offset/limit in Go. O(n) memory. Should use LIMIT/OFFSET query |

### 1.3 Customer Order Stats (Cross-service)

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 1.3.1 | Order stats use atomic SQL | ✅ OK | `customer.go:955,969` | Delegates to `repo.IncrementOrderStats` / `repo.DecrementOrderStats` (atomic DB UPDATE) |
| 1.3.2 | Stats NOT idempotent (duplicate events) | ⚠️ P1 | `customer.go:951-975` | No idempotency key. Duplicate `order.completed` events → double-counted stats |
| 1.3.3 | `AdjustCustomerSpent` delegates to atomic repo | ✅ OK | `customer.go:983` | Uses `repo.AdjustTotalSpent` (expects `GREATEST(0, total_spent + amount)`) |
| 1.3.4 | Stats reconciliation cron is a TODO stub | ⚠️ P2 | `cron/stats_worker.go` | Hourly cron exists but body is empty TODO |

### 1.4 Customer ↔ Segments

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 1.4.1 | `autoAssignDefaultSegments` outside transaction | ⚠️ P2 | `customer.go:278-280` | Best-effort after tx commit — acceptable |
| 1.4.2 | `DeleteSegment` cascades via DB only | ⚠️ P2 | `segment.go:265-288` | Relies on DB CASCADE. No `segment.removed` events emitted for bulk membership removal |
| 1.4.3 | `ListActiveSegments` filters in memory | ⚠️ P2 | `segment.go:244-262` | Fetches ALL then filters `IsActive` in Go — should add `WHERE is_active = true` |

---

## 2. Dữ liệu bị lệch (Data Mismatches)

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 2.1 | Social login customer: profile/prefs created outside tx | ⚠️ P1 | `social_login.go:112-143` | If profile or prefs `Create` fails, customer exists without them. Unlike `CreateCustomer`, no tx wraps the social login new-user path |
| 2.2 | Social login ignores profile/prefs create errors | ⚠️ P1 | `social_login.go:123-125, 140-142` | Profile and prefs create errors are only logged — they do not abort the flow. Silently produces incomplete customer data |
| 2.3 | `customer.updated` outbox event only captures top-level field changes | ⚠️ P2 | `customer.go:318-331` | `changes` map only tracks firstName/lastName/phone/status. Profile and preferences changes (DateOfBirth, Gender, CustomPreferences) are NOT captured in the outbox event |
| 2.4 | `CustomerGroupID` default "B2C"/"B2B" not validated | ⚠️ P1 | `customer.go:189-194` | Hardcoded strings not verified against `stable_customer_groups` table. FK failure at DB level if groups don't exist |
| 2.5 | `ActivateCustomer` / `DeactivateCustomer` status events fire-and-forget | ⚠️ P1 | `customer.go:1134-1135, 1169-1170, 1204-1205` | Status change events published via Dapr directly — not via outbox. If publish fails, downstream services never learn of status change |
| 2.6 | Password reset token found via full-table scan | 🔴 P0 | `auth.go:858-896` | `findCustomerByResetToken` calls `uc.repo.Search(ctx, nil)` which fetches **all customers** (no filter). Iterates each row's metadata JSON. Will timeout at scale |
| 2.7 | Password reset still stored in customer metadata JSONB | ⚠️ P1 | `auth.go:664-684` | Token hash in shared metadata field. Any full metadata overwrite (e.g., social login link, settings update) can wipe active reset token |
| 2.8 | `VerifyEmailToken` marks token used with `Warnf` on failure | ⚠️ P2 | `verification.go:257-259` | If `MarkAsUsed` fails (e.g. DB error), the function continues and sets `EmailVerified = true`. The token remains usable for repeated verification |

---

## 3. Cơ chế Retry / Rollback / Outbox Pattern

### 3.1 Outbox Write Side

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 3.1.1 | `CreateCustomer` writes outbox atomically | ✅ OK | `customer.go:247-268` | `outboxRepo.Create()` inside same `uc.transaction()` |
| 3.1.2 | `UpdateCustomer` writes outbox atomically | ✅ OK | `customer.go:427-442` | `customer.updated` outbox event inside tx |
| 3.1.3 | `DeleteCustomer` writes outbox atomically | ✅ OK | `customer.go:783-803` | `customer.deleted` outbox event inside tx |
| 3.1.4 | Social login writes outbox | ⚠️ P1 | `social_login.go:145-164` | Outbox write NOT inside a transaction with customer/profile/prefs creation. Race: customer can be created but outbox event lost |
| 3.1.5 | Status transitions use outbox | 🔴 P0 | `customer.go:1108-1210` | `ActivateCustomer`, `DeactivateCustomer`, `SuspendCustomer` all use direct fire-and-forget `events.PublishCustomerStatusChanged`. No outbox, no transaction |
| 3.1.6 | Address operations use outbox | ⚠️ P1 | `address.go` | ZERO outbox writes — all address events (`address.created`, `address.updated`, `address.deleted`) are direct fire-and-forget Dapr publishes |
| 3.1.7 | Verification events use outbox | ⚠️ P2 | `verification.go` | `VerifyEmailToken` and `VerifyPhoneCode` do not write outbox. `customer.verified` events emitted only from `VerifyEmail`/`VerifyPhone` usecase via direct publish |

### 3.2 Outbox Publish Side (Worker)

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 3.2.1 | Outbox worker polls and processes events | ✅ OK | `biz/worker/outbox.go:33-50` | Polls every 30s, batch of 10 |
| 3.2.2 | Worker handles `customer.created` | ✅ OK | `outbox.go:116-156` | Full event construction and publish |
| 3.2.3 | Worker handles `customer.updated` | ✅ OK | `outbox.go:158-164` | Raw passthrough via `json.RawMessage` |
| 3.2.4 | Worker handles `customer.deleted` | ✅ OK | `outbox.go:166-172` | Raw passthrough via `json.RawMessage` |
| 3.2.5 | Worker handles other event types | 🔴 P0 | `outbox.go:174-176` | `default: return fmt.Errorf("unsupported event type")` — causes events like `customer.status_changed`, `address.created`, `segment.assigned` to be permanently failed after 10 retries if they ever reach outbox. Combined with issue 3.1.5/3.1.6, those events don't reach outbox — so at least they won't get stuck. But if outbox coverage expands without updating worker, they will silently die |
| 3.2.6 | Max retry + exponential backoff | ✅ OK | `outbox.go:52-93` | `maxOutboxRetries = 10`. Exponential backoff `2^retryCount` minutes capped at 60min |
| 3.2.7 | Published events cleanup | ⚠️ P2 | N/A | No cleanup cron for published outbox events — table grows indefinitely |

### 3.3 GDPR Deletion (Cross-service Saga)

| # | Check | Status | File | Notes |
|---|-------|--------|------|-------|
| 3.3.1 | `ProcessAccountDeletion` wraps local ops in transaction | 🔴 P0 | `gdpr.go:138-237` | 7 sequential DB operations with NO transaction wrapper. If address loop (`200-208`) partially fails mid-loop, customer is anonymized but some addresses remain |
| 3.3.2 | Cross-service calls have retry/compensation | ⚠️ P1 | `gdpr.go:220-233` | Order anonymization and payment method deletion are fire-and-forget with `Errorf` log. No retry, no outbox, no saga step tracker |
| 3.3.3 | GDPR deletion status tracked per-step | ⚠️ P1 | `gdpr.go:162` | After all operations, status set to Inactive. If cross-service calls fail, status is still Inactive — no per-step completion flag. Impossible to know which steps succeeded |
| 3.3.4 | 30-day grace period enforced | ✅ OK | `gdpr.go:77`, `cleanup_worker.go` | `DeletionScheduledAt = now + 30 days`. Cron queries `WHERE deletion_scheduled_at < NOW()` |
| 3.3.5 | `CancelAccountDeletion` always restores to Active | ⚠️ P2 | `gdpr.go:128` | `customer.Status = constants.CustomerStatusActive` always. Customer previously Suspended who requests deletion, then cancels, will become Active (bypasses suspension) |

---

## 4. Edge Cases & Rủi ro Logic

### 4.1 Authentication & Security

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 4.1.1 | `findCustomerByResetToken` full-table scan | 🔴 P0 | `auth.go:858` | `repo.Search(ctx, nil)` fetches all customers, then iterates each metadata JSONB. **Must** migrate to `verification_tokens` table or Redis |
| 4.1.2 | Password reset token stored in metadata | ⚠️ P1 | `auth.go:674-680` | Any metadata update can overwrite reset token. `TODO` comment acknowledges this but no ticket/fix |
| 4.1.3 | `Login` rate limit per-IP only | ⚠️ P1 | `auth.go:276-292` | Account lock is per-email (5 failures), IP rate limit is per-IP (10/min). Distributed attack from multiple IPs bypasses IP throttle |
| 4.1.4 | `Login` doesn't check `EmailVerified` | ⚠️ P2 | `auth.go:305-312` | Status check only (`Status != 2`). Unverified customers with Active status can login. Shopify/Lazada enforce email verification before first login |
| 4.1.5 | `enable2FA` activates without confirmation code | ⚠️ P1 | `two_factor.go` | 2FA enabled immediately without requiring customer to confirm one valid TOTP code first. If customer sets up TOTP incorrectly, they lock themselves out |
| 4.1.6 | No backup codes for 2FA | ⚠️ P2 | `two_factor.go` | No backup code generation. If TOTP app is lost, no recovery path |
| 4.1.7 | `Register` sends verification email inside tx | ⚠️ P1 | `auth.go:218-226` | `SendEmailVerification` is called inside `uc.transaction()`. If email service is down, the registration tx rolls back — user cannot register even though their data is valid |

### 4.2 Customer Lifecycle

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 4.2.1 | `UpdateCustomer` allows direct status change without state machine | ⚠️ P1 | `customer.go:349-351` | `req.Status != "" → existing.Status = FromString(req.Status)`. Can jump Suspended → Active bypassing business rules (should require admin approval) |
| 4.2.2 | Email uniqueness TOCTOU race | ⚠️ P1 | `customer.go:154-160` | `FindByEmail` + `Create` without tx lock. Two concurrent requests can create duplicate emails. Relies on DB unique index for final guard |
| 4.2.3 | `CustomerGroupID "B2C"/"B2B"` hardcoded | ⚠️ P1 | `customer.go:189-194` | Not validated against `stable_customer_groups`. FK error at DB if group doesn't exist |
| 4.2.4 | `VerifyEmail` publishes status event via direct publish (not outbox) | ⚠️ P1 | `customer.go:848-854` | `PublishCustomerVerified` + `PublishCustomerStatusChanged` are direct fire-and-forget. If Dapr is down at moment of verification, event lost |
| 4.2.5 | `UpdateLastLogin` is separate non-transactional DB write | ⚠️ P2 | `customer.go:907-924; auth.go:335-339` | `UpdateLastLogin` called after `GenerateToken` — not critical but can fail silently losing last-login audit trail |

### 4.3 Social Login

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 4.3.1 | New social login user creation has no transaction | ⚠️ P1 | `social_login.go:90-165` | Customer, profile, prefs, outbox event created sequentially WITHOUT `uc.transaction()`. Race condition / partial failure possible |
| 4.3.2 | Profile + prefs create errors silently swallowed | ⚠️ P1 | `social_login.go:123-125, 140-142` | `uc.log.Errorf(...)` only — errors don't abort. Can create customer without profile/prefs |
| 4.3.3 | Apple token verification hardcodes client_id | ⚠️ P1 | `social_login.go:362-366` | `"com.example.app"` and `"apple_client_secret"` and `"https://example.com/callback"` are hardcoded strings — will fail in production |
| 4.3.4 | `LinkSocialAccount` is not idempotent | ⚠️ P2 | `social_login.go:211-220` | Overwrites metadata key `social_<provider>` — re-linking the same provider always overwrites, not an error |
| 4.3.5 | Social login does not verify `AccessToken` matches claimed email | ⚠️ P1 | `social_login.go:79-86` | `verifyAccessToken` only confirms token is valid but does NOT verify returned user info matches `req.Email`. Attacker can pass a valid token for user A but claim email of user B |

### 4.4 Address Logic

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 4.4.1 | No customer existence check in `CreateAddress` | ⚠️ P1 | `address.go:93-200` | `req.CustomerID` validated as Required but never checked if customer exists in DB. FK constraint catches it at DB level only |
| 4.4.2 | No max address limit per customer | ⚠️ P2 | `address.go` | No upper bound on address count. Shopee: 5 addresses/type. No limit = potential abuse |
| 4.4.3 | `standardizeCity` breaks Vietnamese city names | ⚠️ P2 | `address.go:678-690` | Title-cases all words using ASCII conversion. Unicode names (e.g. "Đà Nẵng") may be corrupted |
| 4.4.4 | Address CRUD events not transactional | ⚠️ P1 | `address.go` | All address events are fire-and-forget. No outbox for address operations |

### 4.5 Segment Logic

| # | Risk | Severity | File | Description |
|---|------|----------|------|-------------|
| 4.5.1 | Segment evaluator loads ALL customers | ⚠️ P2 | `cron/segment_evaluator.go:128-180` | O(segments × customers) — does not scale. Delta-based evaluation needed |
| 4.5.2 | Segment assignment not idempotent in evaluator | ⚠️ P2 | `segment_evaluator.go:155` | Always calls `AssignCustomerToSegment` without checking membership first. Generates unnecessary assignment events |

---

## 5. Severity Summary

| Severity | Count | Items |
|----------|-------|-------|
| 🔴 P0 Critical | 3 | `findCustomerByResetToken` full-table scan; GDPR no tx for local ops; Outbox worker `default: error` on unknown types |
| ⚠️ P1 High | 17 | Social login no tx; status transition events not outbox; GDPR cross-service fire-and-forget; Apple config hardcoded; Social email mismatch; address not transactional; etc. |
| ⚠️ P2 Medium | 11 | Address pagination; stats reconciliation stub; segment evaluation scale; city name unicode; etc. |
| ✅ OK / Fixed | 12 | All items from previous P0 list — see changelog above |

---

## 6. So sánh với Industry Patterns (Shopify, Shopee, Lazada)

| Pattern | Shopify | Shopee | Lazada | Current Code | Gap |
|---------|---------|--------|--------|-------------|-----|
| **Customer Registration** | Atomic with metafields. Webhook for welcome email outside tx | Customer + profile atomic. OTP before activation | Similar | ✅ `CreateCustomer` atomic. ✅ `Register` atomic. ⚠️ `SocialLogin` not atomic | P1: Wrap social login in tx |
| **Outbox Pattern** | Webhooks retry 19× with exp backoff | Pub/Sub with retry + DLQ | Kafka exactly-once | ✅ Create/Update/Delete use outbox. 🔴 Status changes, address events still fire-and-forget | P0: Status transitions → outbox |
| **Password Reset** | UUID in separate tokens table. 1h expiry | OTP via SMS/email, stored in Redis | Similar to Shopee | ✅ `crypto/rand` token. ✅ SHA-256 hash stored not raw. 🔴 Full-table scan to find token | P0: Migrate to `password_reset_tokens` table or Redis |
| **GDPR Deletion** | 30-day hold. Orchestrated with compensation | Grace period + staged deletion | Status-tracked deletion | ✅ 30-day grace. 🔴 No tx on 7-step operation. ⚠️ Cross-service calls fire-and-forget | P0: Wrap local ops in tx. P1: Use outbox for cross-service |
| **Address Management** | Atomic default assignment | 5 addresses/type limit | Similar limits | ✅ Prevent last-delete. ⚠️ Create+SetDefault not atomic. ❌ No address count limit | P1: Add tx, add max limit |
| **2FA Setup** | Requires confirming first TOTP code. Backup codes mandatory | SMS OTP at login | Similar | ⚠️ 2FA enabled without confirmation. ❌ No backup codes | P1: Require confirmation + backup codes |
| **Social Login** | OAuth 2.0 proper validation. Customer created atomically | Full customer profile on social login | Similar + phone binding | ⚠️ Creates customer WITHOUT tx for profile/prefs. Apple config hardcoded | P1: Add tx; fix Apple config |
| **Order Stats** | Idempotent with order version tracking | Redis atomic counters | Event-sourced | ⚠️ Stats atomic SQL now, but NOT idempotent — duplicate events double-count | P1: Add idempotency key per order |
| **Segmentation** | Rule-based via background jobs. Shopify Flow | Real-time on attribute change + batch | Batch + real-time hybrid | ✅ Dynamic segment cron. ⚠️ Full-scan, not delta | P2: Delta-based evaluation |

---

## 7. Recommended Priority Fixes

### Immediate (P0 — Before Production)

1. **`findCustomerByResetToken` full-table scan** — Migrate password reset tokens to `verification_tokens` table (already exists). Lookup by `token_hash + type = "password_reset"`. Zero O(n) scan required
2. **GDPR `ProcessAccountDeletion` — wrap local ops in single transaction** — Steps 1-5 (anonymize customer, profile, prefs, delete addresses, delete wishlists) must be atomic. Cross-service calls (order, payment) should be moved to outbox events for retry
3. **Status transitions via outbox** — `ActivateCustomer`, `DeactivateCustomer`, `SuspendCustomer` must write `customer.status_changed` outbox events inside transaction before calling direct event publish

### Short-term (P1 — Sprint Backlog)

1. **Wrap social login new-user creation in transaction** — `CreateCustomer` pattern must be followed: customer + profile + prefs + outbox event in single `uc.transaction()`
2. **Make `IncrementCustomerOrderStats` idempotent** — add `order_id` to event payload and use `INSERT INTO processed_events(order_id) ON CONFLICT DO NOTHING` guard
3. **Fix Apple social login hardcoded config** — three hardcoded strings must come from `config.go`
4. **Verify social login token claims email** — after `verifyAccessToken`, compare returned email from provider against `req.Email`
5. **Move address events to outbox** — `AddressUsecase` needs an `outboxRepo` dependency; all events written to outbox instead of fire-and-forget
6. **State machine for status transitions** — `UpdateCustomer` must validate allowed status transitions (e.g., `Suspended → Active` requires admin flag)
7. **`Register` email outside transaction** — move `SendEmailVerification` outside the tx or use outbox for email triggering. Currently email failure rolls back registration
8. **2FA confirmation before enable** — require customer to confirm one valid TOTP code before activating 2FA
9. **Fix `VerifyEmailToken` soft `MarkAsUsed` failure** — if marking fails, abort or re-check; don't silently allow reuse

### Medium-term (P2 — Backlog)

1. Add max address limit per customer (suggest 50, configurable)
2. `ListAddressesByCustomer` — paginate at DB level (LIMIT/OFFSET)
3. Segment evaluator — delta-based evaluation (only changed customers)
4. Cleanup cron for published outbox events
5. `CancelAccountDeletion` — store pre-deletion status to restore correctly
6. Stats reconciliation worker — implement actual order service integration
7. `ListActiveSegments` — filter at DB level

---

## 8. Test Coverage Assessment

| Test File | Current Coverage | Critical Gaps |
|-----------|-----------------|--------------|
| `biz/customer/customer_test.go` | Create, Update, Get, List, Delete | Social login tx atomicity; GDPR partial failure; status transitions; order stat idempotency |
| `biz/address/address_test.go` | Exists | Default address race; Create+SetDefault partial failure |
| `biz/customer/auth.go` | No dedicated test file found | `findCustomerByResetToken` full-scan; rate limit bypass; 2FA enable without confirmation |
| Outbox worker | No test file found | `publishEvent` routing for all event types |

### Recommended New Tests

1. `TestAuthenticateSocialLogin_NewUser_AtomicCreation` — verify profile + prefs created even if individual creates called in parallel
2. `TestProcessAccountDeletion_PartialAddressDeleteFailure` — if 3rd address delete fails, first 2 should roll back (currently they won't)
3. `TestIncrementOrderStats_DuplicateEvent_NotDoubleCounted` — simulate duplicate order events, verify count stays correct
4. `TestActivateCustomer_EventPublishedViaOutbox` — verify outbox event written (currently fails — event is fire-and-forget)
5. `TestPasswordReset_FindByToken_NotFullTableScan` — assert lookup uses index, not full scan
6. `TestOutboxWorker_UnknownEventType_GetsMarkedFailed` — verify `default` branch causes max-retry exhaustion
7. `TestSocialLogin_AppleProvider_UsesConfigNotHardcoded` — verify Apple client_id reads from config
