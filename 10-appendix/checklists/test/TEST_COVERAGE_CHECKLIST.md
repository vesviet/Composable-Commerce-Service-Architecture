# Test Coverage Checklist — Target 60%+ All Services

> **Generated**: 2026-03-02 | **Last Updated**: 2026-03-05 08:30 (UTC+7)
> **Platform**: 21 Go Services | **Current**: 14/21 above 60% (overall service-level)
> **Test Files**: 468 total test files across all services

> [!IMPORTANT]
> This checklist is the single source of truth for test coverage status.
> Agents should update this file after completing any test coverage work.
> **Last Indexed**: March 4, 2026 - Full codebase scan completed

---

## 📊 Dashboard

**Test File Distribution:**
- Total test files: 468
- Biz layer tests: 291 files (63%)
- Service layer tests: 97 files (21%)
- Data layer tests: 38 files (8%)
- Other tests: 42 files (9%)

**Services with Service Layer Tests:** 12/21 (57%)
- ✅ analytics (15), search (20), order (11), shipping (7), loyalty-rewards (7), catalog (6), auth (1), location (1), gateway (1), promotion (2), payment (5), common-operations (2), checkout (4)
- ⚠️ Missing: pricing, review, user, customer, notification, return

| # | Service | Biz Coverage | Overall | Target | Status | Test Files (biz/svc/data) | Work Done |
|---|---------|-------------|---------|--------|--------|---------------------------|-----------|
| 1 | **analytics** | **67.6%** | **~65%** | 60% | ✅ Done | 16/15/0 (32 total) | biz 67.6%, service 61.1%, marketplace 73.2%, pii 96.2% |
| 2 | **pricing** | **75.5% avg** | **~68%** | 60% | ✅ Done | 13/0/0 (13 total) | All 8 biz packages >63%, avg 75.5%. ⚠️ No service tests |
| 3 | **gateway** | N/A | **~82%** | 60% | ✅ Done | 0/1/0 (68 total) | All packages >56%, most >70% |
| 4 | **review** | **62.9% avg** | **~55%** | 60% | ✅ Biz Done | 5/0/0 (5 total) | helpful 63.9%, moderation 72.4%, rating 51.8%, review 59.6%. ⚠️ No service tests |
| 5 | **loyalty-rewards** | **75.6% avg** | **~55%** | 60% | ✅ Biz Done | 6/7/8 (21 total) | All 6 biz packages >71%. Service 30.4% |
| 6 | **auth** | **74.9% avg** | **~80%** | 60% | ✅ Fully Done | 7/1/3 (15 total) | biz 71.0%, audit 91.7%, login 79.1%, token 67.5%, session 65.3%. Service **89.6%**. Added model 100%, middle 79.2%, obs 94.4%, data ~3% |
| 7 | **location** | **62.2%** | **~64%** | 60% | ✅ Done | 1/1/1 (3 total) | biz 62.2%, postgres 65.1%, service 65.3% |
| 8 | **catalog** | **69.1% avg** | **~62%** | 60% | ✅ Biz Done | 24/6/12 (48 total) | 7/7 biz >62%: product 62.9%, cms 83.0%, pvr 76.4%, mfr 70.9%, cat 64.8%, brand 63.0%, attr 62.5% |
| 9 | **search** | **80.9% avg** | **~40%** | 60% | ✅ Improved | 15/20/0 (35 total) | biz 80.1%, cms 100%, ml 100%. validators 70%, common 71.7%, service 30.5% |
| 10 | **user** | **84.7%** | **~60%** | 60% | ✅ Biz Done | 7/0/4 (12 total) | biz 84.7% (was 73.0%). Postgres 65.6%. ⚠️ No service tests |
| 11 | **shipping** | **63.7%** | **~70%** | 60% | ✅ Service Done | 14/7/7 (36 total) | shipment 71.4%, carriers >83%. Service **91.4%** (was 70.6%) |
| 12 | **fulfillment** | **79.8% avg** | **~60%** | 60% | ✅ Service Done | 15/10/0 (25 total) | biz 76.5%, pkg 74.2%, picklist 80.2%, qc 88.2%. Service **58.1%** (was 0%) |
| 13 | **order** | **79.8% avg** | **~60%** | 60% | ✅ Service Improved | 13/11/5 (31 total) | cancel 78.6%, order 60.2%, status 85.3%, validation 94.7%. eventbus 52%, security 69%. Service **65.5%** |
| 14 | **promotion** | **77.3%** | **~50%** | 60% | ✅ Biz Done | 20/2/0 (22 total) | biz 77.3%. Service 21.3% |
| 15 | **payment** | **62.5% avg** | **~50%** | 60% | ✅ Service Improved | 28/5/1 (34 total) | pm 90.2%, txn 80.6%, settings 80.9%, refund 69.1%, payment 62.5%, fraud 36.6%, recon 17.1%. Gateways 18-24%. Service **53.6%** (was 0%) |
| 16 | **warehouse** | **68.2% avg** | **~60%** | 60% | ✅ Service Done | 28/2/0 (30 total) | warehouse 82.0%, txn 72.0%, inventory 70.5%, reservation 61.8%, throughput 64.9%. Service **68.3%** (was 0%) |
| 17 | **customer** | **71.6% avg** | **~48%** | 60% | ✅ Biz Done | 32/0/0 (32 total) | wishlist 68.4%, group 82.3%, audit 68.8%, pref 68.0%, segment 64.8%, customer 68.3%, address 65.6%, analytics 73.8%. ⚠️ No service tests |
| 18 | **notification** | **75.2% avg** | **~55%** | 60% | ✅ Biz Done | 24/0/0 (27 total) | biz 100%, events 85.7%, message 89.7%, pref 82.2%, sub 75.6%, delivery 68.7%, template 63.4%, notification 65.6%. ⚠️ No service tests |
| 19 | **return** | **65.1%** | **~65%** | 60% | ✅ Done | 4/0/0 (4 total) | biz 65.1%. Build fixed. ⚠️ No service tests |
| 20 | **common-operations** | **82.9% avg** | **~80%** | 60% | ✅ Done | 8/2/0 (13 total) | biz 100%, audit 100%, settings 98.1%, message 90.5%, task 82.9%, security 90.7%, model 95.7%, constants 100%, service 8% |
| 21 | **checkout** | **~70% est** | **~75%** | 60% | ✅ Service Done | 12/4/0 (16 total) | cart tests, checkout tests, pricing engine tests. Service **73.1%** |

