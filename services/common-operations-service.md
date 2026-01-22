# 🔧 Common-Operations Service - Task Orchestration & Shared Jobs

**Service Name**: Common-Operations Service  
**Version**: 1.0.0  
**Last Updated**: 2026-01-22  
**Production Ready**: 90%  

---

## 🎯 Overview

Common-Operations Service cung cấp task orchestration và shared operational jobs cho toàn bộ e-commerce platform. Service này xử lý background tasks, bulk operations, và common operational workflows.

### Core Capabilities
- **⚙️ Task Orchestration**: Background job processing và task scheduling
- **📤 Bulk Operations**: Mass data import/export operations
- **🔄 Async Processing**: Long-running task management
- **📊 Progress Tracking**: Real-time task progress monitoring
- **🔄 Retry Logic**: Automatic retry với exponential backoff
- **📋 Queue Management**: Job queuing và prioritization
- **📈 Performance Monitoring**: Task execution metrics
- **🛡️ Error Handling**: Comprehensive error recovery

### Business Value
- **Operational Efficiency**: Automate repetitive operational tasks
- **Scalability**: Handle large-scale data operations
- **Reliability**: Robust task processing với error recovery
- **Visibility**: Real-time monitoring của operational tasks

---

## 🏗️ Architecture

### Service Architecture
```
common-operations/
├── cmd/
│   ├── operations/              # Main service entry point
│   ├── worker/                  # Background worker processes
│   └── migrate/                 # Database migration tool
├── internal/
│   ├── biz/                      # Business logic
│   │   ├── task/                # Task orchestration
│   │   ├── bulk/                # Bulk operations
│   │   ├── import/              # Data import logic
│   │   ├── export/              # Data export logic
│   │   └── monitoring/          # Task monitoring
│   ├── data/                     # Data access
│   │   ├── postgres/            # PostgreSQL repositories
│   │   ├── redis/               # Redis for queues
│   │   └── storage/             # File storage (S3/MinIO)
│   ├── service/                  # gRPC/HTTP API layer
│   ├── server/                   # Server setup
│   ├── middleware/               # HTTP middleware
│   ├── config/                   # Configuration
│   └── worker/                   # Background workers
├── api/operations/v1/            # Protocol buffers
├── migrations/                   # Database schema
└── configs/                      # Configuration files
```

### Ports & Dependencies
- **HTTP API**: `:8017` - REST endpoints
- **gRPC API**: `:9017` - Internal communication
- **Database**: PostgreSQL (`operations_db`)
- **Cache/Queue**: Redis for job queuing
- **Storage**: S3/MinIO for file storage

---

## 🔄 Business Flow

### Task Orchestration Workflow

```mermaid
graph TD
    A[Task Request] --> B[Task Validation]
    B --> C[Task Creation]
    C --> D[Queue Assignment]
    D --> E[Worker Processing]
    E --> F[Progress Updates]
    F --> G[Task Completion]
    G --> H[Result Storage]
    H --> I[Notification]
```

### Detailed Task Processing

#### 1. Task Submission & Validation
```
User/API Request → Task Validation
├── Validate task parameters
├── Check user permissions
├── Estimate resource requirements
├── Validate data sources/destinations
└── Create task record with metadata
```

#### 2. Queue Management & Scheduling
```
Validated Task → Queue Processing
├── Assign task to appropriate queue
├── Set priority based on task type
├── Schedule execution time if needed
├── Update task status to 'queued'
└── Notify relevant systems
```

#### 3. Background Processing
```
Queued Task → Worker Execution
├── Worker picks up task from queue
├── Load task configuration
├── Execute task logic with progress tracking
├── Handle errors with retry logic
├── Update progress in real-time
└── Store results upon completion
```

#### 4. Result Handling & Notification
```
Completed Task → Result Processing
├── Store final results in designated location
├── Update task status to completed/failed
├── Send completion notifications
├── Trigger downstream processes if needed
└── Clean up temporary resources
```

---

## 🔌 Key APIs

### Task Management
```protobuf
// Submit task for execution
rpc SubmitTask(SubmitTaskRequest) returns (SubmitTaskResponse) {
  option (google.api.http) = {
    post: "/api/v1/tasks"
    body: "*"
  };
}

// Get task status
rpc GetTaskStatus(GetTaskRequest) returns (TaskStatus) {
  option (google.api.http) = {
    get: "/api/v1/tasks/{task_id}"
  };
}

// List user tasks
rpc ListTasks(ListTasksRequest) returns (ListTasksResponse) {
  option (google.api.http) = {
    get: "/api/v1/tasks"
  };
}

// Cancel running task
rpc CancelTask(CancelTaskRequest) returns (CancelTaskResponse) {
  option (google.api.http) = {
    post: "/api/v1/tasks/{task_id}/cancel"
  };
}
```

