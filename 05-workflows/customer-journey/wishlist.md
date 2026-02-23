# Wishlist Flow

**Purpose**: Customer wishlist management, back-in-stock and price-drop notification flows  
**Services**: Gateway, Customer, Catalog, Pricing, Search, Notification, Analytics  
**Pattern Reference**: Shopee, Lazada, Amazon

---

## Overview

The wishlist serves as a purchase-intent funnel. Items saved to a wishlist generate triggered notifications (back-in-stock, price drop) that drive high-conversion re-engagement.

---

## 1. Add to Wishlist

**Trigger**: Customer clicks "Save" / heart icon on PDP or search results.

```
Customer → Gateway → Catalog (check product active)
                  → Customer Service (save wishlist item)
                  → Notification (optional: "item saved" confirmation)
                  → Analytics (wishlist.item_added event)
```

**Business rules**:
- Maximum 200 items per wishlist per customer
- Guest users: wishlist stored in session/cookie, merged on login
- Duplicate add: idempotent — no error, no duplicate entry
- Inactive/delisted product: allow save, flag as unavailable in wishlist view

---

## 2. View Wishlist

**Trigger**: Customer navigates to wishlist page.

```
Customer → Gateway → Customer Service (fetch wishlist items)
                  → Catalog Service (batch fetch product details, current price)
                  → Warehouse Service (batch fetch stock availability per SKU)
```

**Display rules**:
- Show current price alongside saved price (highlight if price dropped)
- Show "Low Stock" badge if available qty < threshold (e.g., < 5 units)
- Show "Sold Out" badge, keep item in list (do not auto-remove)
- Show "No Longer Available" if product delisted

---

## 3. Wishlist → Cart Conversion

**Trigger**: Customer clicks "Add to Cart" from wishlist.

```
Customer → Gateway → Checkout Service (add item to cart)
                  → Customer Service (optionally keep in wishlist or remove on cart add)
                  → Analytics (wishlist.converted_to_cart event)
```

**Business rules**:
- Item stays in wishlist after add-to-cart (Shopee pattern) — customer can remove manually
- If stock unavailable: block add-to-cart, show "Notify Me" prompt

---

## 4. Back-in-Stock Notification

**Trigger**: `stock.restocked` event published by Warehouse Service.

```
Warehouse Service → [stock.restocked event]
    → Notification Worker:
        1. Query Customer Service: find all customers with this SKU in wishlist
        2. Batch send push + email: "Great news! [Product] is back in stock"
        3. Update wishlist item: mark as "in-stock notified"
    → Analytics (notification.backinstock_sent event)
```

**Business rules**:
- Max 1 back-in-stock notification per customer per SKU per 72 hours
- Only notify if customer opted in (check notification preferences)
- Deep link in notification → PDP with "add to cart" CTA
- If multiple restocks in 24h, batch into single notification

---

## 5. Price-Drop Notification

**Trigger**: `price.updated` event published by Pricing Service when price decreases.

```
Pricing Service → [price.updated event, old_price, new_price, discount_pct]
    → Notification Worker:
        1. If discount_pct >= threshold (e.g., >= 5%):
           Query Customer Service: find customers with this SKU wishlisted
        2. Batch send push + email: "[Product] dropped from $X to $Y"
        3. Update wishlist item: log last notified price
    → Analytics (notification.pricedrop_sent event)
```

**Business rules**:
- Notification threshold: ≥ 5% price drop (configurable per category)
- Last notified price tracked: do not re-notify unless price drops further from last notification price
- Respect customer quiet hours and frequency cap (max 3 marketing push/day)
- Flash sale prices: notify immediately, note "Flash sale ends in Xh"

---

## 6. Wishlist Sharing

**Trigger**: Customer clicks "Share Wishlist".

```
Customer → Gateway → Customer Service (generate shareable token)
                  → Returns: public URL with token
```

**Business rules**:
- Public wishlist link valid for 30 days (configurable)
- Recipients can view and add items to their own cart but cannot edit the wishlist
- Privacy toggle: public / private (default: private)

---

## 7. Remove from Wishlist

**Trigger**: Customer manually removes item, or item purchased.

```
POST-ORDER event (order.completed):
    → Customer Service: auto-remove ordered SKUs from wishlist
    → Analytics (wishlist.item_purchased event)

Manual remove:
    → Customer → Gateway → Customer Service (delete wishlist item)
```

---

## State Machine

```
                  [Saved]
                     │
        ┌────────────┼────────────────────┐
        │            │                    │
   [In Stock]   [Out of Stock]      [Price Dropped]
        │            │                    │
   Add to Cart   Back-in-Stock Notif  Price Drop Notif
        │            │                    │
   [Converted]  [In Stock Again]     [Add to Cart]
                     │
              [Back-in-Stock Notif]
```

---

## Events Published

| Event | Topic | Published By | When |
|---|---|---|---|
| `wishlist.item_added` | customer.events | Customer Service | Item saved to wishlist |
| `wishlist.item_removed` | customer.events | Customer Service | Item removed |
| `wishlist.converted_to_cart` | customer.events | Customer Service | Item added to cart from wishlist |
| `wishlist.item_purchased` | customer.events | Order Service | Wishlisted SKU included in completed order |

---

## Events Consumed

| Event | Source Topic | Action |
|---|---|---|
| `stock.restocked` | warehouse.events | Trigger back-in-stock notifications |
| `price.updated` | pricing.events | Trigger price-drop notifications if threshold met |
| `product.delisted` | catalog.events | Mark wishlist item as unavailable |
| `order.completed` | order.events | Auto-remove purchased SKUs from wishlist |

---

## Analytics Funnel

```
Wishlist adds → Notifications sent → Notification CTR → Add to cart → Purchase
     ↑                                                                   │
     └───────────────── Cost of keeping item in wishlist ────────────────┘
```

**Key KPIs**:
- Wishlist → cart conversion rate: target > 20%
- Back-in-stock notification CTR: target > 15%
- Price-drop notification CTR: target > 12%

---

**Last Updated**: 2026-02-21  
**Owner**: Customer Experience Team
