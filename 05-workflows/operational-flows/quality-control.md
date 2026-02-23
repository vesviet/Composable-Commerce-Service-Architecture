# Quality Control Workflow

**Version**: 2.0  
**Last Updated**: 2026-02-21  
**Category**: Operational Flows  
**Status**: Active

## Overview

Warehouse QC in e-commerce is about verifying the right item in the right condition ships to the right customer, before handover to carrier. This is not a manufacturing inspection — it is a last-mile accuracy gate done by warehouse staff on packed orders.

---

## Participants

- **Warehouse Staff / Packer**: Performs QC during or after packing
- **QC Supervisor**: Reviews failed orders, makes disposition decisions
- **Fulfillment Service**: Triggers QC requirement, records results
- **Warehouse Service**: Provides inventory/product info
- **Notification Service**: Alerts staff and sellers for issues

---

## QC Trigger Rules

| Condition | QC Type | Who Inspects |
|---|---|---|
| Order value > ₫5,000,000 | Mandatory 100% | Senior warehouse staff |
| Contains fragile items | Mandatory 100% | Any staff |
| First-time seller order | Mandatory 100% | QC Supervisor |
| Random sampling | 10% of all orders | Any staff |
| Customer-flagged seller (return rate > 8%) | Mandatory 100% | QC Supervisor |

All other orders: skip QC, proceed directly to carrier handover.

---

## Main Flow: Post-Pack QC

### Step 1: QC Assignment

```
Fulfillment Service (after packing step):
    → Evaluate QC trigger rules
    → If QC required:
        Create QC task: { order_id, qc_type, assigned_to }
        Fulfillment Service: order status = PENDING_QC
    → If QC not required:
        Proceed directly to shipping label generation
```

### Step 2: Item Verification (Scan-to-Verify)

```
QC Staff:
    → Scan each item barcode / QR code in package
    → Fulfillment Service: validate against order line items
    → Items match → proceed
    → Items mismatch:
        Log: wrong_item_in_package (expected SKU, found SKU)
        Status: QC_FAILED — WRONG_ITEM
        → Re-pick correct item, restart from packing
```

### Step 3: Product Condition Check

```
Staff visual inspection:
    - No visible damage (dents, tears, cracks, stains)
    - Original packaging intact (not opened, not tampered)
    - Labels / stickers intact
    - Expiry date (for consumables): > [return window + 30 days]

If damage found:
    Log: product_condition_issue (describe damage)
    Status: QC_FAILED — DAMAGED
    → Return to warehouse inventory (quarantine bin)
    → Pick replacement unit → restart from packing
    → If no replacement: notify seller, cancel order item, partial refund
```

### Step 4: Weight Verification

```
Packed order → placed on scale
    → Actual weight vs. declared weight (from product catalog)
    → Tolerance: ± 5% or ± 50g (whichever is greater)

If weight outside tolerance:
    Flag for QC Supervisor: possible missing item or wrong item
    QC Supervisor re-opens package, re-verify contents
    → If missing item: re-pick, repack
    → If weight catalog data wrong: update catalog, proceed
```

### Step 5: Packaging Adequacy Check

```
Staff checks:
    - Package sealed properly (tape, no open seams)
    - Fragile items: bubble wrap / air pillows present
    - Multi-item orders: items don't shift/damage each other
    - Shipping label: correct name, address, barcode (scan to verify)

If packaging inadequate:
    → Repack with proper protection materials
    → Apply new shipping label if damaged
    → Re-seal and return to QC Step 5
```

### Step 6: Photo Documentation (High-Value & Mandatory QC Orders)

For orders with QC type = Mandatory 100% or order value > ₫5,000,000:

```
Staff:
    → Photo 1: All items laid out next to order packing slip
    → Photo 2: Packed box open (contents visible)
    → Photo 3: Sealed package with shipping label visible
    → Upload photos: linked to order_id in QC record
```

Photos serve as evidence in buyer disputes / chargebacks.

### Step 7: QC Pass — Proceed to Shipping

```
Fulfillment Service:
    → Record: qc_passed_at, inspector_id, qc_type, photos_attached
    → Order status: QC_PASSED
    → Trigger: shipping label generation
    → Handover package to carrier collection point
```

---

## QC Failure Handling

### Wrong Item

```
Severity: High — never ship wrong item
Action:
    1. Remove wrong item → return to inventory (wrong_pick_bin)
    2. Pick correct item
    3. Re-verify → restart QC from Step 2
    4. Log picker error for performance tracking
```

### Damaged Item

```
Severity: High — never ship damaged goods
Action:
    1. Quarantine damaged unit (damaged_stock_bin)
    2. Warehouse Service: stock adjustment (reason=DAMAGE)
    3. Pick replacement if available → restart QC
    4. If no replacement:
        → Notify seller (if marketplace model)
        → Order Service: partial cancellation for that item
        → Payment Service: partial refund
        → Notification: buyer receives partial refund notice
```

### Weight Mismatch Unresolved

```
Severity: Medium — re-inspect once
Action:
    1. QC Supervisor opens package, re-verifies item by item
    2. If resolved: update QC record, proceed
    3. If weight still wrong: defer to supervisor decision
       (usually: proceed with note if fragile item packing explains weight delta)
```

---

## Carrier Pre-Handover Check

Regardless of QC type, always before handing to carrier:

```
Staff / system:
    ✓ Shipping label barcode scans successfully (scan test)
    ✓ Package weight entered in carrier manifest matches actual
    ✓ Package dimensions recorded (if courier calculates volumetric weight)
    ✓ COD amount (if COD order) written on package clearly
```

---

## QC Metrics

| Metric | Target | Alert Threshold |
|---|---|---|
| Order accuracy rate | > 99.5% | < 98% |
| Damaged item catch rate | > 99% | < 97% |
| QC throughput | 50+ orders/hour | < 30 orders/hour |
| Weight discrepancy rate | < 0.5% | > 2% |
| Photo documentation compliance | 100% for mandatory QC | < 95% |

**Daily report**: Fulfillment Service → QC summary event → Analytics Service
- Count: QC passed, failed (by reason), total orders QC'd
- Alert: if failure rate > 2% within any 4-hour window

---

## Changelog

### Version 2.0 (2026-02-21)
- Rewritten for practical e-commerce warehouse operations
- Replaced manufacturing/ISO framework with scan-to-verify, weight check, photo docs
- Added carrier pre-handover checklist
- Added damage disposition flow with refund trigger

### Version 1.0 (2026-01-31)
- Initial quality control workflow documentation

## References

- [Order Fulfillment Workflow](./order-fulfillment.md)
- [Seller & Merchant Flow — Order Management](./seller-merchant.md)
- [Returns-Exchanges — Item Inspection](../customer-journey/returns-exchanges.md)