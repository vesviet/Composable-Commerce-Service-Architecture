# E-Commerce Platform — Standard Flow Reference

**Last Updated**: 2026-02-21  
**Pattern Reference**: Shopify, Shopee, Lazada  
**Scope**: All standard business flows for a full-stack e-commerce platform

---

## Table of Contents

1. [Customer & Identity Flows](#1-customer--identity-flows)
2. [Catalog & Product Flows](#2-catalog--product-flows)
3. [Search & Discovery Flows](#3-search--discovery-flows)
4. [Pricing, Promotion & Tax Flows](#4-pricing-promotion--tax-flows)
5. [Cart & Checkout Flows](#5-cart--checkout-flows)
6. [Order Lifecycle Flows](#6-order-lifecycle-flows)
7. [Payment Flows](#7-payment-flows)
8. [Inventory & Warehouse Flows](#8-inventory--warehouse-flows)
9. [Fulfillment & Shipping Flows](#9-fulfillment--shipping-flows)
10. [Return & Refund Flows](#10-return--refund-flows)
11. [Notification Flows](#11-notification-flows)
12. [Seller / Merchant Flows](#12-seller--merchant-flows)
13. [Admin & Operations Flows](#13-admin--operations-flows)
14. [Analytics & Reporting Flows](#14-analytics--reporting-flows)
15. [Cross-Cutting Concerns](#15-cross-cutting-concerns)

---

## 1. Customer & Identity Flows

### 1.1 Registration & Onboarding
- Register with email/phone/social (Google, Facebook, Apple)
- OTP verification (SMS / email)
- Profile completion (name, DOB, gender)
- Address book creation (first address)
- Customer group assignment (default: Regular)
- Welcome notification (email + push)

### 1.2 Authentication
- Login with email+password / phone+OTP / social OAuth
- JWT access token + refresh token issuance
- Device fingerprint binding
- Multi-device session management
- Token refresh flow
- Forced logout (all sessions / single session)
- Suspicious login detection → step-up auth

### 1.3 Account Management
- Profile update (name, avatar, DOB)
- Email / phone change with re-verification
- Password change / forgot password reset
- Address book CRUD (default shipping address)
- Preference management (language, currency, notifications)
- Account deletion (GDPR / data erasure)

### 1.4 Customer Loyalty & Tier
- Tier calculation (Bronze → Silver → Gold → Platinum)
- Tier-based benefit unlock (free shipping, cashback %)
- Points earn on purchase
- Points redeem at checkout
- Points expiry & expiry notification
- Customer group rules (B2B, VIP, Employee)

---

## 2. Catalog & Product Flows

### 2.1 Product Lifecycle
- Product draft creation (seller / admin)
- Attribute & variant definition (size, color, weight)
- SKU generation per variant
- Rich content upload (images, video, description)
- SEO metadata setup (title, slug, meta description)
- Product submission for review
- Approval / Rejection workflow (moderation queue)
- Product publish → visible in catalog
- Product edit → re-review if needed
- Product deactivation / archive
- Product deletion (soft-delete)

### 2.2 Category & Taxonomy
- Category tree management (L1 → L2 → L3)
- Product → category mapping
- Category attribute template inheritance
- Featured category curation
- Category SEO pages

### 2.3 Product Variants & SKU
- Variant matrix generation (e.g., Size × Color)
- SKU-level stock, price, image override
- Default variant selection
- Sold-out variant handling (hide vs. display grayed)
- SKU barcode/EAN mapping

### 2.4 Media & Content
- Image upload → CDN storage
- Image resize / thumbnail generation
- Video upload (product demo)
- A+ Content / rich description blocks

### 2.5 Review & Rating
- Buyer submits review after delivery
- Photo/video review upload
- Rating aggregation (average, distribution)
- Review moderation (spam filter, flagging)
- Seller reply to review
- Review display on PDP (Product Detail Page)
- Review incentive (bonus points for photo review)

---

## 3. Search & Discovery Flows

### 3.1 Full-Text Search
- Keyword query → tokenize → Elasticsearch query
- Typo tolerance / fuzzy matching
- Synonym expansion (e.g., "phone" → "smartphone")
- Search ranking (relevance score + business boost)
- Autocomplete / typeahead suggestions
- Zero-result fallback (popular products, suggestions)

### 3.2 Filtering & Faceting
- Filter by category, brand, price range, rating, attributes
- Multi-select facets (e.g., Color: Red, Blue)
- Dynamic facet count update on selection
- Sort by: relevance, newest, price asc/desc, best selling, rating

### 3.3 Personalized Discovery
- Personalized homepage feed (collaborative filtering)
- "Recently viewed" products
- "Customers also bought" recommendations
- "Frequently bought together" bundles
- "You may also like" on cart page
- Re-targeting recommendations (abandoned cart items)

### 3.4 Search Indexing
- New product publish → index to Elasticsearch
- Product update → index update (partial)
- Product deactivate → remove from index
- Stock-out → deprioritize or hide in results
- Price change → update index document
- Scheduled full re-index (nightly sync)

### 3.5 SEO & Landing Pages
- Category page with canonical URL + structured data
- Brand landing pages
- Sale / Campaign landing pages
- Sitemap generation

---

## 4. Pricing, Promotion & Tax Flows

### 4.1 Base Pricing
- Seller sets base price (MRP / list price)
- Platform minimum price rule enforcement
- Currency conversion (multi-currency)
- Price history tracking
- Price competitiveness alerts

### 4.2 Promotion Types
- Percentage discount (e.g., 20% off)
- Fixed amount discount (e.g., -$10)
- Buy X Get Y free (BOGO)
- Bundle discount (set price for group)
- Minimum order value threshold (spend $50, save $5)
- Flash sale (time-bounded, stock-limited)
- Voucher / coupon code redemption
- Cashback (post-purchase credit)
- Free shipping threshold

### 4.3 Promotion Eligibility & Stacking
- Promotion applicability check (product, category, brand)
- Customer segment targeting (VIP only, new user only)
- Promotion priority & stacking rules (max 1 voucher + 1 platform discount)
- Promotion conflict resolution
- Promotion start/end scheduling
- Campaign quota management (max redemptions)

### 4.4 Tax Calculation
- Tax jurisdiction detection (shipping address → tax zone)
- Product tax category mapping (taxable, exempt)
- Tax rate lookup (HST, VAT, GST by rate code)
- Inclusive vs. exclusive tax display
- Tax line breakdown at checkout
- Tax invoice generation (post-purchase)

### 4.5 Price Finalization at Checkout
- Base price → apply promotions → apply vouchers → apply points → compute tax → final price
- Line item price lock on order creation
- Price mismatch handling (product price changed mid-checkout)

---

## 5. Cart & Checkout Flows

### 5.1 Cart Management
- Add to cart (logged-in / guest)
- Guest cart → merge into user cart on login
- Update cart item quantity
- Remove cart item
- Cart validity check (product still active, stock available)
- Cart expiry (30-day idle)
- Save for later (wishlist from cart)
- Cart sharing (shareable link)

### 5.2 Wishlist
- Add / remove product from wishlist
- Wishlist → cart conversion
- Back-in-stock notification for wishlisted items
- Price drop notification for wishlisted items
- Public / private wishlist

### 5.3 Checkout Steps
1. Cart review & confirmation
2. Shipping address selection / creation
3. Shipping method selection (standard, express, same-day)
4. Promotion / voucher code application
5. Loyalty points redemption
6. Payment method selection
7. Order summary review
8. Order submission → payment initiation

### 5.4 Checkout Validations
- Stock availability re-check at submission
- Price consistency check (cart price vs. current price)
- Promotion eligibility re-validation
- Address validation (city, postal code, delivery zone)
- Payment method eligibility (COD limit, installment threshold)
- Fraud pre-check (velocity, blacklist)

### 5.5 Guest Checkout
- Proceed without account
- Collect email for order updates
- Offer post-purchase account creation

---

## 6. Order Lifecycle Flows

### 6.1 Order Creation
- Order placed → order record created (PENDING_PAYMENT)
- Inventory reservation (soft hold on stock)
- Order confirmation notification (email + push)
- Payment window timer starts (e.g., 24h for bank transfer)

### 6.2 Order Status Lifecycle
```
PENDING_PAYMENT → PAID → PROCESSING → READY_TO_SHIP
    → SHIPPED → IN_TRANSIT → OUT_FOR_DELIVERY
    → DELIVERED → COMPLETED
                                  ↘ RETURN_REQUESTED → RETURNED
PENDING_PAYMENT → CANCELLED (timeout / user cancel)
PAID → CANCELLED_REFUND_PENDING → REFUNDED
```

### 6.3 Order Confirmation & Processing
- Payment confirmed → order moves to PROCESSING
- Seller / warehouse receives pick task
- Packing slip & shipping label generated
- Seller / warehouse marks order as packed

### 6.4 Order Modifications
- Cancel before payment (immediate, no charge)
- Cancel after payment but before shipment (refund initiated)
- Address change request (before shipment)
- Item quantity edit (before packing)
- Split order (items from multiple warehouses)

### 6.5 Order Tracking
- Shipping label created → tracking number assigned
- Tracking events pushed (carrier webhook → order update)
- Customer tracking page (real-time status)
- Delivery proof capture (photo, signature)

### 6.6 Order Completion
- Delivered → auto-complete after N days (if no dispute)
- Release funds to seller (escrow release)
- Trigger review request notification
- Credits & loyalty points earned

---

## 7. Payment Flows

### 7.1 Payment Methods
- Credit / Debit Card (Visa, Mastercard, Amex)
- Digital Wallets (GrabPay, GoPay, ShopeePay, Apple Pay, Google Pay)
- Bank Transfer (virtual account, real-time transfer)
- Buy Now Pay Later (BNPL) — Atome, Kredivo, Akulaku
- Cash on Delivery (COD)
- Installment plans (0% EMI via card)
- Loyalty points / store credit redemption

### 7.2 Payment Initiation
- Payment gateway selection based on method
- 3DS / OTP challenge flow (card payments)
- QR code generation (QRIS, PromptPay)
- Virtual account issuance (bank transfer)
- Payment session expiry management

### 7.3 Payment Confirmation
- Webhook / callback received from payment gateway
- Idempotent callback processing
- Payment status update → order status advance
- Failed payment → retry or alternative method prompt
- Pending payment → polling or webhook wait

### 7.4 Escrow & Payout
- Seller funds held in escrow on order creation/payment
- Escrow release on order completion / auto-completion
- Marketplace commission deduction before payout
- Settlement report generation
- Payout to seller bank account (batch daily/weekly)

### 7.5 Fraud Prevention
- Velocity checks (multiple orders from same card)
- Device fingerprint & IP analysis
- Address mismatch detection (billing vs. shipping)
- Machine-learning fraud score
- Manual review queue for high-risk orders
- 3DS enforcement for high-value amounts

---

## 8. Inventory & Warehouse Flows

### 8.1 Stock Management
- Initial stock upload (bulk import / API)
- Real-time stock level tracking per SKU per warehouse
- Stock reservation on cart add (soft reserve)
- Reservation confirmation on order pay
- Reservation release on cart expiry / cancellation
- Stock deduction on shipment dispatch
- Low-stock alert (threshold notification to seller)
- Out-of-stock handling → auto hide or backorder

### 8.2 Multi-Warehouse Logic
- Warehouse zone mapping (address → nearest warehouse)
- Multi-warehouse order splitting
- Warehouse priority routing (stock level, shipping cost, SLA)
- Warehouse-to-warehouse transfer
- Cross-docking support

### 8.3 Receiving & Inbound
- Purchase order (PO) creation to supplier
- Goods receipt notice (GRN) on delivery
- Quality inspection gate
- Stock put-away → bin location assignment
- Inbound discrepancy handling (short shipment, damaged)

### 8.4 Stocktake & Adjustment
- Scheduled cycle count
- Physical count vs. system count reconciliation
- Stock adjustment with reason codes (damaged, lost, found)
- Adjustment approval workflow

### 8.5 Replenishment
- Reorder point (ROP) calculation
- Auto-replenishment trigger
- Supplier lead time tracking
- Safety stock calculation

---

## 9. Fulfillment & Shipping Flows

### 9.1 Pick, Pack & Ship
- Order → pick task assigned to warehouse staff / picker
- Batch picking (multiple orders in one trip)
- Packing confirmation (items verified, package weight/dimension captured)
- Shipping label print (carrier integration)
- Handover to carrier / 3PL

### 9.2 Shipping Methods
- Standard (3–5 days)
- Express (1–2 days)
- Same-day delivery
- Instant delivery (on-demand, 2h)
- Click & Collect (store pickup)
- International shipping (cross-border)

### 9.3 Carrier Integration
- Carrier rate shopping (cheapest / fastest)
- Label generation via carrier API
- Shipment booking & manifest
- Real-time tracking events (carrier webhook)
- Failed delivery attempt → re-attempt scheduling
- Return to sender (RTS) on max attempts

### 9.4 Last Mile
- Route optimization (for own fleet)
- Driver assignment & dispatch
- Proof of delivery (POD) capture
- Failed delivery handling (customer contact → re-schedule)

### 9.5 SLA & Commitment Tracking
- Seller ship-by SLA (e.g., ship within 24h of order)
- Carrier delivery SLA tracking
- SLA breach alert → escalation
- Late shipment seller penalty calculation

---

## 10. Return & Refund Flows

### 10.1 Return Request
- Buyer initiates return (within return window)
- Return reason selection (wrong item, damaged, not as described, changed mind)
- Photo/video evidence upload
- Return eligibility check (return window, item condition policy)
- Seller / platform approval / rejection

### 10.2 Return Logistics
- Return label generation (prepaid or buyer-paid)
- Buyer drops off at courier / carrier pickup
- Return tracking (reverse logistics)
- Item received at warehouse / seller

### 10.3 Item Inspection
- Received item vs. original order verification
- Condition inspection (as described, damaged, counterfeit)
- Disposition decision: restock / quarantine / destroy

### 10.4 Refund Processing
- Refund approved → refund amount calculation (full / partial)
- Refund to original payment method (card, wallet, virtual account)
- Refund to store credit / points (faster option)
- Refund timeline by method (instant wallet vs. 5–7 days card)
- Refund confirmation notification

### 10.5 Dispute & Resolution
- Buyer escalates dispute to platform
- Mediation: platform reviews evidence
- Resolution options: full refund, partial refund, replacement
- Seller appeal process
- Chargeback handling (card network dispute)

---

## 11. Notification Flows

### 11.1 Notification Channels
- Email (transactional — SendGrid / SES)
- SMS (OTP, order status — Twilio, local aggregator)
- Push notification (mobile app — FCM / APNs)
- In-app notification center
- WhatsApp Business API
- LINE / Zalo (regional)

### 11.2 Triggered Notification Events
| Event | Channels |
|---|---|
| Registration OTP | SMS + Email |
| Order placed | Email + Push |
| Payment confirmed | Email + Push |
| Order shipped | Email + Push + SMS |
| Out for delivery | Push + SMS |
| Delivered | Push + Email |
| Return approved | Email + Push |
| Refund processed | Email + Push |
| Flash sale starts | Push |
| Price drop (wishlisted) | Push + Email |
| Back in stock | Push + Email |
| Loyalty tier upgrade | Push + Email |
| Points expiring | Push + Email |
| Session suspicious login | SMS + Email |

### 11.3 Notification Preferences
- Opt-in / opt-out per channel per category
- Quiet hours (no push 10pm–8am)
- Frequency capping (max N per day)
- Unsubscribe management (CAN-SPAM / PDPA compliance)

---

## 12. Seller / Merchant Flows

### 12.1 Seller Onboarding
- Seller registration (individual / business)
- Legal document upload (business registration, tax ID)
- KYC / identity verification
- Bank account setup for payouts
- Store profile creation (logo, banner, description)
- Test product listing guidance

### 12.2 Seller Dashboard
- Product management (CRUD, bulk import/export)
- Order management (view, process, ship)
- Inventory management (stock levels, alerts)
- Promotion management (seller-funded vouchers, flash deals)
- Analytics (GMV, conversion, returns, traffic)
- Finance (balance, payout history, invoices)
- Customer messages / Q&A

### 12.3 Seller Performance
- Seller score / rating (response time, cancellation rate, late ship rate)
- Performance tiers (Star Seller, Preferred Seller, Official Store)
- Policy violation tracking
- Seller improvement plan (SIP) trigger
- Suspension / re-activation flow

### 12.4 B2B / Wholesale
- Bulk pricing tiers (price breaks by quantity)
- B2B buyer registration & approval
- Quote request flow
- Net-30 / credit terms
- Purchase order management
- Bulk invoice generation

---

## 13. Admin & Operations Flows

### 13.1 User & Role Management
- Admin user creation with RBAC roles
- Permission matrix (product, order, finance, config)
- Audit log for admin actions
- 2FA enforcement for admin accounts

### 13.2 Content Management
- Homepage banner management (A/B test support)
- Campaign page creation (Flash Sale, 11.11, 12.12)
- Pop-up / modal management
- App version feature flags

### 13.3 Platform Configuration
- Category management (tree, attributes)
- Shipping zone & rate configuration
- Payment method enable / disable by region
- Tax rule configuration
- Fraud rule tuning
- Promotion rules engine configuration

### 13.4 Customer Support Operations
- CS agent order lookup & override
- Manual refund / compensation issuance
- Account unlock / reset
- Order cancellation override
- Escalation queue management

### 13.5 Seller Operations
- Seller application review queue
- KYC document review
- Suspension / reinstatement workflow
- Seller payout management
- Dispute arbitration

---

## 14. Analytics & Reporting Flows

### 14.1 Real-Time Metrics
- Live GMV dashboard
- Live order volume
- Active user count (MAU/DAU)
- Cart abandonment rate
- Payment success rate
- Out-of-stock rate

### 14.2 Business Reports
- Daily / weekly / monthly GMV report
- Revenue by category / brand / seller
- Product performance (views, conversion, revenue)
- Customer acquisition cost (CAC)
- Return rate by category
- Seller performance scorecard
- Payout reconciliation report
- Tax report (by jurisdiction)

### 14.3 Customer Analytics
- Funnel analysis (landing → PDP → cart → checkout → order)
- Cohort retention analysis
- CLV (Customer Lifetime Value) segmentation
- RFM (Recency, Frequency, Monetary) segmentation
- A/B test result analysis

### 14.4 Operational Analytics
- Inventory turnover
- Fulfillment SLA compliance rate
- Carrier performance
- Warehouse picking accuracy rate
- Support ticket resolution time

---

## 15. Cross-Cutting Concerns

### 15.1 Idempotency
- Payment callback idempotency (dedupe by gateway txn ID)
- Order creation idempotency (dedupe key per checkout session)
- Event processing idempotency (event ID tracking)

### 15.2 Distributed Transaction Patterns
- **Saga (Choreography)**: Order → Payment → Inventory → Shipment with compensating events
- **Outbox Pattern**: Guaranteed at-least-once event publishing from DB
- **Reservation Pattern**: Soft-lock stock before payment, confirm or release
- **Two-Phase Commit** (avoided; use Saga instead)

### 15.3 Security
- JWT + refresh token rotation
- Rate limiting (per user, per IP, per endpoint)
- CORS policy (allowlist origins per environment)
- SQL injection / XSS prevention
- PCI-DSS compliance for card data (tokenization, never store raw PAN)
- PDPA / GDPR data handling (consent, erasure)
- API gateway authentication enforcement

### 15.4 Resilience & Reliability
- Circuit breaker (service-to-service calls)
- Retry with exponential backoff + jitter
- Dead letter queue (DLQ) for failed events
- Graceful degradation (search down → category browse still works)
- Health check endpoints (`/healthz`, `/readyz`)
- Chaos engineering (simulate downstream failures)

### 15.5 Observability
- Structured logging (trace-id, span-id on every log line)
- Distributed tracing (Jaeger / Tempo)
- Metrics (RED: Rate, Errors, Duration — Prometheus + Grafana)
- Alerting (on SLA, error rate, queue depth)
- On-call runbooks per service

### 15.6 Localization & Internationalization
- Multi-language content (product title, description)
- Multi-currency pricing & display
- Region-specific payment methods
- Tax rules per country / state
- Date/time format by locale
- Address schema by country (postal code format, state required)

---

## Flow Dependency Map

```
[Auth/User/Customer]
        ↓
[Catalog + Search + Pricing + Promotion + Tax]
        ↓
[Cart → Checkout]
        ↓
[Order Created]
    ↓           ↓
[Payment]  [Inventory Reservation]
    ↓
[Inventory Confirmed]
    ↓
[Fulfillment → Pick → Pack → Ship]
    ↓
[Carrier → Tracking]
    ↓
[Delivered → Complete]
    ↓           ↓
[Review]    [Return/Refund]
    ↓
[Analytics / Reporting]

[Notification] ← triggers from every flow above
[Admin/Ops]    ← manages every flow above
[Seller]       ← manages Catalog, Inventory, Fulfillment
```

---

## Related Documents

| Document | Path |
|---|---|
| Workflow Index (legacy) | [workflow-index.md](legacy/workflow-index.md) |
| Service Deploy Order | [SERVICE_DEPLOY_ORDER.md](SERVICE_DEPLOY_ORDER.md) |
| Checklists | [checklists/](checklists/) |
| System Completeness Assessment | [legacy/SYSTEM_COMPLETENESS_ASSESSMENT.md](legacy/SYSTEM_COMPLETENESS_ASSESSMENT.md) |
