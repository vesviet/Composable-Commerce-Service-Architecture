# Core Business Services

**Last Updated**: 2026-03-02  
**Architecture**: Clean Architecture + DDD  
**Total Services**: 14 Core Business Services

---

## 📋 Service Index

### 🛒 Commerce Services

| # | Service | Documentation | Port (HTTP/gRPC) | Database | Purpose |
|---|---------|---------------|-------------------|----------|---------|
| 1 | **Checkout** | [checkout-service.md](./checkout-service.md) | 8005/9005 | `checkout_db` | Cart management, checkout orchestration |
| 2 | **Order** | [order-service.md](./order-service.md) | 8004/9004 | `order_db` | Order lifecycle management |
| 3 | **Return** | [return-service.md](./return-service.md) | 8006/9006 | `return_db` | Returns, exchanges, refunds |
| 4 | **Payment** | [payment-service.md](./payment-service.md) | 8007/9007 | `payment_db` | Payment processing (VNPay, MoMo, Stripe) |

### 📦 Product & Supply Chain Services

| # | Service | Documentation | Port (HTTP/gRPC) | Database | Purpose |
|---|---------|---------------|-------------------|----------|---------|
| 5 | **Catalog** | [catalog-service.md](./catalog-service.md) | 8002/9002 | `catalog_db` | Products, categories, EAV attributes |
| 6 | **Pricing** | [pricing-service.md](./pricing-service.md) | 8011/9011 | `pricing_db` | Dynamic pricing, tax calculation |
| 7 | **Promotion** | [promotion-service.md](./promotion-service.md) | 8013/9013 | `promotion_db` | Campaigns, coupons, discounts |
| 8 | **Warehouse** | [warehouse-service.md](./warehouse-service.md) | 8008/9008 | `warehouse_db` | Inventory, stock reservations |
| 9 | **Fulfillment** | [fulfillment-service.md](./fulfillment-service.md) | 8009/9009 | `fulfillment_db` | Pick/pack/ship, order processing |
| 10 | **Shipping** | [shipping-service.md](./shipping-service.md) | 8010/9010 | `shipping_db` | Carrier integration (GHN, Grab) |

### 👤 Identity & Customer Services

| # | Service | Documentation | Port (HTTP/gRPC) | Database | Purpose |
|---|---------|---------------|-------------------|----------|---------|
| 11 | **Auth** | [auth-service.md](./auth-service.md) | 8001/9001 | `auth_db` | JWT, OAuth2, MFA, RBAC |
| 12 | **User** | [user-service.md](./user-service.md) | 8003/9003 | `user_db` | Admin user management |
| 13 | **Customer** | [customer-service.md](./customer-service.md) | 8014/9014 | `customer_db` | Customer profiles, addresses, segments |
| 14 | **Loyalty** | [loyalty-rewards-service.md](./loyalty-rewards-service.md) | 8017/9017 | `loyalty_db` | Points, tiers, rewards |

---

## 🔄 Key Interaction Flows

### Shopping Flow
```
Customer → Checkout (cart) → Checkout (session) → Order → Fulfillment → Shipping
```

### Payment Flow
```
Checkout → Payment → Order (confirmed) → Notification
```

### Return Flow
```
Customer → Return → Payment (refund) + Warehouse (restock) → Notification
```

### Authentication Flow
```
Client → Gateway → Auth → User/Customer → Business Services
```

---

## 🔗 Related Documentation

- **[Platform Services](../platform-services/)** — Gateway, Search, Analytics, etc.
- **[System Overview](../../01-architecture/system-overview.md)** — Architecture overview
- **[API Architecture](../../01-architecture/api-architecture.md)** — Proto/gRPC standards

---

**Communication**: gRPC (sync) + Dapr PubSub (async)  
**Data**: PostgreSQL per service + Redis caching  
**Patterns**: Transactional Outbox, Saga, Circuit Breaker