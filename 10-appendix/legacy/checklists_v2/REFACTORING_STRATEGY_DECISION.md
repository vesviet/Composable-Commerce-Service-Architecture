# Refactoring Strategy: Domain Split vs File Refactoring - Decision Analysis

**Date**: 2026-01-22  
**Question**: Nên làm gì trước - Split domain hay refactor large files?  
**Answer**: **REFACTOR FILES FIRST** ✅

---

## 📊 Quick Comparison

| Aspect | Refactor Files First | Domain Split First |
|--------|---------------------|-------------------|
| **Risk** | 🟢 Low (same service) | 🔴 High (new services, data migration) |
| **Time** | 🟢 2-4 weeks | 🔴 3 months |
| **Deployment** | 🟢 Rolling update | 🔴 Blue-green, data sync |
| **Rollback** | 🟢 Easy (same code structure) | 🔴 Hard (data split) |
| **Team Impact** | 🟢 Minimal | 🔴 Requires coordination |
| **Business Value** | 🟡 Indirect (maintainability) | 🟢 Direct (team independence) |

**Verdict**: ✅ **Refactor large files FIRST, then domain split**

---

## 🎯 Recommended Approach: "Bottom-Up Refactoring"

### **Phase 1: Refactor Large Files (Weeks 1-4)**

**Why first?**
1. **Lower risk**: Code stays in same service, same database
2. **Easier to test**: Existing integration tests still work
3. **Better foundation**: Clean code makes domain split easier
4. **Quick wins**: Immediate maintainability improvement

**Focus on 3 critical files**:

#### **Week 1-2: Pricing Service**
- `pricing/service/pricing.go` (1743 lines) → Split into:
  - `pricing_handlers.go` - gRPC handlers
  - `pricing_rules.go` - Rule evaluation logic
  - `pricing_cache.go` - Caching logic
  - `currency_converter.go` - Multi-currency

**Impact**: Unlocks pricing feature development (currently blocked)

#### **Week 3: Promotion Service**  
- `promotion/biz/promotion.go` (1426 lines) → Split into:
  - `validation.go` - Eligibility validation
  - `discount_rules.go` - Discount calculation
  - `usage_tracking.go` - Usage limits
  - `promotion.go` - Core orchestration (keep)

**Impact**: Makes adding new promotion types easier

#### **Week 4: Order Return**
- `order/biz/return/return.go` (1576 lines) → Split into:
  - `validation.go` - Return request validation
  - `refund.go` - Refund processing
  - `restock.go` - Inventory return
  - `workflow.go` - State machine
  - `return.go` - Core orchestration (keep)

**Impact**: Cleanest code before extracting to Return Service later

**Total Effort**: ~50-60 hours (2 engineers x 2 weeks)

---

### **Phase 2: Domain Split (Weeks 5-16)**

After refactoring, domain split becomes **MUCH EASIER**:

#### **Week 5-10: Order → Cart Service Split**
- Extract **already refactored** `cart/` package
- Clean boundaries make extraction straightforward
- Database migration clearer with organized code

#### **Week 11-16: Order → Return Service Split**  
- Extract **already refactored** `return/` package
- Clean state machine makes event-driven easier

---

## 🚨 Why NOT Domain Split First?

### **Problem 1: Messy Code Makes Split Harder**
```
❌ Bad scenario:
1. Split Order → Cart service
2. Move cart/totals.go (415 lines) to new service
3. Realize totals calculation is messy
4. Need to refactor IN THE NEW SERVICE
5. Now you have messy code in 2 places during transition
```

```
✅ Good scenario:
1. Refactor cart/totals.go first (split into smaller files)
2. Clean code with clear boundaries
3. Move clean, well-structured code to Cart service
4. Migration is straightforward
```

### **Problem 2: Testing Nightmare**
- Domain split requires integration tests across services
- If code is messy (1000+ line files), debugging failures is HARD
- Refactored code = easier to isolate issues

