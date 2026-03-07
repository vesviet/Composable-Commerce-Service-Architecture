# 🤖 Agent Prompts — Service Review & Release

> Copy-paste each prompt into a separate agent session.
> All 5 agents run **in parallel**. `common@v1.23.2` is already tagged & pushed.
> Date: 2026-03-07

---

## 🟢 Agent 1 — Leaf & Foundation (notification, analytics, user)

```
Bạn là Agent 1, nhiệm vụ review & release 3 services: notification, analytics, user.

## Context
- common package đã review xong, đã commit + tag `v1.23.2` + push. Bạn không cần review common.
- Tất cả 5 agents đang chạy song song, bạn chỉ chịu trách nhiệm 3 services được assign.
- Workspace: /home/user/microservices

## Services to Review (theo thứ tự)
1. `notification/` (Wave 1) — depends on: common
2. `analytics/` (Wave 1) — depends on: common  
3. `user/` (Wave 1) — depends on: common

## Instructions

### Bước 1: Chuẩn bị
- Đọc skill review-service: `.agent/skills/review-service/SKILL.md`
- Đọc skill commit-code: `.agent/skills/commit-code/SKILL.md`
- Đọc coding standards: `docs/07-development/standards/coding-standards.md`
- Đọc review guide: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

### Bước 2: Với MỖI service (notification → analytics → user), follow review-service skill:

Step 0: `cd /home/user/microservices/<service> && git pull`
Step 1: Update deps: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
Step 2: Index & Review codebase → tìm P0/P1/P2 issues
Step 3: Cross-Service Impact Analysis (proto, events, go.mod)
Step 4: Tạo review checklist → `docs/10-appendix/review-service/<service>-review-checklist.md`
Step 5: Fix P0/P1 bugs ngay lập tức
Step 6: Test Coverage → chạy `go test ./... -cover`, target >80% biz layer
Step 7: Dependencies → verify không có replace directives, `go mod tidy`
Step 8: Lint & Build → `golangci-lint run`, `go build ./...`, `go test ./...`
Step 9: Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill

### Bước 3: Sau khi xong tất cả
- Update `docs/10-appendix/checklists/test/TEST_COVERAGE_CHECKLIST.md` cho 3 services
- Update `docs/10-appendix/review-service/REVIEW_CHECKLIST.md` → đánh dấu ✅ Done cho notification, analytics, user

## Critical Rules
- KHÔNG sửa common package
- KHÔNG dùng `replace` directive trong go.mod
- KHÔNG edit wire_gen.go hoặc *.pb.go bằng tay
- PHẢI đạt 0 lint warnings trước khi commit
- PHẢI dùng conventional commits format: `fix(<service>): ...`, `feat(<service>): ...`
- PHẢI xóa `bin/` directory trước khi commit
```

---

## 🟡 Agent 2 — Core Domain (auth, customer, payment, shipping, location)

