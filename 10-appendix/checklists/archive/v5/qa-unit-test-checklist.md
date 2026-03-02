# 🧪 QA Unit Test Checklist — Per-Service Business Logic
> **Version**: v5.4 | **Updated**: 2026-02-19
> **Scope**: 19 Go services — `internal/biz/` layer tests
> **Framework**: testify (`assert` + `require`), table-driven tests, gomock/testify mocks
> **Run**: `go test -v -cover ./internal/biz/...`
>
> **Legend**: `[x]` = test exists in codebase · `[ ]` = not yet written

---

## 🔴 P0 — Critical Money & Data Services

### 1. Auth Service (`auth/`)

#### 1.1 Authentication
- [x] `TestLogin_ValidCredentials` — returns JWT access + refresh tokens _(auth/internal/biz/login/login_comprehensive_test.go)_
- [x] `TestLogin_InvalidPassword` — returns 401 error
- [x] `TestLogin_UserNotFound` — returns 401 (no info leak)
- [x] `TestLogin_LockedAccount` — rejects after max failed attempts
- [x] `TestLogin_MFA_RequiredWhenEnabled` — returns MFA challenge
- [x] `TestLogin_MFA_ValidOTP` — completes login after valid TOTP
- [x] `TestLogin_MFA_InvalidOTP` — rejects with proper error
- [x] `TestLogin_AdminUser` — admin login with full permissions _(auth/internal/biz/login/login_comprehensive_test.go)_
- [x] `TestLogin_CustomerUser` — customer login with profile access _(auth/internal/biz/login/login_comprehensive_test.go)_
- [x] `TestLogin_UnsupportedUserType` — rejects unsupported user types _(auth/internal/biz/login/login_comprehensive_test.go)_
- [x] `TestLogin_ValidationError` — handles missing required fields _(auth/internal/biz/login/login_comprehensive_test.go)_
- [x] `TestLogin_ConcurrentOperations` — thread-safe concurrent logins _(auth/internal/biz/login/login_comprehensive_test.go)_

#### 1.2 Token Management
- [x] `TestRefreshToken_Valid` — issues new access token _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestRefreshToken_Expired` — returns 401
- [x] `TestRefreshToken_Revoked` — returns 401
- [x] `TestLogout_RevokesRefreshToken` — token no longer usable
- [x] `TestValidateToken_Valid` — validates JWT and extracts claims _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestValidateToken_Expired` — rejects expired tokens _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestValidateToken_InvalidSignature` — rejects tampered tokens _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestValidateToken_Revoked` — checks revocation status _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestGenerateToken_Success` — creates JWT with proper claims _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestGenerateToken_WithPermissions` — includes user permissions _(auth/internal/biz/token/token_comprehensive_test.go)_
- [x] `TestRevokeToken_Success` — invalidates tokens _(auth/internal/biz/token/token_comprehensive_test.go)_

#### 1.3 OAuth2
- [ ] `TestOAuth2_Google_NewUser` — creates customer + returns JWT
- [ ] `TestOAuth2_Google_ExistingUser` — links accounts + returns JWT
- [ ] `TestOAuth2_InvalidCallback` — rejects invalid state/code

---

### 2. Checkout Service (`checkout/`)

#### 2.1 Cart Management
- [x] `TestAddToCart_ExceedsStock` — returns stock error _(checkout/internal/biz/cart/cart_p0_test.go)_
- [x] `TestAddToCart_InvalidProduct` — returns not-found error
- [x] `TestAddToCart_ExistingItem` — increments quantity (TestAddToCart_ExistingItem_MergesQuantity)
- [x] `TestRemoveFromCart_LastItem` — removes entry, cart still exists
- [x] `TestUpdateCartQty_Zero` — removes item from cart (TestUpdateCartItem_QuantityZero)
- [x] `TestGetCart_WithPromotions` — applies active promotions to cart total
- [ ] `TestAddToCart_NewItem` — creates cart entry with correct qty

#### 2.2 Checkout Orchestration (🔴 SAGA-001)
- [x] `TestConfirmCheckout_HappyPath` — creates order + authorizes payment + reserves stock _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_PaymentFails` — releases stock reservations + voids auth _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_OrderCreationFails` — voids payment auth + creates DLQ entry _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_VoidAuthFails` — creates DLQ entry (not just log CRITICAL) _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_ConcurrentDuplicate` — SETNX rejects second request (EC-001) _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_PriceChanged` — revalidateCartPrices detects drift + rejects (EC-003) _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_EmptyCart` — returns validation error _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_
- [x] `TestConfirmCheckout_IdempotencyKey` — same key returns same order (Redis 24h TTL) _(checkout/internal/biz/checkout/checkout_saga_comprehensive_test.go)_

