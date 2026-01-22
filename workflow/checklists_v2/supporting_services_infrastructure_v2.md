# Supporting Services & Infrastructure - Quality Review V2 Summary

**Last Updated**: 2026-01-22  
**Scope**: All remaining microservices and infrastructure  
**Coverage**: Catalog, Search, Customer, Auth, Shipping, Notification, Location, Review, Tax, Return/Refund, Common Package, Gateway, Infrastructure

---

## 📊 Executive Summary

This consolidated checklist covers **supporting services and infrastructure** that don't require full dedicated v2 checklists but have important quality issues.

**Overall Assessment**: Mixed maturity (5/10 to 8/10 depending on service)

---

## 🗂️ Service-by-Service Summary

### 1. Catalog Service (Score: 7/10)

**Critical Issues**:
- **[P0]** No authentication on Create/Update Product endpoints
- **[P0]** N+1 query in product listing with attributes
- **[P1]** Product SKU uniqueness not enforced at DB level
- **[P1]** No caching for product details (high read traffic)

**Recommendations**:
- Add admin role check for write endpoints (1d)
- Use GORM `Preload("Attributes")` (1d)
- Add UNIQUE constraint on SKU column (0.5d)
- Redis cache with TTL for product details (2d)

---

### 2. Search Service (Score: 6.5/10)

**Critical Issues**:
- **[P1]** Event subscriptions fail silently when config nil
- **[P1]** Search index sync lag causes stale results
- **[P2]** No faceted search optimization

**Recommendations**:
- Fail-fast on missing config (0.5d)
- Real-time index updates via Kafka/Dapr (3d)
- Elasticsearch aggregations for facets (2d)

---

### 3. Customer Service (Score: 7/10)

**Critical Issues**:
- **[P0]** Profile update race condition (no optimistic locking)
- **[P0]** Hardcoded database credentials in config
- **[P0]** Missing input sanitization (XSS/SQL injection risk)
- **[P1]** Customer segment cache not invalidated on updates

**Recommendations**:
- Add version field + optimistic locking (2d)
- Move credentials to env vars/K8s Secrets (1d)
- Input validation using `common/utils/validation` (2d)
- Cache invalidation on profile changes (2d)

---

### 4. Auth Service (Score: 6/10)

**Critical Issues**:
- **[P0]** JWT signing key from ENV, no rotation support
- **[P1]** Password reset tokens not invalidated after use
- **[P1]** No refresh token pattern (users logged out on expiry)

**Recommendations**:
- Load keys from secret manager with rotation (3d)
- Mark tokens as used in database (1d)
- Implement refresh token with sliding window (3d)

---

### 5. Shipping Service (Score: 7/10)

**Critical Issues**:
- **[P0]** Carrier integration failure blocks shipment creation
- **[P0]** Tracking number uniqueness not enforced
- **[P1]** No caching for carrier rate calculations

**Recommendations**:
- Async carrier processing with fallback (3d)
- Add UNIQUE constraint on `tracking_number + carrier_code` (0.5d)
- Cache rates by origin/destination/weight for 1hr (2d)

---

### 6. Notification Service (Score: 7/10)

**Critical Issues**:
- **[P1]** Email sending blocks on SMTP connection
- **[P1]** No template versioning for email templates
- **[P2]** Missing notification preferences management

**Recommendations**:
- Asynchronous queue + worker pattern (2d)
- Template versioning system (2d)
- User preference management UI (3d)

---

### 7. Review Service (Score: 6/10)

**Critical Issues**:
- **[P0]** Purchase verification bypass (stub returns true)
- **[P1]** Review moderation queue missing
- **[P1]** Limited authenticity verification

**Recommendations**:
- Implement real gRPC calls to Order service (2d)
- Content moderation pipeline + manual queue (4d)
- Enhanced purchase verification (3d)

---

### 8. Common Package & Infrastructure (Score: 6/10)

**Critical Issues**:
- **[P0]** Database connection strings include credentials in logs
- **[P1]** JSONMetadata helper functions scattered (code duplication)
- **[P1]** No standardized error code mappings across services
- **[P2]** Health check implementations vary by service