```
Bạn là Agent 2, nhiệm vụ review & release 5 services: auth, customer, payment, shipping, location.

## Context
- common package đã review xong, đã commit + tag `v1.23.2` + push. Bạn không cần review common.
- Tất cả 5 agents đang chạy song song, bạn chỉ chịu trách nhiệm 5 services được assign.
- Workspace: /home/user/microservices

## Services to Review (theo thứ tự)
1. `auth/` (Wave 2) — depends on: common, customer, user
2. `customer/` (Wave 2) — depends on: common, auth, notification, order, payment
3. `payment/` (Wave 2) — depends on: common, customer, order ⚠️ CRITICAL: kiểm tra idempotency race condition!
4. `shipping/` (Wave 3) — depends on: common, catalog, fulfillment
5. `location/` (Wave 3) — depends on: common, shipping, user, warehouse

## ⚠️ Special Attention
- `auth ↔ customer` có mutual dependencies — review impact cùng nhau
- `payment` có known P0 idempotency race condition — phải fix
- Kiểm tra proto backward compatibility giữa auth ↔ customer

## Instructions

### Bước 1: Chuẩn bị
- Đọc skill review-service: `.agent/skills/review-service/SKILL.md`
- Đọc skill commit-code: `.agent/skills/commit-code/SKILL.md`
- Đọc coding standards: `docs/07-development/standards/coding-standards.md`
- Đọc review guide: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

### Bước 2: Với MỖI service (auth → customer → payment → shipping → location), follow review-service skill:

Step 0: `cd /home/user/microservices/<service> && git pull`
Step 1: Update deps: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
Step 2: Index & Review codebase → tìm P0/P1/P2 issues
Step 3: Cross-Service Impact Analysis (proto, events, go.mod)
Step 4: Tạo review checklist → `docs/10-appendix/review-service/<service>-review-checklist.md`
Step 5: Fix P0/P1 bugs ngay lập tức
Step 6: Test Coverage → chạy `go test ./... -cover`, target >80% biz layer
Step 7: Dependencies → verify không có replace directives, `go mod tidy`
Step 8: Lint & Build → `golangci-lint run`, `go build ./...`, `go test ./...`
Step 9: Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill

### Bước 3: Sau khi xong tất cả
- Update `docs/10-appendix/checklists/test/TEST_COVERAGE_CHECKLIST.md` cho 5 services
- Update `docs/10-appendix/review-service/REVIEW_CHECKLIST.md` → đánh dấu ✅ Done cho auth, customer, payment, shipping, location

## Critical Rules
- KHÔNG sửa common package
- KHÔNG dùng `replace` directive trong go.mod
- KHÔNG edit wire_gen.go hoặc *.pb.go bằng tay
- PHẢI đạt 0 lint warnings trước khi commit
- PHẢI dùng conventional commits format: `fix(<service>): ...`, `feat(<service>): ...`
- PHẢI xóa `bin/` directory trước khi commit
```

---

## 🟠 Agent 3 — Commerce & Catalog (pricing, catalog, warehouse, review)

```
Bạn là Agent 3, nhiệm vụ review & release 4 services: pricing, catalog, warehouse, review.

## Context
- common package đã review xong, đã commit + tag `v1.23.2` + push. Bạn không cần review common.
- Tất cả 5 agents đang chạy song song, bạn chỉ chịu trách nhiệm 4 services được assign.
- Workspace: /home/user/microservices

## Services to Review (theo thứ tự)
1. `pricing/` (Wave 3) — depends on: common, catalog, customer, warehouse ⚠️ CRITICAL: financial calculations!
2. `catalog/` (Wave 4) — depends on: common, customer, pricing, promotion, warehouse
3. `warehouse/` (Wave 4) — depends on: common, catalog, common-operations, location, notification, user
4. `review/` (Wave 5) — depends on: common, catalog, order, user

## ⚠️ Special Attention
- `catalog ↔ warehouse` có circular dependency — review together
- `pricing` xử lý tính toán tài chính — check rounding, decimal precision
- `catalog ↔ pricing ↔ warehouse` có cross-dependency — verify proto compat

## Instructions

### Bước 1: Chuẩn bị
- Đọc skill review-service: `.agent/skills/review-service/SKILL.md`
- Đọc skill commit-code: `.agent/skills/commit-code/SKILL.md`
- Đọc coding standards: `docs/07-development/standards/coding-standards.md`
- Đọc review guide: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

### Bước 2: Với MỖI service (pricing → catalog → warehouse → review), follow review-service skill:

Step 0: `cd /home/user/microservices/<service> && git pull`
Step 1: Update deps: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
Step 2: Index & Review codebase → tìm P0/P1/P2 issues
Step 3: Cross-Service Impact Analysis (proto, events, go.mod)
Step 4: Tạo review checklist → `docs/10-appendix/review-service/<service>-review-checklist.md`
Step 5: Fix P0/P1 bugs ngay lập tức
Step 6: Test Coverage → chạy `go test ./... -cover`, target >80% biz layer
Step 7: Dependencies → verify không có replace directives, `go mod tidy`
Step 8: Lint & Build → `golangci-lint run`, `go build ./...`, `go test ./...`
Step 9: Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill

### Bước 3: Sau khi xong tất cả
- Update `docs/10-appendix/checklists/test/TEST_COVERAGE_CHECKLIST.md` cho 4 services
- Update `docs/10-appendix/review-service/REVIEW_CHECKLIST.md` → đánh dấu ✅ Done cho pricing, catalog, warehouse, review

## Critical Rules
- KHÔNG sửa common package
- KHÔNG dùng `replace` directive trong go.mod
- KHÔNG edit wire_gen.go hoặc *.pb.go bằng tay
- PHẢI đạt 0 lint warnings trước khi commit
- PHẢI dùng conventional commits format: `fix(<service>): ...`, `feat(<service>): ...`
- PHẢI xóa `bin/` directory trước khi commit
```

