# Cart API Fix - Implementation Checklist

**Date**: 2026-02-01  
**Issue**: Frontend Cart API returning 404  
**Status**: ✅ Implementation Complete, ⏳ Deployment Pending

---

## 📋 Implementation Checklist

### ✅ Phase 1: Code Analysis & Root Cause
- [x] Index frontend codebase (cart-api.ts, cart-context.tsx, api-client.ts)
- [x] Index gateway routing configuration
- [x] Index checkout service proto definitions
- [x] Identify Cart API is part of Checkout Service (not separate service)
- [x] Confirm gateway routes `/api/v1/cart` → checkout service
- [x] Identify missing error handling for 404 responses

**Findings**:
- Cart API correctly exposed at `/api/v1/cart` by Checkout Service
- Gateway config correct: `/api/v1/cart` → checkout
- Frontend calling correct endpoint
- Missing proper 404 handling (404 = cart doesn't exist, not error)
- Missing debug logging

---

### ✅ Phase 2: Frontend Code Fixes

#### File: `frontend/src/lib/api/cart-api.ts`
- [x] Add comprehensive console logging
- [x] Fix proto field name: `product_id` (was `product_sku`)
- [x] Add JSDoc comments explaining backend endpoints
- [x] Add full URL logging for debugging

#### File: `frontend/src/lib/contexts/cart-context.tsx`
- [x] Enhanced error handling for 404 (cart doesn't exist)
- [x] Add detailed logging for debugging
- [x] Differentiate error types (404, 401, 500)
- [x] Don't treat 404 as error state

#### File: `frontend/src/lib/api/api-client.ts`
- [x] Add debug logging for cart requests
- [x] Log session/guest tokens in headers
- [x] Log full request details

---

### ✅ Phase 3: Testing & Verification

#### Test Script
- [x] Create `test-cart-api.sh` script
- [x] Add test cases:
  - [x] Test 1: GET /api/v1/cart (new session)
  - [x] Test 2: POST /api/v1/cart/items (add item)
  - [x] Test 3: GET /api/v1/cart (verify item added)
  - [x] Test 4: Test with frontend session IDs
- [x] Add colored output for pass/fail
- [x] Add troubleshooting tips

#### Documentation
- [x] Create `CART_API_404_FIX_SUMMARY.md`
- [x] Document architecture (Cart as subdomain of Checkout)
- [x] Document request flow (Frontend → Gateway → Checkout)
- [x] Add deployment steps
- [x] Add monitoring & debugging guide
- [x] Add common issues & solutions

---

## ⏳ Phase 4: Deployment (PENDING)

### Pre-Deployment Checklist
- [ ] Run test script locally: `./test-cart-api.sh`
- [ ] Verify console logs in browser DevTools
- [ ] Check gateway config is deployed: `kubectl get configmap gateway-config -n default -o yaml`
- [ ] Check checkout service is running: `kubectl get pods -n default | grep checkout`
- [ ] Verify service endpoints: `kubectl get endpoints checkout -n default`

### Frontend Build & Deploy
- [ ] Navigate to frontend directory: `cd frontend`
- [ ] Install dependencies: `npm install`
- [ ] Run build: `npm run build`
- [ ] Verify build success (no errors)
- [ ] Build Docker image: `docker build -t frontend:latest .`
- [ ] Push to registry: `docker push registry.tanhdev.com/frontend:latest`
- [ ] ArgoCD sync or manual deploy: `kubectl rollout restart deployment/frontend -n default`
- [ ] Wait for rollout: `kubectl rollout status deployment/frontend -n default`

### Post-Deployment Verification
- [ ] Check pod status: `kubectl get pods -n default | grep frontend`
- [ ] Check frontend logs: `kubectl logs -n default deployment/frontend --tail=50`
- [ ] Test cart API via curl: `curl https://api.tanhdev.com/api/v1/cart`
- [ ] Test in browser (open DevTools console)
- [ ] Verify console logs appear
- [ ] Test add to cart flow
- [ ] Check gateway logs: `kubectl logs -n default deployment/gateway --tail=50 | grep cart`
- [ ] Check checkout logs: `kubectl logs -n default deployment/checkout --tail=50 | grep cart`

### Smoke Tests
- [ ] Open frontend: https://frontend.tanhdev.com
- [ ] Open DevTools console
- [ ] Navigate to product page
- [ ] Click "Add to Cart"
- [ ] Check console logs:
  - [ ] `[cartApi.addItem] Request:`
  - [ ] `[cartApi.addItem] Response:`
  - [ ] `[CartContext] Cart fetched successfully`
- [ ] Verify cart icon updates with item count
- [ ] Click cart icon to open mini cart
- [ ] Verify item appears in cart
- [ ] Test quantity update
- [ ] Test item removal

---

## 🐛 Rollback Plan (if issues occur)

### Quick Rollback
```bash
# Rollback frontend deployment
kubectl rollout undo deployment/frontend -n default

# Verify rollback
kubectl rollout status deployment/frontend -n default

# Check pods
kubectl get pods -n default | grep frontend
```

### Debug Issues
```bash
# Check frontend logs
kubectl logs -n default deployment/frontend --tail=100 -f

# Check gateway logs
kubectl logs -n default deployment/gateway --tail=100 -f | grep cart

# Check checkout logs
kubectl logs -n default deployment/checkout --tail=100 -f | grep cart

# Test API directly
curl -v https://api.tanhdev.com/api/v1/cart \
  -H 'x-session-id: test' \
  -H 'x-guest-token: test'
```

---

## 📊 Success Metrics

### Technical Metrics
- [ ] Cart API 404 rate < 5% (404 is normal for new users)
- [ ] Cart API 500 error rate = 0%
- [ ] Cart API response time < 500ms (p95)
- [ ] Add to cart success rate > 95%

### User Experience Metrics
- [ ] Cart loads on page visit (or 404 if new)
- [ ] Add to cart updates cart state immediately
- [ ] Cart icon shows correct item count
- [ ] Mini cart displays items correctly
- [ ] No error messages shown to users for 404

### Monitoring
- [ ] Set up Prometheus alerts for cart API errors
- [ ] Monitor cart creation rate
- [ ] Monitor add-to-cart success rate
- [ ] Track cart abandonment rate

---

## 📝 Notes & Observations

### Key Learnings
1. **Cart is NOT a separate service** - it's part of Checkout Service
2. **404 is normal** for new users (cart created on first add)
3. **Headers are critical** - session_id and guest_token must be in headers
4. **Gateway routing works** - `/api/v1/cart` correctly routes to checkout

### Potential Improvements
1. Consider adding cart status endpoint for health checks
2. Add metrics for cart operations (create, add, update, remove)
3. Consider caching cart data in Redis for performance
4. Add rate limiting for cart operations to prevent abuse

### Follow-up Tasks
- [ ] Add Prometheus metrics for cart operations
- [ ] Add Grafana dashboard for cart monitoring
- [ ] Add integration tests for cart flow
- [ ] Add E2E tests for checkout flow
- [ ] Review cart expiration logic (current: 7 days)
- [ ] Consider implementing cart recovery feature

---

## 🔗 Related Documents

- [CART_API_404_FIX_SUMMARY.md](CART_API_404_FIX_SUMMARY.md) - Complete implementation summary
- [test-cart-api.sh](test-cart-api.sh) - Testing script
- [checkout/api/checkout/v1/cart.proto](checkout/api/checkout/v1/cart.proto) - Cart API proto
- [gateway/configs/gateway.yaml](gateway/configs/gateway.yaml) - Gateway routing config
- [frontend/src/lib/api/cart-api.ts](frontend/src/lib/api/cart-api.ts) - Frontend Cart API client
- [frontend/src/lib/contexts/cart-context.tsx](frontend/src/lib/contexts/cart-context.tsx) - Cart context provider

---

**Implementation By**: GitHub Copilot  
**Reviewed By**: _(pending)_  
**Deployed By**: _(pending)_  
**Deployment Date**: _(pending)_  

---

## ✅ Sign-off

- [ ] Code reviewed and approved
- [ ] Tests passing
- [ ] Documentation complete
- [ ] Deployment plan reviewed
- [ ] Rollback plan verified
- [ ] Monitoring configured
- [ ] Ready for production deployment

**Approved By**: ________________  
**Date**: ________________
