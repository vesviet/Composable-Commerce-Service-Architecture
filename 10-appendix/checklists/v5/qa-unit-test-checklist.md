# 🧪 QA Unit Test Checklist — Per-Service Business Logic
> **Version**: v5.3 | **Date**: 2026-02-15
> **Scope**: 19 Go services — `internal/biz/` layer tests
> **Framework**: testify (`assert` + `require`), table-driven tests, gomock/testify mocks
> **Run**: `go test -v -cover ./internal/biz/...`

---

## 🔴 P0 — Critical Money & Data Services

### 1. Auth Service (`auth/`)

#### 1.1 Authentication
- [ ] `TestLogin_ValidCredentials` — returns JWT access + refresh tokens
- [ ] `TestLogin_InvalidPassword` — returns 401 error
- [ ] `TestLogin_UserNotFound` — returns 401 (no info leak)
- [ ] `TestLogin_LockedAccount` — rejects after max failed attempts
- [ ] `TestLogin_MFA_RequiredWhenEnabled` — returns MFA challenge
- [ ] `TestLogin_MFA_ValidOTP` — completes login after valid TOTP
- [ ] `TestLogin_MFA_InvalidOTP` — rejects with proper error

#### 1.2 Token Management
- [ ] `TestRefreshToken_Valid` — issues new access token
- [ ] `TestRefreshToken_Expired` — returns 401
- [ ] `TestRefreshToken_Revoked` — returns 401
- [ ] `TestLogout_RevokesRefreshToken` — token no longer usable

#### 1.3 OAuth2
- [ ] `TestOAuth2_Google_NewUser` — creates customer + returns JWT
- [ ] `TestOAuth2_Google_ExistingUser` — links accounts + returns JWT
- [ ] `TestOAuth2_InvalidCallback` — rejects invalid state/code

---

### 2. Checkout Service (`checkout/`)

#### 2.1 Cart Management
- [ ] `TestAddToCart_NewItem` — creates cart entry with correct qty
- [ ] `TestAddToCart_ExistingItem` — increments quantity
- [ ] `TestAddToCart_ExceedsStock` — returns stock error
- [ ] `TestAddToCart_InvalidProduct` — returns not-found error
- [ ] `TestRemoveFromCart_LastItem` — removes entry, cart still exists
- [ ] `TestUpdateCartQty_Zero` — removes item from cart
- [ ] `TestGetCart_WithPromotions` — applies active promotions to cart total

#### 2.2 Checkout Orchestration (🔴 SAGA-001)
- [ ] `TestConfirmCheckout_HappyPath` — creates order + authorizes payment + reserves stock
- [ ] `TestConfirmCheckout_PaymentFails` — releases stock reservations + voids auth
- [ ] `TestConfirmCheckout_OrderCreationFails` — voids payment auth + creates DLQ entry
- [ ] `TestConfirmCheckout_VoidAuthFails` — creates DLQ entry (not just log CRITICAL)
- [ ] `TestConfirmCheckout_ConcurrentDuplicate` — SETNX rejects second request (EC-001)
- [ ] `TestConfirmCheckout_PriceChanged` — revalidateCartPrices detects drift + rejects (EC-003)
- [ ] `TestConfirmCheckout_EmptyCart` — returns validation error
- [ ] `TestConfirmCheckout_IdempotencyKey` — same key returns same order (Redis 24h TTL)

---

### 3. Order Service (`order/`)

#### 3.1 Order Lifecycle
- [ ] `TestCreateOrder_HappyPath` — order created with `pending` status
- [ ] `TestCreateOrder_InvalidItems` — returns validation error
- [ ] `TestConfirmOrder_TransitionsToConfirmed` — publishes `order.confirmed` event
- [ ] `TestCancelOrder_BeforeFulfillment` — releases warehouse reservations (gRPC)
- [ ] `TestCancelOrder_AfterDelivery` — rejects with "cannot cancel completed order"
- [ ] `TestCancelOrder_PublishesEvent` — `order.cancelled` event sent to Loyalty, Promotion, Fulfillment
- [ ] `TestCancelOrder_InitiatesRefund` — calls `CancellationUsecase.InitiateRefund()`

#### 3.2 Payment Saga
- [ ] `TestCaptureRetryJob_Success` — captures payment on retry
- [ ] `TestCaptureRetryJob_AuthExpired` — skips capture, voids auth (EC-002)
- [ ] `TestCaptureRetryJob_MaxRetries` — moves to DLQ
- [ ] `TestCompensationJob_VoidSuccess` — voids auth + cancels order
- [ ] `TestCompensationJob_VoidFails` — triggers alert + moves to FailedCompensation

