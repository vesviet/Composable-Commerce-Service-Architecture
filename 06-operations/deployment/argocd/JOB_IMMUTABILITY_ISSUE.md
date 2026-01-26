# Kubernetes Job Immutability Issue - Common Pattern

## Issue Description

**Error Message:**
```
error when replacing "/dev/shm/...": Job.batch "{service}-migration-{hash}" is invalid: 
spec.template: Invalid value: ... field is immutable
```

## Root Cause

Kubernetes Jobs are **immutable resources**. Once created, you cannot modify:
- `spec.template` (pod template)
- `spec.selector` (label selector)
- Any fields in the job spec

When ArgoCD tries to apply changes to a Job's configuration (e.g., changing environment variables, image, or config), it fails because Jobs don't support in-place updates.

## Solution Pattern

**Always delete the existing Job before ArgoCD syncs the new configuration:**

```bash
# Delete the specific job
kubectl delete job -n {namespace} {job-name} --ignore-not-found=true

# Or delete all migration jobs for a service
kubectl delete job -n core-business-dev -l app.kubernetes.io/component=migration,app.kubernetes.io/name={service}
```

After deletion, ArgoCD will automatically recreate the job with the new configuration during the next sync.

## Prevention Strategy

### Option 1: Use Job TTL (Recommended)

Add TTL to auto-cleanup completed jobs:

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: migration-job
spec:
  ttlSecondsAfterFinished: 300  # Delete after 5 minutes
  template:
    # ...
```

**Benefit**: Old jobs are automatically deleted, preventing conflicts.

### Option 2: Use Unique Job Names

Generate unique job names based on config hash:

```yaml
metadata:
  name: {{ include "service.fullname" . }}-migration-{{ .Values.image.tag | trunc 8 }}
```

**Benefit**: Each config change creates a new job instead of updating the old one.

### Option 3: Manual Cleanup Before Sync

Before making config changes:
```bash
# Delete all completed migration jobs
kubectl delete job -n {namespace} --field-selector status.successful=1
```

## Current Implementation

Our migration jobs already use **Option 1** (TTL):

```yaml
# File: templates/migration-job.yaml
spec:
  ttlSecondsAfterFinished: 300
  backoffLimit: 3
```

## Why This Still Happens

Even with TTL, the issue occurs when:
1. Job completed but TTL hasn't expired yet (still within 300 seconds)
2. You make config changes before cleanup
3. ArgoCD tries to update the existing job → **FAILS** (immutable)

## Best Practice Workflow

When updating service configuration that affects migration jobs:

1. **Check for existing jobs:**
   ```bash
   kubectl get jobs -n core-business-dev | grep {service}-migration
   ```

2. **Delete if exists:**
   ```bash
   kubectl delete job -n core-business-dev {job-name}
   ```

3. **Commit and push changes:**
   ```bash
   git add .
   git commit -m "fix: update config"
   git push
   ```

4. **Wait for ArgoCD sync or force sync:**
   ```bash
   argocd app sync {app-name}
   ```

## Automation Script

Save as `scripts/update-service-config.sh`:

```bash
#!/bin/bash
SERVICE=$1
NAMESPACE=${2:-core-business-dev}

echo "Deleting existing migration jobs for $SERVICE..."
kubectl delete job -n $NAMESPACE \
  -l app.kubernetes.io/name=$SERVICE,app.kubernetes.io/component=migration \
  --ignore-not-found=true

echo "✅ Migration jobs deleted. ArgoCD will recreate on next sync."
```

Usage:
```bash
./scripts/update-service-config.sh promotion core-business-dev
```

## Services Affected Today

- ✅ Order Service: Fixed (deleted `order-dev-migration-10c72fa2`)
- ✅ Promotion Service: Fixed (deleted `promotion-dev-migration-05bee3ff`)
- Common Operations: Pending (if similar issue occurs)

## Key Takeaway

**Kubernetes Jobs are immutable. Always delete before updating configuration.**

---

**Last Updated**: 2025-12-29  
**Related**: ArgoCD sync waves, migration jobs, TTL cleanup
