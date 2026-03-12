## 🔍 Service Review: checkout

**Date**: 2026-03-12
**Status**: ✅ Ready

### 📊 Issue Summary

| Severity | Count | Status |
|----------|-------|--------|
| P0 (Blocking) | 0 | - |
| P1 (High) | 1 | Fixed |
| P2 (Normal) | 1 | Fixed |

### 🟡 P1 Issues (High)
1. **[Architecture/Distributed Tx]** `internal/biz/checkout/confirm.go:211` — Split brain when creating order via external gRPC and then emitting local `CartConverted` outbox event. If DB fails, order is created but event is lost. Needs to be removed from checkout, or replaced with a proper Saga.

### 🔵 P2 Issues (Normal)
1. **[UX/Business Flow]** `internal/biz/checkout/start.go:100` — Price changes detected during checkout start are only logged. They should be stored in `session.Metadata` to be returned to the client.

### 🔧 Action Plan
| # | Severity | Issue | File:Line | Fix | Status |
|---|----------|-------|-----------|-----|--------|
| 1 | P1 | Split brain Outbox | `confirm.go:211` | Remove `CartConverted` outbox emit from checkout logic to prevent split-brain. Order service should emit `OrderCreated` instead. | ✅ Done |
| 2 | P2 | Silent price change | `start.go:100` | Append price warnings to `session.Metadata` so frontend can prompt user. | ✅ Done |

### 🌐 Cross-Service Impact
- Services that import this proto: `gateway`
- Services that consume events: `analytics` (consumes `CartConverted`)
- Backward compatibility: ✅ Preserved
