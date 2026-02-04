# NetworkPolicy Templates for GitOps (Per-Service Namespace)

**Architecture**: Each service in separate namespace (auth-dev, catalog-dev, etc.)  
**Date**: February 4, 2026  
**Purpose**: Standard NetworkPolicy templates for multi-namespace GitOps

---

## 📋 Namespace Structure

```
Dev Environment:
├── auth-dev              # Auth service
├── catalog-dev           # Catalog service
├── order-dev             # Order service
├── gateway-dev           # API Gateway
├── infrastructure        # Shared infrastructure (DB, Redis, Consul)
└── dapr-system          # Dapr control plane
```

**Key Labels for Namespaces**:
```yaml
metadata:
  labels:
    name: auth-dev                      # Unique namespace name
    app.kubernetes.io/environment: dev  # Environment
    app.kubernetes.io/managed-by: kustomize
```

---

## 🔒 Template 1: Standard Backend Service

**Use for**: auth, user, customer, catalog, order, payment, pricing, etc.

```yaml
# gitops/apps/{service}/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: {service}
  labels:
    app.kubernetes.io/name: {service}
    app.kubernetes.io/component: backend
    app.kubernetes.io/managed-by: kustomize
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: {service}
      app.kubernetes.io/component: backend
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow from API Gateway only (Phase 1)
    - from:
        - namespaceSelector:
            matchLabels:
              name: gateway-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: gateway
      ports:
        - protocol: TCP
          port: 8000  # HTTP service port
        - protocol: TCP
          port: 9000  # GRPC service port
    
    # ⏸️ Service-to-Service Communication (Phase 2 - SKIP FOR NOW)
    # Will be added later based on actual service dependencies
    # Example: order service needs to call payment
    # - from:
    #     - namespaceSelector:
    #         matchLabels:
    #           name: order-dev
    #       podSelector:
    #         matchLabels:
    #           app.kubernetes.io/name: order
    #   ports:
    #     - protocol: TCP
    #       port: 8000
  
  egress:
    # DNS Resolution (required for all)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    
    # PostgreSQL (if service uses database)
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: postgresql
      ports:
        - protocol: TCP
          port: 5432
    
    # Redis (if service uses cache/pub-sub)
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
    
    # Consul Service Discovery (if service uses Consul)
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: consul
      ports:
        - protocol: TCP
          port: 8500  # HTTP API
        - protocol: TCP
          port: 8300  # RPC
    
    # Dapr Control Plane (dapr-system namespace)
    - to:
        - namespaceSelector:
            matchLabels:
              name: dapr-system
      ports:
        - protocol: TCP
          port: 443   # Sentry Service (mTLS certificates)
        - protocol: TCP
          port: 50001 # Sentry gRPC port
        - protocol: TCP
          port: 80    # Dapr API Service
        - protocol: TCP
          port: 6500  # Dapr API gRPC port
        - protocol: TCP
          port: 50005 # Placement Service
        - protocol: TCP
          port: 50006 # Scheduler Service (workflows)

# ⏸️ Phase 2: Service-to-Service Communication (DEFERRED)
# Will add specific egress rules based on service dependency mapping
# Example patterns:
#
# Call other services (add as needed per service)
# - to:
#     - namespaceSelector:
#         matchLabels:
#           name: user-dev
#       podSelector:
#         matchLabels:
#           app.kubernetes.io/name: user
#   ports:
#     - protocol: TCP
#       port: 80    # Service ClusterIP port
#     - protocol: TCP
#       port: 81    # GRPC Service port
```

---

## 🌐 Template 2: API Gateway

**Use for**: gateway

```yaml
# gitops/apps/gateway/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: gateway
  labels:
    app.kubernetes.io/name: gateway
    app.kubernetes.io/component: gateway
    app.kubernetes.io/managed-by: kustomize
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: gateway
      app.kubernetes.io/component: backend
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow from NGINX Ingress Controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 8080  # Gateway HTTP port
    
    # Allow from admin/frontend namespaces (if needed)
    - from:
        - namespaceSelector:
            matchLabels:
              name: admin-dev
      ports:
        - protocol: TCP
          port: 8080
    
    - from:
        - namespaceSelector:
            matchLabels:
              name: frontend-dev
      ports:
        - protocol: TCP
          port: 8080
  
  egress:
    # DNS Resolution
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    
    # Allow calling ALL backend services
    # Gateway routes to all microservices
    - to:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/environment: dev
      ports:
        - protocol: TCP
          port: 80    # Service HTTP port
        - protocol: TCP
          port: 81    # Service GRPC port
    
    # Infrastructure services
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
      ports:
        - protocol: TCP
          port: 6379  # Redis
        - protocol: TCP
          port: 8500  # Consul
        - protocol: TCP
          port: 5432  # PostgreSQL (if gateway has DB)
    
    # Dapr Control Plane
    - to:
        - namespaceSelector:
            matchLabels:
              name: dapr-system
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 50001
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 6500
        - protocol: TCP
          port: 50005
        - protocol: TCP
          port: 50006
```

