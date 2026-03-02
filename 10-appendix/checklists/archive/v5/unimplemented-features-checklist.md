# 📋 v5 Unimplemented Features & Tasks Checklist

> **Date**: 2026-03-01
> **Status**: Consolidated Gap Analysis (v5.3)
> **Source**: Merged from `master-checklist.md`, `step-by-step-implementation-checklist.md`, and `missing-functional-checklist.md`

---

## 🔴 Phase A — Infrastructure & Tooling (High Priority)
> Goal: Automate quality checks and streamline development workflows.

- [ ] **A.1 GitLab CI — Auto Lint**
    - [ ] Create root `.golangci.yml` (enable `errcheck`, `staticcheck`, `govet`).
    - [ ] Add `lint` stage to `.gitlab-ci.yml`.
    - [ ] Fix existing blocking lint errors.
- [ ] **A.2 GitLab CI — Auto Test**
    - [ ] Add `test` stage to `.gitlab-ci.yml` (`go test -race -cover ./...`).
    - [ ] Set initial 40% coverage threshold for PR failure.
    - [ ] Configure `go mod` caching for faster pipelines.
- [ ] **A.3 Developer Tooling (Make/Task)**
    - [ ] Create root `Taskfile.yml` for unified command execution (e.g., `task proto:gen`).
    - [ ] Implement `buf.yaml` for Protobuf linting and breaking change detection.

---

## 🟡 Phase B — Service Consolidation (Medium Priority)
> Goal: Reduce service count from 19 to ~14, simplify operational overhead.

- [ ] **B.1 Identity Service (Merge Auth + User)**
    - [ ] Consolidate `auth` logic and `user` models into `identity` service.
    - [ ] Update all cross-service gRPC clients to use `identity.` proto.
    - [ ] Merge DB migrations and GitOps/ArgoCD configs.
- [ ] **B.2 Insights Service (Merge Analytics + Review)**
    - [ ] Merge `review` business/data logic into `analytics` (rename to `insights`).
    - [ ] Replace stub Review clients with internal function calls.
- [ ] **B.3 Location Service Decommission**
    - [ ] Move location data to `common/location/` lookup table.
    - [ ] Implement in-memory lookup in `gateway`.
    - [ ] Delete `location` service deployment.

---

## 🟡 Phase C — QA & Testing (Medium Priority)
> Goal: Reach >60% business layer coverage and verify cross-service flows.

- [ ] **C.1 P0 Unit Tests (Money & Security)**
    - [ ] `payment`: Authorization/Refund/Fraud logic (~15 cases).
    - [ ] `order`: State machine & Cancellation SAGA (~15 cases).
    - [ ] `warehouse`: Reservation atomicity (~12 cases).
- [ ] **C.2 Integration Tests**
    - [ ] End-to-end "Happy Path" (Cart → Shipping).
    - [ ] Complex Cancellation (SAGA cleanup verification).
    - [ ] Event Contract Validation (Schema matching across all services).
- [ ] **C.3 Non-Functional Tests**
    - [ ] Load test: 100 concurrent checkouts via `k6`.
    - [ ] Security scan: Basic SQLi/Auth bypass fuzzing on Gateway.

---

## 🔵 Phase D — Functional Gaps (Future Roadmap)
> Goal: Implement missing industry-standard e-commerce features.

- [ ] **D.1 Wallet & Store Credit**
    - [ ] `Deposit`, `Withdraw`, `Transfer` capability.
    - [ ] "Refund to Wallet" integration in `Return` service.
- [ ] **D.2 Gift Cards**
    - [ ] Gift card domain (issue, balance tracking, redemption).
    - [ ] Support for digital delivery of unique codes.
- [ ] **D.3 Subscriptions & Recurring**
    - [ ] Recurring billing scheduler in `Payment`.
    - [ ] Automated order generation cron jobs.
- [ ] **D.4 Compliance (GDPR)**
    - [ ] "Right to be Forgotten" orchestrator (GDPR-delete saga).
    - [ ] Automated "Export My Data" aggregator.
- [ ] **D.5 Multi-Currency & FX**
    - [ ] FX Rate provider integration.
    - [ ] Display vs. Settlement currency logic.

---

## ⚡ Track Q — Cursor-Based Pagination Refactor
> Goal: Migrate all remaining List/Search APIs to standard cursor pagination.

- [x] **Notification Service**
- [x] **Payment Service**
- [x] **Pricing Service**
- [x] **Promotion Service**
- [x] **Review Service**
- [x] **Search Service**
- [x] **Shipping Service**
- [x] **User Service**
- [x] **Warehouse Service**

---

## 📋 Ongoing Maintenance
- [ ] **F.1 Infrastructure Security**
    - [ ] Migrate hardcoded Git secrets to Sealed Secrets (ARGOCD-P0-1).
- [ ] **F.2 Service Observability**
    - [ ] Complete search-worker verification (sync documents, price updates).
- [ ] **F.3 Documentation**
    - [ ] Update README with new service consolidated architecture.