---

## ✅ Per-Service Detailed Breakdown

### 1. analytics — ✅ DONE (~65% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz` | **67.6%** | ✅ Done |
| `pkg/pii` | **96.2%** | ✅ Excellent |
| `service` | **61.1%** | ✅ Done |
| `service/marketplace` | **73.2%** | ✅ Done |

---

### 2. pricing — ✅ DONE (~68% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/calculation` | **74.1%** | ✅ Done |
| `biz/currency` | **72.5%** | ✅ Done |
| `biz/discount` | **93.3%** | ✅ Excellent |
| `biz/dynamic` | **77.1%** | ✅ Done |
| `biz/price` | **63.5%** | ✅ Done |
| `biz/rule` | **80.2%** | ✅ Done |
| `biz/tax` | **63.1%** | ✅ Done |
| `biz/worker` | **82.5%** | ✅ Done |

---

### 3. gateway — ✅ DONE (~82% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `bff` | **77.0%** | ✅ Done |
| `client` | **80.5%** | ✅ Done |
| `config` | **85.5%** | ✅ Done |
| `errors` | **90.4%** | ✅ Excellent |
| `handler` | **79.8%** | ✅ Done |
| `middleware` | **70.7%** | ✅ Done |
| `observability` | **89.8%** | ✅ Done |
| `observability/health` | **74.2%** | ✅ Done |
| `observability/jaeger` | **73.5%** | ✅ Done |
| `observability/prometheus` | **95.8%** | ✅ Excellent |
| `observability/redis` | **81.7%** | ✅ Done |
| `proxy` | **87.2%** | ✅ Done |
| `registry` | **100.0%** | ✅ Perfect |
| `router` | **64.1%** | ✅ Done |
| `router/url` | **100.0%** | ✅ Perfect |
| `router/utils` | **56.3%** | ⚠️ Below target |
| `server` | **96.0%** | ✅ Excellent |
| `service` | **64.8%** | ✅ Done |
| `transformer` | **98.4%** | ✅ Excellent |
| `worker` | **83.5%** | ✅ Done |

---

### 4. review — ✅ Biz Done, Production Review Complete

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/helpful` | **63.9%** | ✅ Done |
| `biz/moderation` | **72.4%** | ✅ Done (was 69.9%) |
| `biz/rating` | **51.8%** | ⚠️ Below target (refactored N+1 → SQL aggregate) |
| `biz/review` | **59.6%** | ⚠️ Near target |
| `service` | 0.0% | ✅ Build fixed (`req.Rating` type mismatch). [ ] Add gRPC handler tests |

**Production Review (2026-03-05)**: Fixed 3 P0 bugs (outbox TX bypass, external calls inside TX, IsVerified security), 4 P1 issues (rating N+1 → SQL aggregate, moderation offset pagination, tracing spans, outbox status case mismatch), 3 P2 issues (duplicate import, division-by-zero, pageSize default). All tests pass. Lint clean.

---

### 5. loyalty-rewards — ✅ Biz Done, Service/Data Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/account` | **75.7%** | ✅ Done |
| `biz/redemption` | **75.3%** | ✅ Done |
| `biz/referral` | **75.5%** | ✅ Done |
| `biz/reward` | **77.6%** | ✅ Done |
| `biz/tier` | **71.9%** | ✅ Done |
| `biz/transaction` | **77.5%** | ✅ Done |
| `data/postgres` | 38.3% | [ ] Add repo-level tests |
| `service` | 30.4% | [ ] Add gRPC handler tests |

---

### 6. auth — ✅ Fully Done

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/login` | **79.1%** | ✅ Done |
| `biz/token` | **67.5%** | ✅ Done |
| `biz/audit` | **91.7%** | ✅ Done |
| `biz/session` | **65.3%** | ✅ Done |
| `biz` | **71.0%** | ✅ Done |
| `service` | **89.6%** | ✅ Done (was 0%) |
| `model` | **100.0%** | ✅ Perfect |
| `middleware` | **79.2%** | ✅ Done |
| `observability`| **94.4%** | ✅ Excellent |
| `data` | **3.5%** | ⚠️ Started |
| `data/postgres` | **3.1%** | ⚠️ Started |

**Gap Coverage (2026-03-04)**: Added `auth_test.go` with 35 test cases covering all 18 service-layer RPC handlers: Login (admin/customer/invalid-credentials/unsupported-type/validator-error), GenerateToken (success/with-claims/validation-error), ValidateToken (valid/invalid/empty), RefreshToken (success/invalid/wrong-type), RevokeToken (success/invalid), GetCurrentUser (success/missing-token/invalid-token + roles/email extraction), Logout (single-session/all-sessions/missing-token/invalid-token), CreateSession, GetSession (found/not-found), GetUserSessions (multiple/empty), RevokeSession, RevokeUserSessions (multi-session + count), HealthCheck (status/version/details), GetServiceMetrics, GetCircuitBreakerStatus, ResetCircuitBreaker, sessionToProto (all fields), and Login→Validate→Logout integration flow. Also added tests for middleware (`error_encoder_test.go`, `rate_limit_test.go`), `model` (TableName/Hooks), `observability` metrics initialization, and `data/postgres` connections.

---

### 7. location — ✅ DONE (~64% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/location` | **62.2%** | ✅ Done |
| `data/postgres` | **65.1%** | ✅ Done |
| `service` | **65.3%** | ✅ Done (build fixed — added DeleteLocation mock) |

