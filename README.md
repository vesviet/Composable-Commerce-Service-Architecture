# Documentation Index

**Last Updated**: 2026-01-19
**Status**: ✅ Current

This directory contains the comprehensive documentation for the Microservices project, including architectural overviews, detailed implementation guides, workflows, runbooks, and checklists.

---

## 🚀 Project Overview

**E-Commerce Microservices Platform** (2025 - Present)
A comprehensive, production-grade e-commerce ecosystem designed for scale and high availability.

- **Architecture**: Microservices (21+ services), Event-Driven, Clean Architecture.
- **Tech Stack**:
    - **Backend**: Go 1.25+ (Kratos Framework), gRPC, Wire.
    - **Frontend**: Next.js, React, TypeScript.
    - **Infrastructure**: Kubernetes, Dapr (Service Mesh), ArgoCD (GitOps), Docker.
    - **Data & Search**: PostgreSQL, Redis, Elasticsearch.
    - **Observability**: Prometheus, Grafana, Jaeger.
- **Key Modules**:
    - **Core**: Auth, User, Customer, Catalog (25k+ SKUs), Order Management.
    - **Commerce**: Payment (Multi-gateway), Pricing, Cart, Checkout.
    - **Operations**: Multi-warehouse Inventory, Shipping & Logistics, Fulfillment.
    - **Engagement**: Loyalty Rewards, Review System, AI-powered Search, Notifications.

---

## 🎯 Quick Access

### 🏗 Architecture & Core Concepts
- **[SYSTEM_ARCHITECTURE_OVERVIEW.md](./SYSTEM_ARCHITECTURE_OVERVIEW.md)**: The high-level architectural diagram and explanation.
- **[EVENTS_REFERENCE.md](./EVENTS_REFERENCE.md)**: Reference guide for system-wide events.
- **[GRPC_PROTO_AND_VERSIONING_RULES.md](./GRPC_PROTO_AND_VERSIONING_RULES.md)**: Guidelines for gRPC API development and versioning.
- **[CODEBASE_INDEX.md](./CODEBASE_INDEX.md)**: Guide to the codebase structure.

### 🚀 Operations & Runbooks
- **[sre-runbooks/](./sre-runbooks/)**: Operational guides for each service (Alerts, Troubleshooting).
- **[deployment/](./deployment/)**: Deployment guides and checklists.
- **[k8s/](./k8s/)**: Kubernetes cluster setup, configuration, and migration guides.

### 🛠 Development & Implementation
- **[platform-engineering/](./platform-engineering/)**: Common code, library usage, and engineering standards.
- **[checklists/](./checklists/)**: Implementation checklists, sprint trackers, and service reviews.
- **[templates/](./templates/)**: Templates for issues, features, and new services.

---

## 🔄 Business Workflows
*Detailed logic flows and sequence diagrams for core business processes.*

> Located in **[workflow/](./workflow/)**

- **Auth & Identity**
    - [Auth Flow](./workflow/auth-flow.md)
    - [Customer Account Flow](./workflow/customer_account_flow.md)
    - [Gateway Flow](./workflow/gateway_flow.md)

- **Product & Catalog**
    - [Catalog Flow](./workflow/catalog_flow.md)
    - [Inventory Flow](./workflow/inventory-flow.md)
    - [Search & Discovery](./workflow/search-product-discovery-flow.md)
    - [Search Visibility](./workflow/search-product-visibility-filtering.md)
    - [Search Sellable View](./workflow/search-sellable-view-per-warehouse-complete.md)

- **Order & Checkout**
    - [Cart Flow](./workflow/cart_flow.md)
    - [Checkout Flow](./workflow/checkout_flow.md)
    - [Order Flow](./workflow/order-flow.md)
    - [Payment Flow](./workflow/payment-flow.md)
    - [Tax Flow](./workflow/tax_flow.md)

- **Fulfillment & Shipping**
    - [Order Fulfillment](./workflow/order_fulfillment_flow.md)
    - [Shipping Flow](./workflow/shipping_flow.md)
    - [Return & Refund](./workflow/return_refund_flow.md)

- **Pricing & Promotions**
    - [Pricing Flow](./workflow/PRICING_FLOW.md)
    - [Promotion Flow](./workflow/promotion_flow.md)
    - [Pricing & Promotion Integration](./workflow/pricing-promotion-flow.md)

- **Communication**
    - [Notification Flow](./workflow/notification_flow.md)

- **Status & Roadmap**
    - [ROADMAP](./workflow/ROADMAP.md)
    - [PROJECT_STATUS](./workflow/PROJECT_STATUS.md)

---

## 📚 Detailed Directory Index

### [adr/](./adr/)
Architecture Decision Records (ADRs) documenting significant architectural choices.

### [argocd/](./argocd/)
ArgoCD configuration and deployment guides.

### [checklists/](./checklists/)
Tracks the progress of service implementation, migrations, and code reviews.
- Key file: `PROJECT_STATUS.md`

### [ddd/](./ddd/)
Domain-Driven Design artifacts, including context maps and domain definitions.

### [design/](./design/)
Specific feature designs and technical specifications.

### [json-schema/](./json-schema/)
JSON schemas for domain events and data validation.

### [openapi/](./openapi/)
OpenAPI (Swagger) specifications for service APIs.

### [platform-engineering/](./platform-engineering/)
Guides for the platform team, including common libraries `common/*` and standardization efforts.

### [services/](./services/)
Service-specific detailed documentation (e.g., specific quirks or local docs).

---

## 📃 Other Top-Level Documents
- **[CONSOLIDATION_IMPLEMENTATION_GUIDE.md](./CONSOLIDATION_IMPLEMENTATION_GUIDE.md)**: Guide for the recent service consolidation.
- **[CUSTOMER_GROUP_IMPLEMENTATION_PLAN.md](./CUSTOMER_GROUP_IMPLEMENTATION_PLAN.md)**: Plan for customer groups feature.
- **[DEBUGGING_PRICE_UPDATES.md](./DEBUGGING_PRICE_UPDATES.md)**: Troubleshooting guide for price updates.
- **[DEPLOYMENT_STATUS_REVIEW.md](./DEPLOYMENT_STATUS_REVIEW.md)**: Status of deployments.
- **[DOCUMENTATION_REVIEW_REPORT.md](./DOCUMENTATION_REVIEW_REPORT.md)**: Report on documentation quality.
- **[FRONTEND_AUTH_README.md](./FRONTEND_AUTH_README.md)**: Frontend authentication details.
- **[K8S_CONFIG_STANDARDIZATION_CHECKLIST.md](./K8S_CONFIG_STANDARDIZATION_CHECKLIST.md)**: Checklist for K8s config.
- **[K8S_MIGRATION_QUICK_GUIDE.md](./K8S_MIGRATION_QUICK_GUIDE.md)**: Quick guide for K8s migration.
- **[MIGRATION_SUMMARY.md](./MIGRATION_SUMMARY.md)**: Summary of migration efforts.
- **[TEAM_LEAD_CODE_REVIEW_GUIDE.md](./TEAM_LEAD_CODE_REVIEW_GUIDE.md)**: Guide for team leads performing code reviews.

---

**Note**: The directory `workfllow/` appears to be a legacy typo directory and should be ignored in favor of `workflow/`.
