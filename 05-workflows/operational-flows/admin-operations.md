# Admin & Operations Flow

**Purpose**: Platform admin user management, CS agent operations, seller governance, platform config, and campaign management flows  
**Services**: Gateway, Auth, User (Admin), Customer, Order, Payment, Return, Catalog, Promotion, Notification, Analytics  
**Pattern Reference**: Shopee ShopeeMall Admin, Lazada Seller Center Admin, Shopify Admin

---

## Overview

Admin operations are the control plane of the platform. This covers: who can do what (RBAC), how CS agents handle buyer issues, how seller applications are processed, and how platform-wide configuration is managed safely.

---

## 1. Admin User Management & RBAC

### 1.1 Admin Role Definitions

| Role | Scope | Key Permissions |
|---|---|---|
| `SUPER_ADMIN` | All | Create roles, manage all config, access all data |
| `PRODUCT_ADMIN` | Catalog | Approve/reject listings, manage categories |
| `ORDER_ADMIN` | Orders | View/cancel/override orders, refunds up to limit |
| `FINANCE_ADMIN` | Payments | View payments, initiate refunds, view seller balances |
| `SELLER_OPS` | Sellers | Review KYC, approve/suspend sellers |
| `CS_AGENT` | Customer Support | Order lookup, limited cancel/refund, account unlock |
| `CONTENT_ADMIN` | CMS | Manage banners, campaigns, SEO pages |
| `ANALYTICS_VIEWER` | Reports | Read-only dashboards and reports |

### 1.2 Admin Account Creation

```
SUPER_ADMIN → Create Admin User:
    → Auth Service: create user with admin role
    → User Service: assign permissions per role
    → Notification: invite email with temporary password link (expires 24h)
    → 2FA enforcement: TOTP required on first login
    → Audit log: admin_user.created (who created, when, role)
```

**Security rules**:
- 2FA mandatory for all admin accounts (no exceptions)
- Admin sessions: 4-hour TTL, re-auth required on sensitive actions (refunds)
- IP allowlist: admin panel accessible only from approved IP ranges (configurable)
- Admin actions: every mutation logged in immutable audit trail

### 1.3 Permission Changes

```
SUPER_ADMIN → Modify admin permissions:
    → Requires 2FA step-up re-authentication
    → User Service: update role/permissions
    → Audit log: admin_user.permission_changed
    → Notification to affected admin
```

---

## 2. Customer Support (CS) Agent Operations

### 2.1 CS Dashboard — Order Lookup

```
CS Agent → Search by: order_id | buyer_email | buyer_phone | tracking number
    → Order Service: fetch order details
    → Payment Service: fetch payment status
    → Return Service: fetch return status (if any)
    → View: order timeline, line items, payment, shipping, CS notes
```

### 2.2 Manual Order Cancellation

```
CS Agent → Cancel Order:
    Eligibility check:
        - Order status: PAID or PROCESSING (not yet shipped)
        - Reason: buyer request, fraud, seller non-compliance
    → Order Service: cancel order (with cs_agent_id, reason)
    → Payment Service: initiate refund to original payment method
    → Warehouse Service: release inventory reservation
    → Notification: buyer receives cancellation + refund confirmation
    → Audit log: order.cancelled_by_cs (agent_id, order_id, reason)
```

### 2.3 Manual Refund / Compensation

```
CS Agent → Issue Refund:
    Eligibility:
        - CS Agent: up to ₫2,000,000 (configurable per tier)
        - ORDER_ADMIN: up to ₫10,000,000
        - FINANCE_ADMIN: unlimited
    → Payment Service: create_refund(order_id, amount, reason, agent_id)
    → Requires 2FA step-up if amount > threshold
    → Payment Service: process refund (to original method or store credit)
    → Notification: buyer receives refund confirmation
    → Audit log: payment.manual_refund (agent, amount, reason, order)
```

**Compensation types**:
- Refund to original payment method (3-7 business days)
- Store credit (instant, preferred for fast resolution)
- Loyalty points credit (instant)
- Promo voucher issuance

### 2.4 Account Unlock / Reset

```
CS Agent → Customer Account Actions:
    - Unlock locked account (too many failed login attempts):
        Auth Service: unlock_account(customer_id)
        Audit log: account.unlocked_by_cs
    - Reset password (send link to email):
        Auth Service: send_password_reset_email(email)
        Audit log: account.password_reset_by_cs
    - Unlink social account (buyer request):
        Auth Service: revoke_social_link(provider, customer_id)
    - Delete account (GDPR erasure request):
        Requires: ORDER_ADMIN approval
        Customer Service: schedule erasure job
        Audit log: account.erasure_requested
```

### 2.5 CS Notes & Ticket Management

```
CS Agent → Add note to order:
    → Order Service: append cs_note (agent_id, timestamp, text)
    → Notes visible to all CS agents, not visible to buyer

Escalation:
    CS Agent → Escalate ticket → CS Team Lead
    → User Service: reassign ticket owner
    → Notification to team lead
    → SLA: escalated tickets responded within 2h
```

---

## 3. Seller Application Review & Governance

### 3.1 KYC Document Review

```
SELLER_OPS Admin → KYC Review Queue
    → View pending seller applications (sorted by submission time)
    → View: submitted documents, business info, identity verification
    → Actions:
        Approve: User Service → seller status = APPROVED
        Reject: User Service → seller status = REJECTED + reason
        Request More Info: Notification to seller with checklist
    → Audit log: seller_kyc.reviewed (admin_id, decision, reason)
    → SLA: < 2 business days
```

### 3.2 Seller Suspension / Reinstatement

