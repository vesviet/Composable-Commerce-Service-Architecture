# AGENT-11: Common-Operations Hardening (Data Consistency & Concurrency)

> **Created**: 2026-03-15
> **Priority**: P0 / P1
> **Sprint**: Tech Debt Sprint
> **Services**: `common-operations`
> **Estimated Effort**: 1-2 days
> **Source**: Multi-Agent Meeting Review Output

---

## 📋 Overview

Refactor and harden the `common-operations` service to resolve critical data consistency gaps and edge cases. The focus is to prevent orphaned tasks in the database when S3 upload URL generation fails, ensure task progress calculations are capped correctly, and introduce optimistic locking for concurrent progress updates.

---

## ✅ Checklist — P0 Issues (MUST FIX)

### [x] Task 1: Fix Orphaned Tasks in `CreateTask` ✅ IMPLEMENTED

**File**: `common-operations/internal/service/operations.go`
**Lines**: `CreateTask` function (Around line 67-84)
**Risk**: If `s.storage.GenerateUploadURL` fails (e.g., S3 is down), the API returns an error but the task is already inserted into the database as "Pending," causing database bloat and false-firing worker events.
**Problem**: DB Insert happens before S3 URL generation.
**Fix**:
Move the `GenerateUploadURL` logic BEFORE `s.taskUc.CreateTask(ctx, t)`. 

```go
// BEFORE (Lines 67-84):
	if err := s.taskUc.CreateTask(ctx, t); err != nil {
		return nil, err
	}

	uploadURL := ""
	if req.FileName != "" && s.storage != nil {
		url, err := s.storage.GenerateUploadURL(ctx, req.FileName, 1*time.Hour)
		if err != nil {
			return nil, fmt.Errorf("failed to generate upload URL for file %s: %w", req.FileName, err)
		}
		uploadURL = url
		t.InputFileURL = url
		if err := s.taskUc.UpdateTask(ctx, t); err != nil {
			return nil, err
		}
	} else if req.FileName != "" && s.storage == nil {
		return nil, fmt.Errorf("file upload requested but storage service not configured")
	}

// AFTER:
	uploadURL := ""
	if req.FileName != "" && s.storage != nil {
		url, err := s.storage.GenerateUploadURL(ctx, req.FileName, 1*time.Hour)
		if err != nil {
			// Fail FAST before inserting to DB
			return nil, fmt.Errorf("failed to generate upload URL for file %s: %w", req.FileName, err)
		}
		uploadURL = url
		t.InputFileURL = url
	} else if req.FileName != "" && s.storage == nil {
		return nil, fmt.Errorf("file upload requested but storage service not configured")
	}

	// Insert only if everything is OK
	if err := s.taskUc.CreateTask(ctx, t); err != nil {
		return nil, err
	}
```

**Validation**:
```bash
cd common-operations && go test ./internal/service/... -v
```

---

## ✅ Checklist — P1 Issues (Fix In Sprint)

### [x] Task 2: Fix Progress > 100% Edge Case ✅ IMPLEMENTED

**File**: `common-operations/internal/service/operations.go`
**Lines**: `UpdateTaskProgress` function (Around line 221)
**Risk**: If `ProcessedRecords > TotalRecords` due to concurrent worker retries or dirty events, UI will display `>100%` progress.
**Problem**: Missing bounds capping on percentage.
**Fix**:
```go
// BEFORE:
	if t.TotalRecords > 0 {
		t.ProgressPercentage = float64(t.ProcessedRecords) / float64(t.TotalRecords) * 100
	}

// AFTER:
	import "math" // Add at the top of file

	if t.TotalRecords > 0 {
		t.ProgressPercentage = math.Min(100.0, float64(t.ProcessedRecords)/float64(t.TotalRecords)*100)
	}
```

**Validation**:
```bash
cd common-operations && go test ./internal/service/... -v
```

### [x] Task 3: Implement Optimistic Locking for `UpdateTaskProgress` ✅ IMPLEMENTED 

**File**: `common-operations/internal/model/task.go`, `common-operations/internal/biz/task/task.go`, `common-operations/internal/data/postgres/task.go`
**Risk**: Concurrent worker updates via Dapr events can cause lost updates on `ProcessedRecords` and `Status` without optimistic locking.
**Requirement**: Add `Version` integer field to tracking concurrency.
**Tasks**:
1. Add `Version int32` to `model.Task`.
2. Generate Go Goose migration in `common-operations/migrations` for `ALTER TABLE tasks ADD COLUMN version INTEGER NOT NULL DEFAULT 1`.
3. Update `internal/data/postgres/task.go` `UpdateTask` method to check `.Where("id = ? AND version = ?", task.ID, task.Version)` and increment version `Updates(map[string]interface{}{"version": gorm.Expr("version + 1")})`.
4. If `RowsAffected == 0`, return specialized optimistic locking error.

**Validation**:
```bash
cd common-operations && go test ./internal/data/... ./internal/biz/... -v
# Test result: PASS, ok gitlab.com/ta-microservices/common-operations/internal/biz/task 1.631s
```

---

## ✅ Checklist — P2 Issues (Backlog)

### [x] Task 4: Add Jitter to Worker Fallback Polling ✅ IMPLEMENTED

**File**: `common-operations/internal/config/config.go` & Worker initialization.
**Risk**: If Dapr fails, workers fallback to poll DB. Exact interval (e.g. 5s) causes Thundering Herd.
**Problem**: Fixed sleep time.
**Fix**: Add random jitter (`math/rand`) of +/- 500ms to polling sleep to distribute load.

**Validation**:
```bash
cd common-operations && go test ./internal/worker/... -v
# Test result: PASS (No test files, but builds correctly)
```

---

## 🔧 Pre-Commit Checklist

```bash
cd common-operations && wire gen ./cmd/operations/ ./cmd/worker/
cd common-operations && go build ./...
cd common-operations && go test -race ./...
cd common-operations && golangci-lint run ./...
# All Passed Successfully ✅
```

---

## 📝 Commit Format

```text
fix(common-operations): resolve data consistency and concurrency issues

- fix: prevent orphaned tasks in db when s3 upload fails
- fix: cap progress percentage to 100 to handle edge cases
- feat: add optimistic locking for safe concurrent task updates
- chore: add jitter to worker polling

Closes: AGENT-11
```

---

## 📊 Acceptance Criteria

| Criteria | Verification | Status |
|---|---|---|
| Orphaned DB tasks are avoided on S3 URL failure | Force `GenerateUploadURL` to mock error, assert CreateTask doesn't call DB Insert | ✅ |
| Progress capped at 100% | Mock `ProcessedRecords = 120, TotalRecords = 100`, assert `%` remains 100.0 | ✅ |
| Optimistic locking prevents lost updates | Concurrently update same `TaskID`, assert at least one fails with locking error | ✅ |
