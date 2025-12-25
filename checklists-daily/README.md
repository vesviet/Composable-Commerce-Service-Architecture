# Daily Checklists

Thư mục này chứa các checklist hàng ngày để review và maintain microservices system.

## 📋 Available Checklists

### 1. [Module Path và Git Tag Review](./module-path-and-tag-review.md)
**Mục đích:** Review và đảm bảo tất cả services có module path đúng và Git tag phù hợp

**Tần suất:** Daily  
**Thời gian:** ~30 phút  
**Ưu tiên:** High

**Nội dung:**
- ✅ Kiểm tra module path theo convention
- ✅ Verify Git tags cho releases
- ✅ Standardize Go versions
- ✅ Build verification

### 2. [Service Dependencies Review](./service-dependencies-review.md)
**Mục đích:** Review HTTP calls internal, gRPC connections và service dependencies

**Tần suất:** Daily  
**Thời gian:** ~45 phút  
**Ưu tiên:** High

**Nội dung:**
- 🔍 HTTP internal calls monitoring
- 🔧 gRPC connections health
- ⚡ Circuit breakers status
- 🌐 Service URL configurations
- 📊 Performance metrics

### 3. [HTTP to gRPC Migration](./http-to-grpc-migration.md)
**Mục đích:** Systematic migration từ HTTP sang gRPC cho internal service communication

**Tần suất:** Daily (during migration period)  
**Thời gian:** ~60 phút  
**Ưu tiên:** Critical

**Nội dung:**
- 🎯 Migration strategy và priority
- 🚨 Critical HTTP → gRPC conversions
- 🔧 Technical implementation steps
- 📊 Performance tracking
- 🚨 Rollback procedures

### 4. [gRPC Client Implementation Checklist](./grpc-client-implementation-checklist.md)
**Mục đích:** Comprehensive checklist cho gRPC client implementation across all microservices

**Tần suất:** Weekly (during implementation phase)  
**Thời gian:** ~90 phút  
**Ưu tiên:** High

**Nội dung:**
- 🔴 Circuit Breakers & Resilience
- 🟡 Performance Optimization (Connection Pooling, Compression, Keep-Alive)
- 🟡 Error Handling & Status Codes
- 🟡 Observability & Tracing (Metrics, Logging, Tracing)
- 🟢 Testing (Unit, Integration, Load Tests)

**Services Covered:**
- Order Service (10 gRPC clients)
- Catalog Service (4 gRPC clients)
- Warehouse Service (4 gRPC clients)
- Customer Service (1 gRPC client) - ⚠️ CRITICAL improvements needed
- Gateway Service (1 gRPC client)
- Search Service (3 gRPC clients)

## 🗓️ Daily Schedule

| Time | Checklist | Assignee | Duration |
|------|-----------|----------|----------|
| 09:00 | Module Path & Tag Review | DevOps Team | 30 min |
| 09:30 | Service Dependencies Review | Backend Team | 45 min |
| 10:15 | HTTP to gRPC Migration | Architecture Team | 60 min |
| 11:15 | Issues Discussion | All Teams | 15 min |

## 📊 Weekly Summary

Mỗi tuần tạo summary report từ daily checklists:

### Template Weekly Report:
```markdown
# Weekly Summary - [Week of YYYY-MM-DD]

## Module Path & Tag Issues
- Fixed: X issues
- Pending: Y issues
- New: Z issues

## Service Dependencies
- Circuit breaker improvements: X
- Performance optimizations: Y
- New monitoring: Z

## HTTP to gRPC Migration
- Services migrated: X/6
- Performance improvements: Y%
- Issues encountered: Z

## Action Items for Next Week
- [ ] Action 1
- [ ] Action 2
- [ ] Action 3
```

## 🚀 Automation Goals

### Short-term (1-2 weeks):
- [ ] Script để auto-check module paths
- [ ] Script để batch create Git tags
- [ ] Automated Go version updates
- [ ] Proto file generation automation
- [ ] gRPC client code generation

### Medium-term (1 month):
- [ ] CI/CD integration cho module path validation
- [ ] Automated circuit breaker monitoring
- [ ] Performance metrics dashboard
- [ ] gRPC migration progress tracking
- [ ] Automated rollback mechanisms

### Long-term (3 months):
- [ ] Full automation của daily checks
- [ ] Predictive issue detection
- [ ] Self-healing mechanisms
- [ ] Complete gRPC migration
- [ ] Advanced service mesh integration

## 📞 Escalation Process

### Level 1: Team Lead
- Module path conflicts
- Missing Git tags blocking development
- Minor performance issues

### Level 2: Architecture Team
- Major service dependency issues
- Circuit breaker failures
- Cross-service communication problems
- gRPC migration blocking issues
- Performance degradation > 50%

### Level 3: CTO/VP Engineering
- System-wide outages
- Critical security issues
- Major architecture changes needed
- Complete migration rollback required

## 📝 How to Use

1. **Daily Execution:**
   - Assign checklist to team member
   - Complete all items in checklist
   - Document issues and actions taken
   - Update metrics and status

2. **Issue Tracking:**
   - Log all issues found
   - Assign priority levels
   - Track resolution progress
   - Update documentation

3. **Continuous Improvement:**
   - Review checklist effectiveness weekly
   - Add new items based on recurring issues
   - Remove obsolete checks
   - Optimize automation opportunities

## 🔧 Tools Required

- **Git** - For tag management
- **Go** - For build verification
- **kubectl** - For Kubernetes monitoring
- **curl** - For health checks
- **Docker** - For container management
- **buf** - For Protocol Buffer management
- **grpcurl** - For gRPC testing
- **protoc** - For proto compilation

## 📚 Related Documentation

- [Service Architecture Overview](../architecture/)
- [Deployment Guide](../deployment/)
- [Monitoring Setup](../monitoring/)
- [Troubleshooting Guide](../troubleshooting/)

---

**Last Updated:** 2025-01-01  
**Maintained By:** DevOps Team  
**Review Frequency:** Weekly