# ⚙️ Common Operations Service - Complete Documentation

> **Owner**: Platform Team  
> **Last Updated**: 2026-02-15  
> **Architecture**: [Clean Architecture](../../01-architecture/) | [Service Map](../../SERVICE_INDEX.md)  
> **Ports**: 8019/9019

**Service Name**: Common Operations Service
**Version**: 1.0
**Last Updated**: 2026-01-31
**Review Status**: 🔄 Active
**Production Ready**: ✅ Active

## Overview

Common-Operations Service provides task orchestration, bulk operations (import/export), file storage (upload/download URLs), and shared operational jobs for the e-commerce platform. It manages background tasks, progress tracking, event publishing via Dapr, and settings (e.g. payment settings). Other services use it to create and monitor long-running operations.

## Architecture

### Responsibilities
- Task lifecycle: create, get, list, update progress, cancel, retry, delete
- Progress tracking and task logs/events
- Secure upload/download URL generation (S3/MinIO/local)
- Event publishing (task created, progress, completed, failed, cancelled) via Dapr
- Settings management (e.g. payment settings) via HTTP
- Health checks (DB, Redis) via common observability

### Dependencies
- **Upstream services**: Notification (optional), Order (optional), User (optional), Customer (optional), Warehouse (optional) for integrations
- **Downstream services**: Any service that submits or monitors tasks
- **External dependencies**: PostgreSQL, Redis, Dapr pub/sub, optional S3/MinIO

## API Contract

### gRPC Services
- **Service**: `api.operations.v1.OperationsService`
- **Proto location**: `common-operations/api/operations/v1/operations.proto`
- **Key methods**:
  - `CreateTask(CreateTaskRequest) → CreateTaskResponse` — Create background task; optional upload URL
  - `GetTask(GetTaskRequest) → GetTaskResponse` — Get task by ID
  - `ListTasks(ListTasksRequest) → ListTasksResponse` — List tasks with filters and pagination
  - `CancelTask(CancelTaskRequest) → CancelTaskResponse` — Cancel task
  - `RetryTask(RetryTaskRequest) → RetryTaskResponse` — Retry failed task
  - `UpdateTaskProgress(UpdateTaskProgressRequest) → UpdateTaskProgressResponse` — Update progress (internal)
  - `GetDownloadUrl(GetDownloadUrlRequest) → GetDownloadUrlResponse` — Generate download URL for output file
  - `GetTaskLogs(GetTaskLogsRequest) → GetTaskLogsResponse` — Get task logs
  - `GetTaskEvents(GetTaskEventsRequest) → GetTaskEventsResponse` — Get task events
  - `DeleteTask(DeleteTaskRequest) → DeleteTaskResponse` — Delete task
  - `Health(HealthRequest) → HealthResponse` — Health check

### HTTP Endpoints (gRPC-Gateway)
- `POST /api/v1/operations/tasks` — Create task
- `GET /api/v1/operations/tasks/{id}` — Get task
- `GET /api/v1/operations/tasks` — List tasks (query: page, pageSize, taskType, entityType, status, requestedBy, startDate, endDate, search)
- `POST /api/v1/operations/tasks/{id}/cancel` — Cancel task
- `POST /api/v1/operations/tasks/{id}/retry` — Retry task
- `PATCH /api/v1/operations/tasks/{taskId}/progress` — Update progress
- `GET /api/v1/operations/tasks/{taskId}/download` — Get download URL
- `GET /api/v1/operations/tasks/{taskId}/logs` — Get task logs
- `GET /api/v1/operations/tasks/{taskId}/events` — Get task events
- `DELETE /api/v1/operations/tasks/{id}` — Delete task
- `GET /api/v1/operations/health` — Health (gRPC)
- `GET /health` — Health (common)
- `GET /health/ready` — Readiness (DB/Redis)
- `GET /health/live` — Liveness
- `GET /metrics` — Prometheus metrics
- `GET /api/v1/settings/payment` — Get/put payment settings
- `GET /api/v1/public/settings/payment` — Public payment settings

