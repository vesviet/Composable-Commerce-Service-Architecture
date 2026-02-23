# Seller & Merchant Flow

**Purpose**: Seller onboarding, KYC, store management, performance, payout, and B2B flows  
**Services**: Gateway, Auth, User (Admin), Customer, Catalog, Order, Payment, Warehouse, Notification, Analytics  
**Pattern Reference**: Shopee Seller Centre, Lazada Seller Center, Shopify Partner

---

## Overview

The seller/merchant layer is the supply side of the marketplace. Every product on the platform originates from a seller. This doc covers the full seller lifecycle from application to payout.

---

## 1. Seller Onboarding & KYC

### 1.1 Application

```
Seller → Seller Registration Form
    → Auth Service: create seller account (role: SELLER)
    → User Service: create seller profile record
    → Notification: send verification email
    → Status: APPLICATION_PENDING
```

**Required fields**:
- Business type: Individual / Company
- Business registration number (if Company)
- Store name, store description, store logo
- Primary business category
- Contact: email, phone, WhatsApp

### 1.2 Document Upload & KYC

```
Seller → Document Upload
    → Storage: upload to secure bucket (encrypted at rest)
    → User Service: link documents to seller profile
    → Admin queue: KYC review task created
    → Status: KYC_UNDER_REVIEW
```

**Required documents**:
- Individual: national ID / passport (front + back)
- Company: business registration certificate, tax certificate, director ID

### 1.3 KYC Review (Admin-side)

```
Admin CS Agent → review KYC documents
    → Approve:
        User Service: update seller status → APPROVED
        Notification: "Your store is approved, start listing!"
        Seller portal access unlocked
    → Reject:
        User Service: update seller status → REJECTED (with reason)
        Notification: rejection email with reason + resubmit link
```

**SLA**: KYC review completed within 2 business days.

### 1.4 Bank Account Setup

```
Seller → Bank Account Form (account number, bank code, account holder name)
    → Payment Service: validate bank account (penny test or aggregator validation)
    → Payment Service: store as payout_method (encrypted, tokenized)
    → Status: PAYOUT_CONFIGURED
```

---

## 2. Store Profile Management

```
Seller → Seller Centre → Update store:
    → Store name, logo, banner, description
    → Operating hours (for SLA calculation)
    → Return policy (custom return window)
    → Shipping policy (self-ship vs. platform logistics)
    → Catalog Service: update store metadata
```

---

## 3. Product Listing Management

### 3.1 Create Listing

```
Seller → New Product Form
    → Catalog Service: create product draft
        - Title, description (rich text)
        - Category selection → attribute template loaded
        - Variant matrix (size × color)
        - SKU codes, barcode/EAN
        - Base price per SKU
        - Main image + gallery images (CDN upload)
    → Submit for moderation
    → Status: PENDING_REVIEW
```

### 3.2 Moderation

```
Catalog Service → moderation queue → Admin / AI moderation:
    - Check title/description (prohibited keywords, spam)
    - Verify images (NSFW, watermark policy)
    - Verify category assignment
    → Approve → Status: PUBLISHED (visible in search)
    → Reject → Notification to seller with reason
```

### 3.3 Bulk Operations

```
Seller → Upload CSV/XLSX
    → Catalog Service: bulk import job
        - Validate each row (required fields, price range)
        - Create / update products in batch
        - Return: import_report.csv (success count, error rows)
```

---

## 4. Inventory Management (Seller Side)

```
Seller → Inventory update (per SKU per warehouse):
    → Warehouse Service: update stock level
    → If stock = 0:
        Search Service: deprioritize SKU in results
        Notification: "Your SKU [X] is out of stock"

Seller → Stock replenishment upload:
    → Warehouse Service: bulk stock adjustment with reason = SELLER_RESTOCK
```

---

## 5. Order Management (Seller Side)

### 5.1 New Order Notification

```
Order Service → order.seller_notified event → Notification Service
    → Push + email to seller: "New order #123 — ship by [date]"
    → Seller Centre: order appears in "To Ship" queue
```

### 5.2 Seller Processing an Order

```
Seller → Mark as Packed (in Seller Centre)
    → Fulfillment Service: create fulfillment record
    → If self-ship:
        Shipping Service: generate shipping label
        Seller prints and attaches label
    → Mark as Shipped (enter tracking number)
    → Order Service: update status → SHIPPED
    → Notification: buyer receives tracking info
```

### 5.3 Seller Ship-By SLA

```
Order placed → SLA timer starts (e.g., 24h for standard, 48h for remote)

SLA Worker (cron):
    → Check all PROCESSING orders past ship-by deadline
    → Seller: warning notification at 80% of window
    → SLA breached:
        → Record late_shipment on seller performance record
        → Auto-cancel if X hours past SLA (configurable)
        → Refund buyer if payment captured
        → Penalty points applied to seller score
```

---

## 6. Seller-Funded Promotions

### 6.1 Voucher Creation

```
Seller → Seller Centre → Create Voucher:
    - Voucher type: % off, fixed amount, free shipping
    - Scope: store-wide, specific products, min spend
    - Usage limit (total + per buyer)
    - Budget cap (maximum payout from seller account)
    - Start / end date
    → Promotion Service: create voucher, status: SCHEDULED
```

