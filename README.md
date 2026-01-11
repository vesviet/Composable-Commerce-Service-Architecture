# Documentation Index

**Last Updated**: 2025-12-30  
**Status**: ✅ Recently consolidated (244 → 62 files, 75% reduction)

---

## 🎯 Quick Navigation

### For Developers (MUST READ)
→ **[GRPC_PROTO_AND_VERSIONING_RULES.md](./GRPC_PROTO_AND_VERSIONING_RULES.md)** - Rules for internal gRPC API changes and versioning.


### For Business Logic & Features
→ **[checklists/](./checklists/)** (40 files)
- Business logic implementation checklists
- Sprint trackers and roadmaps
- Service-specific implementation guides

### For Infrastructure & Technical Debt
→ **[platform-engineering/](./platform-engineering/)** (22 files)
- Common code migration
- gRPC standardization
- Infrastructure improvements

---

## 📊 Directory Structure

```
docs/
├── README.md (this file)
│
├── checklists/ (40 files)
│   ├── PROJECT_STATUS.md  (78% complete, canonical status)
│   ├── SPRINT_TRACKER.md  (master sprint checklist)
│   ├── ROADMAP.md  (priority roadmap)
│   ├── SPRINT_*_CHECKLIST.md  (6 sprint files)
│   └── *-checklist.md  (24 business logic checklists)
│
├── platform-engineering/ (22 files)
│   ├── common-code consolidation
│   ├── gRPC migration guides
│   ├── ArgoCD standardization
│   └── Infrastructure checklists
│
└── Other documentation directories:
    ├── adr/ - Architecture Decision Records
    ├── argocd/ - ArgoCD deployment guides
    ├── design/ - System design documents
    ├── processes/ - Business process documentation
    └── sre-runbooks/ - SRE operational guides
```

---

## 🚀 Getting Started

### New Team Members
1. **Start**: [checklists/README.md](./checklists/README.md)
2. **Status**: [checklists/PROJECT_STATUS.md](./checklists/PROJECT_STATUS.md)
3. **Sprints**: [checklists/SPRINT_TRACKER.md](./checklists/SPRINT_TRACKER.md)

### Business Logic Implementation
1. Review [checklists/](./checklists/) for feature checklists
2. Check [checklists/ROADMAP.md](./checklists/ROADMAP.md) for priorities
3. Follow specific service checklist (e.g., cart, checkout, payment)

### Platform Engineering
1. Review [platform-engineering/README.md](./platform-engineering/README.md)
2. Check gRPC migration status
3. Follow common code consolidation guides

---

## 📋 Top-Level Documentation

| Document | Purpose |
|----------|---------|
| [SYSTEM_ARCHITECTURE_OVERVIEW.md](./SYSTEM_ARCHITECTURE_OVERVIEW.md) | Complete system architecture (19KB) |
| [CONSOLIDATION_IMPLEMENTATION_GUIDE.md](./CONSOLIDATION_IMPLEMENTATION_GUIDE.md) | Service consolidation guide (31KB) |
| [MIGRATION_SUMMARY.md](./MIGRATION_SUMMARY.md) | Migration progress summary |
| [K8S_MIGRATION_QUICK_GUIDE.md](./K8S_MIGRATION_QUICK_GUIDE.md) | Kubernetes migration guide |
| [K8S_CONFIG_STANDARDIZATION_CHECKLIST.md](./K8S_CONFIG_STANDARDIZATION_CHECKLIST.md) | K8s config standards |
| [CUSTOMER_GROUP_IMPLEMENTATION_PLAN.md](./CUSTOMER_GROUP_IMPLEMENTATION_PLAN.md) | Customer groups feature plan |
| [DOCUMENTATION_REVIEW_REPORT.md](./DOCUMENTATION_REVIEW_REPORT.md) | Docs review findings |

---

## 📊 Project Health

**Overall Completion:** 78%  
**Services Operational:** 19/19 (100%)  
**Production Ready:** 12/19 (63%)  
**Timeline to 95%:** 6-8 weeks

**Recent Changes (Dec 30, 2025):**
- ✅ Consolidated 244 files → 62 files (75% reduction)
- ✅ Removed outdated backup-2025-11-17/ archive
- ✅ Merged checklists-v2 sprint trackers into checklists/
- ✅ Renamed checklists-daily to platform-engineering/
- ✅ Removed duplicate checklists-implement/

---

## 🔄 Consolidation Summary

### Before (Dec 30, 2025 morning)
```
docs/
├── backup-2025-11-17/ (154 files) - OLD
├── checklists/ (28 files)
├── checklists-v2/ (29 files) - DUPLICATE
├── checklists-daily/ (22 files)
└── checklists-implement/ (11 files) - DUPLICATE

Total: 244 files
```

### After (Dec 30, 2025 afternoon)
```
docs/
├── checklists/ (40 files) ✅
└── platform-engineering/ (22 files) ✅

Total: 62 files (75% reduction)
```

**Archived:** backup-2025-11-17-archive.tar.gz (655KB)

---

## 📞 Support

### Questions about:
- **Business Features**: Check [checklists/](./checklists/)
- **Infrastructure**: Check [platform-engineering/](./platform-engineering/)
- **Deployment**: Check [argocd/](./argocd/)
- **Architecture**: Check [design/](./design/)

---

**Maintained By**: Platform Architecture Team  
**Last Major Update**: 2025-12-30 (Documentation Consolidation)  
**Next Review**: Weekly
