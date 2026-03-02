# ADR-023: Standardized Caching and Worker Patterns

**Date:** 2026-03-02  
**Status:** Accepted  
**Deciders:** Data Architecture Team, Technical Leads

## Context
During the documentation audit (`docs/09-migration-guides/CONSOLIDATION_IMPLEMENTATION_GUIDE.md`), we successfully abstracted database connections, health checks, HTTP clients, and Event Publishing into the `gitlab.com/ta-microservices/common` library, eliminating over 4,150 lines of duplicate code. 

However, two major areas remain decentralized and inconsistent across services:
1. **Caching Patterns (10/19 Services):** Redis is used widely, but caching strategies (cache-aside, write-through, TTLs, invalidation logic) vary drastically. Some services use custom decorators, others inline the Redis calls in the `data` layer.
2. **Background Workers/Jobs (10/19 Services):** Cron jobs, event consumers, and Outbox processors are implemented differently. Some use simple Goroutines, some use `cron` libraries, and error handling/retries are not uniform.

## Decision
We will establish standard interfaces and implementations inside the `common` library for both Caching and Workers.

### 1. Standardized Caching Module (`common/cache`)
We will create a uniform `CacheManager` abstraction over `go-redis`.
- **Strategy:** Default to **Cache-Aside** (Lazy Loading) pattern.
- **Implementation:** `GetOrSet(ctx, key, ttl, fetchFunc)` helper that handles cache misses, protects against Cache Stampedes via single-flight locking, and handles JSON marshal/unmarshal generically.
- **Namespacing:** Enforce `{service_name}:{entity}:{id}` namespace standardization to avoid key collisions.

### 2. Standardized Worker Framework (`common/worker`)
We will create a unified `WorkerPool` and `Job` abstraction for scheduled tasks and outbox processing.
- **Implementation:** A robust `WorkerManager` that handles graceful shutdown (`context` cancellation), panic recovery, and metric tracking.
- **Cron Jobs:** Wrapper around a robust Go chron library (e.g., `robfig/cron/v3`) with distributed locking (using Redis/Redlock) to ensure cron jobs only fire on exactly one pod.
- **Outbox Processors:** Standard base struct for Outbox tailing that implements exponential backoff and batch size configuration.

## Consequences

### Positive
- **Reduced Tech Debt:** Eradicates inconsistent caching logic and copy-pasted worker boilerplate.
- **Safer Cron Jobs:** Distributed locking prevents multiple pods from processing the same cron trigger (e.g., sending duplicate reminder emails).
- **Stampede Protection:** Single-flight cache fetching protects the Postgres DB from sudden traffic spikes when popular cache keys expire.

### Negative
- **Refactoring Effort:** Requires rewriting the `data` and `worker` layers in 10 services to adopt the new `common` patterns.
- **Slight Lock Overhead:** Redis distributed locks strictly govern CRON tasks, adding a small overhead.

## Implementation Plan
1. Implement `common/cache` and `common/worker` (Target: Next Sprint).
2. Migrate a low-risk service (e.g., `notification` or `review`) as a Proof of Concept.
3. Roll out to high-risk services (`order`, `warehouse`, `catalog`) gradually.
