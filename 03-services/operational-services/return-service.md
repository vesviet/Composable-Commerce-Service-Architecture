# Return Service

**Version**: 1.0
**Last Updated**: 2026-02-13
**Service Type**: Operational
**Status**: Active

## Overview

The Return Service manages product returns, refunds, and exchanges. It handles the lifecycle of a return request from creation to approval, receipt of items, and final refund or exchange.

## Architecture

### Responsibilities
- Create and manage return requests.
- Validate return eligibility (time window, policy).
- Process approvals and rejections.
- Track received items and their condition.
- Trigger refunds or exchanges.

### Dependencies
- **Upstream services**: Gateway (BFF).
- **Downstream services**:
    - `order`: To validate order details and items.
    - `shipping`: To generate return labels.
    - `payment`: To process refunds.
- **External dependencies**: PostgreSQL (Data), Kafka/RabbitMQ (Events via Dapr).

## API Contract

### gRPC Services
- **Service**: `return.v1.ReturnService`
- **Proto location**: `return/api/return/v1/return.proto`
- **Key methods**:
    - `CreateReturnRequest`: Submit a new return.
    - `GetReturnRequest`: Retrieve return details.
    - `ListReturnRequests`: List returns for a customer.
    - `ApproveReturn`: Admin approval.
    - `ReceiveItems`: Mark items as received at warehouse.

## Data Model

### Key Entities
- **ReturnRequest**: The aggregate root.
- **ReturnItem**: Individual items being returned.

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `DB_SOURCE` | Yes | - | PostgreSQL connection string |
| `DAPR_GRPC_PORT` | Yes | - | Dapr sidecar port |

## Review Findings (2026-02-13)

**Status**: ⚠️ Needs Work

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | - |
| P1 (High) | 1 | Remaining |
| P2 (Normal) | 2 | Remaining |

### 🟡 P1 Issues (High)
1. **[Architecture]** `internal/biz/return/return.go`: Transaction management missing for multi-step operations (e.g. CreateReturnRequest).

### 🔵 P2 Issues (Normal)
1. **[Docs]** Service documentation was missing (created this file).
2. **[Observability]** Metrics for return processing time/rates should be added.

### ✅ Completed Actions
1. Created this service documentation.
2. Verified architecture alignment with Kratos standards.
3. Verified strict layer separation (Service -> Biz -> Data).

### 🌐 Cross-Service Impact
- **Proto**: No external Go services import `gitlab.com/ta-microservices/return` directly in `go.mod`.
- **Events**: `ReturnRequestedEvent`, `ReturnApprovedEvent` defined but consumers need verification.

### 🚀 Deployment Readiness
- **Config/GitOps**: Checked ports (need to verify against `PORT_ALLOCATION_STANDARD.md`).
- **Health Probes**: To be verified.