```
SELLER_OPS Admin → Suspend Seller:
    Reasons: policy violation, fraud, poor performance, legal request
    → User Service: status = SUSPENDED
    → Catalog Service: delist all seller products
    → Order Service: block new order creation from seller
    → Ongoing orders: notify seller to fulfill existing orders within 48h
    → Notification: seller receives suspension + reason + appeal link
    → Audit log: seller.suspended

Seller Appeal:
    Seller → Submit appeal (evidence upload, explanation)
    → SELLER_OPS queue
    → Admin reviews
    → Reinstate: User Service → status = ACTIVE, relist products
    → Reject appeal: status remains SUSPENDED
    → Audit log: seller.appeal_reviewed
```

### 3.3 Payout Dispute Resolution

```
FINANCE_ADMIN → Seller payout dispute:
    - Seller claims: "I was not paid for order #123"
    → Finance Admin: query Payment Service ledger for order
    → Verify: escrow hold → escrow release → payout_disbursed events
    → If discrepancy found:
        → Manual adjustment entry in ledger
        → Initiate corrective bank transfer
        → Audit log: payment.manual_ledger_adjustment
```

---

## 4. Platform Configuration Management

### 4.1 Shipping Zone & Rate Configuration

```
SUPER_ADMIN → Shipping Config:
    → Define delivery zones (by state / province / postal range)
    → Set base shipping rates per carrier per zone
    → Set free shipping threshold (platform-wide or per category)
    → Effective date: publish config with activation_at timestamp
```

### 4.2 Tax Rule Configuration

```
FINANCE_ADMIN → Tax Rules:
    → Define tax jurisdiction (country → state → city)
    → Assign tax rate per jurisdiction (VAT %, HST %)
    → Define product tax categories (standard, exempt, reduced)
    → Map product categories → tax categories
    → Test calculator: input address + products → expected tax output
```

### 4.3 Payment Method Enable / Disable

```
SUPER_ADMIN → Payment Methods Config:
    → Enable / disable per payment type per region
    → Set COD limit per order value
    → Set BNPL eligibility rules (min account age, min orders completed)
    → Configure 3DS threshold (enforce 3DS for orders > ₫1,000,000)
```

### 4.4 Fraud Rule Tuning

```
SUPER_ADMIN / FINANCE_ADMIN → Fraud Rules:
    → Adjust velocity thresholds (max N orders per card per 24h)
    → Update IP blocklist / email domain blocklist
    → Configure machine-learning score threshold for auto-reject vs. manual review
    → Review manual review queue
    → Approve / reject flagged orders
```

---

## 5. Content Management (CMS)

### 5.1 Homepage Banner Management

```
CONTENT_ADMIN → Create Banner:
    → Upload image (recommended: 1200×400px)
    → Set: title, click URL (internal product page / external URL)
    → Set: display_start, display_end, target regions
    → Set: A/B test split (optional — show banner A to 50% of traffic)
    → Preview → Publish
    → Analytics: track banner clicks, CTR
```

### 5.2 Flash Sale / Campaign Creation

```
CONTENT_ADMIN → Create Campaign:
    Step 1: Campaign Definition
        - Name: "11.11 Mega Sale"
        - Date range, countdown timer display
        - Campaign landing page URL
        - Marketing assets (banners, push notification content)
    
    Step 2: Product Nomination (from sellers)
        - Sellers nominate products via Seller Centre
        - CONTENT_ADMIN reviews, approves items
        - Locks nominated stock in Warehouse Service
    
    Step 3: Promotion Rules
        - Promotion Service: create campaign discount rules
        - Set: platform contribution % + seller contribution %
        - Voucher pool: platform-funded voucher codes
    
    Step 4: Pre-launch Checklist
        - Verify inventory reserved
        - Test campaign landing page
        - Schedule push notification batch
    
    Step 5: Launch
        - Promotion Service: activate campaign rules
        - Content Service: publish landing page + banners
        - Notification Service: send campaign push
```

### 5.3 Pop-up / Modal Management

```
CONTENT_ADMIN → Create Pop-up:
    - Trigger: first visit, exit intent, scroll 50%
    - Content: promotional offer, newsletter signup, app download
    - Targeting: new users only, specific country, specific URL
    - Frequency: show once per session / once per 7 days
    - A/B test variant support
```

---

## 6. Audit Trail & Compliance

Every admin action writes to the immutable audit log:

```
Audit Log Entry:
    actor_id: admin_user_id
    actor_role: SELLER_OPS
    action: seller.suspended
    entity_type: seller
    entity_id: seller_uuid
    payload: { reason, previous_state, new_state }
    timestamp: RFC3339
    ip_address: requester IP
    session_id: admin session UUID
```

**Retention**: 7 years (compliance with financial regulations).  
**Access**: SUPER_ADMIN can view. No admin can mutate audit log.  
**Export**: Finance/legal team can export as CSV for audits.

---

## 7. Dashboard & Reporting for Admins

| Dashboard | Audience | Key Metrics |
|---|---|---|
| Operations Overview | All Admins | Live GMV, orders/hr, payment success rate, error rate |
| CS Dashboard | CS Agents | Open tickets, avg resolution time, pending refunds |
| Seller Dashboard | SELLER_OPS | Pending KYC, suspended sellers, SLA breach count |
| Finance Dashboard | FINANCE_ADMIN | Revenue, refund rate, payout queue, fraud flag rate |
| Content Dashboard | CONTENT_ADMIN | Banner CTR, campaign GMV contribution, voucher redemption |

---

**Last Updated**: 2026-02-21  
**Owner**: Platform Operations Team
