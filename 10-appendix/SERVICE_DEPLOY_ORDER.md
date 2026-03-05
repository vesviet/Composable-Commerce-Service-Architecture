# Service Deployment Order Index

> **Purpose**: Thứ tự deploy các microservice để đảm bảo các proto API package đã có trên registry trước khi service phụ thuộc vào chúng được build.
> 
> **Status**: ✅ Tất cả services đã chuyển từ `replace` sang `import` - không còn local dependencies

---

## Nguyên tắc xác định thứ tự

1. **Shared library** (`common`): deploy trước tất cả
2. **Leaf services** (không phụ thuộc service nào khác): deploy tiếp theo
3. **Services phụ thuộc vào leaf**: deploy sau leaf services
4. **Orchestration services** (gọi nhiều upstream): deploy cuối cùng
5. **Gateway / Frontend**: luôn deploy sau tất cả backend

---

## Dependency Status

✅ **Tất cả services đã sử dụng versioned imports** - không còn `replace` directives trong go.mod

Các services hiện đang sử dụng semantic versioning cho dependencies:
- `common`: v1.22.0 - v1.23.1
- Service APIs: v1.0.x - v1.3.x

---

## Deployment Order (Sorted by Dependency Graph)

### 🔵 Wave 0 — Shared Library (phải publish trước tất cả)

| # | Service | Module | Current Version | Lý do |
|---|---------|--------|-----------------|-------|
| 0 | **common** | `gitlab.com/ta-microservices/common` | v1.23.1 | Shared library — tất cả services đều depend |

---

### 🟢 Wave 1 — Leaf Services (không gọi service nào khác)

Các service không có outbound gRPC call đến service khác trong hệ thống.

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 1 | **notification** | `notification/` | 8009 | 9009 | common |
| 2 | **analytics** | `analytics/` | 8019 | 9019 | common |
| 3 | **user** | `user/` | 8001 | 9001 | common |

---

### 🟡 Wave 2 — Core Domain Services (depend Wave 1)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 4 | **auth** | `auth/` | 8000 | 9000 | common + customer, user API |
| 5 | **customer** | `customer/` | 8003 | 9003 | common + auth, notification, order, payment API |
| 6 | **payment** | `payment/` | 8005 | 9005 | common + customer, order API |

---

### 🟠 Wave 3 — Commerce Primitives (depend Wave 2)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 7 | **shipping** | `shipping/` | 8012 | 9012 | common + catalog, fulfillment API |
| 8 | **location** | `location/` | 8007 | 9007 | common + shipping, user, warehouse API |
| 9 | **pricing** | `pricing/` | 8002 | 9002 | common + catalog, customer, warehouse API |

---

### 🔴 Wave 4 — Catalog & Warehouse (depend Wave 3)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 10 | **catalog** | `catalog/` | 8015 | 9015 | common + customer, pricing, promotion, warehouse API |
| 11 | **warehouse** | `warehouse/` | 8006 | 9006 | common + catalog, common-operations, location, notification, user API |

---

### 🔴 Wave 5 — Order & Review (depend Wave 4)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 12 | **review** | `review/` | 8016 | 9016 | common + catalog, order, user API |
| 13 | **order** | `order/` | 8004 | 9004 | common + catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse API |
| 14 | **promotion** | `promotion/` | 8011 | 9011 | common + catalog, customer, pricing, review, shipping API |

---

### 🟣 Wave 6 — Fulfillment & Operations (depend Wave 5)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 15 | **fulfillment** | `fulfillment/` | 8008 | 9008 | common + catalog, shipping, warehouse API |
| 16 | **return** | `return/` | 8013 | 9013 | common + order, payment, shipping, warehouse API |
| 17 | **search** | `search/` | 8017 | 9017 | common + catalog, pricing, warehouse API |
| 18 | **loyalty-rewards** | `loyalty-rewards/` | 8014 | 9014 | common + customer, notification, order API |
| 19 | **common-operations** | `common-operations/` | 8018 | 9018 | common + customer, notification, order, user, warehouse API |

---

### 🟣 Wave 7 — Checkout (depend Wave 6)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 20 | **checkout** | `checkout/` | 8010 | 9010 | common + catalog, customer, order, payment, pricing, promotion, shipping, warehouse API |

---

### ⚫ Wave 8 — Edge Services (deploy last)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 21 | **gateway** | `gateway/` | 80 | — | common + all upstream services (analytics, auth, catalog, checkout, common-operations, customer, fulfillment, location, loyalty-rewards, notification, order, payment, pricing, promotion, review, search, shipping, user, warehouse) |

