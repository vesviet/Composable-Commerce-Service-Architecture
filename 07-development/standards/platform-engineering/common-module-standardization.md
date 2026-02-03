# Common Module Standardization Checklist

> **Strategy**: Standardize and enhance `common` module first, then gradually migrate services.
> 
> **Goal**: Create a robust, well-tested common module that can be confidently used across all services.

## Status: In Progress 🚀

Last Updated: 2025-12-27

---

## Phase 1: Common Module Enhancement & Testing ✅

### Goal
Improve test coverage and code quality of common module before any service migration.

### Progress: 60% Complete

#### Testing & Quality
- [x] **Config Package** - 15.2% coverage (from 0%)
  - ✅ config_test.go: env helpers
  - ✅ loader_test.go: ConfigLoader, ConfigValidator
  - ✅ 29 test cases added
  - [ ] Add tests for LoadBaseConfig, LoadDatabaseConfig, LoadRedisConfig
  
- [x] **Events Package** - 30.6% coverage (from 0%)
  - ✅ dapr_publisher_test.go: 10+ test cases
  - ✅ All publisher types tested
  - ✅ Event structs tested
  
- [x] **Worker Package** - 91.9% coverage ✅ (Already excellent)
- [x] **Validation Package** - 85.7% coverage ✅ (Already excellent)
- [x] **Repository Package** - 75.8% coverage ✅ (Good)

#### Code Cleanup
- [x] Remove unused `utils/http_client` package
- [ ] Document all public APIs
- [ ] Add GoDoc comments for all packages

---

## Phase 2: Utils Package Standardization ✅

### Goal
Clean up and standardize common/utils package structure.

### Status: **COMPLETED** ✅

### Actions Completed

**Phase 1 - Consolidate Duplicates:** ✅
- Moved `cache.go` → `cache/manager.go`
- Moved `cache_sync.go` → `cache/sync.go`
- Removed duplicate `validation.go` (validators.go already exists)

**Phase 2 - Reorganize Structure:** ✅
- Moved `database.go` → `database/postgres.go`
- Moved `migration.go` → `database/migration.go`
- Moved `json_metadata.go` → `metadata/json_metadata.go`
- Moved `logger.go` → `common/logger.go`
- Utils root now has **only provider.go** ✨

**Phase 3 - Remove Unused:** ✅
- Removed `utils/eventbus` (0 usages - replaced by common/events)
- Removed `utils/upload_parser` (0 usages)

### Results
- ✅ No duplicate logic
- ✅ Clean package structure  
- ✅ 23 well-organized utils packages
- ✅ 8 commits pushed

### Next: Phase 4 - Testing
- [ ] Add tests for cache package
- [ ] Add tests for validation package
- [ ] Add tests for database package
- [ ] Add tests for other utils packages

---

## Phase 3: Config Package Enhancement

### Goal
Make config package the single source of truth for all service configurations.

### Progress: 40% Complete

#### Completed
- [x] Created BaseAppConfig struct
- [x] Created ServiceConfigLoader
- [x] Migrated 4 services (catalog, customer, promotion, fulfillment)
- [x] Comprehensive tests added

#### In Progress
- [/] common-operations migration ✅ DONE
- [/] search service migration
- [/] review service migration

#### Pending
- [ ] gateway migration (complex config)
- [ ] analytics migration (package conflicts)
- [ ] loyalty-rewards migration
- [ ] Remaining 6 services

---

## Phase 4: Utils Package Organization

### Goal
Organize and test utility packages for better maintainability.

### Status: Not Started

### Tasks
- [ ] Audit all utils subpackages
- [ ] Add tests for 0% coverage packages:
  - [ ] cache utilities
  - [ ] database utilities  
  - [ ] strings package
  - [ ] pointer package
  - [ ] time utilities
  - [ ] pagination
- [ ] Document usage patterns
- [ ] Remove unused utilities

---

## Phase 5: Events Package Standardization

### Goal
Ensure all services use common/events consistently.

### Progress: 85% Complete

#### Completed
- [x] Created DaprEventPublisher (gRPC)
- [x] Migrated 8+ services to common/events
- [x] Added comprehensive tests (30.6% coverage)

