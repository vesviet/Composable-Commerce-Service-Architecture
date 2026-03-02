# 📋 Architectural Analysis & Refactoring Report: Service Discovery & RPC Client Registries

**Role:** Senior Fullstack Engineer (Virtual Team Lead)  
**Standard Profile:** Shopify / Shopee / Lazada Architecture Patterns  
**Domain Area:** Service Registry (Consul), gRPC Client Topologies & Cascading Failure Prevention

---

## 🎯 Executive Summary
In a microservices mesh spanning 20+ applications, hardcoded RPC routing is fatal. The ecosystem successfully employs HashiCorp Consul for dynamic Service Discovery. The server-side registration topology successfully adheres to the enterprise blueprint. However, catastrophic risk vectors exist on the client-side consumption layer: multiple services are bypassing the resilient `common/client` library to manually instantiate raw gRPC connections devoid of Circuit Breakers or sensible KeepAlive policies.

## 🚩 PENDING ISSUES (Unfixed - Require Immediate Action)

*No P0/P1 issues remain. All gRPC client violations have been fully resolved.*

## ✅ RESOLVED / FIXED

- **[FIXED ✅] SPOF Eradicated: All Services Use Core Discovery Client**: Codebase audit (2026-03-01) confirms `grep -r 'grpc.DialInsecure' --include='*.go'` returns **ZERO results** across the entire codebase. All services (including previously flagged `shipping` and `order`) now exclusively use `common/client.NewDiscoveryClient()` with integrated Circuit Breakers, Retry Logic, and Consul Resolver bindings. The `auth/internal/data/grpc.go` legacy file was deleted in commit `630dd25`.
- **[FIXED ✅] Server-Side Consul Registration Uniformity**: Extensive audits of `wire.go` configurations across 15+ services (including `customer`, `order`, `shipping`) confirm 100% adherence to the `common/registry/consul.go` (`NewConsulRegistrar`) standard. Services read their environment configs, bootstrap clean Kratos application objects, and reliably broadcast their readiness probes to the Consul mesh without code duplication.

---

## 📋 Architectural Guidelines & Playbook

### 1. The Catastrophic Anti-Pattern (Manual Dialing)
Bespoke gRPC dialysis strips the meshed network of its protective layers.

**Anti-Pattern (Banned):**
```go
// Manually building the Consul resolver - NO CIRCUIT BREAKER!
client, _ := api.NewClient(consulConfig)
conn, err := grpc.DialInsecure(
    fmt.Sprintf("discovery:///%s", "catalog"),
    grpc.WithDiscovery(consul.New(client)),
) // If catalog goes down, this caller hangs indefinitely.
```

### 2. The Core Factory Standard (Resilient RPCs)
The `common/client` package is the singular, non-negotiable entrypoint for cross-domain RPCs.
* **Mechanism**: The factory natively wraps `grpc.Dial` with Kratos recovery middlewares, metrics interceptors, and error handling.

**Lazada/Shopify Standard (Mandatory Client Instantiation):**
All RPC client constructors must be reduced to invoking the Core Factory.
```go
// shipping/internal/client/catalog.go
func NewCatalogServiceClient(consulAddr string) (*CatalogServiceClient, error) {
    // 1. Core library automatically handles Consul resolution
    // 2. Core library injects Circuit Breakers & Retries
    conn, err := commonClient.NewDiscoveryClient("catalog", consulAddr) 
    if err != nil { 
        return nil, err 
    }
    return &CatalogServiceClient{ 
        client: catalogPB.NewCatalogServiceClient(conn),
    }, nil
}
```
*Note from the Senior TA: Any Pull Request containing the literal string `grpc.DialInsecure` outside of the `common` repository constitutes a P0 architectural violation.*