#### 3.3 Status Management
- [ ] `TestStatusTransition_ValidPath` — pending → confirmed → paid → fulfilled → shipped → delivered
- [ ] `TestStatusTransition_InvalidPath` — pending → delivered rejected
- [ ] `TestStatusHistory_Created` — creates status history entry on each transition
- [ ] `TestPrometheusMetrics_OrderCreated` — increments `OrdersCreatedTotal`
- [ ] `TestPrometheusMetrics_OrderCancelled` — increments `OrdersCancelledTotal`

---

### 4. Payment Service (`payment/`)

#### 4.1 Payment Processing
- [ ] `TestAuthorizePayment_Card_Success` — creates authorization hold
- [ ] `TestAuthorizePayment_Card_Declined` — returns decline reason
- [ ] `TestAuthorizePayment_VNPay_Success` — returns redirect URL
- [ ] `TestAuthorizePayment_COD` — auto-confirmed, no gateway call
- [ ] `TestCapturePayment_Success` — publishes `payment.confirmed` event
- [ ] `TestCapturePayment_InsufficientFunds` — publishes `payment.failed` event
- [ ] `TestRefundPayment_Full` — creates full refund transaction
- [ ] `TestRefundPayment_Partial` — creates partial refund, correct amount

#### 4.2 Fraud Detection
- [ ] `TestFraudCheck_CleanTransaction` — score below threshold, approved
- [ ] `TestFraudCheck_HighRiskIP` — GeoIP detects VPN/proxy, flags for review
- [ ] `TestFraudCheck_VelocityLimit` — multiple transactions in short window, blocked
- [ ] `TestFraudCheck_MismatchedCountry` — billing vs IP country mismatch
- [ ] `TestGeoIPService_PublicIP` — returns real country from ip-api.com
- [ ] `TestGeoIPService_PrivateIP` — detects 10.x/172.16.x/192.168.x
- [ ] `TestGeoIPService_CacheHit` — second call uses cached result (24h TTL)

#### 4.3 Outbox & Idempotency
- [ ] `TestPaymentOutbox_EventCreated` — outbox entry in same DB transaction
- [ ] `TestPaymentIdempotency_DuplicateEvent` — second processing skipped
- [ ] `TestPaymentDistributedLock_ConcurrentCapture` — only one succeeds

---

### 5. Warehouse Service (`warehouse/`)

#### 5.1 Stock Management
- [ ] `TestReserveStock_Sufficient` — creates reservation, decrements available
- [ ] `TestReserveStock_Insufficient` — returns error, no partial reserve
- [ ] `TestReserveStock_TOCTOU` — concurrent requests handled correctly (DB transaction)
- [ ] `TestReleaseReservation_Success` — restores available stock
- [ ] `TestExpireReservation_TTL` — expired reservations auto-released by worker

#### 5.2 Inventory
- [ ] `TestAdjustStock_Positive` — increases available qty + creates movement record
- [ ] `TestAdjustStock_Negative` — decreases qty + creates movement record
- [ ] `TestAdjustStock_BelowZero` — rejects with error
- [ ] `TestStockMovement_AuditTrail` — every change logged with reason + user

#### 5.3 Events
- [ ] `TestStockUpdated_EventPublished` — `warehouse.stock.updated` via outbox
- [ ] `TestStockConsumer_Idempotent` — duplicate `order.confirmed` events processed once
- [ ] `TestFulfillmentStatusConsumer_Idempotent` — uses `IdempotencyHelper`
- [ ] `TestOrderStatusConsumer_Idempotent` — uses `IdempotencyHelper`

---

### 6. Return Service (`return/`)

#### 6.1 Return Request
- [ ] `TestCreateReturn_HappyPath` — creates return with real order item data (not "stub-product")
- [ ] `TestCreateReturn_OrderNotDelivered` — rejects return
- [ ] `TestCreateReturn_EligibilityExpired` — 30-day window check rejects (EC-005)
- [ ] `TestCreateReturn_NilCompletedAt` — falls back to `UpdatedAt` for eligibility

#### 6.2 Return Processing
- [ ] `TestApproveReturn_PublishesEvent` — `return.approved` via outbox
- [ ] `TestProcessRefund_CallsPaymentGRPC` — initiates refund through Payment service
- [ ] `TestRestockItems_CallsWarehouseGRPC` — restores inventory through Warehouse service
- [ ] `TestProcessExchange_CreatesNewOrder` — exchange creates replacement order
- [ ] `TestGenerateShippingLabel_CallsShippingGRPC` — generates return shipping label