---

### 8. catalog — ⚡ Biz Mostly Done, Product Close

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/brand` | **63.0%** | ✅ Done |
| `biz/category` | **64.8%** | ✅ Done |
| `biz/cms` | **83.0%** | ✅ Done |
| `biz/manufacturer` | **70.9%** | ✅ Done |
| `biz/product` | **62.9%** | ✅ Done (was 57.5%) |
| `biz/product_attribute` | **62.5%** | ✅ Done |
| `biz/product_visibility_rule` | **76.4%** | ✅ Done |
| `model` | **79.2%** | ✅ Done |
| `data/eventbus` | 0.0% | [ ] Add event publishing tests |
| `service` | 0.0% | [ ] Add gRPC handler tests |

---

### 9. search — ✅ Improved

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/cms` | **100.0%** | ✅ Perfect |
| `biz/ml` | **100.0%** | ✅ Perfect |
| `biz` | **80.1%** | ✅ Done (was 81.3%) |
| `service/common` | **71.7%** | ✅ Done (was 0%) |
| `service/validators` | **70.0%** | ✅ Done (was 0%) |
| `service` (main) | **30.5%** | ✅ Improved (was 29.0%) |

**Work Done**: Added popularity_booster_internal_test.go (getBoostFactor 8 tiers, BoostResults nil/empty/success/error/zero-score/no-percentile). Added helpers_test.go for common (all 7 helper functions + retry with backoff + IsRetryableError + WriteSuccessResponse/WriteErrorResponse + UnmarshalEventData + MarkEventProcessed). Added validators_test.go (ProductValidator/PriceValidator/StockValidator/CMSValidator created/updated/deleted events, ValidatorRegistry, isValidSlug, isValidURL). Added coverage_extended_test.go for service main: ProcessEventRequest (valid/invalid JSON/already processed/idempotency error), UnmarshalEventData, RecordEventMetrics, MarkEventProcessed (nil/empty ID/success/error), WriteSuccessResponse, WriteErrorResponse (retryable/non-retryable), HealthHandler, LivenessHandler, ReadinessHandler, AlertManager (SendAlert/dedup/CleanupHistory/shouldSendAlert), alert conditions (DLQ/Validation/CircuitBreaker), GetDefaultAlertRules, CreateAlertRuleManager, LoggingAlertHandler (Name/HandleAlert/getLogLevel), SlackAlertHandler (getSlackColor/buildSlackPayload), PagerDutyAlertHandler (mapAlertLevelToSeverity/buildPayload), EmailAlertHandler (buildEmailBody), CompositeAlertHandler, IdempotencyCleanupService, determineFacetType, mapFacetsToProto, mapHitsToProtoResults, mapHitsToProtoResultsWithHighlights, ReviewConsumerService, mapCMSContentFromSource, CategoryConsumerService, SetReadinessDependencies, generateQueryID.

**Gap Coverage (2026-03-04)**: Refactored SearchUsecase, SyncUsecase, RecommendationsUsecase, AnalyticsUsecase, CMS SearchUsecase to interfaces with mockgen tags. Fixed pointer-to-interface bug in TrendingWorkerService. Fixed autocomplete default limit logic (Limit=0 → 10). Added `service_gap_coverage_test.go` (+1.5% service: SearchProducts, SearchContent, ReindexAll with background goroutine wait, Autocomplete, AdvancedProductSearch, GetRecommendations). Removed duplicate CMSSearchUsecase from root biz package. Updated `search_optimization_test.go` to cast interface to concrete type for private method access.

---

### 10. user — ✅ Biz Done, Data Remaining

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/user` | **84.7%** | ✅ Done (was 73.0%) |
| `data/postgres` | **65.6%** | ✅ Done |
| `service` | 0.0% | [ ] Add gRPC handler tests |

**Work Done**: Added `user_gap_coverage_test.go` covering all low-coverage methods: BulkUpdateUserStatus fallback path (25%→100%), CreateUsersBatch fallback+validation (65%→100%), GetUser repo fallback (50%→50%), CreateUser email duplicate/save error/role UUID/outbox error (76.4%→94.5%), UpdateUser find error/tx error/outbox error/status revocation (77.5%→95.8%), DeleteUser tx error/outbox error/revocation paths (68.8%→84.4%), AssignRole authorized+repo error+version error (88.9%→100%), RemoveRole version error (88.9%→100%), GrantServiceAccess version error (85.7%→100%), RevokeServiceAccess version error (87.5%→100%), GetUserPermissions perms error (90%→100%), ProcessUserUpdated/Deleted error paths (83.3%→100%), CheckDatabaseHealth (85.7%→100%), CreateRole, ListRoles, GetUserRoles, ValidateAccess delegate tests.

---

### 11. shipping — ✅ Biz+Carriers+Service Done

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/shipment` | **71.4%** | ✅ Done (was 63.7%) |
| `carrier/dhl` | **92.3%** | ✅ Excellent |
| `carrier/fedex` | **90.1%** | ✅ Excellent |
| `carrier/ups` | **83.7%** | ✅ Done |
| `data/postgres` | **62.2%** | ✅ Done |
| `service` | **91.4%** | ✅ Excellent (was 70.6%) |