---

## 🖥️ Template 3: Frontend Services

**Use for**: admin, frontend (Node.js apps)

```yaml
# gitops/apps/admin/base/networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: admin
  labels:
    app.kubernetes.io/name: admin
    app.kubernetes.io/component: frontend
    app.kubernetes.io/managed-by: kustomize
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: admin
      app.kubernetes.io/component: backend
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Allow from NGINX Ingress Controller
    - from:
        - namespaceSelector:
            matchLabels:
              name: ingress-nginx
          podSelector:
            matchLabels:
              app.kubernetes.io/name: ingress-nginx
      ports:
        - protocol: TCP
          port: 80  # Admin app port
  
  egress:
    # DNS Resolution
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    
    # Call API Gateway
    - to:
        - namespaceSelector:
            matchLabels:
              name: gateway-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: gateway
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 8080
    
    # External APIs (if needed - for Next.js SSR)
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: TCP
          port: 443  # HTTPS for external APIs
```

---

## 🛠️ Template 4: Worker Deployments

**Use for**: Workers with Dapr pub/sub

```yaml
# gitops/apps/catalog/base/worker-networkpolicy.yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: catalog-worker
  labels:
    app.kubernetes.io/name: catalog
    app.kubernetes.io/component: worker
    app.kubernetes.io/managed-by: kustomize
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: catalog
      app.kubernetes.io/component: worker
  
  policyTypes:
    - Ingress
    - Egress
  
  ingress:
    # Workers typically don't need ingress
    # Unless you have internal monitoring/health checks
    []
  
  egress:
    # DNS
    - to:
        - namespaceSelector: {}
      ports:
        - protocol: UDP
          port: 53
        - protocol: TCP
          port: 53
    
    # PostgreSQL
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: postgresql
      ports:
        - protocol: TCP
          port: 5432
    
    # Redis (for pub/sub)
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: redis
      ports:
        - protocol: TCP
          port: 6379
    
    # Consul
    - to:
        - namespaceSelector:
            matchLabels:
              name: infrastructure
          podSelector:
            matchLabels:
              app: consul
      ports:
        - protocol: TCP
          port: 8500
    
    # Dapr (for pub/sub component)
    - to:
        - namespaceSelector:
            matchLabels:
              name: dapr-system
      ports:
        - protocol: TCP
          port: 443
        - protocol: TCP
          port: 50001
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 6500
    
    # Call other services if needed
    - to:
        - namespaceSelector:
            matchLabels:
              app.kubernetes.io/environment: dev
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 81
```

---

## 📝 Service-to-Service Communication Matrix (Phase 2 - DEFERRED)

**Status**: ⏸️ Will be implemented after basic NetworkPolicy is in place

**Approach**: Start with gateway-only access, then incrementally add service-to-service rules based on actual needs.

Configure ingress rules based on actual service dependencies:

| Service | Calls To | Add Egress To Namespaces |
|---------|----------|--------------------------|
| **gateway** | All services | auth-dev, user-dev, catalog-dev, order-dev, etc. |
| **order** | payment, warehouse, pricing | payment-dev, warehouse-dev, pricing-dev |
| **payment** | notification | notification-dev |
| **warehouse** | notification | notification-dev |
| **catalog** | search, pricing | search-dev, pricing-dev |
| **auth** | user | user-dev |
| **checkout** | order, payment, warehouse | order-dev, payment-dev, warehouse-dev |

### Example: Order Service NetworkPolicy

```yaml
# gitops/apps/order/base/networkpolicy.yaml
spec:
  ingress:
    # From gateway
    - from:
        - namespaceSelector:
            matchLabels:
              name: gateway-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: gateway
      ports:
        - protocol: TCP
          port: 8000
    
    # From checkout service
    - from:
        - namespaceSelector:
            matchLabels:
              name: checkout-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: checkout
      ports:
        - protocol: TCP
          port: 8000
  
  egress:
    # ... standard egress ...
    
    # Call payment service
    - to:
        - namespaceSelector:
            matchLabels:
              name: payment-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: payment
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 81
    
    # Call warehouse service
    - to:
        - namespaceSelector:
            matchLabels:
              name: warehouse-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: warehouse
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 81
    
    # Call pricing service
    - to:
        - namespaceSelector:
            matchLabels:
              name: pricing-dev
          podSelector:
            matchLabels:
              app.kubernetes.io/name: pricing
      ports:
        - protocol: TCP
          port: 80
        - protocol: TCP
          port: 81
```

---

## 🚀 Implementation Steps (Phase 1)

**Focus**: Basic connectivity (Gateway → Services → Infrastructure → Dapr)  
**Deferred**: Service-to-Service direct calls (will route through Gateway for now)

