# 🔄 Business Process Flows

- **Purpose**: Detailed business process flows and sequence diagrams based on actual implementation
- **Last Updated**: February 7, 2026
- **Platform Scope**: 23 deployable services; current runtime maturity is tracked in [SERVICE_INDEX.md](../SERVICE_INDEX.md)
- **Navigation**: [← Business Domains](../02-business-domains/README.md) | [← Back to Main](../README.md) | [Services →](../03-services/README.md)

---

## 📋 **What's in This Section**

This section contains detailed documentation of business processes, user journeys, and system workflows based on the actual implementation of our **23 deployable service platform**. It bridges the gap between business requirements and technical implementation with visual diagrams and step-by-step process descriptions.

> [!IMPORTANT]
> Workflow documents describe business behavior and service interactions. They are not the source of truth for per-service maturity or deploy readiness. Use [SERVICE_INDEX.md](../SERVICE_INDEX.md) for service maturity and [../../gitops/README.md](../../gitops/README.md) plus the [GitOps review checklist](../10-appendix/checklists/gitops/review_checklist.md) for deployment/runtime status.

### **📚 Workflow Categories**

#### **[Customer Journey](customer-journey/)**
End-to-end customer-facing processes
- **[browse-to-purchase.md](customer-journey/browse-to-purchase.md)** - Complete shopping journey from discovery to delivery
- **[account-management.md](customer-journey/account-management.md)** - Customer registration, profile, and authentication flows
- **[wishlist.md](customer-journey/wishlist.md)** - Wishlist management, back-in-stock and price-drop notification flows
- **[guest-checkout.md](customer-journey/guest-checkout.md)** - Guest cart, anonymous checkout, cart merge on login, post-purchase account creation
- **[returns-exchanges.md](customer-journey/returns-exchanges.md)** - Return and exchange processes, seller appeal, chargeback handling, partial refund negotiation
- **[loyalty-rewards.md](customer-journey/loyalty-rewards.md)** - Loyalty program, points, and rewards workflows
- **[product-reviews.md](customer-journey/product-reviews.md)** - Product review and rating workflows

#### **[Operational Flows](operational-flows/)**
Internal business operations and processes
- **[order-fulfillment.md](operational-flows/order-fulfillment.md)** - Complete order processing and fulfillment workflow
- **[inventory-management.md](operational-flows/inventory-management.md)** - Stock management, reservations, and capacity planning
- **[payment-processing.md](operational-flows/payment-processing.md)** - Multi-gateway payment flows, BNPL, QR, escrow, and chargeback handling
- **[pricing-promotions.md](operational-flows/pricing-promotions.md)** - Dynamic pricing and promotion management
- **[shipping-logistics.md](operational-flows/shipping-logistics.md)** - Multi-carrier shipping and delivery tracking
- **[quality-control.md](operational-flows/quality-control.md)** - Warehouse QC: scan-to-verify, weight check, photo documentation, damage disposition
- **[customer-service-workflow.md](operational-flows/customer-service-workflow.md)** - Customer support operations and ticket management
- **[seller-merchant.md](operational-flows/seller-merchant.md)** - Seller onboarding, KYC, order ops, performance scoring, escrow/payout, B2B
- **[admin-operations.md](operational-flows/admin-operations.md)** - RBAC, CS agent operations, seller governance, platform config, campaign management
- **[analytics-reporting.md](operational-flows/analytics-reporting.md)** - Funnel analysis, RFM/cohort, A/B testing, payout reconciliation, tax reporting

#### **[Integration Flows](integration-flows/)**
System integrations and data synchronization
- **[event-processing.md](integration-flows/event-processing.md)** - Event-driven architecture flows across 23 services
- **[data-synchronization.md](integration-flows/data-synchronization.md)** - Data sync patterns overview (product, price, stock)
- **[real-time-data-sync.md](integration-flows/real-time-data-sync.md)** - Detailed real-time sync implementation (events, cache, search index)
- **[external-apis.md](integration-flows/external-apis.md)** - Third-party integrations (payment gateways, shipping carriers)
- **[search-indexing.md](integration-flows/search-indexing.md)** - Elasticsearch indexing and search workflows
- **[reservation-release-flows.md](integration-flows/reservation-release-flows.md)** - Stock reservation and release workflows
- **[idempotency-saga.md](integration-flows/idempotency-saga.md)** - Outbox pattern, Saga choreography/orchestration, DLQ retry, payment callback idempotency
- **[3pl-delivery-webhook-flow.md](integration-flows/3pl-delivery-webhook-flow.md)** - 3PL carrier delivery webhook integration

