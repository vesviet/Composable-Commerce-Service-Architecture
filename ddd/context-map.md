# Domain-Driven Design - Context Map

**Last Updated:** 2025-11-17  
**Status:** Active

## Overview

This document maps all Bounded Contexts in the e-commerce platform and their relationships.

## Bounded Contexts

### 1. Order Context
**Service:** Order Service  
**Responsibility:** Order lifecycle, cart management, order processing  
**Database:** `order_db`  
**Key Entities:** Order, OrderItem, Cart, CartItem

**Relationships:**
- **Upstream:** Customer Context (customer data)
- **Upstream:** Product Context (product information)
- **Upstream:** Pricing Context (price calculation)
- **Downstream:** Payment Context (payment processing)
- **Downstream:** Shipping Context (fulfillment)

**Events Published:**
- `orders.order.status_changed`
- `orders.cart.item_added`
- `orders.cart.checked_out`

**Events Consumed:**
- `payment.processed`
- `payment.failed`
- `shipping.shipment.created`

---

### 2. Product Context
**Service:** Catalog Service  
**Responsibility:** Product catalog, categories, brands, CMS  
**Database:** `catalog_db`  
**Key Entities:** Product, Category, Brand, Manufacturer

**Relationships:**
- **Downstream:** Order Context (product info for orders)
- **Downstream:** Pricing Context (product pricing)
- **Downstream:** Warehouse Context (stock levels)

**Events Published:**
- `catalog.product.created`
- `catalog.product.updated`
- `catalog.product.deleted`

**Events Consumed:**
- `warehouse.stock.updated`
- `pricing.price.updated`

---

### 3. Inventory Context
**Service:** Warehouse Service  
**Responsibility:** Stock management, inventory, warehouses  
**Database:** `warehouse_db`  
**Key Entities:** Warehouse, Inventory, StockMovement, Reservation

**Relationships:**
- **Upstream:** Product Context (product reference)
- **Downstream:** Order Context (stock reservation)
- **Downstream:** Product Context (stock sync)

**Events Published:**
- `warehouse.stock.updated`
- `warehouse.stock.reserved`
- `warehouse.stock.released`
- `warehouse.inventory.low_stock`

**Events Consumed:**
- `orders.order.status_changed` (for stock reservation/release)

---

### 4. Pricing Context
**Service:** Pricing Service  
**Responsibility:** Price calculation, discounts, taxes  
**Database:** `pricing_db`  
**Key Entities:** Price, Discount, TaxRule, PriceRule

**Relationships:**
- **Upstream:** Product Context (product pricing)
- **Upstream:** Warehouse Context (warehouse-specific pricing)
- **Downstream:** Order Context (price calculation)

**Events Published:**
- `pricing.price.updated`
- `pricing.price.bulk_updated`
- `pricing.warehouse_price.updated`
- `pricing.sku_price.updated`

**Events Consumed:**
- `catalog.product.created` (for initial pricing)
- `warehouse.stock.updated` (for dynamic pricing)

---

### 5. Customer Context
**Service:** Customer Service  
**Responsibility:** Customer profiles, addresses, segmentation  
**Database:** `customer_db`  
**Key Entities:** Customer, Address, CustomerSegment

**Relationships:**
- **Upstream:** Auth Context (authentication)
- **Downstream:** Order Context (customer info for orders)

**Events Published:**
- `customer.created`
- `customer.updated`
- `customer.address.added`

**Events Consumed:**
- `orders.order.completed` (for customer analytics)

---

### 6. Payment Context
**Service:** Payment Service  
**Responsibility:** Payment processing, transactions, refunds  
**Database:** `payment_db`  
**Key Entities:** Payment, Transaction, Refund

**Relationships:**
- **Upstream:** Order Context (order payment)
- **Downstream:** Order Context (payment confirmation)

**Events Published:**
- `payment.processed`
- `payment.failed`
- `payment.refunded`

**Events Consumed:**
- `orders.order.created` (for payment initiation)

---

### 7. Shipping Context
**Service:** Shipping Service  
**Responsibility:** Fulfillment, carriers, tracking  
**Database:** `shipping_db`  
**Key Entities:** Shipment, Carrier, TrackingEvent

**Relationships:**
- **Upstream:** Order Context (order fulfillment)
- **Upstream:** Warehouse Context (pickup location)

**Events Published:**
- `shipping.shipment.created`
- `shipping.delivery.confirmed`

**Events Consumed:**
- `orders.order.confirmed` (for fulfillment)

---

### 8. User Context
**Service:** User Service  
**Responsibility:** Internal users, roles, permissions  
**Database:** `user_db`  
**Key Entities:** User, Role, Permission

**Relationships:**
- **Upstream:** Auth Context (authentication)
- **Downstream:** All services (authorization)

**Events Published:**
- `user.created`
- `user.role.assigned`

---

### 9. Auth Context
**Service:** Auth Service  
**Responsibility:** Authentication, JWT, sessions  
**Database:** `auth_db`  
**Key Entities:** Session, Token

**Relationships:**
- **Downstream:** All services (token validation)

**Events Published:**
- `auth.user.logged_in`
- `auth.user.logged_out`

---

## Context Relationships Diagram

```
┌─────────────┐
│   Auth      │
│  Context    │
└──────┬──────┘
       │
       ▼
┌─────────────┐     ┌─────────────┐
│   User      │     │  Customer   │
│  Context    │     │  Context    │
└──────┬──────┘     └──────┬──────┘
       │                   │
       └──────────┬────────┘
                  ▼
          ┌─────────────┐
          │   Order     │
          │  Context    │
          └──────┬──────┘
                 │
        ┌────────┼────────┐
        ▼        ▼        ▼
  ┌─────────┐ ┌──────┐ ┌────────┐
  │ Product │ │Price │ │Payment │
  │ Context │ │Context│ │Context │
  └────┬────┘ └──────┘ └────┬───┘
       │                    │
       ▼                    ▼
  ┌─────────┐         ┌─────────┐
  │Inventory│         │ Shipping│
  │ Context │         │ Context │
  └─────────┘         └─────────┘
```

## Integration Patterns

### Shared Kernel
- **Common Package**: Shared types, errors, utilities
- **Location:** `/common/`

### Published Language
- **Events**: All events use CloudEvents format
- **APIs**: REST + gRPC with OpenAPI specs

### Customer-Supplier
- **Order → Payment**: Order is customer, Payment is supplier
- **Order → Shipping**: Order is customer, Shipping is supplier

### Conformist
- **External Payment Gateways**: Must conform to their APIs
- **Shipping Carriers**: Must conform to carrier APIs

## Anti-Corruption Layer

- **Payment Gateways**: Payment Service acts as ACL
- **Shipping Carriers**: Shipping Service acts as ACL
- **External APIs**: All external integrations go through dedicated services

## References

- See individual domain docs: `product-domain.md`, `order-domain.md`, etc.
- [Domain-Driven Design](https://martinfowler.com/bliki/DomainDrivenDesign.html)
- [Context Mapping](https://www.domainlanguage.com/ddd/context-mapping/)