**Submit Task Request:**
```json
{
  "task_type": "product_import",
  "priority": "normal",
  "parameters": {
    "source_file": "s3://bucket/products.csv",
    "target_service": "catalog",
    "options": {
      "skip_duplicates": true,
      "validate_data": true
    }
  },
  "notification_settings": {
    "email_on_completion": true,
    "email_on_failure": true
  },
  "scheduled_at": null
}
```

### Bulk Operations
```protobuf
// Bulk data import
rpc StartBulkImport(StartBulkImportRequest) returns (BulkImportResponse) {
  option (google.api.http) = {
    post: "/api/v1/bulk/import"
    body: "*"
  };
}

// Bulk data export
rpc StartBulkExport(StartBulkExportRequest) returns (BulkExportResponse) {
  option (google.api.http) = {
    post: "/api/v1/bulk/export"
    body: "*"
  };
}

// Get bulk operation status
rpc GetBulkOperationStatus(GetBulkOperationStatusRequest) returns (BulkOperationStatus) {
  option (google.api.http) = {
    get: "/api/v1/bulk/operations/{operation_id}"
  };
}
```

### File Management
```protobuf
// Upload file for processing
rpc UploadFile(UploadFileRequest) returns (UploadFileResponse) {
  option (google.api.http) = {
    post: "/api/v1/files/upload"
    body: "*"
  };
}

// Download processed file
rpc DownloadFile(DownloadFileRequest) returns (DownloadFileResponse) {
  option (google.api.http) = {
    get: "/api/v1/files/{file_id}/download"
  };
}

// List user files
rpc ListFiles(ListFilesRequest) returns (ListFilesResponse) {
  option (google.api.http) = {
    get: "/api/v1/files"
  };
}
```

---

## ⚙️ Task Types & Operations

### Data Import Operations
- **Product Import**: Bulk product data import with validation
- **Customer Import**: Customer data migration with deduplication
- **Order Import**: Historical order data import
- **Inventory Import**: Stock level bulk updates

### Data Export Operations
- **Sales Reports**: Comprehensive sales data export
- **Customer Data**: Customer analytics export (GDPR compliant)
- **Product Catalog**: Full product data export
- **Order History**: Order data export for analysis

### Maintenance Operations
- **Data Cleanup**: Remove old/unused data
- **Index Rebuilding**: Database index optimization
- **Cache Warming**: Pre-populate frequently accessed data
- **Backup Verification**: Validate backup integrity

### Integration Operations
- **API Synchronization**: Sync data between systems
- **Third-party Updates**: Update external service data
- **Notification Batches**: Bulk notification processing

---

## 🔗 Integration Points

### All Services Integration
- **Provides**: Background task processing cho tất cả services
- **Consumes**: Task requests từ tất cả microservices
- **Data Flow**: Service tasks → Queue → Processing → Results

### Storage Integration
- **Provides**: File upload/download capabilities
- **Uses**: S3/MinIO for scalable file storage
- **Data Flow**: Upload → Storage → Processing → Results

### Notification Integration
- **Provides**: Task completion notifications
- **Uses**: Notification service for status updates
- **Events**: Task started, progress updates, completion

---

## 🎯 Business Logic

### Task Orchestration Engine
```go
func submitTask(req SubmitTaskRequest) (*Task, error) {
    // 1. Validate task parameters
    validationResult := validateTaskParameters(req)
    if !validationResult.IsValid {
        return nil, fmt.Errorf("invalid task parameters: %s", validationResult.Message)
    }

    // 2. Check user permissions
    authorized, err := checkUserPermissions(req.UserID, req.TaskType)
    if err != nil || !authorized {
        return nil, errors.New("insufficient permissions")
    }

    // 3. Estimate resource requirements
    resourceEstimate := estimateTaskResources(req.TaskType, req.Parameters)

    // 4. Create task record
    task := createTaskRecord(req, resourceEstimate)

    // 5. Assign to appropriate queue
    queueName := assignTaskToQueue(task)
    err = enqueueTask(queueName, task)
    if err != nil {
        updateTaskStatus(task.ID, "failed", err.Error())
        return nil, err
    }

    // 6. Update task status
    updateTaskStatus(task.ID, "queued", "")

    // 7. Publish task submitted event
    publishTaskEvent("task.submitted", task)

    return task, nil
}
```

