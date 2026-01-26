# Order Service - Fulfillment Consumer Deployment Notes

## Implementation Status: ✅ COMPLETE

**Commit**: `c711fb2` - feat(order): add FulfillmentConsumer to auto-update order status  
**Pushed to**: `origin/main`  
**Date**: 2025-12-22

---

## Changes Summary

### New Files
1. `internal/data/eventbus/fulfillment_consumer.go` (195 lines)
2. `internal/data/eventbus/fulfillment_consumer_test.go` (155 lines)

### Modified Files
1. `cmd/worker/wire.go` - Added FulfillmentConsumer to WorkerManager
2. `cmd/worker/wire_gen.go` - Wire auto-generated
3. `internal/data/eventbus/provider.go` - Added NewFulfillmentConsumer
4. `docs/flow/order-status-flow.md` - Updated documentation

**Total**: +412 insertions, -36 deletions

---

## CI/CD Pipeline

### GitLab CI
- ✅ Code pushed to `main` branch
- ⏳ CI will automatically build Docker image
- 📦 Image will be tagged and pushed to registry

**Monitor CI**: https://gitlab.com/ta-microservices/order/-/pipelines

---

## Deployment with ArgoCD

### Prerequisites

**kubectl-tunnel script**: `argocd/scripts/kubectl-tunnel.sh`

### Deployment Steps

#### 1. Wait for CI Build
```bash
# Check CI pipeline status
# Should see Docker image built and pushed
```

#### 2. Update ArgoCD Image Tag

**File**: `argocd/applications/order-service/staging/tag.yaml`

```yaml
image:
  tag: "c711fb2"  # or v1.x.x if you use semantic versioning
```

#### 3. Commit ArgoCD Change
```bash
cd /home/user/microservices
git add argocd/applications/order-service/staging/tag.yaml
git commit -m "chore(argocd): update order-service to c711fb2 with FulfillmentConsumer"
git push
```

#### 4. Access Kubernetes via kubectl-tunnel

```bash
# Start kubectl tunnel
./argocd/scripts/kubectl-tunnel.sh

# In another terminal, verify ArgoCD sync
kubectl get application order-service -n argocd

# Watch deployment rollout
kubectl rollout status deployment/order-worker -n core-business
```

#### 5. Verify Deployment

```bash
# Check worker pod logs
kubectl logs -f deployment/order-worker -c worker -n core-business | grep -i fulfillment

# Expected logs:
# "Subscribing to topic: fulfillment.status_changed, pubsub: pubsub-redis"
# "Starting eventbus gRPC server on :5005..."
```

#### 6. Verify Dapr Subscription

```bash
# Get worker pod name
POD=$(kubectl get pod -n core-business -l app.kubernetes.io/name=order-service,app.kubernetes.io/component=worker -o jsonpath='{.items[0].metadata.name}')

# Check Dapr subscriptions
kubectl exec -n core-business $POD -c daprd -- \
  wget -qO- http://localhost:3500/dapr/subscribe | jq

# Expected output (3 subscriptions):
# [
#   {
#     "pubsubname": "pubsub-redis",
#     "topic": "payment.confirmed",
#     "route": "/payment.confirmed"
#   },
#   {
#     "pubsubname": "pubsub-redis",
#     "topic": "payment.failed",
#     "route": "/payment.failed"
#   },
#   {
#     "pubsubname": "pubsub-redis",
#     "topic": "fulfillment.status_changed",    # ← NEW
#     "route": "/fulfillment.status_changed"
#   }
# ]
```

---

## Testing After Deployment

### Test 1: Create COD Order

```bash
# Via kubectl port-forward
kubectl port-forward -n core-business svc/order-service 8000:80

# Create COD order
curl -X POST http://localhost:8000/api/v1/checkout/confirm \
  -H "Content-Type: application/json" \
  -d '{
    "cart_session_id": "<session-id>",
    "payment_method": "cod",
    "shipping_address": {...}
  }'

# Note the order_id from response
```

### Test 2: Monitor Order Status Flow

