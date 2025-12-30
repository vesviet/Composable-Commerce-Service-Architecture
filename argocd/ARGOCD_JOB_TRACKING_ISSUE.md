# ArgoCD Job Tracking Issue - TTL Cleanup Problem

## Issue Description

**Error**: `Resource not found in cluster: batch/v1/Job:{service}-migration-{hash}`  
**Symptom**: ArgoCD requests sync every 30 minutes for a Job that no longer exists  
**Root Cause**: TTL cleanup deleted the Job, but ArgoCD still tracks it in desired state

## Why This Happens

Our migration jobs use `ttlSecondsAfterFinished: 300` (5 minutes). After a Job completes:

1. **T+0**: Job completes successfully
2. **T+300s**: Kubernetes TTL controller deletes the Job
3. **T+301s**: ArgoCD detects Job is missing → marks as OutOfSync
4. **Every 30min**: ArgoCD auto-sync attempts to recreate the Job

## Quick Fix

### Method 1: Hard Refresh (Recommended)

```bash
# Force ArgoCD to rescan cluster state
kubectl annotate application {app-name} -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite
```

### Method 2: Use Script

```bash
./scripts/fix-argocd-job-tracking.sh argocd {app-name}
```

### Method 3: Sync with Prune

```bash
argocd app sync {app-name} --prune
```

## Permanent Solution

### Option 1: Disable TTL for Migration Jobs

**File**: `templates/migration-job.yaml`

```yaml
spec:
  # ttlSecondsAfterFinished: 300  # Comment out or remove
  backoffLimit: 3
```

**Pros**: ArgoCD tracks jobs correctly  
**Cons**: Manual cleanup required, clutters namespace

### Option 2: Conditional TTL Based on Environment

```yaml
spec:
  {{- if eq .Values.environment "production" }}
  # Keep jobs in prod for debugging
  {{- else }}
  ttlSecondsAfterFinished: 300  # Auto-cleanup in dev/staging
  {{- end }}
```

### Option 3: Increase TTL Duration

```yaml
spec:
  ttlSecondsAfterFinished: 3600  # 1 hour instead of 5 minutes
```

**Benefit**: Gives ArgoCD more time before cleanup

### Option 4: Use Helm Hook for Migrations

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync
    argocd.argoproj.io/hook-delete-policy: BeforeHookCreation
```

**Benefit**: ArgoCD manages Job lifecycle, auto-deletes before creating new one

## Applied Fix for {service}

For **catalog-dev** application:

```bash
# 1. Removed stuck operation
kubectl patch application catalog-dev -n argocd \
  --type json -p='[{"op": "remove", "path": "/operation"}]'

# 2. Hard refresh
kubectl annotate application catalog-dev -n argocd \
  argocd.argoproj.io/refresh=hard --overwrite

# 3. Verified status
kubectl get application catalog-dev -n argocd
# Status: OutOfSync:Missing → Synced:Healthy
```

## Prevention Tips

1. **Monitor Job cleanup**: Set alerts when Jobs with TTL are deleted
2. **Increase sync interval**: Change ArgoCD sync from 30min to 1hr+ if jobs complete quickly
3. **Use sync waves carefully**: Migration jobs in wave 0 should complete before wave 5
4. **Document TTL behavior**: Team should know Jobs auto-delete after 5min

## Similar Issues

This same pattern affects:
- ✅ Order migration jobs
- ✅ Promotion migration jobs  
- ✅ Common-operations migration jobs
- ✅ Catalog migration jobs (fixed today)

All services using migration-job.yaml template with TTL will encounter this.

## Automation

Add to CI/CD or cronjob:

```bash
# Run weekly to cleanup stuck ArgoCD syncs
for app in $(kubectl get applications -n argocd -o name); do
  kubectl annotate $app -n argocd argocd.argoproj.io/refresh=hard --overwrite
done
```

---

**Last Updated**: 2025-12-29  
**Related**: JOB_IMMUTABILITY_ISSUE.md, migration jobs, ArgoCD sync