### Queue Processing & Worker Logic
```go
func processTaskQueue(queueName string) {
    for {
        // 1. Get next task from queue
        task, err := dequeueTask(queueName)
        if err != nil {
            log.Printf("Error dequeuing task: %v", err)
            continue
        }

        // 2. Update task status to processing
        updateTaskStatus(task.ID, "processing", "")

        // 3. Execute task with progress tracking
        result := executeTask(task)

        // 4. Update final status
        if result.Success {
            updateTaskStatus(task.ID, "completed", "")
            storeTaskResult(task.ID, result.Data)
        } else {
            updateTaskStatus(task.ID, "failed", result.Error)
        }

        // 5. Send notifications
        sendTaskNotification(task, result)

        // 6. Publish completion event
        publishTaskEvent("task.completed", task, result)
    }
}
```

### Bulk Operation Processing
```go
func processBulkImport(operation BulkImportOperation) BulkImportResult {
    result := BulkImportResult{
        OperationID: operation.ID,
        Processed: 0,
        Succeeded: 0,
        Failed: 0,
        Errors: []ImportError{},
    }

    // 1. Open data source (file, API, database)
    dataSource, err := openDataSource(operation.Source)
    if err != nil {
        return BulkImportResult{Error: err.Error()}
    }
    defer dataSource.Close()

    // 2. Initialize progress tracking
    totalRecords := dataSource.RecordCount()
    updateProgress(operation.ID, 0, totalRecords)

    // 3. Process records in batches
    batchSize := 100
    for {
        records, err := dataSource.ReadBatch(batchSize)
        if err == io.EOF {
            break
        }
        if err != nil {
            result.Errors = append(result.Errors, ImportError{
                Record: result.Processed,
                Error: err.Error(),
            })
            continue
        }

        // 4. Process batch
        batchResult := processImportBatch(records, operation.Target)
        result.Processed += batchResult.Processed
        result.Succeeded += batchResult.Succeeded
        result.Failed += batchResult.Failed

        // 5. Update progress
        updateProgress(operation.ID, result.Processed, totalRecords)

        // 6. Check for cancellation
        if isOperationCancelled(operation.ID) {
            result.Cancelled = true
            break
        }
    }

    return result
}
```

### Retry & Error Handling
```go
func executeTaskWithRetry(task Task, maxRetries int) TaskResult {
    var lastError error

    for attempt := 0; attempt <= maxRetries; attempt++ {
        // Calculate backoff delay
        delay := calculateBackoffDelay(attempt)
        if delay > 0 {
            time.Sleep(delay)
        }

        // Execute task
        result := executeTask(task)

        // Check if successful or non-retryable error
        if result.Success || !isRetryableError(result.Error) {
            return result
        }

        lastError = errors.New(result.Error)

        // Update retry attempt
        updateTaskRetryAttempt(task.ID, attempt+1)
    }

    // All retries exhausted
    return TaskResult{
        Success: false,
        Error: fmt.Sprintf("Task failed after %d retries: %v", maxRetries, lastError),
    }
}

func calculateBackoffDelay(attempt int) time.Duration {
    // Exponential backoff: 1s, 2s, 4s, 8s, 16s, max 60s
    delay := time.Duration(1<<uint(attempt)) * time.Second
    if delay > 60*time.Second {
        delay = 60 * time.Second
    }
    return delay
}
```

---

## 📊 Event-Driven Architecture

### Published Events
- `task.submitted` - Task submitted for processing
- `task.started` - Task execution started
- `task.progress.updated` - Task progress updated
- `task.completed` - Task completed successfully
- `task.failed` - Task execution failed
- `bulk.operation.started` - Bulk operation started
- `bulk.operation.progress` - Bulk operation progress
- `bulk.operation.completed` - Bulk operation finished

### Consumed Events
- Service-specific task requests from all microservices
- File upload completion events
- External system triggers

---

## 🚀 Development Guide

### Quick Start
```bash
# Setup
cd common-operations
go mod download
make migrate-up
make api
make wire

# Run service
make run

# Run workers
make run-worker
```

### Configuration
```yaml
# configs/config.yaml
database:
  dsn: postgres://operations_user:operations_pass@postgres:5432/operations_db

redis:
  addr: redis:6379
  db: 7

storage:
  s3:
    enabled: true
    bucket: operations-files
    region: us-east-1
  minio:
    enabled: false
    endpoint: localhost:9000

queues:
  default_queue: operations.tasks
  high_priority_queue: operations.urgent
  bulk_operations_queue: operations.bulk

workers:
  count: 5
  max_concurrent_tasks: 10
  task_timeout: 3600s

retry:
  max_attempts: 3
  initial_delay: 1s
  max_delay: 60s
```

---

**Service Status**: Production Ready (90%)  
**Critical Path**: Background task processing cho toàn bộ platform  
**Performance Target**: <500ms task submission, support 1000+ concurrent tasks  
**Queue Capacity**: Handle 10,000+ queued tasks with prioritization