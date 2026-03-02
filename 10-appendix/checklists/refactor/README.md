# Refactor Analysis Reports

Technical analysis reports covering specific architectural dimensions across all microservices. Generated during the platform-wide refactoring audit (March 2026).

---

## Reports Index

### Architecture & Code Quality

| Report | Scope |
|--------|-------|
| [clean_architecture_domain_analysis_report.md](clean_architecture_domain_analysis_report.md) | Clean Architecture / DDD layer violations |
| [api_grpc_layer_analysis_report.md](api_grpc_layer_analysis_report.md) | gRPC/HTTP API layer patterns |
| [unit_test_coverage_analysis_report.md](unit_test_coverage_analysis_report.md) | Test coverage gaps per service |

### Data & Persistence

| Report | Scope |
|--------|-------|
| [database_transaction_analysis_report.md](database_transaction_analysis_report.md) | Transaction usage, missing `InTx` |
| [database_pagination_analysis_report.md](database_pagination_analysis_report.md) | Pagination patterns (offset vs cursor) |
| [migration_analysis_report.md](migration_analysis_report.md) | Migration safety, zero-downtime checks |
| [caching_strategy_analysis_report.md](caching_strategy_analysis_report.md) | Cache-aside patterns, TTL configs |

### Events & Messaging

| Report | Scope |
|--------|-------|
| [dapr_pubsub_analysis_report.md](dapr_pubsub_analysis_report.md) | Dapr PubSub event pipeline audit |
| [worker_analysis_report.md](worker_analysis_report.md) | Worker binary wiring and registration |
| [internal_worker_code_analysis_report.md](internal_worker_code_analysis_report.md) | Worker implementation patterns |

### Resilience & Security

| Report | Scope |
|--------|-------|
| [resilience_distributed_transaction_analysis_report.md](resilience_distributed_transaction_analysis_report.md) | Circuit breakers, retries, timeouts |
| [security_idempotency_analysis_report.md](security_idempotency_analysis_report.md) | Idempotency patterns, security checks |
| [service_discovery_analysis_report.md](service_discovery_analysis_report.md) | Consul service discovery config |
| [observability_tracing_analysis_report.md](observability_tracing_analysis_report.md) | OpenTelemetry tracing coverage |

### GitOps & Kubernetes

| Report | Scope |
|--------|-------|
| [gitops_api_deployment_analysis_report.md](gitops_api_deployment_analysis_report.md) | Main service deployment configs |
| [gitops_worker_analysis_report.md](gitops_worker_analysis_report.md) | Worker deployment configs |
| [gitops_infrastructure_analysis_report.md](gitops_infrastructure_analysis_report.md) | Infra components (Redis, PostgreSQL) |
| [kubernetes_policies_analysis_report.md](kubernetes_policies_analysis_report.md) | NetworkPolicy, PDB, HPA |

### Summary Reports

| Report | Scope |
|--------|-------|
| [REFACTOR_CHECKLIST.md](REFACTOR_CHECKLIST.md) | Master refactoring checklist |
| [TA_REVIEW_REPORT_2026-03-02.md](TA_REVIEW_REPORT_2026-03-02.md) | TA review summary |
| [ta_report_review_order.md](ta_report_review_order.md) | Review execution order |
