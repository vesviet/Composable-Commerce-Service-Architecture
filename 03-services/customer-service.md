# Customer Service Documentation

## Service Overview
**Service Name**: `customer`
**Domain**: Customer Management
**Maintainers**: Backend Team
**Status**: Production

The Customer Service is responsible for managing the lifecycle of customers, their personal information, security credentials, addresses, and segmentation.

## Architecture

### Layered Structure (Clean Architecture)
- **Transport Layer** (`internal/server`): Handles HTTP/gRPC requests and Dapr events.
- **Service Layer** (`internal/service`): DTO mapping and validation.
- **Business Layer** (`internal/biz`): Core domain logic (Auth, Profile, Segmentation).
- **Data Layer** (`internal/data`): Persistence (PostgreSQL, Redis) and external clients.

### Dependencies
| Dependency | Purpose |
|Prefix|Description|
| `auth` | Token generation and session management |
| `order` | Order history for segmentation |
| `notification` | Sending transactional emails/SMS |
| `payment` | Stored payment methods (references) |

## Data Model

### Core Tables
- `customers`: Primary profile data.
- `addresses`: 1:N relationship with customers.
- `customer_preferences`: Settings.
- `segments`: Dynamic rules for grouping customers.
- `outbox_events`: Reliable event publishing.

## Events

### Published Events
- `customer.created`: When a new customer registers.
- `customer.updated`: When profile is modified.
- `customer.address.updated`: Address changes.

### Subscribed Events
- `order.completed`: Updates customer stats (total spent, order count).
- `auth.login`: Updates last login timestamp.

## Key Workflows

### 1. Registration
Ref: `internal/biz/customer/auth.go`
- Validates input.
- Hashes password.
- Creates customer + profile + preference transactionally.
- Uses Outbox to publish `customer.created`.
- Triggers welcome email via `notification` service.

### 2. Segmentation
Ref: `internal/biz/segment/rules_engine.go`
- Evaluates rules on customer data + order stats.
- Assigns customers to segments (e.g., "VIP", "New").
- Runs via cron worker.

## Troubleshooting

### Common Issues
- **Login fails**: Check `auth` service connectivity.
- **Verification email not received**: Check `notification` service logs and Outbox status.

### Health Checks
- Live: `/health/live`
- Ready: `/health/ready`