**Work Done**: 
1. **Biz Layer**: Added `shipment_rules_test.go` (Gomock-based table-driven tests). Covered P2-5 transitions: Shipped→Cancelled, Failed→Draft, Failed→Processing. Verified SH-BUG-01 (disallow 'TEMP' tracking numbers) and SH-BUG-03 (transactional status updates).
2. **Service Layer**: Added `service_gap_coverage_test.go` to address the 7.3% coverage gap. Covered gRPC endpoints: `GetShipment`, `ListShipments`, `UpdateShipmentStatus`, `CancelShipment`, and `TrackShipment`. Improved service coverage to 70.6%.

**Gap Coverage (2026-03-04)**: Added `helper_gap_test.go` (+12.3% service: all convertStructToInterfaceMap branches, convertReturnStatusToProto/FromProto all 8 statuses, convertStatusFromProto all 9 statuses, convertShippingMethodToProto full/minimal/nil, convertFilterFromProto nil/full/defaults, convertShipmentToProto optional fields, convertProtoToShipment addresses, convertReturnToProto full, convertCarrierToProto optional fields, convertAddressToMap, timestamppbFromTimePtr, int32Ptr/intPtr, validateAddress, convertTrackingEventToProto, validateCreateShipmentRequest 5 paths, convertShippingRateToProto). Added `service_error_test.go` (+8.5%: error paths for CreateShipment, GetShipment, DeleteCarrier, GetCarrier, TrackByNumber, ConfirmDelivery, CreateReturn, GetReturn, UpdateReturnStatus, GetShippingMethod, DeleteShippingMethod, ProcessWebhook 3 error paths, ListShipments, CalculateRates, ListCarriers, GetCarriers, ListShippingMethods, CreateShippingMethod, UpdateShippingMethod, GenerateLabel).

---

### 12. fulfillment — ✅ Biz Improved, Service 58.1%

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/fulfillment` | **76.5%** | ✅ Done (was 70.0%) |
| `biz/package_biz` | **74.2%** | ✅ Done (was 72.9%) |
| `biz/picklist` | **80.2%** | ✅ Done (was 77.1%) |
| `biz/qc` | **88.2%** | ✅ Excellent |
| `service` | **58.1%** | ✅ Done (was 0%). 120 tests, 10 test files |

**Service Layer Work Done**: Added 10 test files with 120 tests covering: `health_test.go` (health/readiness/liveness handlers), `validation_test.go` (all 6 validators with edge cases), `error_mapping_test.go` (nil, GORM not-found, 7 constants errors, 11 message patterns, case-insensitive match, contains/toLower helpers), `fulfillment_service_test.go` (convertFulfillmentToProto nil/minimal/full, convertFulfillmentItemToProto nil/withVariant, convertOrderItemsFromProto empty/single/multi/variant, convertQCResultToProto nil/noChecks/withChecks, constructor), `converter_test.go` (convertPicklistToProto nil/minimal/all-fields, convertPicklistItemToProto, convertPackageToProto nil/minimal/all-fields/metadata-types, isCircuitBreakerError), `fulfillment_handler_test.go` (all handler validation error paths: GetFulfillment/GetFulfillmentByOrderID/CreateFulfillment 9 cases/StartPlanning/CancelFulfillment/UpdateFulfillmentStatus 3 cases/GeneratePicklist/ConfirmPicked 5 cases/ConfirmPacked 4 cases/MarkReadyToShip/PerformQC 4 cases/MarkPickFailed/MarkPackFailed/RetryPick/RetryPack/GetQCResult), `fulfillment_handler_extended_test.go` (GetFulfillment success/not-found/error via mock repo, GetFulfillmentByOrderID success/not-found/error, ListFulfillments success/cursor/empty/error, GetQCResult, UpdateFulfillmentStatus not-found/invalid-transition), `fulfillment_gap_coverage_test.go` (ListFulfillments all-filters/no-filters/multi-results, GetFulfillment with items, GetFulfillmentByOrderID with COD, UpdateFulfillmentStatus invalid-status/repo-error/not-found/invalid-transition), `picklist_package_test.go` (PicklistService: constructor, List nil-repo/success/error/nil-cursor/with-cursor, Get nil-repo/not-found/success/error, all 10 write handler nil-usecase guards; PackageService: constructor, List nil-repo/success/error/with-cursor, Get nil-repo/not-found/success, all 7 write handler nil-usecase guards), `product_service_test.go` (constructor, nil-client graceful degradation).

**Biz Layer Work Done**: Added `fulfillment_gap_coverage_test.go`: UpdateStatus timestamp branches (Planning/Picked/Completed/Cancelled/NotFound/Nil), HandlePicklistStatusChanged (non-completed/not-picking/FindByID error/nil), ConfirmPacked with packageUsecase (weight verify+packing slip), CancelFulfillment (release reservation pending/error/no reservation), MarkCompensationPending (success/not-shipped/repo error), MarkPickFailed (max retries critical/wrong status/nil), MarkPackFailed (max retries critical/wrong status/nil), RetryPick (max retries/wrong status/nil/success), RetryPack (max retries/wrong status/nil/success), MarkReadyToShip (QC required not passed/wrong status), handleOrderCancelled (shipped→compensation/terminal skip/no fulfillments/FindAll error), HandleOrderStatusChanged (shipped no-op/default no-op), handleOrderConfirmed (existing pending), GeneratePicklist (no usecase), ConfirmPicked (no picklist ID/wrong status), ShipFulfillment (wrong status/no client/nil), computeProRataCOD (nil/zero/single/empty/zero-total), GetQCUsecase, extractReservationID. Added `package_gap_coverage_test.go`: PackError.Error all branches, getBoxWeight all 6 package types, truncateString edge cases. Added `picklist_gap_coverage_test.go`: PickError/PackError.Error all branches, groupItemsByZone (with zone/empty/nil), FulfillmentRepoAdapter constructor.

---

### 13. order — ✅ Biz+Service Done

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/cancellation` | **78.6%** | ✅ Done |
| `biz/order` | **60.2%** | ✅ Done |
| `biz/status` | **85.3%** | ✅ Excellent |
| `biz/validation` | **94.7%** | ✅ Excellent |
| `data/eventbus` | **52.0%** | ⚡ Improved (was 44.3%) |
| `security` | **69.0%** | ✅ Done (was 31.0%) |
| `service` | **65.5%** | ✅ Done (was 53.9%) |