---

### 3. Order Service (`order/`)

#### 3.1 Order Lifecycle
- [x] `TestCreateOrder_HappyPath` — order created with `pending` status _(order/internal/biz/order/create_test.go)_
- [x] `TestCreateOrder_InvalidItems` — returns validation error _(order/internal/biz/order/create_test.go)_
- [x] `TestConfirmOrder_TransitionsToConfirmed` — publishes `order.confirmed` event _(order/internal/biz/order/process_test.go)_
- [x] `TestCancelOrder_BeforeFulfillment` — releases warehouse reservations (gRPC) _(order/internal/biz/order/cancel_test.go)_
- [x] `TestCancelOrder_AfterDelivery` — rejects with "cannot cancel completed order" _(order/internal/biz/order/cancel_test.go)_
- [x] `TestCancelOrder_PublishesEvent` — `order.cancelled` event sent to Loyalty, Promotion, Fulfillment _(order/internal/biz/order/cancel_test.go)_
- [x] `TestCancelOrder_InitiatesRefund` — calls `CancellationUsecase.InitiateRefund()` _(order/internal/biz/order/cancel_test.go)_

#### 3.2 Payment Saga
- [x] `TestCaptureRetryJob_Success` — captures payment on retry _(order/internal/biz/order/payment_test.go)_
- [x] `TestCaptureRetryJob_AuthExpired` — skips capture, voids auth (EC-002) _(order/internal/biz/order/payment_test.go)_
- [x] `TestCaptureRetryJob_MaxRetries` — moves to DLQ _(order/internal/biz/order/payment_test.go)_
- [x] `TestCompensationJob_VoidSuccess` — voids auth + cancels order _(order/internal/biz/order/payment_test.go)_
- [x] `TestCompensationJob_VoidFails` — triggers alert + moves to FailedCompensation _(order/internal/biz/order/payment_test.go)_

#### 3.3 Status Management
- [x] `TestStatusTransition_ValidPath` — pending → confirmed → paid → fulfilled → shipped → delivered _(order/internal/biz/order/p0_consistency_test.go)_
- [x] `TestStatusTransition_InvalidPath` — pending → delivered rejected _(order/internal/biz/order/p0_consistency_test.go)_
- [x] `TestStatusHistory_Created` — creates status history entry on each transition _(order/internal/biz/order/p0_consistency_test.go)_
- [x] `TestPrometheusMetrics_OrderCreated` — increments `OrdersCreatedTotal` _(order/internal/biz/order/monitoring.go)_
- [x] `TestPrometheusMetrics_OrderCancelled` — increments `OrdersCancelledTotal` _(order/internal/biz/order/monitoring.go)_

---

### 4. Payment Service (`payment/`)

#### 4.1 Payment Processing
- [x] `TestAuthorizePayment_Card_Success` — creates authorization hold _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestAuthorizePayment_Card_Declined` — returns decline reason _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestAuthorizePayment_VNPay_Success` — returns redirect URL _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestAuthorizePayment_COD` — auto-confirmed, no gateway call _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestCapturePayment_Success` — publishes `payment.confirmed` event _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestCapturePayment_InsufficientFunds` — publishes `payment.failed` event _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestRefundPayment_Full` — creates full refund transaction _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_
- [x] `TestRefundPayment_Partial` — creates partial refund, correct amount _(payment/internal/biz/payment/payment_processing_comprehensive_test.go)_

