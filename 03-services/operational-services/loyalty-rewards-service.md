# Loyalty Rewards Service

## Overview

The **loyalty-rewards** service manages the points-based loyalty program for the e-commerce platform. It tracks customer point balances, tier progression, reward redemptions, referral bonuses, and promotional campaigns.

## Architecture

- **Framework**: Go 1.25+ / Kratos v2 (gRPC + HTTP gateway)
- **Database**: PostgreSQL (loyalty_db)
- **Cache**: Redis (tier/reward/account caching)
- **Event Bus**: Dapr PubSub (consumes order/customer events, publishes loyalty events via outbox)
- **DI**: Google Wire (server binary)

### Dual-Binary Architecture

| Binary | Entry Point | Purpose |
|--------|-------------|---------|
| `loyalty-rewards` (server) | `cmd/loyalty-rewards/main.go` | gRPC APIs, HTTP gateway |
| `loyalty-rewards-worker` | `cmd/worker/main.go` | Event consumer (order status, customer deletion), outbox processor |

### Domain Subdomains (7)

| Subdomain | Directory | Responsibility |
|-----------|-----------|----------------|
| **Account** | `internal/biz/account/` | Point balances, status management |
| **Transaction** | `internal/biz/transaction/` | Point earn/spend/expire |
| **Tier** | `internal/biz/tier/` | Tier levels, progression rules |
| **Reward** | `internal/biz/reward/` | Available rewards catalog |
| **Redemption** | `internal/biz/redemption/` | Point-to-reward exchanges |
| **Referral** | `internal/biz/referral/` | Referral codes, bonus points |
| **Campaign** | `internal/biz/campaign/` | Promotional campaigns |

## Ports

| Protocol | Port | Standard |
|----------|------|----------|
| HTTP | 8014 | PORT_ALLOCATION_STANDARD |
| gRPC | 9014 | PORT_ALLOCATION_STANDARD |
| Worker Health | 8081 | Common worker pattern |

## gRPC Services (8)

1. **LoyaltyService** — Aggregate dashboard, health check
2. **AccountService** — Account CRUD, balance queries
3. **TransactionService** — Point operations (earn, spend, expire)
4. **TierService** — Tier management, progression
5. **RewardService** — Reward catalog management
6. **RedemptionService** — Reward redemptions
7. **ReferralService** — Referral program management
8. **CampaignService** — Campaign CRUD

## Event Subscriptions (Dapr)

| Topic | Purpose |
|-------|---------|
| `orders.order.status_changed` | Award points on delivery, reverse on cancellation |
| `customer.deleted` | GDPR: deactivate loyalty account |

## Dependencies

- **Proto consumers**: `gateway` (v1.1.4)
- **Service clients**: `order`, `customer`, `notification` (gRPC)
- **Shared libraries**: `common` v1.17.0
