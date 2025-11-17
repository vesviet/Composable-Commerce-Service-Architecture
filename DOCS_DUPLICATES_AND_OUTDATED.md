# 📋 Documentation Duplicates & Outdated Files

> **Quick Reference** - Files to review, archive, or delete

---

## 🔴 Duplicates (Remove/Archive)

### Progress Reports

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `PROJECT_PROGRESS_REPORT.md` | ✅ KEEP | Keep | Most comprehensive, Nov 16, 2025, 88% complete |
| `PROJECT_STATUS_SUMMARY.md` | ❌ DUPLICATE | Archive | Duplicate of PROJECT_PROGRESS_REPORT.md |
| `PROJECT_PROGRESS_UPDATE_NOV16.md` | ❌ DUPLICATE | Archive | Update info, already in main report |
| `PROGRESS_COMPARISON.md` | ❌ DUPLICATE | Archive | Comparison data, can be in archive |

### Index Files

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `INDEX.md` | ✅ KEEP | Update | Main index, needs update with INDEX_UPDATE_NOV16 content |
| `INDEX_UPDATE_NOV16.md` | ❌ DUPLICATE | Archive | After merging into INDEX.md |

### Worker Guides

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `WORKERS_QUICK_GUIDE.md` | ⚠️ REVIEW | Merge | Check overlap with WORKERS_QUICK_START |
| `WORKERS_QUICK_START.md` | ⚠️ REVIEW | Merge | Check overlap with WORKERS_QUICK_GUIDE |
| → `guides/infrastructure/WORKERS_GUIDE.md` | ✅ CREATE | Create | Merged guide |

### Dapr Guides

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `DAPR_GRPC_WORKER_EVENT_COMPATIBILITY.md` | ⚠️ REVIEW | Review | Check if can consolidate |
| `DAPR_GRPC_WORKERS_GUIDE.md` | ⚠️ REVIEW | Review | Check if can consolidate |
| `DAPR_HTTP_CALLBACKS_PORT_GUIDE.md` | ⚠️ REVIEW | Review | Check if can consolidate |
| `DAPR_VS_REDIS_STREAMS_COMPARISON.md` | ⚠️ REVIEW | Review | Check if can consolidate |
| → `guides/infrastructure/DAPR_GUIDE.md` | ✅ CREATE | Create | Consolidated guide (if possible) |

### Client Type Docs

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `CLIENT_TYPE_QUICK_REFERENCE.md` | ⚠️ REVIEW | Review | Check if duplicate of CLIENT_TYPE_IDENTIFICATION |
| `architecture/CLIENT_TYPE_IDENTIFICATION.md` | ✅ KEEP | Keep | Main guide |

---

## 🟡 Outdated (Archive/Delete)

### Old Status Reports (in archive/)

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `archive/status-reports-nov2024/PROJECT_STATUS_NOV11.md` | ❌ OUTDATED | Delete | Superseded by Nov 16 reports |
| `archive/status-reports-nov2024/QUICK_UPDATE_NOV11_EVENING.md` | ❌ OUTDATED | Delete | Superseded by Nov 16 reports |
| `archive/status-reports-nov2024/CLEANUP_SUMMARY_NOV11.md` | ⚠️ REVIEW | Review | May have useful info |
| `archive/status-reports-nov2024/COMPREHENSIVE_PROJECT_REVIEW_NOV12.md` | ⚠️ REVIEW | Review | Check if still useful |
| `archive/status-reports-nov2024/PROJECT_COMPREHENSIVE_REVIEW_NOV12.md` | ⚠️ REVIEW | Review | Check if duplicate of above |

### Old Comparison Docs

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `archive/SHOP_MAIN_VS_CATALOG_COMPARISON.md` | ❌ OUTDATED | Delete | Old comparison, no longer relevant |
| `SERVICE_STRUCTURE_COMPARISON.md` | ⚠️ REVIEW | Review | Check if still relevant |

### Old Migration Plans

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `archive/COMMON_MIGRATION_PLAN.md` | ⚠️ REVIEW | Review | Check if migration completed |
| `archive/CUSTOMER_SERVICE_MIGRATION_ANALYSIS.md` | ⚠️ REVIEW | Review | Check if migration completed |

### Potentially Outdated

| File | Status | Action | Reason |
|------|--------|--------|--------|
| `TRAFFIC_FLOW_AND_CONVERSION_ANALYSIS.md` | ⚠️ REVIEW | Review | Check if still relevant |
| `TRAFFIC_TO_ORDERS_QUICK_REFERENCE.md` | ⚠️ REVIEW | Review | Check if still relevant |
| `MISSING_SERVICES_REPORT.md` | ⚠️ REVIEW | Review | Check if still accurate |

---

## 📊 Summary

### Duplicates
- **Progress Reports:** 3 duplicates → Archive
- **Index Files:** 1 duplicate → Archive after merge
- **Worker Guides:** 2 files → Merge into 1
- **Dapr Guides:** 4 files → Review and consolidate
- **Client Type:** 1 potential duplicate → Review

### Outdated
- **Old Status Reports:** 2-3 files → Delete
- **Old Comparisons:** 1-2 files → Delete/Review
- **Old Migration Plans:** 2 files → Review
- **Potentially Outdated:** 3 files → Review

### Total Actions
- **Archive:** ~10-12 files
- **Delete:** ~3-5 files
- **Review:** ~10-12 files
- **Merge:** ~2-3 groups

---

## 🎯 Action Plan

### Immediate (Do First)
1. Archive duplicate progress reports (3 files)
2. Merge INDEX files (1 file)
3. Review and merge worker guides (2 files)

### Short Term
4. Review Dapr guides (4 files)
5. Delete outdated status reports (2-3 files)
6. Review potentially outdated docs (3 files)

### Long Term
7. Reorganize structure
8. Update all links
9. Create new INDEX.md

---

## 📝 Notes

- **Archive location:** `docs/archive/2024-nov/` or `docs/archive/outdated/`
- **Before deleting:** Always archive first, then delete after review
- **Link updates:** Update all internal links when moving files
- **Testing:** Test navigation after reorganization

---

**See Also:**
- [DOCS_CLEANUP_PLAN_2025.md](./DOCS_CLEANUP_PLAN_2025.md) - Detailed plan
- [DOCS_CLEANUP_SUMMARY.md](./DOCS_CLEANUP_SUMMARY.md) - Quick summary

