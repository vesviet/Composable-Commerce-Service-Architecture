# Consul Dataplane (Agentless) Evaluation

> **Status**: Evaluated — DaemonSet model retained for current phase
> **Date**: 2026-03-15
> **Context**: AGENT-05 Task 23

---

## 1. Current Architecture: DaemonSet Agent

```
┌─────────────────────────────────────────────────┐
│ K8s Node                                        │
│  ┌──────────────┐  ┌──────────────┐             │
│  │ Service Pod   │  │ Service Pod   │            │
│  │ (catalog)     │  │ (order)       │            │
│  │ → localhost:  │  │ → localhost:  │            │
│  │   8500        │  │   8500        │            │
│  └──────┬───────┘  └──────┬───────┘             │
│         │                  │                     │
│  ┌──────▼─────────────────▼────────┐             │
│  │ consul-agent (DaemonSet)         │            │
│  │ - Serf gossip membership         │            │
│  │ - Local cache                    │            │
│  │ - Service registration           │            │
│  └──────────────┬──────────────────┘             │
└─────────────────┼────────────────────────────────┘
                  │
          ┌───────▼────────┐
          │ Consul Server  │
          │ (StatefulSet)  │
          │ 3 nodes        │
          └────────────────┘
```

### Pros
- ✅ Services connect to `localhost:8500` — fast, no cross-node latency
- ✅ Local health checking (when using TTL heartbeat)
- ✅ Agent handles anti-entropy sync automatically
- ✅ DNS forwarding on each node (`*.consul` resolution)
- ✅ Mature, production-proven pattern

### Cons
- ❌ DaemonSet = 1 agent per node (resource overhead: 50m CPU + 64Mi per node)
- ❌ Serf gossip overhead grows with cluster size
- ❌ Agent needs gossip encryption key + ACL token on every node
- ❌ Agent restart can temporarily disrupt service registration

---

## 2. Consul Dataplane (Agentless) Architecture

```
┌─────────────────────────────────────────────────┐
│ K8s Node                                        │
│  ┌──────────────────────┐                       │
│  │ Service Pod           │                      │
│  │ ┌──────────────────┐ │                       │
│  │ │ consul-dataplane  │ │  ← sidecar            │
│  │ │ (envoy proxy)     │ │                       │
│  │ └──────────────────┘ │                       │
│  └──────────┬───────────┘                       │
│             │ gRPC (xDS)                        │
└─────────────┼───────────────────────────────────┘
              │
       ┌──────▼────────┐
       │ Consul Server  │
       │ (StatefulSet)  │
       │ 3 nodes        │
       └────────────────┘
```

### Pros
- ✅ No DaemonSet — eliminates per-node agent overhead
- ✅ Per-pod sidecar = fine-grained lifecycle (no shared-node blast radius)
- ✅ Native Envoy integration for service mesh (mTLS, traffic splitting)
- ✅ Simpler operational model (no gossip pool to manage)

### Cons
- ❌ **Sidecar overhead per pod** — more total resource usage if many pods 
- ❌ Requires Consul Connect (service mesh) — we currently use basic service discovery
- ❌ No local DNS forwarding (services must use gRPC for discovery)
- ❌ Breaking change: all services must change from HTTP API → gRPC xDS protocol
- ❌ HCP Consul Enterprise feature in some modes

---

## 3. Decision

### Recommendation: **Keep DaemonSet Agent** (current phase)

**Rationale**:
1. **Minimal migration cost**: Our services use `localhost:8500` HTTP API for registration. Switching to Dataplane requires rewriting all service registration to use gRPC xDS — a massive effort across 19+ services.
2. **No service mesh requirement**: We use Consul for service discovery + KV config only. Dataplane's main benefit (Envoy sidecar mesh) is unnecessary for our use case.
3. **Resource efficiency**: With k3d/k3s (3-5 nodes), 1 DaemonSet per node costs ~150-250m CPU total. Dataplane sidecars across 20+ service pods would cost more.
4. **DNS resolution**: DaemonSet agent provides `*.consul` DNS on each node, which some services use. Dataplane doesn't support this.

### When to Reconsider
- When adopting **Consul Connect service mesh** for mTLS between services
- When cluster scales beyond **50+ nodes** (gossip overhead becomes significant)
- When migrating to **HCP Consul Managed** (Dataplane is the recommended pattern)

---

## 4. Optimizations Applied to Current Model

Instead of migrating to Dataplane, we've hardened the DaemonSet model:

| Optimization | Status |
|-------------|--------|
| 3-node HA server with PVC | ✅ Task 7 |
| Gossip encryption | ✅ Task 6 |
| ACL default-deny | ✅ Task 19 |
| TLS for HTTP API | ✅ Task 22 |
| Circuit breaker on Consul clients | ✅ Task 21 |
| Service metadata tags for canary routing | ✅ Task 20 |

These provide security and resilience parity with Dataplane without the migration cost.