### Step 1: Verify Namespace Labels

```bash
# Check namespace labels
kubectl get namespace --show-labels

# Expected output:
# auth-dev        Active   name=auth-dev,app.kubernetes.io/environment=dev
# catalog-dev     Active   name=catalog-dev,app.kubernetes.io/environment=dev
# gateway-dev     Active   name=gateway-dev,app.kubernetes.io/environment=dev
# infrastructure  Active   name=infrastructure
# dapr-system     Active   name=dapr-system
```

### Step 2: Add NetworkPolicy to Service

```bash
# 1. Copy appropriate template to service base/
cp templates/backend-networkpolicy.yaml gitops/apps/auth/base/networkpolicy.yaml

# 2. Update service name and ports
sed -i 's/{service}/auth/g' gitops/apps/auth/base/networkpolicy.yaml
sed -i 's/port: 8000/port: 8001/g' gitops/apps/auth/base/networkpolicy.yaml  # Auth uses 8001

# 3. Add to kustomization.yaml
cat >> gitops/apps/auth/base/kustomization.yaml << EOF
  - networkpolicy.yaml
EOF

# 4. Commit and push
git add gitops/apps/auth/base/networkpolicy.yaml
git commit -m "feat(auth): add NetworkPolicy for per-service namespace"
```

### Step 3: Test Network Isolation

```bash
# Deploy with NetworkPolicy
kubectl apply -k gitops/apps/auth/overlays/dev/

# Test from gateway (should work)
kubectl run -it --rm test-gateway --image=busybox --namespace=gateway-dev -- \
  wget -qO- http://auth.auth-dev.svc.cluster.local/health

# Test from unauthorized namespace (should fail)
kubectl run -it --rm test-fail --image=busybox --namespace=catalog-dev -- \
  wget -qO- --timeout=5 http://auth.auth-dev.svc.cluster.local/health
# Expected: Connection timeout
```

---

## 📋 Checklist: NetworkPolicy Phase 1 (Basic Connectivity)

**Phase 1 Focus**: Gateway ingress + Infrastructure/Dapr egress only

- [ ] **auth** - Standard backend template (gateway → auth → infra/dapr)
- [ ] **user** - Standard backend template
- [ ] **customer** - Standard backend template + worker
- [ ] **catalog** - Standard backend template + worker
- [ ] **search** - Standard backend template + worker + Elasticsearch egress
- [ ] **pricing** - Standard backend template + worker
- [ ] **promotion** - Standard backend template
- [ ] **review** - Standard backend template
- [ ] **order** - Standard backend template + worker ⏸️ ~~calls (payment, warehouse, pricing)~~
- [ ] **payment** - Standard backend template + worker ⏸️ ~~calls (notification)~~
- [ ] **shipping** - Standard backend template + worker
- [ ] **warehouse** - Standard backend template + worker ⏸️ ~~calls (notification)~~
- [ ] **fulfillment** - Standard backend template + worker
- [ ] **notification** - Standard backend template + worker
- [ ] **analytics** - Standard backend template
- [ ] **location** - Standard backend template
- [ ] **loyalty-rewards** - Standard backend template
- [ ] **checkout** - Standard backend template ⏸️ ~~calls (order, payment, warehouse)~~
- [ ] **return** - Standard backend template
- [ ] **common-operations** - ✅ Already has NetworkPolicy (update to Phase 1 rules)
- [ ] **gateway** - Gateway template (allow all backends)
- [ ] **admin** - Frontend template
- [ ] **frontend** - Frontend template

**Phase 2 (Deferred)**: Add service-to-service rules after Phase 1 validation

---

## 🔍 Validation Commands

```bash
# List all NetworkPolicies
kubectl get networkpolicy --all-namespaces

# Describe specific NetworkPolicy
kubectl describe networkpolicy auth -n auth-dev

# Test connectivity matrix
# From gateway to auth (should work)
kubectl exec -it <gateway-pod> -n gateway-dev -- curl http://auth.auth-dev.svc.cluster.local/health

# From catalog to auth (should work if configured, else timeout)
kubectl exec -it <catalog-pod> -n catalog-dev -- curl --max-time 5 http://auth.auth-dev.svc.cluster.local/health

# Monitor NetworkPolicy logs (if using Calico/Cilium)
kubectl logs -n kube-system -l k8s-app=calico-node | grep -i "denied"
```

---

## 📚 References

- [Kubernetes NetworkPolicy](https://kubernetes.io/docs/concepts/services-networking/network-policies/)
- [Dapr Network Security](https://docs.dapr.io/operations/security/mtls/)
- [Namespace-scoped NetworkPolicy Best Practices](https://kubernetes.io/docs/concepts/services-networking/network-policies/#behavior-of-to-and-from-selectors)

---

**Last Updated**: February 4, 2026  
**Status**: Ready for implementation