#### 4.2 Fraud Detection
- [x] `TestFraudCheck_CleanTransaction` — score below threshold, approved _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestFraudCheck_HighRiskIP` — GeoIP detects VPN/proxy, flags for review _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestFraudCheck_VelocityLimit` — multiple transactions in short window, blocked _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestFraudCheck_MismatchedCountry` — billing vs IP country mismatch _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestGeoIPService_PublicIP` — returns real country from ip-api.com _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestGeoIPService_PrivateIP` — detects 10.x/172.16.x/192.168.x _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_
- [x] `TestGeoIPService_CacheHit` — second call uses cached result (24h TTL) _(payment/internal/biz/payment/fraud_detection_comprehensive_test.go)_

#### 4.3 Outbox & Idempotency
- [x] `TestPaymentOutbox_EventCreated` — outbox entry in same DB transaction _(payment/internal/biz/payment/outbox_idempotency_comprehensive_test.go)_
- [x] `TestPaymentIdempotency_DuplicateEvent` — second processing skipped _(payment/internal/biz/payment/outbox_idempotency_comprehensive_test.go)_
- [x] `TestPaymentDistributedLock_ConcurrentCapture` — only one succeeds _(payment/internal/biz/payment/outbox_idempotency_comprehensive_test.go)_

---

### 5. Warehouse Service (`warehouse/`)

#### 5.1 Stock Management
- [x] `TestReserveStock_Sufficient` — creates reservation, decrements available _(warehouse/internal/biz/reservation/reserve_stock_test.go)_
- [x] `TestReserveStock_Insufficient` — returns error, no partial reserve _(warehouse/internal/biz/reservation/reserve_stock_test.go)_
- [x] `TestReserveStock_TOCTOU` — concurrent requests handled correctly (DB transaction) _(warehouse/internal/biz/reservation/reservation_test.go)_
- [x] `TestReleaseReservation_Success` — restores available stock _(warehouse/internal/biz/reservation/reservation_release_test.go)_
- [x] `TestExpireReservation_TTL` — expired reservations auto-released by worker _(warehouse/internal/biz/reservation/reservation_lifecycle_test.go)_

#### 5.2 Inventory
- [x] `TestAdjustStock_Positive` — increases available qty + creates movement record _(warehouse/internal/biz/inventory/inventory_p0_test.go)_
- [x] `TestAdjustStock_Negative` — decreases qty + creates movement record _(warehouse/internal/biz/inventory/inventory_p0_test.go)_
- [x] `TestAdjustStock_BelowZero` — rejects with error _(warehouse/internal/biz/inventory/inventory_p0_test.go)_
- [x] `TestStockMovement_AuditTrail` — every change logged with reason + user _(warehouse/internal/biz/inventory/inventory_transactional_integrity_test.go)_

#### 5.3 Events
- [x] `TestStockUpdated_EventPublished` — `warehouse.stock.updated` via outbox _(warehouse/internal/biz/inventory/inventory_events.go)_
- [x] `TestStockConsumer_Idempotent` — duplicate `order.confirmed` events processed once _(warehouse/internal/biz/inventory/fulfillment_status_handler_test.go)_
- [x] `TestFulfillmentConsumer_Idempotent` — uses `IdempotencyHelper` _(warehouse/internal/biz/inventory/fulfillment_status_handler_test.go)_
- [x] `TestOrderStatusConsumer_Idempotent` — uses `IdempotencyHelper` _(warehouse/internal/biz/inventory/fulfillment_status_handler_test.go)_

---

### 6. Return Service (`return/`)

#### 6.1 Return Request
- [x] `TestCreateReturn_HappyPath` — creates return with real order item data (not "stub-product") _(return/internal/biz/return/return_p0_test.go)_
- [x] `TestCreateReturn_OrderNotDelivered` — rejects return _(return/internal/biz/return/return_p0_test.go)_
- [x] `TestCreateReturn_EligibilityExpired` — 30-day window check rejects (EC-005) _(return/internal/biz/return/return_p0_test.go)_
- [x] `TestCreateReturn_NilCompletedAt` — falls back to `UpdatedAt` for eligibility _(return/internal/biz/return/return_p0_test.go)_

#### 6.2 Return Processing
- [x] `TestApproveReturn_PublishesEvent` — `return.approved` via outbox _(return/internal/biz/return/return_p0_test.go)_
- [x] `TestProcessRefund_CallsPaymentGRPC` — initiates refund through Payment service _(return/internal/biz/return/refund.go)_
- [x] `TestRestockItems_CallsWarehouseGRPC` — restores inventory through Warehouse service _(return/internal/biz/return/restock.go)_
- [x] `TestProcessExchange_CreatesNewOrder` — exchange creates replacement order _(return/internal/biz/return/exchange.go)_
- [x] `TestGenerateShippingLabel_CallsShippingGRPC` — generates return shipping label _(return/internal/biz/return/shipping.go)_

#### 6.3 Outbox & Events
- [x] `TestReturnOutbox_EventCreated` — outbox entry in same DB transaction (not `_ =`) _(return/internal/biz/return/events.go)_
- [x] `TestReturnEvent_Requested` — `return.requested` event built correctly _(return/internal/biz/return/events.go)_
- [x] `TestReturnEvent_Approved` — `return.approved` event built correctly _(return/internal/biz/return/events.go)_
- [x] `TestReturnEvent_Completed` — `return.completed` event built correctly _(return/internal/biz/return/events.go)_
- [x] `TestExchangeEvent_Approved` — `buildExchangeApprovedEvent()` returns valid event _(return/internal/biz/return/exchange.go)_

---

## 🟡 P1 — Business Logic Correctness

### 7. Catalog Service (`catalog/`)
- [x] `TestCreateProduct_WithEAV` — creates product with dynamic EAV attributes _(catalog/internal/biz/product/)_
- [x] `TestUpdateProduct_PublishesEvent` — `product.updated` event via outbox
- [x] `TestDeleteProduct_SoftDelete` — marks inactive, publishes `product.deleted`
- [x] `TestCategoryTree_HierarchicalQuery` — returns nested category tree _(catalog/internal/biz/category/)_
- [x] `TestProductVisibility_ActiveOnly` — hidden products excluded
- [x] `TestVariantManagement_SKUUniqueness` — rejects duplicate SKUs

### 8. Pricing Service (`pricing/`)
- [x] `TestCalculatePrice_BasePrice` — returns correct base price _(pricing/internal/biz/price/price_test.go)_
- [x] `TestCalculatePrice_WithDiscount` — applies percentage/fixed discounts _(pricing/internal/biz/price/price_test.go)_
- [x] `TestCalculatePrice_CustomerTier` — tier-based pricing applied correctly _(pricing/internal/biz/price/price_test.go)_
- [x] `TestCalculatePrice_TaxCalculation` — tax computed per region _(pricing/internal/biz/tax/tax_test.go)_
- [x] `TestPriceUpdate_PublishesEvent` — `price.updated` event via outbox _(pricing/internal/biz/price/price_test.go)_
- [x] `TestBulkPricing_VolumeDiscounts` — quantity-based tier pricing _(pricing/internal/biz/price/price_test.go)_

### 9. Promotion Service (`promotion/`)
- [x] `TestApplyCoupon_Valid` — applies discount to cart total _(promotion/internal/biz/promotion/promotion_test.go)_
- [x] `TestApplyCoupon_Expired` — rejects expired coupon _(promotion/internal/biz/promotion/promotion_test.go)_
- [x] `TestApplyCoupon_UsageLimitReached` — rejects overused coupon _(promotion/internal/biz/promotion/promotion_test.go)_
- [x] `TestApplyCoupon_MinOrderValue` — rejects below minimum _(promotion/internal/biz/promotion/promotion_test.go)_
- [x] `TestCampaign_BOGO` — buy-one-get-one applied correctly _(promotion/internal/biz/promotion/promotion_test.go)_
- [x] `TestOrderCancelled_ReversesUsage` — `order.cancelled` consumer reverses promo slot _(promotion/internal/biz/promotion/promotion_test.go)_

### 10. Fulfillment Service (`fulfillment/`)
- [x] `TestCreateFulfillment_FromOrder` — creates fulfillment from `order.paid` event _(fulfillment/internal/biz/package_biz/package_test.go)_
- [x] `TestBatchPicking_AssignPicker` — assigns picker to picking list _(fulfillment/internal/biz/picklist/picklist_test.go)_
- [x] `TestBatchPicking_ZoneOptimized` — groups items by warehouse zone _(fulfillment/internal/biz/picklist/picklist_test.go)_
- [x] `TestCompleteFulfillment_PublishesEvent` — `fulfillment.completed` via outbox _(fulfillment/internal/biz/package_biz/package_test.go)_
- [x] `TestOrderCancelled_StopsPicking` — `order.cancelled` consumer stops in-progress picking _(fulfillment/internal/biz/package_biz/package_test.go)_
- [x] `TestQualityControl_HighValueOrder` — QC required for orders > threshold _(fulfillment/internal/biz/qc/qc_test.go)_

### 11. Shipping Service (`shipping/`)
- [x] `TestCreateShipment_GHN` — creates shipment via GHN carrier _(shipping/internal/biz/shipment/shipment_test.go)_
- [x] `TestWebhookProcessing_StatusUpdate` — parses carrier webhook, updates shipment status _(shipping/internal/biz/shipment/shipment_test.go)_
- [x] `TestTrackingUpdate_PublishesEvent` — `shipping.shipped` / `shipping.delivered` events _(shipping/internal/biz/shipment/shipment_test.go)_
- [x] `TestShippingRateCalculation_WeightBased` — correct rate for package weight _(shipping/internal/biz/shipping_method/shipping_test.go)_
- [x] `TestAccessControl_JWTExtraction` — `UserContextMiddleware` extracts user from JWT _(shipping/internal/biz/shipping_test.go)_
- [x] `TestShipmentIdempotency_DuplicateEvent` — duplicate `fulfillment.completed` handled _(shipping/internal/biz/shipment/shipment_test.go)_

### 12. Customer Service (`customer/`)
- [x] `TestCreateCustomer_FromAuthEvent` — `auth.user.created` consumer creates profile _(customer/internal/service/customer_test.go)_
- [x] `TestUpdateProfile_AddressManagement` — add/update/delete addresses _(customer/internal/service/customer_test.go)_
- [x] `TestCustomerSegmentation_AutoAssign` — customers auto-assigned to segments _(customer/internal/service/segmentation_test.go)_
- [x] `TestAuditLog_SecurityEvents` — `AuditUsecase` logs auth events _(customer/internal/service/audit_test.go)_
- [x] `TestLTV_Calculation` — uses real `TotalSpent`/`TotalOrders` (not placeholders) _(customer/internal/service/analytics_test.go)_

### 13. Loyalty Service (`loyalty-rewards/`)
- [x] `TestEarnPoints_OrderCompleted` — `order.completed` consumer awards points _(loyalty-rewards/internal/biz/points/points_test.go)_
- [x] `TestDeductPoints_OrderCancelled` — `handleOrderCancelled()` reverses exact points _(loyalty-rewards/internal/biz/points/points_test.go)_
- [x] `TestDeductPoints_Idempotent` — `TransactionExists("order_cancellation", orderID)` _(loyalty-rewards/internal/biz/points/points_test.go)_
- [x] `TestRedeemPoints_Success` — deducts points, creates reward _(loyalty-rewards/internal/biz/rewards/rewards_test.go)_
- [x] `TestRedeemPoints_InsufficientBalance` — rejects with error _(loyalty-rewards/internal/biz/rewards/rewards_test.go)_
- [x] `TestTierUpgrade_ThresholdReached` — auto-upgrades tier, notifies customer _(loyalty-rewards/internal/biz/tiers/tiers_test.go)_
- [x] `TestOutbox_PointsDeducted` — `PointsDeducted` event via outbox _(loyalty-rewards/internal/biz/points/points_test.go)_

### 14. Notification Service (`notification/`)
- [x] `TestSendEmail_OrderConfirmation` — renders template, sends via SMTP _(notification/internal/service/email_test.go)_
- [x] `TestSendSMS_ShippingUpdate` — sends SMS notification _(notification/internal/service/sms_test.go)_
- [x] `TestSendPush_DeliveryComplete` — sends push notification _(notification/internal/service/push_test.go)_
- [x] `TestOrderStatusConsumer_TriggersNotification` — event → email/SMS _(notification/internal/service/consumer_test.go)_
- [x] `TestSystemErrorConsumer_TriggersAlert` — system error → PagerDuty/Slack _(notification/internal/service/consumer_test.go)_

### 15. Search Service (`search/`)
- [x] `TestProductIndex_Create` — indexes product to Elasticsearch via alias _(search/internal/service/indexer_test.go)_
- [x] `TestProductSearch_FullText` — returns relevant results _(search/internal/service/search_test.go)_
- [x] `TestProductSearch_Filters` — category, price range, availability filters _(search/internal/service/search_test.go)_
- [x] `TestPriceConsumer_UpdatesIndex` — `price.updated` → ES document update _(search/internal/service/consumer_test.go)_
- [x] `TestStockConsumer_UpdatesAvailability` — `stock.changed` → in_stock field update _(search/internal/service/consumer_test.go)_
- [x] `TestSyncJob_FullReindex` — batch sync indexes all products _(search/internal/service/sync_test.go)_
- [x] `TestIdempotency_DuplicateProductEvent` — `EventIdempotencyRepo` prevents double-process _(search/internal/service/consumer_test.go)_

---

## 🟢 P2 — Standard Coverage

### 16. Gateway Service (`gateway/`)

#### 16.1 Routing & Proxy
- [x] `TestRouteResolution_Success` — resolves routes by method/path _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestRouteResolution_NotFound` — handles missing routes _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestServiceRegistry_HealthCheck` — checks service availability _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestServiceRegistry_UnhealthyService` — handles unhealthy backends _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestRequestForwarding_Success` — forwards requests to backends _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestRequestForwarding_Failure` — handles forwarding errors _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestProxyHandler_Success` — processes proxy requests _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestServiceListing_Success` — lists available services _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestRoutePatterns_Success` — retrieves route patterns _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestConcurrentRouteResolution` — thread-safe concurrent routing _(gateway/internal/router/router_comprehensive_test.go)_

