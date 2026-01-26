# Microservice Deployment Order

To ensure system stability and dependency resolution, services should be deployed in the following order.
While `Dapr` handles transient connection retries, logical data dependencies usually dictate this flow.

## 🚀 Tier 0: Infrastructure (Pre-requisites)
*These must be healthy before ANY application deployment.*
1.  **PostgreSQL** (Data persistence)
2.  **Redis** (Pub/Sub & Caching)
3.  **Consul** (Service Registry)
4.  **Jaeger** (Tracing)
5.  **Dapr System** (Sidecar injector, Operator, Sentry)

---

## 🏗 Tier 1: Core Domain (Identity & Metadata)
*Low-level services that others depend on for data validation.*
1.  **Auth Service** (Required for Token validation)
2.  **User Service** (Required for User Profile resolution)
    *   *Depends on*: `Auth`, `Postgres`, `Redis`
    *   *Used by*: `Order`, `Cart`, `Payment`

---

## 📦 Tier 2: Product Domain
*Static or semi-static content services.*
1.  **Catalog Service** (Products, Categories)
    *   *Depends on*: `Postgres`, `Redis`
    *   *Used by*: `Cart`, `Order`, `Search`
2.  **Pricing Service** (if separated)
3.  **Promotion Service**

---

## 🚚 Tier 3: Fulfillment & Business Operations
*Complex transactional services involving workflows.*
1.  **Cart Service**
2.  **Order Service** (Central Nexus)
    *   *Depends on*: `User`, `Catalog`, `Promotion`
3.  **Warehouse Service** (Inventory Management)
    *   *Depends on*: `Order` (for reservation), `Catalog` (for product details)
    *   *Events*: Listens to `order.created` or `payment.success`
4.  **Payment Service**
5.  **Shipping Service**

---

## 📡 Tier 4: Aggregators & Gateways
*Public facing entry points.*
1.  **Notification Service** (Can be deployed earlier, but mostly consumes events from Tier 3)
2.  **BFF (Backend for Frontend)** / API Gateway
3.  **Frontend Applications** (Web/Mobile)

---

## 💡 Best Practices
*   **Dependency Checks**: Use `initContainers` (as seen in `worker-deployment.yaml`) to wait for Tier 0 (DB/Redis/Consul).
*   **Graceful Startup**: Services should crash/restart gracefully if a functional dependency (Tier 1/2) is missing, relying on Kubernetes `CrashLoopBackOff` until the dependency is ready.
*   **Migration Jobs**: Always run Schema Migrations (`migration-job.yaml`) **before** rolling out the new Deployment code. (ArgoCD Synchronization hooks handle this automatically).