#### **[Sequence Diagrams](sequence-diagrams/)**
Visual representations of system interactions
- **[complete-order-flow.mmd](sequence-diagrams/complete-order-flow.mmd)** - End-to-end order creation sequence
- **[checkout-payment-flow.mmd](sequence-diagrams/checkout-payment-flow.mmd)** - Checkout and payment processing sequence
- **[fulfillment-shipping-flow.mmd](sequence-diagrams/fulfillment-shipping-flow.mmd)** - Fulfillment and shipping workflow
- **[return-refund-flow.mmd](sequence-diagrams/return-refund-flow.mmd)** - Return and refund processing sequence
- **[search-discovery-flow.mmd](sequence-diagrams/search-discovery-flow.mmd)** - Product search and discovery workflow
- **[user-authentication-flow.mmd](sequence-diagrams/user-authentication-flow.mmd)** - User authentication and authorization flow
- **[inventory-management-flow.mmd](sequence-diagrams/inventory-management-flow.mmd)** - Real-time inventory synchronization
- **[notification-workflow.mmd](sequence-diagrams/notification-workflow.mmd)** - Multi-channel notification processing

---

## 🎯 **Platform Overview**

### **Service Architecture (23 Deployable Services)**
Our workflows span across 23 specialized microservices organized into clear categories:

**Core Business Services (13):**
- 🔐 Auth Service (authentication, JWT, OAuth2, MFA)
- 👥 User Service (admin users, RBAC, permissions)
- 👤 Customer Service (profiles, addresses, segments)
- 📦 Catalog Service (products, EAV attributes, categories, CMS)
- 💰 Pricing Service (dynamic pricing, discounts, tax)
- 🎯 Promotion Service (campaigns, coupons, BOGO)
- 🛍️ Checkout Service (cart management, checkout orchestration)
- 🛒 Order Service (order lifecycle, status management)
- 💳 Payment Service (multi-gateway, PCI DSS compliant)
- 📊 Warehouse Service (inventory, stock reservations, capacity)
- 📋 Fulfillment Service (pick, pack, ship workflow)
- 🚚 Shipping Service (multi-carrier integration, tracking)
- ↩️ Return Service (returns, exchanges, refunds)

**Platform Services (5):**
- 🚪 Gateway Service (API routing, rate limiting, security)
- 🔍 Search Service (Elasticsearch, analytics, recommendations)
- 📈 Analytics Service (business intelligence, dashboards)
- ⭐ Review Service (ratings, reviews, moderation)
- 🔧 Common Operations Service (task orchestration, file ops)

**Operational Services (5):**
- 📧 Notification Service (email, SMS, push, in-app)
- 🗺️ Location Service (geographic hierarchy, address validation)
- 🎁 Loyalty Rewards Service (points, tiers, rewards)
- 💻 Admin Service (admin panel frontend - React)
- 🌐 Frontend Service (customer frontend - Next.js)

**Infrastructure Services (5 - Non-deployable):**
- Common library (shared code)
- GitLab CI templates (CI/CD)
- GitOps repository (Kustomize manifests)
- K8s local configs (development)
- ArgoCD configs (deprecated - migrated to GitOps)

### **Event-Driven Architecture**
- **89+ Event Types** across all business domains
- **Dapr Pub/Sub** with Redis backend for reliable messaging
- **Event Sourcing** patterns for audit trails and replay capability
- **Saga Patterns** for distributed transaction management
- **CloudEvents Format** for standardized event structure

### **Deployment Architecture**
- **GitOps**: Kustomize-based deployment with ArgoCD
- **Kubernetes**: Container orchestration with K8s 1.29+
- **Sync Waves**: Ordered deployment (35-45 minutes full platform)
- **Environments**: Dev, Staging, Production with overlays
- **Monitoring**: Prometheus + Grafana + Jaeger

---

## 🔄 **Core Business Workflows**

### **1. Complete Customer Journey (Browse to Purchase)**
**Services:** Gateway → Search → Catalog → Checkout → Order → Payment → Fulfillment → Shipping → Notification

**Key Phases:**
1. **Discovery:** Product search, filtering, recommendations
2. **Engagement:** Cart management, promotion application
3. **Purchase:** Checkout orchestration, payment processing
4. **Fulfillment:** Pick, pack, ship workflow with QC
5. **Delivery:** Multi-carrier shipping with tracking
6. **Post-Purchase:** Reviews, loyalty points, returns

### **2. Order Fulfillment Workflow**
**Services:** Order → Fulfillment → Warehouse → Shipping → Notification

**Key Phases:**
1. **Planning:** Warehouse assignment, time slot allocation
2. **Picking:** Zone-optimized picking lists, staff assignment
3. **Packing:** Weight verification, packing slip generation
4. **Quality Control:** High-value orders (100%), random sampling (10%)
5. **Shipping:** Label generation, carrier handover, tracking

### **3. Inventory Management Workflow**
**Services:** Warehouse → Search → Catalog → Analytics

**Key Operations:**
1. **Stock Tracking:** Real-time levels, movement audit trails
2. **Reservations:** Order-based stock holds with TTL
3. **Capacity Management:** Daily/hourly limits, time slots
4. **Synchronization:** Real-time updates to search index and catalog

### **4. Payment Processing Workflow**
**Services:** Payment → Order → Notification