**Gap Coverage (2026-03-04)**: Added `order_gap_coverage_test.go` (+11.6% service: convertToProtoOrder full with optional fields/ExpiresAt/CancelledAt/CompletedAt/addresses/items/CustomerAddressIDs/metadata, convertToCommonAddress nil+full, convertFromCommonAddress nil+full, convertToProtoOrderPayment with ProcessedAt/FailedAt/GatewayResponse, convertInterfaceMapToStringMap nil+mixed, convertToProtoOrderStatusHistory all fields, AnonymizeCustomerOrders repo error, ListOrders date validation/legacy pagination/error/admin header, RefundOrderItems item-not-found/quantity-exceeds/missing-payment-id/success/partial-refunds, AddPayment usecase error, GetOrder repo error, GetOrderByNumber repo error, GetOrderStatusHistory invalid+error, GetUserOrders error, ProcessOrder error, CancelOrder with CancelledBy, validateUUID edge cases, ValidationError+PermissionError, isAllowedBusinessOperation all 10 statuses, NewOrderEditService, UpdateOrder invalid-uuid/missing-customer/admin, GetOrderEditHistory invalid+cursor, convertToProtoOrderEditHistory nil+full with OldValue/NewValue, stringPtr/int32Ptr, convertMetadataToStringMap nil+mixed, convertModelOrderToProto nil+addresses+timestamps, convertModelOrderToBiz nil+full, convertBizAddressToCommon nil+full, convertFromCommonAddress order_edit nil+full, UpdateOrderStatus ChangedBy, ListOrders valid date range).

---

### 14. promotion — ✅ Biz Done, Service Improved

| Package | Coverage | Status |
|---------|----------|--------|
| `biz` | **77.3%** | ✅ Done (was 74.3%) |
| `service` | **21.3%** | ⚡ Improved (was 3.3%) |

---

### 15. payment — ✅ Service Improved, Key Packages Above Target

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/payment` | **62.5%** | ✅ Done (was 52.0%) |
| `biz/payment_method` | **90.2%** | ✅ Excellent |
| `biz/transaction` | **80.6%** | ✅ Done |
| `biz/settings` | **80.9%** | ✅ Done |
| `biz/refund` | **69.1%** | ✅ Done |
| `biz/fraud` | **36.6%** | ⚡ Improved (was 29.2%) |
| `biz/reconciliation` | **17.1%** | ⚡ Improved (was 12.9%) |
| `biz/webhook` | **17.2%** | ⚠️ Retry handler tested |
| `gateway/momo` | 20.3% | [ ] Add gateway integration tests |
| `gateway/paypal` | 24.5% | [ ] Add gateway integration tests |
| `gateway/stripe` | 19.4% | [ ] Add gateway integration tests |
| `gateway/vnpay` | 18.6% | [ ] Add gateway integration tests |
| `data` | **21.0%** | ⚡ Improved |
| `service` | **53.6%** | ⚡ Improved (was 0%) |

**Service Layer Work Done (2026-03-04)**: Added 5 test files with testify mock-based tests covering all 17 gRPC handlers. `service_gap_coverage_test.go` (mock repos + HealthCheck, GetPayment success/auth, ListPayments with filters/pagination/auth, UpdatePaymentStatus success/validation/error). `service_gap_coverage_part2_test.go` (GetRefund success, GetPaymentTransactions success, GetCustomerTransactions success, ProcessRefund validation/auth). `service_gap_coverage_part3_test.go` (GetCustomerPaymentMethods success, DeletePaymentMethod validation/auth, AddPaymentMethod validation/auth, UpdatePaymentMethod validation, ProcessPayment validation/auth, CapturePayment validation, VoidPayment validation, ProcessWebhook validation). `service_gap_coverage_part4_test.go` (ProcessPayment success flow, AddPaymentMethod success, UpdatePaymentMethod success, ProcessWebhook success, CapturePayment success, VoidPayment success). `settings_test.go` (GetPublicPaymentSettings, GetPaymentSettings, UpdatePaymentSettings, convertOptionalBool, convertOptionalString — all 100%).

**Coverage Details (per-function)**: GetPayment 73.1%, ListPayments 63.9%, UpdatePaymentStatus 64.3%, CapturePayment 21.4%, VoidPayment 45.8%, ProcessRefund 27.3%, GetRefund 76.9%, AddPaymentMethod 64.3%, GetCustomerPaymentMethods 48.1%, UpdatePaymentMethod 63.6%, DeletePaymentMethod 53.3%, GetPaymentTransactions 72.7%, GetCustomerTransactions 63.3%, ProcessWebhook 88.9%, Settings 100.0%.

**Remaining Gaps**: CapturePayment (21.4% — capture biz logic + transaction branch not covered), ProcessRefund (27.3% — refund biz flow not fully covered), VoidPayment (45.8% — void biz logic + transaction branch), GetCustomerPaymentMethods (48.1% — ActiveOnly + Type filter branches), DeletePaymentMethod (53.3% — delete success path).

---

### 16. warehouse — ✅ Biz Improved

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/warehouse` | **82.0%** | ✅ Done (was 60.8%) |
| `biz/transaction` | **72.0%** | ✅ Done |
| `biz/throughput` | **64.9%** | ✅ Done |
| `biz/reservation` | **61.8%** | ✅ Done |
| `biz/inventory` | **70.5%** | ✅ Done |
| `service` | **68.3%** | ✅ Done (was 0%) |

