# AGENT-24: [Title]

> **Created**: YYYY-MM-DD
> **Priority**: P0/P1/P2
> **Services**: `service-name`
> **Status**: 🔲 PENDING

---

## 📋 Overview

[Mô tả tổng quan vấn đề cần giải quyết]

---

## ✅ Checklist

### [ ] Task 1: [Title]

**File**: `service/path/to/file.go`
**Lines**: X-Y
**Risk**: [Mô tả rủi ro]
**Problem**: [Mô tả vấn đề]
**Fix**:
```go
// Code fix
```

---

## 🔧 Pre-Commit Checklist

```bash
cd <service> && wire gen ./cmd/server/ ./cmd/worker/
cd <service> && go build ./...
cd <service> && go test -race ./...
cd <service> && golangci-lint run ./...
```

## 📝 Commit Format

```
fix(<service>): <description>

Closes: AGENT-24
```
