# Service Deployment Order Index

> **Purpose**: Thứ tự deploy các microservice khi thực hiện build từ source (replace → import).
> Build phải theo đúng thứ tự dưới đây để đảm bảo các proto API package đã có trên registry trước khi service phụ thuộc vào chúng được build.

---

## Nguyên tắc xác định thứ tự

1. **Leaf services** (không phụ thuộc service nào khác): deploy trước
2. **Shared library** (`common`): deploy trước tất cả
3. **Services phụ thuộc vào leaf**: deploy tiếp theo
4. **Orchestration services** (gọi nhiều upstream): deploy cuối cùng
5. **Gateway / Frontend**: luôn deploy sau tất cả backend

---

## Replace Directives Hiện Tại (cần chuyển thành import)

| Service | Local Replace Directives |
|---------|--------------------------|
| `checkout` | `catalog`, `common`, `customer`, `order`, `payment`, `pricing`, `promotion`, `shipping`, `warehouse` |
| `auth` | `common` |
| `user` | `common` |
| `customer` | `common` |
| `catalog` | `common` |
| `pricing` | `common` |
| `promotion` | `common` |
| `order` | `common` |
| `warehouse` | `common` |
| `fulfillment` | `common` |
| `gateway` | `common` |
| `loyalty-rewards` | `common` |
| `search` | `common` |
| `shipping` | _(none)_ |
| `payment` | _(none)_ |
| `return` | _(none)_ |
| `notification` | _(none)_ |
| `analytics` | _(none)_ |
| `review` | _(none)_ |
| `location` | _(none)_ |
| `common-operations` | _(none)_ |

> **`checkout` là service duy nhất có local replace nhiều service cùng lúc** — do đang in active development.

---

## Deployment Order (Sorted by Dependency Graph)

### 🔵 Wave 0 — Shared Library (phải publish trước tất cả)

| # | Service | Module | Lý do |
|---|---------|--------|-------|
| 0 | **common** | `gitlab.com/ta-microservices/common` | Shared library — tất cả services đều depend |

---

### 🟢 Wave 1 — Leaf Services (không gọi service nào khác)

Các service không có outbound gRPC call đến service khác trong hệ thống.

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 1 | **notification** | `notification/` | 8009 | 9009 | common |
| 2 | **location** | `location/` | 8007 | 9007 | common |
| 3 | **analytics** | `analytics/` | 8019 | 9019 | common |
| 4 | **auth** | `auth/` | 8000 | 9000 | common, (customer/user API proto only) |

---

### 🟡 Wave 2 — Core Domain Services (depend Wave 1)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 5 | **user** | `user/` | 8001 | 9001 | common |
| 6 | **customer** | `customer/` | 8003 | 9003 | common + auth, notification, order, payment API |
| 7 | **review** | `review/` | 8016 | 9016 | common + catalog, order, user API |

---

### 🟠 Wave 3 — Commerce Primitives (depend Wave 2)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 8 | **warehouse** | `warehouse/` | 8006 | 9006 | common + catalog, notification, user API |
| 9 | **shipping** | `shipping/` | 8012 | 9012 | common + catalog API |
| 10 | **pricing** | `pricing/` | 8002 | 9002 | common + catalog, customer, warehouse API |
| 11 | **payment** | `payment/` | 8005 | 9005 | common + customer, order API |

---

### 🔴 Wave 4 — Catalog & Promotion (depend Wave 3)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 12 | **catalog** | `catalog/` | 8015 | 9015 | common + customer, notification, order, payment, pricing, promotion, review, search, shipping, user, warehouse API |
| 13 | **promotion** | `promotion/` | 8011 | 9011 | common + catalog, customer, pricing, review, shipping API |

---

### 🔴 Wave 5 — Order & Fulfillment (depend Wave 4)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 14 | **order** | `order/` | 8004 | 9004 | common + catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse API |
| 15 | **return** | `return/` | 8013 | 9013 | common + order, shipping API |
| 16 | **fulfillment** | `fulfillment/` | 8008 | 9008 | common + order, warehouse API |

---

### 🟣 Wave 6 — Aggregation Services (depend Wave 5)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 17 | **search** | `search/` | 8017 | 9017 | common + catalog, pricing, warehouse API |
| 18 | **loyalty-rewards** | `loyalty-rewards/` | 8014 | 9014 | common + customer, notification, order API |
| 19 | **common-operations** | `common-operations/` | 8018 | 9018 | common + customer, notification, order, user, warehouse API |
| 20 | **checkout** | `checkout/` | 8010 | 9010 | common + catalog, customer, order, payment, pricing, promotion, shipping, warehouse API |

---

### ⚫ Wave 7 — Edge Services (deploy last)

| # | Service | Dir | HTTP | gRPC | Depends on |
|---|---------|-----|------|------|------------|
| 21 | **gateway** | `gateway/` | 80 | — | common + all upstream services |

---

### 🌐 Wave 8 — Frontend (after all backend is up)

| # | Service | Dir | Port | Depends on |
|---|---------|-----|------|------------|
| 22 | **admin** | `admin/` | 3001 | gateway API |
| 23 | **frontend** | `frontend/` | 3000 | gateway API |

---

## Khi chuyển từ `replace` → `import`

Với mỗi service có local `replace`, cần:

1. **Tag & push** module lên GitLab với semver mới (ví dụ: `git tag vX.Y.Z && git push origin vX.Y.Z`)
2. **Xóa** dòng `replace` trong `go.mod`
3. Chạy `go get gitlab.com/ta-microservices/<dep>@vX.Y.Z` để cập nhật version
4. Chạy `go mod tidy` để clean up
5. Build & push Docker image

### Thứ tự replace → import cho checkout (phức tạp nhất):

```
common → catalog → customer → notification → payment → user →
warehouse → shipping → pricing → review → order → promotion →
checkout
```

---

## CI/CD Pipeline Deploy Order (GitLab CI)

Nếu dùng GitLab CI với `needs:` / `dependencies:`, deploy theo thứ tự:

```yaml
stages:
  - wave-0   # common
  - wave-1   # notification, location, analytics, auth
  - wave-2   # user, customer, review
  - wave-3   # warehouse, shipping, pricing, payment
  - wave-4   # catalog, promotion
  - wave-5   # order, return, fulfillment
  - wave-6   # search, loyalty-rewards, common-operations, checkout
  - wave-7   # gateway
  - wave-8   # admin, frontend
```

---

*Last updated: 2026-02-19*
*Generated from: go.mod dependency analysis across all 23 services*