**Work Done**: Added coverage_extended_test.go for transaction (GetTransaction, ListTransactions, GetByWarehouse, GetByProduct, GetByReference, validators), inventory (calculateVolume, ValidateBulkTransferStockRequest, ValidateProductDimensions, ValidateTransferStockRequest, ValidateCreate/UpdateInventoryRequest, updatePhysicalUtilization, RestoreInventoryFromReturn gap coverage, HandleFulfillmentStatusChanged gap coverage), throughput (all passthrough methods, getDefaultMax* config, GetCapacityUtilization, getEffectiveCapacity), reservation (GetReservation, ListReservations, GetReservationsByOrderID, GetExpiredReservations, FindExpiredReservations, ReleaseReservationsByOrderID, GetExpiryDuration with 6 payment methods).

---

### 17. customer — ✅ Biz Improved

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/customer_group` | **82.3%** | ✅ Done (was 42.0%) |
| `biz/audit` | **68.8%** | ✅ Done (was 41.1%) |
| `biz/wishlist` | **68.4%** | ✅ Done |
| `biz/preference` | **68.0%** | ✅ Done (was 49.7%) |
| `biz/segment` | **64.8%** | ✅ Done (was 42.0%) |
| `biz/address` | **65.6%** | ✅ Done (was 61.1%) |
| `biz/customer` | **68.3%** | ✅ Done (was 63.6%) |
| `biz/analytics` | **73.8%** | ✅ Done (was 15.6%) |

**Work Done**: Added coverage_extended_test.go for customer_group (GetCustomerGroup, GetCustomerGroupByName, ListCustomerGroups, UpdateCustomerGroup with name conflict, GetDefaultCustomerGroup, GetCustomerCount), segment (IsDynamic/IsStatic, GetSegment, ListSegments, ListActiveSegments, ListCustomerSegments with pagination, GetSegmentByName, GetSegmentDistribution, ListDynamicSegments, ListSegmentCustomers, rules engine compare helpers + toFloat64), audit (IsExpired, LogCustomerLogout, LogProfileUpdate, LogAddressChange 4 actions, LogSecurityEvent, GetAuditStats), preference (SetPreference for all 9+ bool keys, unknown key, invalid bool value, custom pref, GetPreferences error).

**Gap Coverage (2026-03-04)**: Added `customer_gap_coverage_test.go` (+4.7% customer: GetCustomerWithDetails 4 scenarios, DeactivateCustomer/SuspendCustomer idempotent+error, DecrementOrderStats/AdjustSpent/OverwriteStats, writeStatusChangedOutbox nil/success/error, event handler nil test, customerConverter, GetCustomerByPhone validation/error, UpdateCustomer status/metadata/preferences/profile-not-found, UpdateStatistics, UpdateLastLogin, VerifyEmail/VerifyPhone paths, HasPassword, IncrementOrderStats). Added `address_gap_coverage_test.go` (+4.5% address: GetAddress repo error, DeleteAddress 5 scenarios including default-set-fails, address events nil/published/error, CreateAddress limit-reached/duplicate, SetDefaultAddress/GetDefaultAddress error).

---

### 18. notification — ✅ Biz Done, Providers/Service below target

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/message` | **89.7%** | ✅ Done |
| `biz/template` | **63.4%** | ✅ Done |
| `biz/subscription` | **75.6%** | ✅ Done |
| `biz/preference` | **82.2%** | ✅ Done |
| `biz/delivery` | **68.7%** | ✅ Done |
| `biz/notification` | **65.6%** | ✅ Done (was 36.6%) |
| `provider/telegram` | **10.1%** | [ ] Add send/error handling tests |

---

### 19. return — ✅ DONE (~65% overall)

| Package | Coverage | Status |
|---------|----------|--------|
| `biz/return` | **65.1%** | ✅ Done (build fixed — added CancelStaleReturns mock) |

---

## 🏗️ Recommended Execution Order