#### 16.2 BFF & Aggregation
- [x] `TestProductTransformer_ProductList` — transforms product data _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestProductTransformer_ProductDetail` — enriches product details _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestProductTransformer_TransformationError` — handles transformation failures _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestAggregationHandler_UserDashboard` — aggregates user dashboard data _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestAggregationHandler_ProductRecommendations` — provides recommendations _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestAggregationHandler_OrderHistory` — aggregates order history _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestServiceManager_HealthCheck` — monitors service health _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestServiceManager_ClientRetrieval` — provides service clients _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestBFFEndToEndFlow` — complete BFF data aggregation _(gateway/internal/bff/bff_comprehensive_test.go)_
- [x] `TestConcurrentBFFOperations` — thread-safe BFF operations _(gateway/internal/bff/bff_comprehensive_test.go)_

#### 16.3 Monitoring & Observability
- [x] `TestGetServiceMetrics_Success` — aggregates gateway metrics _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestGetServiceMetrics_PartialData` — handles partial metric data _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestGatewayMetricsStructure` — validates metrics structure _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestServiceHealthMonitoring` — monitors backend health _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestCircuitBreakerStatus` — tracks circuit breaker states _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestErrorSummaryAggregation` — aggregates error statistics _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestPerformanceMetrics` — collects performance data _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestConcurrentMonitoringAccess` — thread-safe metrics access _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestRequestRecording` — records request metrics _(gateway/internal/service/monitoring_comprehensive_test.go)_
- [x] `TestErrorRecording` — records error metrics _(gateway/internal/service/monitoring_comprehensive_test.go)_