**Recommendations**:
- Redact passwords before logging (0.5d)
- Consolidate into `common/utils/metadata` package (2d)
- Document + standardize error codes in common package (2d)
- Standardize health check format (RFC 7807) (2d)

---

### 9. Gateway Service (Score: 6.5/10)

**Critical Issues** (See payment_security_v2.md for details):
- **[P0]** Missing circuit breakers and timeouts
- **[P0]** Rate limiting bypass vulnerability
- **[P0]** Permissive CORS configuration
- **[P1]** Request ID not globally unique
- **[P1]** Hardcoded service ports (no dynamic discovery)

**Recommendations**: See payment_security_v2.md remediation roadmap

---

### 10. Tax & Location Services (Score: 7.5/10)

**Minor Issues**:
- **[P1]** Tax rate lookup queries without index on (country_code, state)
- **[P1]** Location service lacking reverse geocoding
- **[P2]** No tax calculation audit trail

**Recommendations**:
- Add composite index on tax_rates table (0.5d)
- Integrate Google Maps Geocoding API (2d)
- Audit logging for tax calculations (1d)

---

### 11. Return & Refund Service (Score: 6.5/10)

**Critical Issues**:
- **[P1]** Return-to-stock automation missing
- **[P1]** Refund processing not idempotent
- **[P2]** No return fraud detection

**Recommendations**:
- Automated stock restoration workflow (3d)
- Idempotency keys for refund processing (2d)
- Basic fraud rules (excessive returns) (3d)

---

## 🛠️ Cross-Cutting Recommendations

### Configuration Management
- Standardize config schema across services (Viper validation)
- Move all secrets to K8s Secrets or Vault
- Environment-specific config validation at startup

### Observability
- Complete distributed tracing spans (OpenTelemetry)
- Standardize JSON logging format
- Centralized metrics dashboard (Grafana)

### Testing
- End-to-end tests for critical flows (testcontainers)
- Standardize mock generation (mockgen)
- Achieve 80%+ coverage in business logic

### Security
- Per-customer rate limiting (Redis-based)
- Comprehensive input validation middleware
- API documentation with security sections

---

## 📋 Consolidated Issues Count

| Priority | Count | Key Areas |
|----------|-------|-----------|
| **P0** | ~15 | Auth (keys), Catalog (auth), Customer (race), Shipping (carrier), Review (verification), Common (credentials) |
| **P1** | ~25 | Caching, moderation, idempotency, analytics, indexes |
| **P2** | ~20 | Documentation, monitoring, performance optimization |

**Total**: ~60 issues across supporting services

---

## 🔍 Quick Verification Commands

```bash
# Check for hardcoded credentials
grep -r "password.*=.*\"" */configs/ --exclude-dir=vendor

# Find services without health checks
for svc in catalog customer auth shipping notification review; do
  curl -f http://localhost:8080/$svc/health || echo "$svc: NO HEALTH CHECK"
done

# Verify secret management
kubectl get secrets -n dev | grep -E "db-|jwt-|api-"

# Check distributed tracing coverage
stern -n dev '*' --since=5m | grep -c "trace_id" 
```

---

## 📖 Related Documentation

- **Primary Checklists**: [cart_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/cart_flow_v2.md), [checkout_flow_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/checkout_flow_v2.md), [order_fulfillment_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/order_fulfillment_v2.md)
- **Supporting Checklists**: [payment_security_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/payment_security_v2.md), [inventory_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/inventory_v2.md), [pricing_promotion_v2.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/workflow/checklists_v2/pricing_promotion_v2.md)
- **Team Lead Guide**: [TEAM_LEAD_CODE_REVIEW_GUIDE.md](file:///Users/tuananh/Desktop/myproject/microservice/docs/TEAM_LEAD_CODE_REVIEW_GUIDE.md)

---

**Review Completed**: 2026-01-22  
**Coverage**: 11 supporting services + infrastructure  
**Reviewer**: AI Senior Code Review (Team Lead Standards)

**Note**: This summary checklist consolidates findings for services that don't require full flow-specific v2 checklists. For critical flows (Cart, Checkout, Order, Payment, Inventory), refer to dedicated v2 checklists.