---

### 🌐 Wave 9 — Frontend (after all backend is up)

| # | Service | Dir | Port | Depends on |
|---|---------|-----|------|------------|
| 22 | **admin** | `admin/` | 3001 | gateway API |
| 23 | **frontend** | `frontend/` | 3000 | gateway API |

---

## Dependency Matrix

Bảng tổng hợp dependencies của từng service (dựa trên go.mod analysis):

| Service | Dependencies (ta-microservices only) |
|---------|--------------------------------------|
| **common** | _(none - base library)_ |
| **notification** | common |
| **analytics** | common |
| **user** | common |
| **auth** | common, customer, user |
| **customer** | common, auth, notification, order, payment |
| **payment** | common, customer, order |
| **shipping** | common, catalog, fulfillment |
| **location** | common, shipping, user, warehouse |
| **pricing** | common, catalog, customer, warehouse |
| **catalog** | common, customer, pricing, promotion, warehouse |
| **warehouse** | common, catalog, common-operations, location, notification, user |
| **review** | common, catalog, order, user |
| **order** | common, catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse |
| **promotion** | common, catalog, customer, pricing, review, shipping |
| **fulfillment** | common, catalog, shipping, warehouse |
| **return** | common, order, payment, shipping, warehouse |
| **search** | common, catalog, pricing, warehouse |
| **loyalty-rewards** | common, customer, notification, order |
| **common-operations** | common, customer, notification, order, user, warehouse |
| **checkout** | common, catalog, customer, order, payment, pricing, promotion, shipping, warehouse |
| **gateway** | common, analytics, auth, catalog, checkout, common-operations, customer, fulfillment, location, loyalty-rewards, notification, order, payment, pricing, promotion, review, search, shipping, user, warehouse |

---

## Version Management Best Practices

### Khi publish service mới:

1. **Tag version** cho service:
   ```bash
   cd <service-dir>
   git tag v1.x.y
   git push origin v1.x.y
   ```

2. **Update dependent services**:
   ```bash
   go get gitlab.com/ta-microservices/<service>@v1.x.y
   go mod tidy
   ```

3. **Verify dependencies**:
   ```bash
   go mod graph | grep ta-microservices
   ```

### Semantic Versioning Guidelines:

- **MAJOR** (v2.0.0): Breaking API changes
- **MINOR** (v1.1.0): New features, backward compatible
- **PATCH** (v1.0.1): Bug fixes, backward compatible

---

## CI/CD Pipeline Deploy Order (GitLab CI)

Nếu dùng GitLab CI với `needs:` / `dependencies:`, deploy theo thứ tự:

```yaml
stages:
  - wave-0   # common
  - wave-1   # notification, analytics, user
  - wave-2   # auth, customer, payment
  - wave-3   # shipping, location, pricing
  - wave-4   # catalog, warehouse
  - wave-5   # review, order, promotion
  - wave-6   # fulfillment, return, search, loyalty-rewards, common-operations
  - wave-7   # checkout
  - wave-8   # gateway
  - wave-9   # admin, frontend
```

### Example GitLab CI Job:

```yaml
# Wave 0
deploy:common:
  stage: wave-0
  script:
    - cd common && make deploy

# Wave 1
deploy:notification:
  stage: wave-1
  needs: ["deploy:common"]
  script:
    - cd notification && make deploy

# Wave 8 - Gateway depends on all backend services
deploy:gateway:
  stage: wave-8
  needs:
    - deploy:common
    - deploy:analytics
    - deploy:auth
    - deploy:catalog
    - deploy:checkout
    # ... all other backend services
  script:
    - cd gateway && make deploy
```

---

## Circular Dependency Detection

⚠️ **Potential circular dependencies detected:**

1. **catalog ↔ warehouse**: 
   - catalog depends on warehouse
   - warehouse depends on catalog
   - **Resolution**: Deploy catalog first (warehouse has optional catalog dependency)

2. **customer ↔ order**:
   - customer depends on order API
   - order depends on customer API
   - **Resolution**: Deploy customer first (order has stronger dependency)

3. **catalog ↔ promotion**:
   - catalog depends on promotion
   - promotion depends on catalog
   - **Resolution**: Deploy catalog first (promotion has optional catalog dependency)

---

*Last updated: 2026-03-05*
*Generated from: go.mod dependency analysis across all 23 services*
*Status: ✅ All services using versioned imports (no replace directives)*