#### 16.4 Legacy Routing Tests
- [x] `TestRouting_ProxyToService` — routes request to correct backend service _(gateway/internal/router/router_comprehensive_test.go)_
- [x] `TestRateLimiting_ExceedsThreshold` — returns 429 _(gateway/internal/middleware/rate_limit_test.go)_
- [x] `TestJWTValidation_ValidToken` — passes request with user context _(gateway/tests/jwt_blacklist_integration_test.go)_
- [x] `TestJWTValidation_ExpiredToken` — returns 401 _(gateway/tests/security_test.go)_
- [x] `TestCORS_AllowedOrigins` — correct CORS headers _(gateway/internal/middleware/kratos_middleware_test.go)_

### 17. Review Service (`review/`)
- [x] `TestCreateReview_HappyPath` — creates review with rating _(review/internal/biz/review/review_test.go)_
- [x] `TestCreateReview_PurchaseRequired` — rejects if not purchased _(review/internal/biz/review/review_test.go)_
- [x] `TestModeration_AutoApprove` — clean content auto-approved _(review/internal/biz/moderation/moderation_test.go)_
- [x] `TestModeration_FlagForReview` — suspicious content flagged _(review/internal/biz/moderation/moderation_test.go)_
- [x] `TestAverageRating_Calculation` — correct aggregated rating _(review/internal/biz/rating/rating_test.go)_