## Data Model

### Database Tables
- **tasks**: Task metadata (id, task_type, entity_type, status, priority, requested_by, params, file_name, file_size, input_file_url, output_file_url, progress, counts, scheduled_at, started_at, completed_at, error_message, retry_count, max_retries, created_at, updated_at)
- **task_logs**: Task log entries (id, task_id, level, message, details, created_at)
- **task_events**: Task event history (id, task_id, event_type, event_data, created_at)
- **messages**: Message/notification records
- **settings**: Key-value settings (e.g. payment)

### Key Entities
- **Task**: Core entity; status flow: pending → processing → completed | failed | cancelled; supports scheduled, retry, progress
- **TaskLog / TaskEvent**: Audit trail and event history per task

## Configuration

### Environment Variables
| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `HTTP_PORT` / config `server.http.addr` | No | `0.0.0.0:8000` | HTTP server |
| `GRPC_PORT` / config `server.grpc.addr` | No | `0.0.0.0:9000` | gRPC server |
| Database `source` (config) | Yes | - | PostgreSQL DSN |
| Redis `addr` (config) | No | - | Redis; optional (graceful degradation) |
| `DAPR_GRPC_ENDPOINT` | No | `localhost:50001` | Dapr sidecar gRPC |
| File storage (config) | No | - | MinIO/S3 or local path |

### Config Files
- **Location**: `common-operations/configs/` (e.g. `config.yaml`, `config-docker.yaml`)
- **Key settings**: server (http/grpc), data (database, redis, eventbus topics), consul, operations (max_concurrent_tasks, task_timeout, file_storage)

## Deployment

### Docker
- **Image**: Build via `make docker-build` (e.g. `common-operations:$(VERSION)`)
- **Ports**: 8000 (HTTP), 9000 (gRPC); docs may use 8018/9018 in some setups
- **Health check**: `GET /health/ready`, `GET /health/live`

### Kubernetes
- **Namespace**: As per ArgoCD (e.g. support-services or platform)
- **Resources**: CPU/Memory per deployment manifests
- **Scaling**: Replicas and worker processes as configured

## Monitoring & Observability

### Metrics
- Prometheus metrics at `/metrics`
- RED metrics for API and task operations (as implemented)

### Logging
- Structured logging with context; task_id, operation, entity_type, status, duration_ms

### Tracing
- OpenTelemetry/trace endpoint configurable in config

### Health
- `/health` — General health
- `/health/ready` — Readiness (DB, Redis checks via common)
- `/health/live` — Liveness
- `/health/detailed` — Detailed health (common)

## Development

### Local Setup
1. **Prerequisites**: Go 1.25+, Docker, PostgreSQL, Redis, Dapr (optional for events)
2. **Config**: Copy/adjust `configs/config.yaml`; set database source and optional Redis
3. **Migrations**: `make migrate-up` (requires `DATABASE_URL` or script)
4. **Run**: `make run` (from repo root: `go run ./cmd/operations -conf ./configs`)
5. **Worker**: `make run` for worker entry point if using separate worker binary

### Testing
- Unit tests: `make test`
- Coverage: `make test-coverage`
- Key scenarios: task validation, state transitions, repo/cache behavior

## Troubleshooting

### Common Issues
- **Task stuck in pending**: Check worker process and Dapr/Redis connectivity
- **Cache errors**: Redis optional; service degrades without cache
- **Vendor inconsistent**: After `go get ...@latest`, run `go mod vendor` then `go build ./...` and `make wire`

### Debug Commands
```bash
# Logs (if running in K8s)
kubectl logs -f deployment/common-operations -n <namespace>

# Local
go run ./cmd/operations -conf ./configs
```

## Changelog

See service root `CHANGELOG.md` if present; otherwise see git history and release tags.

## References

- [API / OpenAPI](openapi.yaml in service root or `/docs/openapi.yaml` when served)
- [Service Checklist v3](../../10-appendix/checklists/v3/common-operations_service_checklist_v3.md)
- [Common-Operations README](../../../common-operations/README.md)
