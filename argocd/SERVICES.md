# ArgoCD Services Catalog

Complete list of all 20 services with Helm charts.

---

## Phase 1: Core Services (8 services)

### 1. Auth Service 🚀 **DEPLOYED**
- **Status**: Deployed to production
- **Namespace**: `support-services` / `support-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: JWT authentication, user management, RBAC
- **Chart**: `argocd/applications/auth-service/`

### 2. Gateway Service
- **Status**: Ready to deploy
- **Namespace**: `support-services` / `support-services-prod`
- **Ports**: 80 (HTTP)
- **Features**: API Gateway, routing, auth, rate limiting, circuit breaker
- **Chart**: `argocd/applications/gateway/`

### 3. User Service
- **Status**: Ready to deploy
- **Namespace**: `support-services` / `support-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: User management, RBAC, profiles
- **Chart**: `argocd/applications/user-service/`

### 4. Customer Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Customer data, GDPR compliance, worker deployment
- **Chart**: `argocd/applications/customer-service/`

### 5. Catalog Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Product catalog, categories, brands
- **Chart**: `argocd/applications/catalog-service/`

### 6. Pricing Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Pricing calculations, rules engine
- **Chart**: `argocd/applications/pricing-service/`

### 7. Warehouse Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Inventory management, stock tracking
- **Chart**: `argocd/applications/warehouse-service/`

### 8. Location Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Location management, geolocation
- **Chart**: `argocd/applications/location-service/`

---

## Phase 2: Business Services (4 services)

### 9. Order Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Order management, workflows, state machine
- **Chart**: `argocd/applications/order-service/`

### 10. Payment Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Payment processing, PCI compliance, webhooks
- **Chart**: `argocd/applications/payment-service/`

### 11. Promotion Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Campaigns, coupons (10K/batch), discounts, targeting
- **Chart**: `argocd/applications/promotion-service/`

### 12. Shipping Service
- **Status**: Ready to deploy
- **Namespace**: `integration-services` / `integration-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Shipping rates, carrier integration
- **Chart**: `argocd/applications/shipping-service/`

### 13. Loyalty Rewards Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 8013 (HTTP), 9013 (gRPC)
- **Features**: Points system, tier management (Bronze/Silver/Gold), referrals, campaigns
- **Chart**: `argocd/applications/loyalty-rewards/`

---

## Phase 3: Support Services (4 services)

### 14. Fulfillment Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Order fulfillment workflows
- **Chart**: `argocd/applications/fulfillment-service/`

### 15. Search Service
- **Status**: Ready to deploy
- **Namespace**: `integration-services` / `integration-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Elasticsearch integration, product search
- **Chart**: `argocd/applications/search-service/`

### 16. Review Service
- **Status**: Ready to deploy
- **Namespace**: `core-services` / `core-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Product reviews, ratings
- **Chart**: `argocd/applications/review-service/`

### 17. Notification Service
- **Status**: Ready to deploy
- **Namespace**: `integration-services` / `integration-services-prod`
- **Ports**: 80 (HTTP), 81 (gRPC)
- **Features**: Email/SMS notifications, templates, multi-provider
- **Providers**: SendGrid (email), Twilio (SMS), Firebase (push)
- **Chart**: `argocd/applications/notification-service/`

---

## Phase 4: Frontend Services (2 services)

### 18. Admin Panel
- **Status**: Ready to deploy
- **Namespace**: `frontend` / `frontend-prod`
- **Port**: 80 (HTTP)
- **Tech**: Vite + React 18 + Ant Design
- **Features**: Dashboard, product/order/customer management
- **Chart**: `argocd/applications/admin/`

### 19. Frontend (Customer)
- **Status**: Ready to deploy
- **Namespace**: `frontend` / `frontend-prod`
- **Port**: 80 (HTTP)
- **Tech**: Next.js 14+ (App Router) + Tailwind CSS
- **Features**: Product browsing, cart, checkout, SEO optimized
- **CI/CD**: GitLab pipeline with auto-deployment
- **Chart**: `argocd/applications/frontend/`

---

## Additional Services (1 service)

### 20. Common Operations Service
- **Status**: Ready to deploy
- **Namespace**: `integration-services` / `integration-services-prod`
- **Ports**: 8018 (HTTP), 9018 (gRPC)
- **Features**: Task orchestration, import/export, background jobs
- **Chart**: `argocd/applications/common-operations-service/`

---

## Service Distribution

### By Namespace

**support-services** (3 services):
- Auth Service 🚀
- User Service
- Gateway

**core-services** (10 services):
- Customer, Catalog, Pricing, Order
- Payment, Promotion, Warehouse, Location
- Fulfillment, Review

**integration-services** (4 services):
- Shipping, Search, Notification
- Common Operations

**frontend** (2 services):
- Admin Panel
- Frontend

### By Technology

**Go Microservices** (17 services):
- All backend services

**Node.js Applications** (2 services):
- Admin Panel (Vite + React)
- Frontend (Next.js)

---

## Helm Chart Structure

Each service includes:

```
service-name/
├── Chart.yaml                    # Helm chart metadata
├── values.yaml                   # Default configuration
├── service-name-appSet.yaml      # ApplicationSet
├── templates/
│   ├── _helpers.tpl             # Template helpers
│   ├── deployment.yaml          # Deployment manifest
│   ├── service.yaml             # Service manifest
│   ├── configmap.yaml           # ConfigMap
│   ├── secrets.yaml             # Secrets template
│   └── migration-job.yaml       # DB migration job (if needed)
├── staging/
│   ├── tag.yaml                 # Image tag
│   ├── values.yaml              # Staging overrides
│   └── secrets.yaml             # Staging secrets (SOPS encrypted)
└── production/
    ├── tag.yaml                 # Image tag
    ├── values.yaml              # Production overrides
    └── secrets.yaml             # Production secrets (SOPS encrypted)
```

---

**Total**: 20 services, all with complete Helm charts ✅