#### 6.3 Outbox & Events
- [ ] `TestReturnOutbox_EventCreated` — outbox entry in same DB transaction (not `_ =`)
- [ ] `TestReturnEvent_Requested` — `return.requested` event built correctly
- [ ] `TestReturnEvent_Approved` — `return.approved` event built correctly
- [ ] `TestReturnEvent_Completed` — `return.completed` event built correctly
- [ ] `TestExchangeEvent_Approved` — `buildExchangeApprovedEvent()` returns valid event

---

## 🟡 P1 — Business Logic Correctness

### 7. Catalog Service (`catalog/`)
- [ ] `TestCreateProduct_WithEAV` — creates product with dynamic EAV attributes
- [ ] `TestUpdateProduct_PublishesEvent` — `product.updated` event via outbox
- [ ] `TestDeleteProduct_SoftDelete` — marks inactive, publishes `product.deleted`
- [ ] `TestCategoryTree_HierarchicalQuery` — returns nested category tree
- [ ] `TestProductVisibility_ActiveOnly` — hidden products excluded from queries
- [ ] `TestVariantManagement_SKUUniqueness` — rejects duplicate SKUs

### 8. Pricing Service (`pricing/`)
- [ ] `TestCalculatePrice_BasePrice` — returns correct base price
- [ ] `TestCalculatePrice_WithDiscount` — applies percentage/fixed discounts
- [ ] `TestCalculatePrice_CustomerTier` — tier-based pricing applied correctly
- [ ] `TestCalculatePrice_TaxCalculation` — tax computed per region
- [ ] `TestPriceUpdate_PublishesEvent` — `price.updated` event via outbox
- [ ] `TestBulkPricing_VolumeDiscounts` — quantity-based tier pricing

### 9. Promotion Service (`promotion/`)
- [ ] `TestApplyCoupon_Valid` — applies discount to cart total
- [ ] `TestApplyCoupon_Expired` — rejects expired coupon
- [ ] `TestApplyCoupon_UsageLimitReached` — rejects overused coupon
- [ ] `TestApplyCoupon_MinOrderValue` — rejects below minimum
- [ ] `TestCampaign_BOGO` — buy-one-get-one applied correctly
- [ ] `TestOrderCancelled_ReversesUsage` — `order.cancelled` consumer reverses promo slot

### 10. Fulfillment Service (`fulfillment/`)
- [ ] `TestCreateFulfillment_FromOrder` — creates fulfillment from `order.paid` event
- [ ] `TestBatchPicking_AssignPicker` — assigns picker to picking list
- [ ] `TestBatchPicking_ZoneOptimized` — groups items by warehouse zone
- [ ] `TestCompleteFulfillment_PublishesEvent` — `fulfillment.completed` via outbox
- [ ] `TestOrderCancelled_StopsPicking` — `order.cancelled` consumer stops in-progress picking
- [ ] `TestQualityControl_HighValueOrder` — QC required for orders > threshold

### 11. Shipping Service (`shipping/`)
- [ ] `TestCreateShipment_GHN` — creates shipment via GHN carrier
- [ ] `TestWebhookProcessing_StatusUpdate` — parses carrier webhook, updates shipment status
- [ ] `TestTrackingUpdate_PublishesEvent` — `shipping.shipped` / `shipping.delivered` events
- [ ] `TestShippingRateCalculation_WeightBased` — correct rate for package weight
- [ ] `TestAccessControl_JWTExtraction` — `UserContextMiddleware` extracts user from JWT
- [ ] `TestShipmentIdempotency_DuplicateEvent` — duplicate `fulfillment.completed` handled

### 12. Customer Service (`customer/`)
- [ ] `TestCreateCustomer_FromAuthEvent` — `auth.user.created` consumer creates profile
- [ ] `TestUpdateProfile_AddressManagement` — add/update/delete addresses
- [ ] `TestCustomerSegmentation_AutoAssign` — customers auto-assigned to segments
- [ ] `TestAuditLog_SecurityEvents` — `AuditUsecase` logs auth events
- [ ] `TestLTV_Calculation` — uses real `TotalSpent`/`TotalOrders` (not placeholders)

