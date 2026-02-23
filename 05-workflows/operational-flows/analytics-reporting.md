# Analytics & Reporting Flow

**Purpose**: Funnel analysis, cohort/RFM segmentation, A/B testing lifecycle, payout reconciliation, and tax reporting workflows  
**Services**: Analytics, Order, Payment, Customer, Catalog, Search, Promotion, Notification  
**Pattern Reference**: Shopify Analytics, Lazada Business Advisor, Amplitude, Metabase

---

## Overview

Analytics is not a passive read-layer. It actively powers recommendations, A/B test routing, and real-time alerting. This doc covers both the business reporting flows and the operational analytics patterns that drive platform decisions.

---

## 1. Real-Time Metrics Pipeline

### 1.1 Event Ingestion

```
All services → publish domain events → Dapr Pub/Sub → Analytics Consumer
    → Analytics Service: write to time-series store (InfluxDB / ClickHouse)
    → Deduplicate by event_id (idempotent ingestion)
    → Partition by: service, event_type, date
```

**Key event sources**:
- `order.placed`, `order.completed`, `order.cancelled`
- `payment.captured`, `payment.refunded`, `payment.failed`
- `checkout.started`, `checkout.abandoned`
- `product.viewed`, `product.added_to_cart`
- `search.query`, `search.result_clicked`
- `user.registered`, `user.logged_in`

### 1.2 Live GMV Dashboard

```
Analytics Worker (every 30 seconds):
    → Aggregate: SUM(order.total) WHERE event_time > start_of_day
    → Push to dashboard via WebSocket / SSE
    → Alert: if GMV drops > 30% vs. prior 15-min window → page on-call
```

---

## 2. Conversion Funnel Analysis

### 2.1 Funnel Definition

```
Standard Purchase Funnel:
    Landing Page → PDP View → Add to Cart → Checkout Started
    → Payment Initiated → Order Confirmed
```

### 2.2 Funnel Computation

```
Analytics Worker (hourly batch):
    For each session_id in last 24h:
        1. Identify funnel steps from session events
        2. Classify: completed step N, dropped at step N
        3. Compute: step-by-step conversion rate, avg time between steps
        4. Segment by: device, traffic source, customer segment, product category

Output: funnel_report (conversion_rate per step, top drop-off reasons)
```

### 2.3 Drop-Off Investigation

**Trigger**: cart → checkout drop-off rate spikes > 5% above baseline.

```
Alert → Analytics Team:
    → Query: sessions that started checkout but did not complete
    → Join: checkout_started events with error events
    → Common causes: payment errors, shipping cost surprise, forced registration
    → Action: flag for UX team / product review
```

---

## 3. Customer Segmentation — Cohort & RFM

### 3.1 Cohort Analysis

**Trigger**: Monthly Analytics Worker.

```
Analytics Worker (1st of each month):
    → Group customers by: registration month (acquisition cohort)
    → For each cohort:
        Track month-by-month: % still active (made purchase)
        Compute: M1 retention, M3 retention, M6 retention
    → Store: retention_matrix[cohort_month][months_since]
    → Dashboard: cohort retention heatmap
```

### 3.2 RFM Segmentation

**Runs**: Weekly.

```
Analytics Worker:
    For each customer with ≥ 1 order in last 12 months:
        R (Recency) = days since last order (lower = better) → score 1-5
        F (Frequency) = order count in 12 months → score 1-5
        M (Monetary) = total spend in 12 months → score 1-5

    RFM Segment Classification:
        R≥4, F≥4, M≥4 → Champions
        R≥3, F≥3 → Loyal Customers
        R≥4, F=1 → New Customers
        R≥4, F≥2, M≤2 → Potential Loyalists
        R≤2, F≥3 → At-Risk Customers
        R=1, F=1 → Lost Customers

    → Customer Service: update customer_segment field per customer
    → Used by: Promotion Service (targeted campaigns), Notification (personalized push)
```

---

## 4. A/B Test Lifecycle

### 4.1 Experiment Setup

```
Product Manager → Analytics Admin Panel:
    → Define experiment:
        - Name: "New checkout button color"
        - Hypothesis: "Green CTA increases checkout conversion by 3%"
        - Variants: A (control: blue), B (treatment: green)
        - Split: 50/50
        - Target: all users on checkout page
        - Metric: checkout_completion_rate
        - Minimum runtime: 14 days
        - Minimum sample: 10,000 sessions per variant

    → Analytics Service: create experiment record
    → Feature Flag Service: register flag (checkout_cta_color: [blue|green])
    → Status: RUNNING
```

### 4.2 Traffic Splitting

```
Gateway → request with user_id → Feature Flag Service
    → Hash user_id → assign to variant A or B (sticky assignment)
    → Return: variant = "A" or "B"
    → Header passed to frontend: X-Experiment-Variant: B
    → Frontend renders appropriate variant
    → Event: experiment.exposure_recorded (user_id, experiment_id, variant)
```

### 4.3 Result Analysis

**Trigger**: Minimum runtime reached AND minimum sample size reached.

