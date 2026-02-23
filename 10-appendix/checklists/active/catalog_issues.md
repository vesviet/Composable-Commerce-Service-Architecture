# Product & Catalog Flow - Code Review Issues

**Last Updated**: 2026-02-23

This document lists issues found during the review of the Product & Catalog Flow, based on the `AI-OPTIMIZED CODE REVIEW GUIDE`.

---

## 🚩 PENDING ISSUES (Unfixed)

### High Priority
- ~~[High] **CAT-P1-03 Stock lookup error handling**: Warehouse-specific stock lookup returns 0 on error~~ — **[RESOLVED ✅ 2026-02-23]** Verified in `catalog/internal/biz/product/product_price_stock.go:62–75`: `GetStockFromCache` returns an explicit error (not 0) when the warehouse client fails; `GetProductAvailability` surfaces this error to the caller. No fallback-to-zero behaviour.

### Medium Priority
- [Medium] **CAT-P2-01 Data ownership documentation**: Unclear query patterns for stock/price between catalog vs search services (CQRS ambiguity). **Required**: Document ownership boundaries—catalog for PDP real-time, search for listings. See `catalog/internal/biz/product/product_price_stock.go`. **Impact**: Developers unsure which service to call, risk of stale data.

- ~~[Medium] **CAT-P2-02 Brand/category referential integrity**: DeleteBrand and DeleteCategory do not check product associations~~ — **[RESOLVED ✅ 2026-02-23]** Verified in code: `DeleteBrand` (brand.go:344–354) calls `productRepo.FindByBrand` and returns `"cannot delete brand: it is used by N product(s)"` if any exist. `DeleteCategory` (category.go:492–503) calls `productRepo.FindByCategory` and returns `"cannot delete category with associated products"`. Both guards are correctly fail-closed.

- [Medium] **CAT-P2-03 Cache TTL jitter synchronization**: Uses default RNG seed, causing synchronized cache expirations under load. **Required**: Seed RNG at startup (`rand.Seed(time.Now().UnixNano())`) or use crypto/rand per request. See `catalog/internal/biz/product/product_price_stock.go`. **Impact**: Thundering herd on cache miss.

## 🆕 NEWLY DISCOVERED ISSUES

### Go Specifics
- [Error Handling] **CAT-NEW-01 Silent error fallback pattern**: Multiple locations return default/zero values on errors without logging at appropriate severity. **Suggested fix**: Distinguish transient vs permanent failures, use structured logging with alert triggers for critical paths.

### DevOps/K8s
- [Debugging] **CAT-NEW-02 Dev K8s debugging steps missing**: Catalog service troubleshooting lacks standard K8s commands. **Suggested fix**: Add section:
  ```bash
  # View catalog service logs
  kubectl logs -n dev -l app=catalog-service --tail=100 -f
  
  # Exec into pod for debugging
  kubectl exec -n dev -it deployment/catalog-service -- /bin/sh
  
  # Port-forward for local testing
  kubectl port-forward -n dev svc/catalog-service 8080:8080
  
  # Multi-service logs (catalog + dependencies)
  stern -n dev 'catalog|warehouse|pricing' --since 5m
  
  # Check gRPC health
  grpc_health_probe -addr=catalog-service:9000
  ```

## ✅ RESOLVED / FIXED

- [FIXED ✅] **Category child check**: DeleteCategory now checks for child categories before deletion (line 306-310 in `catalog/internal/biz/category/category.go`). Returns error if children exist, preventing orphaned subcategories.

- [FIXED ✅ 2026-02-23] **CAT-P1-03 Stock lookup error handling**: `GetStockFromCache` returns explicit error on warehouse client failure; `GetProductAvailability` surfaces this to the caller. No silent zero-fallback. Verified in `product_price_stock.go:62–75`.

- [FIXED ✅ 2026-02-23] **CAT-P2-02 Brand/category referential integrity**: Both `DeleteBrand` (`brand.go:344–354`) and `DeleteCategory` (`category.go:492–503`) query products before deletion and reject with an explicit error message if associations exist. Fail-closed: if productRepo check fails, deletion is also blocked.

- [FIXED ✅ 2026-02-23] **GITOPS-CAT-01 Worker volumeMounts**: Added `volumeMounts` block into the container spec in `worker-deployment.yaml`; corrected volume ConfigMap from `overlays-config` to `catalog-config` (the file-based config). Main service deployment is rendered via Kustomize `common-deployment` component.

## P2 - Maintainability / Architecture

- **Issue**: Unclear data ownership and query patterns for stock/price information. [NOT FIXED]
  - **Service**: `catalog`
  - **Location**: `catalog/internal/biz/product/product_price_stock.go`
  - **Impact**: The `catalog` service contains active code for fetching and caching stock/price data, while the primary responsibility for this in listings belongs to the `search` service (CQRS pattern). This creates ambiguity for developers, increasing the risk of inconsistent data being displayed and making the system harder to maintain.
  - **Recommendation**: Create a central architecture document that clearly defines data ownership. For example: "All product listing/searching MUST use the `search` service. The `catalog` service's price/stock enrichment is ONLY for the Product Detail Page as a fallback or for direct, real-time checks."

---

## P2 - Data Integrity

- **Issue**: ~~Deleting a brand or category does not check for existing product associations~~. **[RESOLVED ✅ 2026-02-23]**
  - `DeleteBrand` (brand.go:344–354) uses `productRepo.FindByBrand` and blocks deletion with `"cannot delete brand: it is used by N product(s)"`.
  - `DeleteCategory` (category.go:492–503) uses `productRepo.FindByCategory` and blocks with `"cannot delete category with associated products"`.