### 13. Loyalty Service (`loyalty-rewards/`)
- [ ] `TestEarnPoints_OrderCompleted` — `order.completed` consumer awards points
- [ ] `TestDeductPoints_OrderCancelled` — `handleOrderCancelled()` reverses exact points
- [ ] `TestDeductPoints_Idempotent` — `TransactionExists("order_cancellation", orderID)`
- [ ] `TestRedeemPoints_Success` — deducts points, creates reward
- [ ] `TestRedeemPoints_InsufficientBalance` — rejects with error
- [ ] `TestTierUpgrade_ThresholdReached` — auto-upgrades tier, notifies customer
- [ ] `TestOutbox_PointsDeducted` — `PointsDeducted` event via outbox

### 14. Notification Service (`notification/`)
- [ ] `TestSendEmail_OrderConfirmation` — renders template, sends via SMTP
- [ ] `TestSendSMS_ShippingUpdate` — sends SMS notification
- [ ] `TestSendPush_DeliveryComplete` — sends push notification
- [ ] `TestOrderStatusConsumer_TriggersNotification` — event → email/SMS
- [ ] `TestSystemErrorConsumer_TriggersAlert` — system error → PagerDuty/Slack

### 15. Search Service (`search/`)
- [ ] `TestProductIndex_Create` — indexes product to Elasticsearch via alias
- [ ] `TestProductSearch_FullText` — returns relevant results
- [ ] `TestProductSearch_Filters` — category, price range, availability filters
- [ ] `TestPriceConsumer_UpdatesIndex` — `price.updated` → ES document update
- [ ] `TestStockConsumer_UpdatesAvailability` — `stock.changed` → in_stock field update
- [ ] `TestSyncJob_FullReindex` — batch sync indexes all products
- [ ] `TestIdempotency_DuplicateProductEvent` — `EventIdempotencyRepo` prevents double-process

---

## 🟢 P2 — Standard Coverage

### 16. Gateway Service (`gateway/`)
- [ ] `TestRouting_ProxyToService` — routes request to correct backend service
- [ ] `TestRateLimiting_ExceedsThreshold` — returns 429
- [ ] `TestJWTValidation_ValidToken` — passes request with user context
- [ ] `TestJWTValidation_ExpiredToken` — returns 401
- [ ] `TestCORS_AllowedOrigins` — correct CORS headers

### 17. Review Service (`review/`)
- [ ] `TestCreateReview_HappyPath` — creates review with rating
- [ ] `TestCreateReview_PurchaseRequired` — rejects if not purchased
- [ ] `TestModeration_AutoApprove` — clean content auto-approved
- [ ] `TestModeration_FlagForReview` — suspicious content flagged
- [ ] `TestAverageRating_Calculation` — correct aggregated rating

### 18. Analytics Service (`analytics/`)
- [ ] `TestOrderMetrics_RealData` — `order_fulfillment_rate` from real events (not 0.95)
- [ ] `TestFulfillmentMetrics_RealTiming` — `avg_fulfillment_time` from event metadata
- [ ] `TestRetentionRate_RealCalculation` — returning purchasers / total purchasers
- [ ] `TestFulfillmentConsumer_ProcessesEvent` — ingests fulfillment events
- [ ] `TestShippingConsumer_ProcessesEvent` — ingests shipping events

### 19. Location Service (`location/`)
- [ ] `TestLocationTree_Country` — returns all countries
- [ ] `TestLocationTree_Province` — returns provinces by country
- [ ] `TestLocationTree_District` — returns districts by province
- [ ] `TestLocationTree_Ward` — returns wards by district
- [ ] `TestAddressValidation_FullPath` — validates complete address path

### 20. Common Operations (`common-operations/`)
- [ ] `TestFileUpload_MinIO` — uploads file to MinIO bucket
- [ ] `TestFileDownload_PresignedURL` — generates valid presigned URL
- [ ] `TestTaskOrchestration_CreateTask` — creates async task
- [ ] `TestTaskOrchestration_CompleteTask` — marks task completed

---

## 📊 Coverage Targets

| Layer | Target | Current | Gap |
|-------|--------|---------|-----|
| **P0 Services** (Auth, Checkout, Order, Payment, Warehouse, Return, Gateway) | 80%+ | TBD | Audit needed |
| **P1 Services** (Catalog, Pricing, Promotion, Fulfillment, Shipping, Customer, Loyalty, Notification, Search) | 60%+ | TBD | Audit needed |
| **P2 Services** (Analytics, Review, Location, Common Ops) | 40%+ | TBD | Audit needed |

### Run Commands

```bash
# Per-service test + coverage
go test -v -cover ./internal/biz/...

# Race condition detection
go test -race ./internal/biz/...

# Specific test
go test -v -run TestConfirmCheckout_HappyPath ./internal/biz/checkout/...
```
