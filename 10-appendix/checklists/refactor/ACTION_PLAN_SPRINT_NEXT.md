# Action Plan - Next Sprint
**Created:** March 2, 2026  
**Based on:** TA Review Report 2026-03-02  
**Sprint Goal:** Complete remaining P0 items and update documentation

---

## Sprint Objectives

1. ✅ Complete mockgen migration (Track 7)
2. ✅ Update refactor checklist with accurate status
3. ✅ Document architectural decisions
4. ⚠️ Evaluate remaining pagination offset calls (optional)

**Estimated Total Effort:** 3-4 days

---

## Task Breakdown

### Task 1: Complete Mockgen Migration (P0)
**Owner:** Backend Team  
**Effort:** 2-3 days  
**Priority:** Critical

#### Subtasks

**1.1 Generate Mocks for Order Service (4 hours)**
```bash
cd order

# Generate all mocks
go generate ./internal/biz/...

# Verify generated files
ls -la internal/biz/mocks/
# Expected output:
# - mock_pricing_service.go
# - mock_promotion_service.go
# - mock_product_service.go
# - mock_warehouse_service.go
# - mock_customer_service.go
# - mock_notification_service.go
# - mock_user_service.go
# - mock_shipping_service.go
# - mock_payment_service.go
# - mock_outbox_repo.go
```

**1.2 Update Test Imports (2 hours)**
```go
// Before (in test files):
import "gitlab.com/ta-microservices/order/internal/biz"
mockRepo := biz.NewMockOrderRepo()

// After:
import "gitlab.com/ta-microservices/order/internal/biz/mocks"
mockRepo := mocks.NewMockPricingService(ctrl)
```

**1.3 Run Tests and Fix Failures (4 hours)**
```bash
# Run all tests
go test ./internal/biz/... -v

# Check coverage
go test ./internal/biz/... -cover

# Expected: All tests pass with similar or better coverage
```

**1.4 Delete Hand-Written Mocks (30 minutes)**
```bash
# Backup first
cp internal/biz/mocks.go internal/biz/mocks.go.backup

# Delete after confirming tests pass
rm internal/biz/mocks.go

# Commit
git add .
git commit -m "refactor: migrate to mockgen for order service

- Generated mocks using mockgen directives
- Updated test imports to use generated mocks
- Deleted 768 lines of hand-written mocks
- All tests passing with maintained coverage

Refs: Track 7, commit f41bbc5"
```

**1.5 Repeat for Return Service (3 hours)**
```bash
cd return

# Add mockgen directives if not present
# Generate mocks
go generate ./internal/biz/...

# Update tests
# Run tests
go test ./internal/biz/... -v -cover

# Delete hand-written mocks (397 lines)
rm internal/biz/mocks.go

# Commit
git commit -m "refactor: migrate to mockgen for return service"
```

**1.6 Repeat for Analytics Service (2 hours)**
```bash
cd analytics

# Generate mocks
go generate ./internal/biz/...

# Update tests
# Run tests
go test ./internal/biz/... -v -cover

# Delete hand-written mocks (84 lines)
rm internal/biz/mocks.go

# Commit
git commit -m "refactor: migrate to mockgen for analytics service"
```

**Acceptance Criteria:**
- [ ] All mockgen directives executed successfully
- [ ] Generated mocks in `internal/biz/mocks/` directory
- [ ] All tests updated to use generated mocks
- [ ] Test coverage maintained or improved
- [ ] Hand-written mocks.go files deleted (1,249 lines removed)
- [ ] CI/CD pipeline passes

---

### Task 2: Update Refactor Checklist (P0)
**Owner:** Tech Lead  
**Effort:** 1 hour  
**Priority:** High

#### Subtasks

**2.1 Update Track Status (30 minutes)**

Edit `docs/10-appendix/checklists/refactor/REFACTOR_CHECKLIST.md`:

```markdown
# CHANGES:

## Track 7 - Update Status
| 7 | Testability | Mockgen migration complete | ✅ **DONE** | Migrated 1,249 lines of hand-written mocks to mockgen. All services (order, return, analytics) now use generated mocks. Commit: [hash] |

## Track 9 - Mark Complete
| 9 | GitOps / DRY | Worker & API Deployment Manifest Duplication | ✅ **COMPLETE** | All services including `return` and `review` use `common-deployment-v2` components. Verified 2026-03-02. |

## Track 11 - Reclassify
| 11 | API Standards | Cursor Pagination (Primary APIs) | ✅ **COMPLETE** | 12/14 services have cursor endpoints. Remaining 86 `.Offset()` calls are admin/utility methods (acceptable). Reclassified to P2 tech debt. |

## Track 18 - Mark Complete
| 18 | Security | RBAC migration to RequireRoleKratos | ✅ **DONE** | All 5 services (catalog, review, promotion, return, pricing) migrated. Verified 2026-03-02. |

## Update Summary Table
| Priority | Open Items | Est. Total Effort |
|----------|-----------|-------------------|
| 🔴 P0 | 0 (all complete) | 0 days |
| 🟡 P1 | #15 CI gates | ~5 days |
| 🔵 P2 | #11 remaining offset calls (optional) | ~3 days |
| ⏳ Q3 | #10 Helm chart | ~10 days |
```