---

## 🔴 Agent 4 — Order & Fulfillment (order, promotion, fulfillment, return)

```
Bạn là Agent 4, nhiệm vụ review & release 4 services: order, promotion, fulfillment, return.

## Context
- common package đã review xong, đã commit + tag `v1.23.2` + push. Bạn không cần review common.
- Tất cả 5 agents đang chạy song song, bạn chỉ chịu trách nhiệm 4 services được assign.
- Workspace: /home/user/microservices

## Services to Review (theo thứ tự)
1. `order/` (Wave 5) — depends on: common, catalog, customer, notification, payment, pricing, promotion, shipping, user, warehouse ⚠️ CRITICAL: most complex service (10 deps), double reservation bug, test failures!
2. `promotion/` (Wave 5) — depends on: common, catalog, customer, pricing, review, shipping ⚠️ known compile failures!
3. `fulfillment/` (Wave 6) — depends on: common, catalog, shipping, warehouse
4. `return/` (Wave 6) — depends on: common, order, payment, shipping, warehouse (first-time review!)

## ⚠️ Special Attention
- `order` là service phức tạp nhất (10 dependencies) — review kỹ business logic
- `order` có known bug: double stock reservation — phải fix
- `promotion` có known compile failures — check go build trước
- `return` chưa được review lần nào — cần full first-time review
- `order ↔ customer ↔ promotion` có circular dependencies

## Instructions

### Bước 1: Chuẩn bị
- Đọc skill review-service: `.agent/skills/review-service/SKILL.md`
- Đọc skill commit-code: `.agent/skills/commit-code/SKILL.md`
- Đọc coding standards: `docs/07-development/standards/coding-standards.md`
- Đọc review guide: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

### Bước 2: Với MỖI service (order → promotion → fulfillment → return), follow review-service skill:

Step 0: `cd /home/user/microservices/<service> && git pull`
Step 1: Update deps: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
Step 2: Index & Review codebase → tìm P0/P1/P2 issues
Step 3: Cross-Service Impact Analysis (proto, events, go.mod)
Step 4: Tạo review checklist → `docs/10-appendix/review-service/<service>-review-checklist.md`
Step 5: Fix P0/P1 bugs ngay lập tức
Step 6: Test Coverage → chạy `go test ./... -cover`, target >80% biz layer
Step 7: Dependencies → verify không có replace directives, `go mod tidy`
Step 8: Lint & Build → `golangci-lint run`, `go build ./...`, `go test ./...`
Step 9: Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill

### Bước 3: Sau khi xong tất cả
- Update `docs/10-appendix/checklists/test/TEST_COVERAGE_CHECKLIST.md` cho 4 services
- Update `docs/10-appendix/review-service/REVIEW_CHECKLIST.md` → đánh dấu ✅ Done cho order, promotion, fulfillment, return

## Critical Rules
- KHÔNG sửa common package
- KHÔNG dùng `replace` directive trong go.mod
- KHÔNG edit wire_gen.go hoặc *.pb.go bằng tay
- PHẢI đạt 0 lint warnings trước khi commit
- PHẢI dùng conventional commits format: `fix(<service>): ...`, `feat(<service>): ...`
- PHẢI xóa `bin/` directory trước khi commit
```