### 6.2 Flash Sale Nomination

```
Seller → Nominate products for platform flash sale
    → Promotion Service: submit nomination
        - Discounted price (platform validates: < base price, within min price policy)
        - Allocated stock for flash sale
    → Admin approval
    → Flash sale start → reserved stock locked
    → Flash sale end → release unsold stock back to regular inventory
```

---

## 7. Seller Performance Scoring

### 7.1 Score Components

| Metric | Weight | Target | Measured |
|---|---|---|---|
| Response Rate | 15% | > 90% | Messages replied within 24h |
| Response Time | 10% | < 4h avg | Hours to first reply |
| Ship-On-Time Rate | 30% | > 95% | Orders shipped within SLA |
| Cancellation Rate | 20% | < 3% | Seller-initiated cancellations |
| Return Rate | 15% | < 5% | Returns due to seller fault |
| Rating | 10% | > 4.5 | Product ratings |

### 7.2 Performance Tiers

```
Score > 90: ⭐ Star Seller — badge, search boost, lower commission
Score 75-90: Preferred Seller — standard benefits
Score 60-75: Standard Seller
Score < 60: Under Observation — monthly improvement plan
Score < 40 for 3 months: SUSPENDED
```

### 7.3 Penalty Events

```
Analytics Worker (cron, daily):
    → Compute seller score from last 30 days of data
    → Update User Service: seller_score, tier
    → If tier downgraded: notification to seller
    → If score < 40 for 3 consecutive months:
        User Service: update seller status → SUSPENDED
        Catalog Service: delist all seller products
        Order Service: block new order acceptance
        Notification: suspension email with appeal instructions
```

---

## 8. Escrow & Payout

### 8.1 Escrow Hold

```
Order paid → Payment Service:
    → Hold gross order value in platform escrow account
    → Ledger entry: ESCROW_HOLD (seller_id, order_id, amount)
```

### 8.2 Escrow Release

**Trigger**: Order status → COMPLETED (auto-complete or buyer confirms).

```
Order Service → order.completed event → Payment Service
    → Calculate net payout:
        gross_amount
        − platform_commission (% per category)
        − payment_processing_fee
        − seller_voucher_contribution (if any)
        − seller_penalty_deductions (if any)
        = net_payout
    → Ledger entry: ESCROW_RELEASED
    → Add to seller pending balance (not yet disbursed)
```

### 8.3 Payout Disbursement

**Trigger**: Daily payout batch job (configurable: daily / weekly).

```
Payment Worker (cron):
    → Query all sellers with pending_balance > 0 and balance matured (T+7 or T+3)
    → For each seller:
        → Payment Service: transfer to seller bank account via payment aggregator
        → Ledger entry: PAYOUT_DISBURSED
        → Generate payout statement (PDF)
        → Notification: "₫X has been transferred to your bank account"
```

### 8.4 Payout Hold on Dispute

```
Return Service → return.dispute_opened event → Payment Service
    → Hold escrow release for disputed order amount
    → Release or deduct based on dispute resolution outcome
```

---

## 9. Seller Analytics Dashboard

Available in Seller Centre:
- GMV by day / week / month
- Orders: counts by status
- Top-selling SKUs (revenue, units)
- Traffic: visits to product pages, add-to-cart rate, conversion
- Return rate by SKU
- Payout history + pending balance
- Performance score trend + component breakdown

---

## 10. B2B / Wholesale Flow

### 10.1 B2B Buyer Registration

```
Buyer → Register as B2B buyer:
    → Submit: company name, tax ID, business registration
    → Admin approval → Customer Group: B2B
```

### 10.2 Tiered Pricing

```
Seller → Define quantity price breaks:
    Qty 1-9: ₫500,000 / unit
    Qty 10-49: ₫450,000 / unit (10% off)
    Qty 50+: ₫400,000 / unit (20% off)
→ Pricing Service: store as volume_pricing rules
→ B2B buyer adds qty 50 to cart → price auto-applied
```

### 10.3 Quote Request Flow

```
B2B buyer → Request Quote (product + quantity + delivery date)
    → Notification: seller receives quote request
    → Seller responds: custom price, valid X days
    → Buyer accepts → checkout at quoted price (locked quote token)
    → Quote token validates at checkout: not expired, same buyer
```

### 10.4 Net Terms / Credit

```
B2B buyer (approved credit limit) → Place order
    → Payment Service: register as NET30 order (no payment upfront)
    → Order created → invoice generated
    → Day 30: payment reminder notification
    → Day 35: overdue notification
    → Day 45: credit suspended + collection initiated
```

---

## State Machine — Seller Account

```
APPLICATION_PENDING
    → KYC_UNDER_REVIEW
        → APPROVED → ACTIVE
        → REJECTED → (resubmit) → KYC_UNDER_REVIEW
ACTIVE
    → UNDER_OBSERVATION (score < 60)
        → ACTIVE (score recovers)
        → SUSPENDED (score < 40 × 3 months)
    → SUSPENDED
        → APPEAL_PENDING
            → REINSTATED → ACTIVE
            → PERMANENTLY_BANNED
```

---

**Last Updated**: 2026-02-21  
**Owner**: Seller Operations & Platform Team