#### Remaining
- [ ] Migrate remaining services not using events
- [ ] Add event schema documentation
- [ ] Create event versioning strategy

---

## Phase 6: Middleware & Client Packages

### Goal
Standardize middleware and HTTP/gRPC client utilities.

### Status: Planning

### Tasks
- [ ] Audit middleware usage across services
- [ ] Create common middleware package
- [ ] Standardize circuit breaker usage
- [ ] Document client best practices

---

## Success Metrics

### Test Coverage Goals
- [x] Config: 15%+ (Achieved: 15.2%)
- [x] Events: 25%+ (Achieved: 30.6%)
- [x] Worker: 85%+ (Achieved: 91.9%)
- [x] Validation: 80%+ (Achieved: 85.7%)
- [x] Repository: 70%+ (Achieved: 75.8%)
- [ ] Overall common module: 60%+ (Current: ~25%)

### Migration Progress
- [ ] All services using common/config: 4/11 (36%)
- [ ] All services using common/events: 8/19 (42%)
- [ ] All services using common/worker: 6/19 (32%)
- [ ] All services using common/DB: 13/19 (68%)

---

## Notes & Lessons Learned

### Key Insights
1. **Test First**: Adding tests to common module before migration reduces risk
2. **Start Small**: Pilot with smallest services first
3. **Complexity Underestimation**: Repository migration more complex than expected
4. **Incremental Approach**: Better to have stable common module than rushed migration

### Blockers Identified
- Repository consolidation: High complexity, need better planning
- Analytics service: Package naming conflicts
- Gateway: Complex custom configuration

### Decisions Made
- ✅ Prioritize common module quality over speed of migration
- ✅ Postpone repository consolidation until common module is stable
- ✅ Use wrapper approach for backward compatibility when needed

---

## Next Steps (Priority Order)

1. **Add Tests for Utils Packages** (High Priority) 🆕
   - cache package (0% → 60%+)
   - validation package (0% → 60%+)
   - database package (0% → 60%+)
   - strings, pointer, time packages

2. **Complete Config Testing** (High Priority)
   - Add remaining config function tests
   - Achieve 50%+ coverage

3. **Documentation** (Medium Priority)
   - Document cache/ package API
   - Document validation/ package API
   - Document database/ package API
   - Create utils package usage guide

4. **Service Migrations** (Ongoing)
   - Migrate services from utils/repository → common/repository
   - Continue config migrations for remaining services

---

## Overall Progress Summary

### Completed ✅
1. **Worker Framework Consolidation** - 6/6 services (100%)
2. **DB/Redis Migration** - 13/19 services (68%)
3. **Config Migration** - 5/11 services (45%)
4. **Common Module Testing** - Config & Events packages tested
5. **Utils Standardization** - Phases 1-3 complete ✅
   - Removed duplicates
   - Reorganized structure
   - Removed unused packages

### In Progress 🔄
- Utils package testing (Phase 4)
- Remaining DB/Redis migrations
- Service migrations from utils/repository

### Pending ⏳
- Cache consolidation across services
- Middleware consolidation
- Validation framework extension

---

## Notes & Lessons Learned

### Key Insights
1. **Test First**: Adding tests to common module before migration reduces risk ✅
2. **Start Small**: Pilot with smallest services first ✅
3. **Pragmatic Decisions**: Keep both packages > forced migration
4. **Usage Analysis Critical**: 37+ files using utils/repository = can't remove

### Decisions Made
- ✅ Prioritize common module quality over speed of migration
- ✅ **KEEP BOTH repository packages** - no forced migration
- ✅ Use common/repository for NEW services only
- ✅ Add tests to utils/repository instead of removing it
- ✅ Focus on documentation over architecture changes

### Blockers Resolved
- ~~Repository consolidation~~: **DECIDED to keep both** ✅
- Analytics service: Package naming conflicts (still pending)
- Gateway: Complex custom configuration (still pending)

---

## References

- **Main Task**: [task.md](file:///.../task.md)
- **Implementation Plans**: 
  - [Config Migration Plan](file:///.../implementation_plan.md)
  - [Repository Migration Plan](file:///.../repository_migration_plan.md)
- **Progress Tracker**: [common-code-consolidation-checklist.md](file:///./common-code-consolidation-checklist.md)