### 18. Analytics Service (`analytics/`)
- [x] `TestOrderMetrics_RealData` — `order_fulfillment_rate` from real events _(analytics/internal/service/event_processor_test.go)_
- [x] `TestFulfillmentMetrics_RealTiming` — `avg_fulfillment_time` from event metadata
- [x] `TestRetentionRate_RealCalculation` — returning purchasers / total purchasers _(analytics/internal/service/retention_rate_test.go)_
- [x] `TestFulfillmentConsumer_ProcessesEvent` — ingests fulfillment events
- [x] `TestShippingConsumer_ProcessesEvent` — ingests shipping events

### 19. Location Service (`location/`)
- [x] `TestLocationTree_Country` — returns all countries _(location/internal/service/location_test.go)_
- [x] `TestLocationTree_Province` — returns provinces by country _(location/internal/service/location_test.go)_
- [x] `TestLocationTree_District` — returns districts by province _(location/internal/service/location_test.go)_
- [x] `TestLocationTree_Ward` — returns wards by district _(location/internal/service/location_test.go)_
- [x] `TestAddressValidation_FullPath` — validates complete address path _(location/internal/service/location_test.go)_

### 20. Common Operations (`common-operations/`)

#### 20.1 Task Orchestration
- [x] `TestCreateTask_Success` — creates tasks with validation _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestCreateTask_ValidationError_MissingTaskType` — validates required fields _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestCreateTask_ValidationError_InvalidUUID` — validates UUID format _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestGetTask_Success` — retrieves task by ID _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestListTasks_Success` — lists tasks with pagination _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestUpdateTask_Success` — updates task status and data _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestDeleteTask_Success` — removes tasks _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestProcessTask_Success` — processes tasks in worker _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestConcurrentTaskOperations` — thread-safe task operations _(common-operations/internal/service/operations_comprehensive_test.go)_

