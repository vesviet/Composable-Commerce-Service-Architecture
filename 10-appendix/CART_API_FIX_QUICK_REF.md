# Cart API Fix - Quick Reference Card

## 🎯 Problem
Frontend calling `GET /api/v1/cart` returns 404

## ✅ Solution
- Fixed error handling (404 is normal for new users)
- Added debug logging
- Fixed proto field names
- Created test scripts

## 📦 Files Changed

```
frontend/src/lib/api/cart-api.ts         - Cart API client with logging
frontend/src/lib/contexts/cart-context.tsx - Enhanced error handling
frontend/src/lib/api/api-client.ts        - Added debug logging
test-cart-api.sh                         - Test script
CART_API_404_FIX_SUMMARY.md              - Full documentation
CART_API_FIX_CHECKLIST.md                - Implementation checklist
```

## 🧪 Quick Test

```bash
# Test locally
./test-cart-api.sh

# Test with production gateway
GATEWAY_URL=https://api.tanhdev.com ./test-cart-api.sh
```

## 🚀 Deploy

```bash
cd frontend
npm run build
docker build -t frontend:latest .
kubectl rollout restart deployment/frontend -n default
```

## 🔍 Debug

```bash
# Frontend logs (browser console)
# Look for: [cartApi.getCart], [CartContext], [ApiClient]

# Gateway logs
kubectl logs -n default deployment/gateway --tail=100 -f | grep cart

# Checkout logs
kubectl logs -n default deployment/checkout --tail=100 -f | grep cart
```

## 📐 Architecture

```
Frontend → Gateway → Checkout Service
                        ├── CartService (gRPC/HTTP)
                        │   └── /api/v1/cart
                        │   └── /api/v1/cart/items
                        └── CheckoutService (gRPC/HTTP)
                            └── /api/v1/checkout
```

## ✨ Key Points

1. **Cart is NOT a separate service** - it's part of Checkout Service
2. **404 is normal** for new users (cart created on first add)
3. **Headers matter**: `X-Session-ID`, `X-Guest-Token`, `X-User-ID`
4. **Don't treat 404 as error** - it's expected behavior

## 🎯 Expected Behavior

| Scenario | Request | Response | Frontend Action |
|----------|---------|----------|-----------------|
| New user | `GET /cart` | `404` | Set cart=null, no error |
| Add item | `POST /cart/items` | `200` | Create cart, add item |
| Get cart | `GET /cart` | `200` | Load cart data |

## 📊 Testing Checklist

- [ ] Run `./test-cart-api.sh` (should pass)
- [ ] Test in browser with DevTools open
- [ ] Add item to cart (should work)
- [ ] Refresh page (cart should persist)
- [ ] Check console logs (no errors)

## 🐛 Common Issues

| Error | Cause | Solution |
|-------|-------|----------|
| 404 | Cart doesn't exist | Normal! Will be created on add |
| 401 | Invalid session | Check localStorage tokens |
| 502 | Gateway can't reach service | Check checkout pod status |
| 500 | Server error | Check checkout logs |

## 📞 Quick Commands

```bash
# Check pods
kubectl get pods -n default | grep -E "gateway|checkout|frontend"

# Check logs
kubectl logs -n default deployment/gateway --tail=50 | grep cart
kubectl logs -n default deployment/checkout --tail=50 | grep cart
kubectl logs -n default deployment/frontend --tail=50

# Restart services
kubectl rollout restart deployment/gateway -n default
kubectl rollout restart deployment/checkout -n default
kubectl rollout restart deployment/frontend -n default

# Test API
curl https://api.tanhdev.com/api/v1/cart \
  -H 'x-session-id: test' \
  -H 'x-guest-token: test'
```

## 📚 Full Docs

- [CART_API_404_FIX_SUMMARY.md](CART_API_404_FIX_SUMMARY.md) - Complete summary
- [CART_API_FIX_CHECKLIST.md](CART_API_FIX_CHECKLIST.md) - Deployment checklist

---

**Status**: ✅ Implementation Complete  
**Next**: Deploy to production  
**Date**: 2026-02-01