```
Analytics Worker:
    → Compute per variant:
        - Primary metric: conversion rate (orders / sessions)
        - Secondary metrics: AOV, bounce rate, error rate
    → Statistical test: two-proportion z-test (95% confidence)
    → If statistically significant:
        Status → WINNER_DECLARED (variant_id)
    → If runtime exceeded max (28 days) without significance:
        Status → INCONCLUSIVE
    → Send summary report to PM + engineering team

Rollout:
    Feature Flag Service: set flag to winning variant for 100% traffic
    Status → COMPLETED
    Archive experiment results
```

### 4.4 Guardrail Metrics

```
During experiment, monitor every hour:
    - Error rate: if B variant shows > 2x baseline error rate → auto-stop
    - Payment failure rate: if B variant shows increase > 1% → pause + alert
    - Latency: if B adds > 200ms P95 → auto-stop
```

---

## 5. Payout Reconciliation

### 5.1 Daily Reconciliation

**Trigger**: Daily batch job at 02:00 AM.

```
Finance Worker:
    Step 1: Pull payment gateway settlement report (CSV/API)
        - Gateway: list all settled transactions for T-1
        
    Step 2: Pull internal ledger
        - Payment Service: list all captured payments for T-1
        
    Step 3: Match (gateway txn_id ↔ internal payment_id)
        - Matched: amount matches → OK
        - Amount mismatch: flag for FINANCE_ADMIN review
        - Gateway has txn not in internal ledger → investigate
        - Internal has payment not in gateway settlement → pending settlement
        
    Step 4: Generate reconciliation_report_YYYY-MM-DD.csv
        - Columns: payment_id, order_id, gateway_txn_id, captured_amount, settled_amount, status, discrepancy

    Step 5: Alert if total discrepancy > ₫10,000,000 → page finance team
```

### 5.2 Seller Payout Reconciliation

```
Finance Worker (weekly):
    For each seller:
        → Sum: escrow_released amounts (T-7 to T-0)
        → Subtract: platform_commission + fees + penalty_deductions
        → Compare with: actual disbursed amount
        → If discrepancy:
            → Create: payout_discrepancy_ticket for FINANCE_ADMIN
            → If underpayment: initiate corrective transfer
            → If overpayment: record in next cycle as deduction
```

---

## 6. Tax Reporting

### 6.1 Tax Collection per Order

```
Order Service → order.completed event → Analytics Service
    → Record: tax_line per order (jurisdiction, tax_code, tax_rate, tax_amount)
    → Partition by: tax_period (month), jurisdiction
```

### 6.2 Monthly Tax Report

**Trigger**: 1st of each month (for prior month).

```
Finance Worker:
    → Aggregate tax_lines by jurisdiction for prior month
    → Group by: country, state, tax_code
    → Output: tax_report_YYYY-MM.csv
        Columns: jurisdiction, tax_code, tax_rate, taxable_amount, tax_collected
    → Upload to: secure finance folder
    → Notify: FINANCE_ADMIN
    → Used for: VAT/GST filing submissions to tax authority
```

### 6.3 Tax Invoice Generation

**Trigger**: Order completed (for buyers that had tax applied).

```
Order Service → order.completed event → Analytics Service
    → If order has tax_lines:
        → Generate PDF tax invoice:
            - Seller VAT registration number
            - Buyer details (if B2B)
            - Itemized line items with unit price, qty, subtotal
            - Tax breakdown (rate, amount)
            - Total
        → Upload PDF to storage (CDN-accessible URL)
        → Notification: send invoice link to buyer
```

---

## 7. Business Reports — Standard Set

| Report | Schedule | Audience | Key Metrics |
|---|---|---|---|
| Daily GMV Report | Daily 07:00 | All Admins | GMV, order count, AOV, refund rate |
| Weekly Cohort Summary | Monday 08:00 | Product + Growth | M1-M6 retention by acquisition cohort |
| Monthly Revenue Report | 3rd of month | Finance, CEO | Revenue, commission income, refund deductions, net revenue |
| Seller Performance Report | Monthly | SELLER_OPS | GMV by seller, ship-on-time rate, return rate, score |
| Search Effectiveness Report | Weekly | Product, Search | Top queries, zero-result rate, search→purchase CTR |
| Category Performance Report | Monthly | Catalog, Merchandising | GMV by category, stock-out rate, margin |
| Campaign ROI Report | Post-campaign | Marketing | Campaign GMV, voucher cost, incremental uplift |
| Tax Liability Report | Monthly | Finance | Tax collected per jurisdiction |
| Payout Settlement Report | Daily | Finance | Disbursed, pending, discrepancies |

---

## 8. Anomaly Detection & Alerting

```
Analytics Worker (continuous):
    → Z-score anomaly detection per metric per 15-min window
    → Alert conditions:
        GMV drops > 30% vs. prior hour → Slack alert + PagerDuty P2
        Payment failure rate > 5% → PagerDuty P1
        Order creation errors > 1% → PagerDuty P1
        Search zero-result rate > 20% → Slack alert P2
        Checkout abandonment spikes > 20% → Slack alert P3

    → Runbook linked in every alert
```

---

**Last Updated**: 2026-02-21  
**Owner**: Data & Analytics Team