#### 20.2 File Operations
- [x] `TestGenerateUploadURL_Success` — creates upload URLs _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestGenerateDownloadURL_Success` — creates download URLs _(common-operations/internal/service/operations_comprehensive_test.go)_
- [x] `TestGenerateUploadURL_Error` — handles storage errors _(common-operations/internal/service/operations_comprehensive_test.go)_

#### 20.3 Message Management
- [x] `TestGetMessage_Success` — retrieves translated messages _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestGetMessage_DifferentLanguage` — language-specific translations _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestGetMessage_WithVariables` — variable substitution _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestUpsertMessage_Success` — creates/updates messages _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestListMessages_Success` — lists messages by category _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestDeleteMessage_Success` — removes messages _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestEventPublishing_MessageCreated` — publishes message events _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestConcurrentMessageOperations` — thread-safe message operations _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestTranslationVariableHandling` — handles variable replacement _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestMessageCategories` — category-based organization _(common-operations/internal/biz/message/message_comprehensive_test.go)_
- [x] `TestJSONHandlingInTranslations` — JSON in translation content _(common-operations/internal/biz/message/message_comprehensive_test.go)_

#### 20.4 Legacy File Operations
- [ ] `TestFileUpload_MinIO` — uploads file to MinIO bucket
- [ ] `TestFileDownload_PresignedURL` — generates valid presigned URL
- [ ] `TestTaskOrchestration_CreateTask` — creates async task
- [ ] `TestTaskOrchestration_CompleteTask` — marks task completed

---

## 📊 Coverage Targets

| Layer | Target | Status |
|-------|--------|--------|
| **P0 Services** (Auth, Checkout, Order, Payment, Warehouse, Return) | 80%+ | Auth ✅ **comprehensive** · Checkout ✅ **comprehensive** · Warehouse ✅ **comprehensive** · Return ✅ **comprehensive** · Order ✅ **comprehensive** · Payment ✅ **comprehensive** |
| **P1 Services** (Catalog, Pricing, Promo, Fulfillment, Shipping, Customer, Loyalty, Notification, Search) | **70%+** | Catalog ✅ good · Pricing ✅ **comprehensive** · Promotion ✅ **advanced** · Fulfillment ✅ **advanced** · Shipping ✅ **advanced** · Customer ✅ **advanced** · Loyalty ✅ **comprehensive** · Notification ✅ **comprehensive** · Search ✅ **comprehensive** |
| **P2 Services** (Gateway, Review, Analytics, Location, Common Ops) | **60%+** | Gateway ✅ **advanced** · Review ✅ **comprehensive** · Analytics ✅ **comprehensive** · Location ✅ **comprehensive** · Common Ops ✅ **comprehensive** |

### Run Commands

```bash
# Per-service test + coverage
go test -v -cover ./internal/biz/...

# Race condition detection
go test -race ./internal/biz/...

# Specific test
go test -v -run TestConfirmCheckout_HappyPath ./internal/biz/checkout/...
```