**Payment Methods:**
- Credit/Debit Cards (Stripe)
- E-wallets (PayPal, VNPay, MoMo)
- Cash on Delivery (COD)
- Bank Transfer (VNPay)

**Key Phases:**
1. **Authorization:** Payment method validation, fraud detection
2. **Capture:** Funds transfer after order confirmation
3. **Reconciliation:** Gateway webhook processing
4. **Refunds:** Full/partial refunds with compensation logic

---

## 📊 **Workflow Documentation Standards**

### **📋 Required Elements**
Each workflow document includes:
- **Service Architecture:** All participating services and their roles
- **Event Flow:** Complete event sequence with Dapr topics
- **API Interactions:** gRPC/HTTP calls between services
- **Business Rules:** Validation logic and constraints
- **Error Handling:** Compensation patterns and retry logic
- **Performance Metrics:** SLA targets and monitoring
- **Security Controls:** Authentication, authorization, audit trails

### **🎨 Visual Standards**
- **Mermaid Sequence Diagrams:** Service-to-service interactions
- **Mermaid Flowcharts:** Business logic and decision flows
- **Mermaid State Diagrams:** Entity lifecycle management
- **Architecture Diagrams:** Service topology and data flow

---

## 🔗 **Integration Patterns**

### **Synchronous Communication (gRPC)**
- **Order Creation:** Checkout → Order → Payment → Warehouse
- **Product Search:** Search → Catalog → Warehouse → Pricing
- **Fulfillment:** Fulfillment → Warehouse → Shipping → Catalog

### **Asynchronous Communication (Events)**
- **Order Events:** `order.created`, `order.confirmed`, `order.shipped`, `order.delivered`
- **Inventory Events:** `stock.changed`, `stock.reserved`, `stock.released`
- **Payment Events:** `payment.authorized`, `payment.captured`, `payment.refunded`
- **Fulfillment Events:** `fulfillment.picked`, `fulfillment.packed`, `fulfillment.shipped`

### **Data Synchronization Patterns**
- **Product Data:** Catalog → Search (real-time indexing)
- **Price Data:** Pricing → Search → Catalog (600x faster reads)
- **Stock Data:** Warehouse → Search → Catalog (real-time availability)

---

## 📈 **Performance & Scalability**

### **Target Performance**
- **Order Creation:** <200ms (p95)
- **Product Search:** <100ms (p95)
- **Payment Processing:** <2s (p95)
- **Fulfillment Creation:** <200ms (p95)

### **Scalability Targets**
- **Concurrent Users:** 10,000+
- **Orders per Day:** 50,000+
- **Product Catalog:** 100,000+ products
- **Search Queries:** 1,000 queries/second

---

## 🔒 **Security & Compliance**

### **Security Features**
- **JWT Authentication:** All API endpoints secured
- **Multi-Factor Auth:** TOTP for admin users
- **OAuth2 Integration:** Google, Facebook, GitHub
- **Rate Limiting:** DDoS protection and abuse prevention

### **Compliance Standards**
- **PCI DSS:** Payment card industry compliance
- **GDPR:** European data protection compliance
- **Audit Trails:** Complete operation logging

---

## 📖 **How to Use This Section**

### **For Business Analysts**
- **Process Documentation:** Understand complete business workflows
- **Gap Analysis:** Identify missing or incomplete processes
- **Requirements Gathering:** Map business needs to technical implementation

### **For Developers**
- **Implementation Planning:** Understand service interactions before coding
- **Integration Design:** Plan gRPC calls and event publishing
- **Testing Strategy:** Create test scenarios based on actual workflows

### **For Product Managers**
- **Feature Planning:** Understand current capabilities and limitations
- **User Experience:** Design better customer journeys
- **Performance Planning:** Understand system bottlenecks and optimization opportunities

### **For QA Engineers**
- **Test Case Design:** Create comprehensive test scenarios
- **End-to-End Testing:** Validate complete business processes
- **Performance Testing:** Test against actual SLA targets

---

## 🚀 **Workflow Documentation Status**

These workflow guides cover the business flows that span the 23 deployable services in this repository.

- **Service maturity, versions, and ports**: [SERVICE_INDEX.md](../SERVICE_INDEX.md)
- **Codebase and service map**: [CODEBASE_INDEX.md](../CODEBASE_INDEX.md)
- **GitOps deployment model**: [../../gitops/README.md](../../gitops/README.md)
- **Current GitOps/runtime findings**: [GitOps review checklist](../10-appendix/checklists/gitops/review_checklist.md)
- **Workflow documentation coverage**: Customer journey, operational flows, integration flows, and sequence diagrams

---

- **Last Updated**: 2026-03-02
- **Status Source of Truth**: See [SERVICE_INDEX.md](../SERVICE_INDEX.md) and [GitOps review checklist](../10-appendix/checklists/gitops/review_checklist.md)
- **GitOps**: Kustomize-based deployment with ArgoCD
- **Maintained By**: Business Process & Architecture Team