### **Problem 3: Data Migration Risk**
- Domain split requires database migration (cart_db separate from order_db)
- If code logic is unclear (buried in 1500-line file), risk of data bugs
- Clean code = confident migration

---

## ✅ Benefits of Refactor-First Approach

### **1. Immediate Wins (Week 1-2)**
- ✅ Pricing team unblocked (can add features to pricing.go)
- ✅ Better code review experience (smaller files)
- ✅ Easier onboarding for new engineers

### **2. Safer Domain Split (Week 5+)**
- ✅ Clear boundaries → know what to extract
- ✅ Clean code → easier data migration planning
- ✅ Good tests → confident deployment

### **3. Incremental Value**
- ✅ Week 2: Pricing maintainability improved
- ✅ Week 4: Promotion & Return cleaner
- ✅ Week 10: Cart service launched
- ✅ Week 16: Return service launched

vs domain-split-first:
- ❌ No value until Week 10 (nothing shippable before)

---

## 🛠️ Execution Plan

### **Step 1: Refactor Critical Files (Immediate - Week 1-4)**

**Priority Order**:
1. ⭐ `pricing/service/pricing.go` (1743 lines) - **P0 blocker**
2. ⭐ `promotion/biz/promotion.go` (1426 lines) - **P0 blocker**
3. ⭐ `order/biz/return/return.go` (1576 lines) - **Foundation for future split**

**Checklist per file**:
- [ ] Create feature branches
- [ ] Split file into logical modules
- [ ] Run existing tests (should pass)
- [ ] Add new tests for extracted modules
- [ ] Code review
- [ ] Deploy to dev
- [ ] Deploy to staging
- [ ] Deploy to production (rolling update)

**Risk**: 🟢 Low - same service, incremental deployment

---

### **Step 2: Domain Split (Week 5-16)**

Follow `SERVICE_DOMAIN_SPLIT_PLAN.md` but with **cleaner codebase**:

**Phase 2.1: Cart Service Extraction (Week 5-10)**
- Extract `cart/` package (already clean from refactor)
- Database migration easier with organized code
- Clear API boundaries

**Phase 2.2: Return Service Extraction (Week 11-16)**
- Extract `return/` package (already clean from refactor)
- Event-driven workflows clear from state machine refactor

**Risk**: 🟡 Medium - but LOWER than if code was still messy

---

## 📋 Final Recommendation

### **DO THIS (Recommended)**:
```
Week 1-4:  Refactor 3 critical files (pricing, promotion, return)
Week 5-10: Extract Cart Service (from clean code)
Week 11-16: Extract Return Service (from clean code)
```

**Total Time**: 16 weeks  
**Risk**: Incremental (low risk each step)  
**Value**: Continuous delivery

### **DON'T DO THIS**:
```
Week 1-12: Domain split with messy code
Week 13-16: Refactor in multiple places
```

**Total Time**: 16 weeks  
**Risk**: High upfront (data migration with unclear code)  
**Value**: Back-loaded (nothing until Week 10)

---

## 🎯 Success Criteria

**After Week 4 (Refactor Complete)**:
- [ ] No files >1000 lines in critical paths
- [ ] All refactored code has >80% test coverage
- [ ] Code review time reduced by 30%
- [ ] New features can be added without fear

**After Week 16 (Domain Split Complete)**:
- [ ] Cart service independent (99.9% uptime)
- [ ] Return service independent (dedicated team)
- [ ] Order service simplified (<5000 LOC in /biz)

---

## 💡 Analogy

**Domain split first = Moving house with messy closets**
- You pack everything as-is
- Unpack in new house
- Still have mess, but now in 2 places
- Harder to find things

**Refactor first = Marie Kondo THEN move**
- Organize and declutter FIRST
- Pack neatly
- Unpack is easy
- Both old and new house are clean

---

**Decision**: ✅ **Refactor large files first, domain split second**  
**Next Action**: Start with `pricing/service/pricing.go` (Week 1)  
**Created**: 2026-01-22  
**Recommended By**: AI Senior Architect
