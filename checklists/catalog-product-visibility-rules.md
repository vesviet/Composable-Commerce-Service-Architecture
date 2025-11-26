# Catalog Product Visibility Rules - Design & Implementation Guide

**Service:** Catalog Service  
**Feature:** Product Visibility Rules (Show/Hide Products by Rules)  
**Created:** 2025-11-19  
**Status:** 🟡 Planning  
**Priority:** High

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Use Cases & Requirements](#use-cases--requirements)
3. [Rule Types & Patterns](#rule-types--patterns)
4. [Architecture Design](#architecture-design)
5. [Data Model](#data-model)
6. [API Design](#api-design)
7. [Integration Points](#integration-points)
8. [Implementation Checklist](#implementation-checklist)
9. [Security & Compliance](#security--compliance)

---

## Overview

### Problem Statement

Catalog service needs to support **conditional product visibility** based on various rules:
- **Age restrictions**: Products requiring age verification (18+, 21+)
- **Customer group restrictions**: VIP-only, B2B-only, or specific customer segments
- **Geographic restrictions**: Products not available in certain regions
- **Prescription requirements**: Products requiring valid prescription
- **License requirements**: Products requiring special licenses
- **Custom business rules**: Complex rules combining multiple conditions

### Solution

Implement a **flexible rule engine** in Catalog service that:
- Evaluates product visibility rules at query time
- Supports multiple rule types and conditions
- Integrates with Customer service for customer attributes
- Provides admin interface for rule management
- Ensures compliance with legal requirements

### Key Principles

- **Flexible Rule Engine**: Support multiple rule types and combinations
- **Performance**: Rule evaluation should be fast (cache rules, optimize queries)
- **Compliance**: Ensure legal requirements are met (age verification, prescription validation)
- **User Experience**: Clear messaging when products are hidden
- **Admin Control**: Easy-to-use interface for managing rules

---

## Use Cases & Requirements

### Use Case 1: Age-Restricted Products

**Scenario**: Alcohol, tobacco, or adult content products

**Requirements**:
- Products marked with minimum age requirement (18+, 21+)
- System verifies customer age before showing product
- Age verification can be:
  - Self-declared (with warning)
  - Verified via ID upload
  - Verified via third-party service (BlueCheck, etc.)

**Examples**:
- Wine/Beer: 18+ or 21+ (depending on region)
- Tobacco products: 18+ or 21+
- Adult content: 18+

### Use Case 2: Prescription-Required Products

**Scenario**: Pharmacy products requiring valid prescription

**Requirements**:
- Products marked as "prescription_required"
- System checks if customer has valid prescription
- Prescription validation can be:
  - Upload prescription document
  - Link to doctor's prescription system
  - Verify via pharmacy service

**Examples**:
- Prescription drugs
- Controlled substances
- Medical devices requiring prescription

### Use Case 3: Customer Group Restrictions

**Scenario**: Products visible only to specific customer groups

**Requirements**:
- Products visible to VIP customers only
- Products visible to B2B customers only
- Products visible to specific customer segments
- Products hidden from certain customer groups

**Examples**:
- VIP-only products (luxury items, exclusive deals)
- B2B-only products (wholesale pricing, bulk orders)
- Segment-based products (new customers, returning customers)

### Use Case 4: Geographic Restrictions

**Scenario**: Products not available in certain regions

**Requirements**:
- Products restricted by country/region
- Products restricted by state/province
- Products restricted by city/district
- Shipping restrictions

**Examples**:
- Alcohol not available in certain states
- Prescription drugs restricted by country
- Products with shipping limitations

### Use Case 5: License Requirements

**Scenario**: Products requiring special licenses

**Requirements**:
- Products requiring business license
- Products requiring professional license
- Products requiring import/export license
- License verification and validation

**Examples**:
- Medical equipment requiring business license
- Professional tools requiring certification
- Imported products requiring customs clearance

### Use Case 6: Complex Business Rules

**Scenario**: Multiple conditions combined

**Requirements**:
- Age + Customer group (e.g., VIP customers 21+)
- Geographic + Prescription (e.g., prescription drugs in specific regions)
- License + Customer group (e.g., B2B customers with business license)
- Custom rule combinations

---

## Rule Types & Patterns

### Rule Type 1: Age Restriction

**Pattern**:
```json
{
  "rule_type": "age_restriction",
  "min_age": 18,
  "verification_method": "self_declared" | "id_upload" | "third_party",
  "enforcement_level": "soft" | "hard"
}
```

**Evaluation**:
- Check customer's age from Customer service
- If age not verified, prompt for age verification
- Soft: show product with warning
- Hard: hide product completely

### Rule Type 2: Customer Group Restriction

**Pattern**:
```json
{
  "rule_type": "customer_group",
  "allowed_groups": ["VIP", "B2B", "Premium"],
  "denied_groups": ["New", "Inactive"],
  "match_type": "any" | "all"
}
```

**Evaluation**:
- Get customer groups from Customer service
- Check if customer belongs to allowed groups
- Check if customer belongs to denied groups
- Apply match logic (any/all)

### Rule Type 3: Geographic Restriction

**Pattern**:
```json
{
  "rule_type": "geographic",
  "restricted_countries": ["US", "CA"],
  "restricted_regions": ["CA", "NY"],
  "restricted_cities": ["San Francisco"],
  "restriction_type": "hide" | "require_verification"
}
```

**Evaluation**:
- Get customer location from Customer service or request header
- Check if location matches restricted areas
- Hide or require verification based on restriction_type

### Rule Type 4: Prescription Requirement

**Pattern**:
```json
{
  "rule_type": "prescription_required",
  "prescription_types": ["doctor", "pharmacy"],
  "verification_method": "upload" | "link" | "api",
  "enforcement_level": "soft" | "hard"
}
```

**Evaluation**:
- Check if customer has valid prescription
- Verify prescription via pharmacy service or document upload
- Soft: show product with prescription requirement notice
- Hard: hide product until prescription verified

### Rule Type 5: License Requirement

**Pattern**:
```json
{
  "rule_type": "license_required",
  "license_types": ["business", "professional", "import_export"],
  "verification_method": "upload" | "api",
  "enforcement_level": "soft" | "hard"
}
```

**Evaluation**:
- Check if customer has required license
- Verify license via document upload or API
- Soft: show product with license requirement notice
- Hard: hide product until license verified

### Rule Type 6: Custom Business Rule

**Pattern**:
```json
{
  "rule_type": "custom",
  "conditions": [
    {
      "field": "customer.age",
      "operator": ">=",
      "value": 21
    },
    {
      "field": "customer.group",
      "operator": "in",
      "value": ["VIP", "Premium"]
    }
  ],
  "logic": "AND" | "OR",
  "enforcement_level": "soft" | "hard"
}
```

**Evaluation**:
- Evaluate each condition
- Apply logic (AND/OR)
- Determine visibility based on result

---

## Architecture Design

### High-Level Architecture

```
┌─────────────────┐
│  Admin Dashboard│
│  (Rule Config)  │
└────────┬────────┘
         │
         ↓
┌─────────────────┐
│  Catalog Service│
│  (Rule Engine)  │
└────────┬────────┘
         │
         ├─── Customer Service (customer attributes)
         ├─── Pharmacy Service (prescription validation)
         ├─── Location Service (geographic data)
         └─── License Service (license validation)
```

### Rule Evaluation Flow

```
Product Query Request
  ↓
Get Product from Catalog
  ↓
Get Product Visibility Rules
  ↓
Get Customer Attributes (from Customer Service)
  ↓
Evaluate Rules (Rule Engine)
  ↓
  ├─── Age Restriction → Check customer age
  ├─── Customer Group → Check customer groups
  ├─── Geographic → Check customer location
  ├─── Prescription → Check prescription status
  ├─── License → Check license status
  └─── Custom → Evaluate custom conditions
  ↓
Determine Visibility
  ↓
  ├─── Visible → Return product
  ├─── Hidden → Filter out product
  └─── Requires Verification → Return with verification flag
```

### Rule Engine Design

**Components**:
1. **Rule Repository**: Store and retrieve rules
2. **Rule Evaluator**: Evaluate rules against customer context
3. **Rule Cache**: Cache rules for performance
4. **Rule Validator**: Validate rule configuration

**Evaluation Strategy**:
- **Lazy Evaluation**: Evaluate rules only when needed
- **Caching**: Cache rule results per customer/product combination
- **Batch Evaluation**: Evaluate multiple products at once
- **Early Exit**: Stop evaluation if hard rule fails

---

## Data Model

### Product Visibility Rule

```sql
CREATE TABLE product_visibility_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id),
    sku_id UUID REFERENCES skus(id),  -- Optional: rule per SKU
    rule_type VARCHAR(50) NOT NULL,  -- age_restriction, customer_group, etc.
    rule_config JSONB NOT NULL,  -- Rule-specific configuration
    priority INTEGER DEFAULT 0,  -- Higher priority = evaluated first
    enforcement_level VARCHAR(20) DEFAULT 'hard',  -- soft | hard
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    created_by UUID,
    updated_by UUID
);

CREATE INDEX idx_product_visibility_rules_product ON product_visibility_rules(product_id);
CREATE INDEX idx_product_visibility_rules_sku ON product_visibility_rules(sku_id);
CREATE INDEX idx_product_visibility_rules_type ON product_visibility_rules(rule_type);
CREATE INDEX idx_product_visibility_rules_active ON product_visibility_rules(is_active) WHERE is_active = true;
```

### Product Visibility Rule History

```sql
CREATE TABLE product_visibility_rule_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    rule_id UUID NOT NULL REFERENCES product_visibility_rules(id),
    action VARCHAR(20) NOT NULL,  -- created, updated, deleted, activated, deactivated
    old_config JSONB,
    new_config JSONB,
    changed_by UUID,
    changed_at TIMESTAMP DEFAULT NOW()
);
```

### Customer Verification Status

```sql
CREATE TABLE customer_verifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id UUID NOT NULL,
    verification_type VARCHAR(50) NOT NULL,  -- age, prescription, license
    verification_method VARCHAR(50),  -- self_declared, id_upload, third_party
    status VARCHAR(20) NOT NULL,  -- pending, verified, rejected, expired
    verified_data JSONB,  -- Verification details (age, prescription ID, etc.)
    verified_at TIMESTAMP,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW()
);

CREATE INDEX idx_customer_verifications_customer ON customer_verifications(customer_id);
CREATE INDEX idx_customer_verifications_type ON customer_verifications(verification_type);
CREATE INDEX idx_customer_verifications_status ON customer_verifications(status);
```

### Product Visibility Cache

```sql
-- Redis cache structure
-- Key: catalog:product:visibility:{product_id}:{customer_id}
-- Value: {visible: true/false, reason: "age_restriction", requires_verification: true}
-- TTL: 5 minutes
```

---

## API Design

### Admin APIs (Rule Management)

#### 1. Create Product Visibility Rule

```http
POST /api/v1/catalog/products/{product_id}/visibility-rules
Content-Type: application/json

{
  "sku_id": "optional-sku-id",
  "rule_type": "age_restriction",
  "rule_config": {
    "min_age": 18,
    "verification_method": "self_declared",
    "enforcement_level": "hard"
  },
  "priority": 10,
  "is_active": true
}
```

**Response**:
```json
{
  "id": "rule-uuid",
  "product_id": "product-uuid",
  "sku_id": "sku-uuid",
  "rule_type": "age_restriction",
  "rule_config": {...},
  "priority": 10,
  "enforcement_level": "hard",
  "is_active": true,
  "created_at": "2025-11-19T10:30:00Z"
}
```

#### 2. List Product Visibility Rules

```http
GET /api/v1/catalog/products/{product_id}/visibility-rules
Query Params:
  - rule_type: filter by rule type
  - is_active: filter by active status
  - page: pagination
  - page_size: pagination
```

#### 3. Update Product Visibility Rule

```http
PUT /api/v1/catalog/products/{product_id}/visibility-rules/{rule_id}
Content-Type: application/json

{
  "rule_config": {...},
  "priority": 20,
  "is_active": false
}
```

#### 4. Delete Product Visibility Rule

```http
DELETE /api/v1/catalog/products/{product_id}/visibility-rules/{rule_id}
```

#### 5. Bulk Apply Rules

```http
POST /api/v1/catalog/products/visibility-rules/bulk
Content-Type: application/json

{
  "product_ids": ["product-1", "product-2"],
  "rule_type": "customer_group",
  "rule_config": {
    "allowed_groups": ["VIP"]
  }
}
```

### Customer APIs (Verification)

#### 1. Submit Age Verification

```http
POST /api/v1/customers/{customer_id}/verifications/age
Content-Type: application/json

{
  "date_of_birth": "1990-01-01",
  "verification_method": "self_declared",
  "id_document": "base64-encoded-image"  // Optional for ID upload
}
```

#### 2. Submit Prescription Verification

```http
POST /api/v1/customers/{customer_id}/verifications/prescription
Content-Type: application/json

{
  "prescription_id": "prescription-uuid",
  "prescription_type": "doctor",
  "prescription_document": "base64-encoded-image",
  "doctor_name": "Dr. Smith",
  "expires_at": "2025-12-31"
}
```

#### 3. Get Customer Verification Status

```http
GET /api/v1/customers/{customer_id}/verifications
Query Params:
  - verification_type: filter by type (age, prescription, license)
```

### Product Query APIs (Visibility Check)

#### 1. Get Product with Visibility Check

```http
GET /api/v1/catalog/products/{product_id}
Headers:
  X-User-ID: customer-id
  X-Customer-Group: VIP
  X-Customer-Age: 25
  X-Customer-Location: US,CA,San Francisco
```

**Response** (if visible):
```json
{
  "id": "product-uuid",
  "name": "Product Name",
  "visible": true,
  "visibility_reason": null
}
```

**Response** (if hidden):
```json
{
  "id": "product-uuid",
  "name": "Product Name",
  "visible": false,
  "visibility_reason": "age_restriction",
  "visibility_message": "This product requires age 18+",
  "requires_verification": true,
  "verification_type": "age"
}
```

#### 2. List Products with Visibility Filter

```http
GET /api/v1/catalog/products
Query Params:
  - include_hidden: false (default: hide products that are not visible)
  - show_verification_required: true (show products requiring verification)
Headers:
  X-User-ID: customer-id
  X-Customer-Group: VIP
```

**Response**:
```json
{
  "products": [
    {
      "id": "product-1",
      "name": "Product 1",
      "visible": true
    },
    {
      "id": "product-2",
      "name": "Product 2",
      "visible": false,
      "visibility_reason": "customer_group",
      "requires_verification": false
    }
  ],
  "total": 100,
  "visible_count": 95,
  "hidden_count": 5
}
```

#### 3. Check Product Visibility (Bulk)

```http
POST /api/v1/catalog/products/visibility/check
Content-Type: application/json

{
  "product_ids": ["product-1", "product-2", "product-3"],
  "customer_id": "customer-uuid",
  "customer_context": {
    "age": 25,
    "groups": ["VIP"],
    "location": {
      "country": "US",
      "region": "CA",
      "city": "San Francisco"
    },
    "verifications": {
      "age": "verified",
      "prescription": "pending"
    }
  }
}
```

**Response**:
```json
{
  "results": [
    {
      "product_id": "product-1",
      "visible": true,
      "reason": null
    },
    {
      "product_id": "product-2",
      "visible": false,
      "reason": "age_restriction",
      "requires_verification": true
    },
    {
      "product_id": "product-3",
      "visible": false,
      "reason": "prescription_required",
      "requires_verification": true
    }
  ]
}
```

---

## Integration Points

### Customer Service Integration

**Purpose**: Get customer attributes for rule evaluation

**Endpoints**:
- `GET /api/v1/customers/{customer_id}` - Get customer profile
- `GET /api/v1/customers/{customer_id}/groups` - Get customer groups
- `GET /api/v1/customers/{customer_id}/verifications` - Get verification status

**Data Needed**:
- Age/Date of birth
- Customer groups/segments
- Location (country, region, city)
- Verification status (age, prescription, license)

### Pharmacy Service Integration (Future)

**Purpose**: Validate prescription requirements

**Endpoints**:
- `POST /api/v1/pharmacy/prescriptions/validate` - Validate prescription
- `GET /api/v1/pharmacy/prescriptions/{prescription_id}` - Get prescription details

### Location Service Integration

**Purpose**: Get geographic restrictions

**Endpoints**:
- `GET /api/v1/location/restrictions/{product_id}` - Get product location restrictions
- `GET /api/v1/location/validate` - Validate customer location against restrictions

---

## Implementation Checklist

### Phase 1: Data Model & Core Infrastructure

- [ ] **Database Schema**
  - [ ] Create `product_visibility_rules` table
  - [ ] Create `product_visibility_rule_history` table
  - [ ] Create `customer_verifications` table (in Customer service)
  - [ ] Create indexes for performance
  - [ ] Create migration scripts

- [ ] **Domain Models**
  - [ ] Define `ProductVisibilityRule` entity
  - [ ] Define `RuleConfig` structs for each rule type
  - [ ] Define `CustomerContext` struct
  - [ ] Define `VisibilityResult` struct

- [ ] **Repository Layer**
  - [ ] Implement `ProductVisibilityRuleRepository`
  - [ ] Implement CRUD operations
  - [ ] Implement query methods (by product, by rule type, etc.)

### Phase 2: Rule Engine

- [ ] **Rule Evaluator**
  - [ ] Implement base `RuleEvaluator` interface
  - [ ] Implement `AgeRestrictionEvaluator`
  - [ ] Implement `CustomerGroupEvaluator`
  - [ ] Implement `GeographicEvaluator`
  - [ ] Implement `PrescriptionRequirementEvaluator`
  - [ ] Implement `LicenseRequirementEvaluator`
  - [ ] Implement `CustomRuleEvaluator`

- [ ] **Rule Engine Core**
  - [ ] Implement rule loading and caching
  - [ ] Implement rule evaluation orchestration
  - [ ] Implement priority-based evaluation
  - [ ] Implement early exit optimization
  - [ ] Implement batch evaluation

- [ ] **Caching Strategy**
  - [ ] Cache rules per product (Redis)
  - [ ] Cache visibility results per customer/product (Redis)
  - [ ] Implement cache invalidation on rule updates
  - [ ] Set appropriate TTLs

### Phase 3: API Integration

- [ ] **Product Query Integration**
  - [ ] Integrate visibility check in `GetProduct` endpoint
  - [ ] Integrate visibility filter in `ListProducts` endpoint
  - [ ] Integrate visibility filter in `SearchProducts` endpoint
  - [ ] Add visibility metadata to product responses

- [ ] **Customer Service Integration**
  - [ ] Implement customer client for fetching customer attributes
  - [ ] Implement customer context builder
  - [ ] Handle customer service failures gracefully

- [ ] **Header Processing**
  - [ ] Extract customer context from headers (X-User-ID, X-Customer-Group, etc.)
  - [ ] Validate and sanitize customer context
  - [ ] Fallback to default context if headers missing

### Phase 4: Admin APIs

- [ ] **Rule Management APIs**
  - [ ] `POST /api/v1/catalog/products/{id}/visibility-rules` - Create rule
  - [ ] `GET /api/v1/catalog/products/{id}/visibility-rules` - List rules
  - [ ] `PUT /api/v1/catalog/products/{id}/visibility-rules/{rule_id}` - Update rule
  - [ ] `DELETE /api/v1/catalog/products/{id}/visibility-rules/{rule_id}` - Delete rule
  - [ ] `POST /api/v1/catalog/products/visibility-rules/bulk` - Bulk apply rules

- [ ] **Rule Validation**
  - [ ] Validate rule configuration
  - [ ] Validate rule conflicts
  - [ ] Validate rule priority

- [ ] **Rule History**
  - [ ] Track rule changes
  - [ ] Implement audit logging
  - [ ] Provide history API

### Phase 5: Customer Verification (Customer Service)

- [ ] **Verification APIs**
  - [ ] `POST /api/v1/customers/{id}/verifications/age` - Submit age verification
  - [ ] `POST /api/v1/customers/{id}/verifications/prescription` - Submit prescription
  - [ ] `POST /api/v1/customers/{id}/verifications/license` - Submit license
  - [ ] `GET /api/v1/customers/{id}/verifications` - Get verification status

- [ ] **Verification Processing**
  - [ ] Implement age verification logic
  - [ ] Implement prescription validation (future: integrate with pharmacy)
  - [ ] Implement license validation
  - [ ] Implement verification expiration

### Phase 6: Frontend Integration

- [ ] **Product Display**
  - [ ] Handle hidden products gracefully
  - [ ] Show verification required messages
  - [ ] Implement age gate UI
  - [ ] Implement prescription upload UI

- [ ] **Admin Dashboard**
  - [ ] Rule management UI
  - [ ] Rule configuration forms
  - [ ] Rule testing interface
  - [ ] Visibility preview

### Phase 7: Testing & Validation

- [ ] **Unit Tests**
  - [ ] Test each rule evaluator
  - [ ] Test rule engine orchestration
  - [ ] Test rule caching
  - [ ] Test edge cases

- [ ] **Integration Tests**
  - [ ] Test product query with visibility rules
  - [ ] Test customer service integration
  - [ ] Test rule management APIs
  - [ ] Test verification flow

- [ ] **Performance Tests**
  - [ ] Test rule evaluation performance
  - [ ] Test cache hit rates
  - [ ] Test batch evaluation performance
  - [ ] Optimize slow queries

### Phase 8: Documentation & Monitoring

- [ ] **Documentation**
  - [ ] API documentation
  - [ ] Rule configuration guide
  - [ ] Admin user guide
  - [ ] Compliance guidelines

- [ ] **Monitoring**
  - [ ] Metrics for rule evaluation performance
  - [ ] Metrics for visibility check rates
  - [ ] Metrics for verification submission rates
  - [ ] Alerts for rule evaluation failures

---

## Security & Compliance

### Age Verification Compliance

- [ ] **COPPA Compliance** (Children's Online Privacy Protection Act)
  - [ ] Do not collect data from users under 13
  - [ ] Implement age gate for age-restricted products
  - [ ] Store age verification securely

- [ ] **Age Verification Methods**
  - [ ] Self-declared (with warning) - for soft enforcement
  - [ ] ID upload - for hard enforcement
  - [ ] Third-party verification (BlueCheck, etc.) - for strict compliance

### Prescription Validation Compliance

- [ ] **Pharmacy Regulations**
  - [ ] Validate prescription before allowing purchase
  - [ ] Store prescription data securely (HIPAA compliance if applicable)
  - [ ] Implement prescription expiration checks
  - [ ] Integrate with licensed pharmacy services

### Data Privacy

- [ ] **Customer Data Protection**
  - [ ] Encrypt sensitive verification data
  - [ ] Implement data retention policies
  - [ ] Provide data deletion capabilities
  - [ ] Comply with GDPR/CCPA requirements

### Audit & Logging

- [ ] **Audit Trail**
  - [ ] Log all rule evaluations
  - [ ] Log verification submissions
  - [ ] Log rule changes (who, when, what)
  - [ ] Retain audit logs for compliance

---

## Example Rule Configurations

### Example 1: Age-Restricted Alcohol Product

```json
{
  "product_id": "wine-product-uuid",
  "rule_type": "age_restriction",
  "rule_config": {
    "min_age": 21,
    "verification_method": "id_upload",
    "enforcement_level": "hard",
    "message": "This product requires age 21+ verification"
  },
  "priority": 10,
  "is_active": true
}
```

### Example 2: VIP-Only Product

```json
{
  "product_id": "luxury-product-uuid",
  "rule_type": "customer_group",
  "rule_config": {
    "allowed_groups": ["VIP", "Premium"],
    "match_type": "any",
    "message": "This product is available to VIP customers only"
  },
  "priority": 5,
  "is_active": true
}
```

### Example 3: Prescription-Required Medicine

```json
{
  "product_id": "prescription-drug-uuid",
  "rule_type": "prescription_required",
  "rule_config": {
    "prescription_types": ["doctor", "pharmacy"],
    "verification_method": "upload",
    "enforcement_level": "hard",
    "message": "This product requires a valid prescription"
  },
  "priority": 20,
  "is_active": true
}
```

### Example 4: Geographic Restriction

```json
{
  "product_id": "restricted-product-uuid",
  "rule_type": "geographic",
  "rule_config": {
    "restricted_countries": ["US"],
    "restricted_regions": ["CA", "NY"],
    "restriction_type": "hide",
    "message": "This product is not available in your region"
  },
  "priority": 15,
  "is_active": true
}
```

### Example 5: Complex Rule (Age + Customer Group)

```json
{
  "product_id": "premium-alcohol-uuid",
  "rule_type": "custom",
  "rule_config": {
    "conditions": [
      {
        "field": "customer.age",
        "operator": ">=",
        "value": 21
      },
      {
        "field": "customer.group",
        "operator": "in",
        "value": ["VIP", "Premium"]
      }
    ],
    "logic": "AND",
    "enforcement_level": "hard",
    "message": "This product requires age 21+ and VIP membership"
  },
  "priority": 25,
  "is_active": true
}
```

---

## Success Criteria

- [ ] ✅ Rule evaluation performance <50ms (p95)
- [ ] ✅ Support 10+ rule types
- [ ] ✅ Support complex rule combinations
- [ ] ✅ 99.9% rule evaluation accuracy
- [ ] ✅ Admin can create/update rules via API
- [ ] ✅ Frontend handles hidden products gracefully
- [ ] ✅ Compliance with age verification requirements
- [ ] ✅ Compliance with prescription validation requirements

---

## References

- Age Verification Services: BlueCheck, Veratad, etc.
- Pharmacy Regulations: FDA, local pharmacy boards
- Data Privacy: GDPR, CCPA, HIPAA (if applicable)
- Catalog Service: `catalog/internal/biz/product/`
- Customer Service: `customer/internal/biz/customer/`

---

**Last Updated**: 2025-11-19  
**Status**: Planning Phase