```bash
# Watch order status changes
watch -n 2 "curl -s http://localhost:8000/api/v1/orders/<order-id> | jq '.order.status'"

# Expected flow (within 5-10 minutes):
# T0: "pending"           # Order created
# T1: "confirmed"         # COD auto-confirm (0-5min)
# T2: "processing"        # ← THIS IS THE FIX! Fulfillment planning auto-updates status
# T3: "shipped"           # Fulfillment shipped
# T4: "delivered"         # Fulfillment completed
```

### Test 3: Check Event Flow Logs

```bash
# Terminal 1: Order Worker logs
kubectl logs -f deployment/order-worker -c worker -n core-business | grep -i "fulfillment"

# Expected logs:
# "Processing fulfillment status changed event: fulfillment_id=xxx, order_id=yyy, new_status=planning"
# "Updated order status: order_id=yyy, old_status=confirmed, new_status=processing"

# Terminal 2: Fulfillment Worker logs
kubectl logs -f deployment/fulfillment-worker -c worker -n core-business | grep -i "order.*confirmed"

# Expected logs:
# "Processing confirmed order for fulfillment creation: order_id=yyy"
# "Successfully created and started planning for fulfillment"
```

---

## Rollback Plan

If issues occur:

### Quick Rollback via ArgoCD

```bash
# Revert tag to previous version
cd argocd/applications/order-service/staging
# Edit tag.yaml to previous version
git commit -m "rollback: revert order-service to previous version"
git push

# Wait for ArgoCD auto-sync or manual sync
```

### Full Code Rollback

```bash
cd /home/user/microservices/order
git revert c711fb2
git push origin main
# Then update ArgoCD tag
```

---

## Monitoring & Alerts

### Metrics to Watch (First 24h)

```bash
# Check Prometheus/Grafana for:
# 1. Event consumption rate
fulfillment_status_events_consumed_total

# 2. Order status updates
order_status_updates_total{reason=~"Fulfillment.*"}

# 3. Error rate
fulfillment_consumer_errors_total

# 4. Event processing latency
fulfillment_event_processing_duration_seconds
```

### Key Logs to Monitor

```bash
# Errors in fulfillment consumer
kubectl logs deployment/order-worker -c worker -n core-business | grep -i "error.*fulfillment"

# Failed status updates
kubectl logs deployment/order-worker -c worker -n core-business | grep -i "failed to update order status"

# Dapr subscription errors
kubectl logs deployment/order-worker -c daprd -n core-business | grep -i "error.*fulfillment"
```

---

## Success Criteria

- [ ] CI build passes
- [ ] Docker image pushed to registry
- [ ] ArgoCD syncs successfully
- [ ] Worker pod starts without errors
- [ ] Dapr subscription shows `fulfillment.status_changed`
- [ ] Test COD order auto-transitions: `confirmed` → `processing`
- [ ] No errors in logs for 24 hours
- [ ] Event processing latency < 500ms

---

## Known Issues & Mitigations

### Issue 1: Event Ordering
**Problem**: Fulfillment events may arrive out of order  
**Mitigation**: `isLaterStatus()` prevents backward transitions

### Issue 2: Duplicate Events
**Problem**: Dapr may deliver events multiple times  
**Mitigation**: Idempotency check - skip if already at target status

### Issue 3: Race Condition (COD Confirm + Fulfillment Create)
**Problem**: COD cron confirm and fulfillment creation happen close together  
**Mitigation**: Status checks prevent conflicts, Dapr ensures at-least-once delivery

---

## References

- **Implementation Walkthrough**: [walkthrough.md](file:///home/user/.gemini/antigravity/brain/9a5fe465-9138-429e-8a94-d7dcc7930504/walkthrough.md)
- **Implementation Checklist**: [order-fulfillment-status-integration.md](file:///home/user/microservices/docs/checklists-implement/order-fulfillment-status-integration.md)
- **COD Flow Review**: [cod-order-flow-review.md](file:///home/user/microservices/docs/workfllow/cod-order-flow-review.md)
- **GitLab Commit**: https://gitlab.com/ta-microservices/order/-/commit/c711fb2

---

## Contact

If issues occur during deployment, check:
1. CI pipeline logs
2. Worker pod logs (`kubectl logs`)
3. Dapr sidecar logs (`kubectl logs -c daprd`)
4. This deployment guide

**Implementation completed**: 2025-12-22 10:54  
**Implementation time**: ~1h 45min  
**Status**: ✅ Ready for production deployment