### Sprint 1 — Close the Gap (biz packages near 60%)
1. ~~**fulfillment** biz 57.5%, pkg 53.7%, picklist 52.8% → push all to 60%~~ ✅ Done (70.0%, 72.9%, 77.1%)
2. ~~**catalog** product 57.5% → push to 60%~~ ✅ Done (62.9%)
3. ~~**warehouse** txn 57.9%, inventory 55.7% → push to 60%~~ ✅ Done (txn 72.0%, inv 70.5%, throughput 64.9%, reservation 61.8%)
4. ~~**payment** payment 52.0% → push to 60%~~ ✅ Done (62.5%)

### Sprint 2 — Fix Build Failures
5. ~~**return** — fix MockReturnRequestRepo then test~~ ✅ Done
6. ~~**review** — fix service build (Rating type mismatch)~~ ✅ Done
7. ~~**location** — fix service build~~ ✅ Done

### Sprint 3 — Customer + Notification Deep Coverage
8. ~~**customer** — address 52.4%, customer 51.9%, rest <50% → push all biz >60%~~ ✅ Done (all 8/8 biz > 60%)
9. ~~**notification** — all biz packages <53% → push to 60% (~3h)~~ ✅ Done (all 8/8 biz > 63%)

### Sprint 4 — Service Layer Coverage (biggest overall impact)
10. **service layers** across all services — most are 0-7.3%, yet contain significant code (~20h total)

**Total Remaining Effort**: ~31h (~4 days)

---

## 🔧 Testing Standards

### Mock Strategy
- **mockgen** is the standard (see `write-tests/SKILL.md`)
- Services with mockgen ready: analytics ✅, return ✅ (needs regen), order ✅, loyalty-rewards ✅, fulfillment ✅, customer ✅
- All other services: add `//go:generate mockgen` to interfaces before writing tests

### Test Patterns
- **Table-driven tests** with `t.Run()` subtests
- **gomock** `EXPECT()` + `Return()` for interface mocking
- **testify** `assert` for assertions

### 21. checkout — ✅ Biz Done, Service Remaining

| Package | Coverage | Status | Test Files |
|---------|----------|--------|------------|
| `biz/cart` | **~70% est** | ✅ Done | 4 files |
| `biz/checkout` | **~70% est** | ✅ Done | 6 files |
| `service` | **73.1%** | ✅ Done | 4 files |

**Test Files:**
- `cart_test.go`, `cart_p0_test.go`, `promo_features_test.go`, `totals_internal_test.go`
- `checkout_test.go`, `confirm_test.go`, `confirm_p0_test.go`, `confirm_p2_test.go`, `pricing_p2_test.go`, `start_p2_test.go`, `pricing_engine_test.go`
- `error_handling_test.go`, `converters_test.go`, `cart_gap_coverage_test.go`, `checkout_gap_coverage_test.go`

**Work Done**: Comprehensive cart and checkout business logic tests. Pricing engine tests. Confirmation flow tests. Added 4 test files for the `service` layer covering all gRPC handlers, error handling, gap logic, and converters. Service layer coverage is now **73.1%**.

---

**Coverage Results:**

| Package | Coverage | Status |
|---------|----------|--------|
| `internal/biz` (root) | 100.0% | ✅ |
| `internal/biz/audit` | 100.0% | ✅ |
| `internal/biz/settings` | 98.1% | ✅ |
| `internal/model` | 95.7% | ✅ |
| `internal/security` | 90.7% | ✅ |
| `internal/biz/message` | 90.5% | ✅ |
| `internal/biz/task` | 82.9% | ✅ |
| `internal/constants` | 100.0% | ✅ |
| `internal/service` | **78.4%** | ✅ |

**Work Done:**
- Created `biz/task/errors_test.go`: TaskError constructors, Error/Unwrap/WithCause, sentinel checks (IsNotFound, IsAlreadyExists, etc.)
- Created `biz/task/transaction_test.go`: PostgresTransactionManager success/error paths
- Created `biz/task/task_extended_test.go`: validation failures (empty/invalid types, bad filename), CancelTask, RetryTask (max exceeded), UpdateTask transitions, worker methods, nil/error publisher
- Created `biz/settings/settings_test.go`: ValidateSettingValue (all schema types), GetSettingByKey, UpdateSettingByKey, UpdateSettingByKeyWithVersion (version conflict), audit/publish non-fatal errors
- Created `biz/message/message_test.go`: GetMessage (exact/fallback/vars), GetMessages (batch), UpsertMessage, DeleteMessage, replaceVariables, getLanguageList
- Created `biz/audit/admin_audit_test.go`: RecordAction (success/nil states/repo error), ListByActor, ListByEntity
- Created `biz/biz_test.go`: EventPublisherAdapter, NoOpNotificationSender
- Created `service/service_test.go`: Health/Readiness/Liveness handlers, constructor tests
- Created `service/operations_gap_coverage_test.go`: 12 test cases covering CreateTask (basic/scheduled/errors), GetTask, ListTasks (filters/pagination), CancelTask, RetryTask, UpdateTaskProgress (progress/success/failed), GetDownloadUrl (success/storage-error), GetTaskLogs, GetTaskEvents, DeleteTask, and toProtoTask helper. Achieved **78.4%** coverage in service layer.
- Created `security/filename_test.go`: SanitizeFilename (valid/empty/traversal/reserved/control chars), IsValidFilename, SanitizeExtension, GenerateSafeFilename
- Created `model/model_test.go`: Task validation (all fields/edge cases), Message GetTranslation/SetTranslation, TableName methods
- Created `constants/constants_test.go`: TaskTopic, TerminalStatusSet, CleanupStatuses, constant values
- Tests file naming: `<file>_test.go` in same package