---

## 🟣 Agent 5 — Growth, Ops & Edge (search, loyalty-rewards, common-operations, checkout, gateway)

```
Bạn là Agent 5, nhiệm vụ review & release 5 services: search, loyalty-rewards, common-operations, checkout, gateway.

## Context
- common package đã review xong, đã commit + tag `v1.23.2` + push. Bạn không cần review common.
- Tất cả 5 agents đang chạy song song, bạn chỉ chịu trách nhiệm 5 services được assign.
- Workspace: /home/user/microservices

## Services to Review (theo thứ tự)
1. `search/` (Wave 6) — depends on: common, catalog, pricing, warehouse
2. `loyalty-rewards/` (Wave 6) — depends on: common, customer, notification, order ⚠️ CRITICAL: financial liability (points/rewards)!
3. `common-operations/` (Wave 6) — depends on: common, customer, notification, order, user, warehouse (first-time review!)
4. `checkout/` (Wave 7) — depends on: common, catalog, customer, order, payment, pricing, promotion, shipping, warehouse (first-time review! 9 deps — orchestrator)
5. `gateway/` (Wave 8) — depends on: common + all upstream services (review LAST — first-time review!)

## ⚠️ Special Attention
- `loyalty-rewards` xử lý tài chính (points, rewards) — check calculation logic kỹ
- `common-operations`, `checkout`, `gateway` là first-time review — cần review kỹ hơn
- `checkout` là orchestrator phức tạp (9 dependencies) — verify transaction flow
- `gateway` depends on ALL services — verify all routing rules match actual service ports
- `gateway` phải review CUỐI CÙNG vì nó phụ thuộc vào tất cả upstream services

## Instructions

### Bước 1: Chuẩn bị
- Đọc skill review-service: `.agent/skills/review-service/SKILL.md`
- Đọc skill commit-code: `.agent/skills/commit-code/SKILL.md`
- Đọc coding standards: `docs/07-development/standards/coding-standards.md`
- Đọc review guide: `docs/07-development/standards/TEAM_LEAD_CODE_REVIEW_GUIDE.md`

### Bước 2: Với MỖI service (search → loyalty-rewards → common-operations → checkout → gateway), follow review-service skill:

Step 0: `cd /home/user/microservices/<service> && git pull`
Step 1: Update deps: `go get gitlab.com/ta-microservices/common@v1.23.2 && go mod tidy`
Step 2: Index & Review codebase → tìm P0/P1/P2 issues
Step 3: Cross-Service Impact Analysis (proto, events, go.mod)
Step 4: Tạo review checklist → `docs/10-appendix/review-service/<service>-review-checklist.md`
Step 5: Fix P0/P1 bugs ngay lập tức
Step 6: Test Coverage → chạy `go test ./... -cover`, target >80% biz layer
Step 7: Dependencies → verify không có replace directives, `go mod tidy`
Step 8: Lint & Build → `golangci-lint run`, `go build ./...`, `go test ./...`
Step 9: Deployment Readiness → verify ports, config, GitOps alignment
Step 10: Documentation → update CHANGELOG.md, README.md
Step 11: Commit & Push → conventional commit format, follow commit-code skill

### Bước 3: Sau khi xong tất cả
- Update `docs/10-appendix/checklists/test/TEST_COVERAGE_CHECKLIST.md` cho 5 services
- Update `docs/10-appendix/review-service/REVIEW_CHECKLIST.md` → đánh dấu ✅ Done cho search, loyalty-rewards, common-operations, checkout, gateway

## Critical Rules
- KHÔNG sửa common package
- KHÔNG dùng `replace` directive trong go.mod
- KHÔNG edit wire_gen.go hoặc *.pb.go bằng tay
- PHẢI đạt 0 lint warnings trước khi commit
- PHẢI dùng conventional commits format: `fix(<service>): ...`, `feat(<service>): ...`
- PHẢI xóa `bin/` directory trước khi commit
```