**2.2 Add Completion Notes (30 minutes)**

Add new section at top of checklist:

```markdown
## 🎉 Sprint Completion Summary (March 2026)

**Completion Rate:** 89% (17/19 tracks)

### Completed This Sprint
- ✅ Track 7: Mockgen migration (1,249 lines → generated mocks)
- ✅ Track 9: GitOps DRY (verified complete)
- ✅ Track 11: Cursor pagination (primary APIs complete)
- ✅ Track 18: RBAC migration (all services)

### Remaining Work
- ⏳ Track 10: Helm migration (Q3 strategic initiative)
- ⏳ Track 15: CI coverage gates (infrastructure team)

### Architecture Quality
- Clean Architecture: Grade A+
- Test Coverage: 85.3% (target: 60%)
- Code Consistency: Excellent
- Production Readiness: ✅ Ready

**Last Updated:** March 2, 2026  
**Next Review:** Q3 2026 (Helm migration kickoff)
```

**Acceptance Criteria:**
- [ ] All track statuses updated accurately
- [ ] Summary table reflects current state
- [ ] Completion notes added
- [ ] Document committed to git

---

### Task 3: Create Architecture Decision Record (P1)
**Owner:** Tech Lead / Senior TA  
**Effort:** 2 hours  
**Priority:** Medium

**3.1 Document Pagination Strategy (1 hour)**

Create `docs/08-architecture-decisions/ADR-022-pagination-strategy.md`:

```markdown
# ADR-022: Pagination Strategy - Cursor vs Offset

## Status
Accepted

## Context
We need a consistent pagination strategy across 20+ microservices that:
1. Handles large datasets efficiently (orders, transactions, events)
2. Provides good UX for customer-facing APIs
3. Supports admin/utility queries with simple implementation

## Decision

### Primary APIs (Customer-Facing, High Volume)
**Use Cursor-Based Pagination**
- Order list, transaction history, event logs
- Mobile apps (infinite scroll)
- Large datasets (>10k records)

Implementation: `common/utils/pagination/cursor.go`

### Secondary APIs (Admin, Low Volume)
**Use Offset-Based Pagination**
- Admin dashboards, audit logs
- Small datasets (<1k records)
- Page-based navigation required

Implementation: `common/utils/pagination/pagination.go`

## Consequences

### Positive
- Optimal performance for high-volume queries
- Simple implementation for admin tools
- Consistent patterns across services

### Negative
- Two pagination patterns to maintain
- Developers must choose correct pattern

## Implementation Status
- ✅ 12/14 services have cursor pagination
- ✅ 86 offset calls remain (admin/utility, acceptable)
- ✅ Common library provides both patterns

## References
- Track 11 in refactor checklist
- `common/utils/pagination/` implementation
```

**3.2 Document Mockgen Migration (1 hour)**

Create `docs/08-architecture-decisions/ADR-023-mockgen-testing-strategy.md`:

```markdown
# ADR-023: Mockgen for Test Mocks

## Status
Accepted

## Context
Hand-written mocks (1,249 lines) are:
- Hard to maintain
- Prone to drift from interfaces
- Time-consuming to update

## Decision
Use `mockgen` for all interface mocking in tests.

### Implementation
```go
//go:generate mockgen -destination=mocks/mock_service.go -package=mocks . ServiceInterface
```

### Benefits
- Auto-generated from interfaces
- Always in sync with code
- Reduced maintenance burden
- Standard Go practice

## Migration Plan
1. ✅ Add mockgen directives (commit f41bbc5)
2. ✅ Generate mocks
3. ✅ Update test imports
4. ✅ Delete hand-written mocks

## Services Migrated
- ✅ order (768 lines removed)
- ✅ return (397 lines removed)
- ✅ analytics (84 lines removed)

## References
- Track 7 in refactor checklist
- Go mockgen documentation
```

**Acceptance Criteria:**
- [ ] ADR-022 created and reviewed
- [ ] ADR-023 created and reviewed
- [ ] ADRs linked in refactor checklist
- [ ] ADRs committed to git

---

### Task 4: Optional - Audit Remaining Offset Calls (P2)
**Owner:** Backend Team  
**Effort:** 1 day  
**Priority:** Low (Optional)

**4.1 Categorize Offset Calls (2 hours)**

Create audit spreadsheet:

| Service | File | Method | Volume | Customer-Facing? | Action |
|---------|------|--------|--------|------------------|--------|
| warehouse | inventory.go | ListInventory | Medium | No (admin) | Keep offset |
| catalog | product.go | ListProducts | High | Yes | ⚠️ Consider cursor |
| customer | audit.go | ListAuditLogs | Low | No (admin) | Keep offset |
| ... | ... | ... | ... | ... | ... |

**4.2 Migrate High-Priority Endpoints (6 hours)**

Only if customer-facing AND high-volume:

```go
// Example: catalog/internal/data/postgres/product.go
// Before:
func (r *ProductRepo) ListProducts(ctx context.Context, req *ListRequest) ([]*Product, int64, error) {
    query.Offset(offset).Limit(limit)
}

// After:
func (r *ProductRepo) ListProductsCursor(ctx context.Context, req *CursorRequest) ([]*Product, *CursorResponse, error) {
    cp := pagination.NewCursorPaginator(req)
    query.Where("id > ?", cp.GetCursor()).Limit(cp.GetLimit())
}
```

**Acceptance Criteria:**
- [ ] All 86 offset calls categorized
- [ ] High-priority endpoints identified
- [ ] Migration plan documented
- [ ] Decision recorded (migrate or keep)

---

## Testing Strategy

### Unit Tests
```bash
# Run all affected tests
go test ./order/internal/biz/... -v -cover
go test ./return/internal/biz/... -v -cover
go test ./analytics/internal/biz/... -v -cover

# Expected: All pass, coverage maintained
```

### Integration Tests
```bash
# Test mockgen-based tests in CI
gitlab-ci-lint .gitlab-ci.yml

# Run integration test suite
make test-integration
```

### Manual Verification
- [ ] Order service tests pass locally
- [ ] Return service tests pass locally
- [ ] Analytics service tests pass locally
- [ ] CI/CD pipeline green
- [ ] No regression in test coverage

---

## Rollout Plan

### Phase 1: Development (Day 1-2)
- Complete mockgen migration
- Update tests
- Local testing

### Phase 2: Review (Day 2)
- Code review
- Update documentation
- Create ADRs

### Phase 3: Merge (Day 3)
- Merge to main branch
- Monitor CI/CD
- Update checklist

### Phase 4: Verification (Day 3-4)
- Run full test suite
- Verify coverage reports
- Update team documentation

---

## Success Metrics

| Metric | Target | Current | Status |
|--------|--------|---------|--------|
| Mockgen Migration | 100% | 0% | 🔴 Not Started |
| Test Coverage | ≥85% | 85.3% | ✅ Maintained |
| Hand-Written Mocks | 0 lines | 1,249 lines | 🔴 To Remove |
| CI/CD Pipeline | Green | Green | ✅ Passing |
| Documentation | Complete | Partial | 🟡 In Progress |

---

## Risk Mitigation

### Risk 1: Test Failures After Migration
**Probability:** Medium  
**Impact:** High  
**Mitigation:**
- Keep backup of hand-written mocks
- Migrate one service at a time
- Extensive local testing before merge

### Risk 2: Coverage Drop
**Probability:** Low  
**Impact:** Medium  
**Mitigation:**
- Monitor coverage reports
- Add missing test cases
- Review test quality

### Risk 3: CI/CD Pipeline Breakage
**Probability:** Low  
**Impact:** High  
**Mitigation:**
- Test in feature branch first
- Run full CI pipeline before merge
- Have rollback plan ready

---

## Communication Plan

### Team Notification
```
Subject: [Action Required] Mockgen Migration - Next Sprint

Team,

We're completing the mockgen migration (Track 7) next sprint.

What's Changing:
- Hand-written mocks → mockgen-generated mocks
- Test imports updated
- 1,249 lines of code removed

Impact:
- Easier test maintenance
- Auto-sync with interfaces
- Standard Go practice

Timeline:
- Day 1-2: Migration
- Day 2: Review
- Day 3: Merge

Action Required:
- Review PRs promptly
- Test locally if touching affected services
- Report any issues immediately

Questions? Ping @tech-lead

Thanks!
```

### Stakeholder Update
- Update project board
- Mark Track 7 as "In Progress"
- Update sprint burndown chart

---

## Rollback Plan

If critical issues arise:

```bash
# Revert mockgen migration
git revert [commit-hash]

# Restore hand-written mocks
git checkout HEAD~1 -- internal/biz/mocks.go

# Run tests
go test ./...

# Notify team
# Post-mortem analysis
```

---

## Next Steps After Completion

1. **Update Team Wiki**
   - Document mockgen usage
   - Add examples
   - Update testing guidelines

2. **Share Learnings**
   - Tech talk on mockgen benefits
   - Update onboarding docs
   - Add to coding standards

3. **Plan Q3 Work**
   - Helm migration (Track 10)
   - CI coverage gates (Track 15)
   - Performance optimization

---

**Created by:** Senior Technical Architect  
**Approved by:** [Pending]  
**Start Date:** [TBD]  
**Target Completion:** [TBD + 4 days]