### CI Gate
- `COVERAGE_THRESHOLD=60` enforced in `lint-test.yaml`
- Per-service override via CI variable if needed during migration:
  ```yaml
  variables:
    COVERAGE_THRESHOLD: "40"  # temporary until tests added
  ```


---

## 📈 Test Coverage Trends

### Recent Progress (Last 7 Days)
- **441 test files** modified or created in the last week
- **Service layer coverage** improving: 12/21 services now have service tests
- **Biz layer** consistently strong: 18/21 services above 60%

### Coverage by Layer

| Layer | Services Above 60% | Average Coverage | Status |
|-------|-------------------|------------------|--------|
| **Biz Layer** | 18/21 (86%) | ~72% | ✅ Excellent |
| **Service Layer** | 12/21 (57%) | ~47% | ⚠️ Needs Work |
| **Data Layer** | 8/21 (38%) | ~55% | ⚠️ Needs Work |

### Services Needing Service Layer Tests (8 services)

Priority order based on service complexity and usage:

1. **pricing** (13 biz tests, 0 service) - High priority, complex pricing logic
2. **customer** (32 biz tests, 0 service) - High priority, customer data sensitive
4. **user** (7 biz tests, 0 service) - Medium priority, auth/authz
5. **notification** (24 biz tests, 0 service) - Medium priority, delivery critical
6. **review** (5 biz tests, 0 service) - Low priority, smaller service
7. **return** (4 biz tests, 0 service) - Low priority, smaller service
8. **payment** (28 biz tests, 5 service at 53.6%) - Close to target, push to 60%

**Estimated Effort:** 2-3 days per service (16-24 days total)

---

## 🎯 Sprint Recommendations

### Sprint 1: High-Priority Service Tests (5 days)
1. **pricing** service layer (1 day) - 8 biz packages, complex calculations
2. **warehouse** service layer (1.5 days) - Inventory, reservations, transactions
3. **customer** service layer (1.5 days) - Customer data, segments, preferences
4. **checkout** service layer (1 day) - Cart, checkout, payment flow

### Sprint 2: Medium-Priority Service Tests (4 days)
5. **fulfillment** service layer (1 day) - Picklist, packing, QC
6. **user** service layer (1 day) - User management, permissions
7. **notification** service layer (1 day) - Message delivery, templates
8. **promotion** service layer (1 day) - Improve from 21.3%

### Sprint 3: Data Layer Coverage (3 days)
9. **loyalty-rewards** data layer (0.5 day) - Currently 38.3%
10. **catalog** data layer (1 day) - Product, category, brand repos
11. **payment** data layer (0.5 day) - Transaction, refund repos
12. **order** data layer (1 day) - Order, item, status repos

---

## 🏆 Success Metrics

### Current Status (March 4, 2026)
- ✅ **13/21 services** above 60% overall coverage (62%)
- ✅ **18/21 services** above 60% biz coverage (86%)
- ⚠️ **12/21 services** have service layer tests (57%)
- ⚠️ **8/21 services** have data layer tests (38%)

### Target (End of Q1 2026)
- 🎯 **18/21 services** above 60% overall coverage (86%)
- 🎯 **21/21 services** above 60% biz coverage (100%)
- 🎯 **18/21 services** have service layer tests (86%)
- 🎯 **15/21 services** have data layer tests (71%)

### Key Achievements
1. ✅ **Biz layer excellence**: 18/21 services above target
2. ✅ **Test infrastructure**: 464 test files, mockgen adoption
3. ✅ **Recent momentum**: 441 test files modified in last 7 days
4. ✅ **Quality focus**: Average biz coverage 72% (target 60%)

---

## 📝 Testing Best Practices

### Established Patterns
1. ✅ **mockgen** for interface mocking (order, return, analytics, loyalty-rewards, fulfillment, customer)
2. ✅ **Table-driven tests** with `t.Run()` subtests
3. ✅ **gomock** `EXPECT()` + `Return()` for dependencies
4. ✅ **testify** `assert` for assertions
5. ✅ **Coverage-driven development**: Write tests to close gaps

### File Naming Conventions
- `<package>_test.go` - Main test file
- `<package>_coverage_test.go` - Gap coverage tests
- `<package>_extended_test.go` - Extended scenarios
- `<package>_integration_test.go` - Integration tests
- `mock_<interface>_test.go` - Manual mocks (legacy)

### Test Organization
```
internal/
├── biz/
│   ├── <package>/
│   │   ├── <package>.go
│   │   ├── <package>_test.go          # Main tests
│   │   ├── <package>_coverage_test.go # Gap coverage
│   │   └── mocks/                      # Generated mocks
│   │       └── mock_*.go
├── service/
│   ├── service.go
│   ├── service_test.go                 # gRPC handler tests
│   └── service_error_test.go           # Error path tests
└── data/
    ├── postgres/
    │   ├── <repo>.go
    │   └── <repo>_test.go              # Repository tests
```

---

## 🔗 Related Documentation

- [Refactor Checklist](../refactor/REFACTOR_CHECKLIST.md) - Track 7: Mockgen migration
- [TA Review Report](../refactor/TA_REVIEW_REPORT_2026-03-02.md) - Architecture assessment
- [Action Plan](../refactor/ACTION_PLAN_SPRINT_NEXT.md) - Next sprint tasks
- [Write Tests Skill](../../../.agent/skills/write-tests/SKILL.md) - Testing guidelines

---

**Last Updated:** March 5, 2026 08:30 UTC+7  
**Next Review:** March 11, 2026 (Weekly)  
**Maintained by:** QA Team + Backend Team
