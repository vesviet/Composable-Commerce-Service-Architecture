# ArgoCD Deployment Guide

How to deploy services using ArgoCD.

---

## Prerequisites

1. **ArgoCD installed** and configured
2. **Git repository** access
3. **SOPS/GPG keys** configured for secrets
4. **Docker registry** access
5. **Kubernetes cluster** access

---

## Deployment Process

### Step 1: Prepare Secrets

```bash
# Navigate to service directory
cd argocd/applications/<service-name>/

# Edit staging secrets
sops staging/secrets.yaml

# Edit production secrets
sops production/secrets.yaml

# Verify encryption
cat staging/secrets.yaml  # Should show encrypted content
```

### Step 2: Set Image Tag

```bash
# For staging
cat > staging/tag.yaml <<EOF
image:
  tag: "latest"  # or specific version
EOF

# For production
cat > production/tag.yaml <<EOF
image:
  tag: "v1.0.0"  # specific version
EOF
```

### Step 3: Commit Changes

```bash
# Add files
git add applications/<service-name>/

# Commit
git commit -m "Deploy <service-name> to staging/production"

# Push
git push origin main
```

### Step 4: Apply ApplicationSet

```bash
# Apply ApplicationSet (first time only)
kubectl apply -f applications/<service-name>/<service-name>-appSet.yaml

# Verify ArgoCD application created
argocd app list | grep <service-name>
```

### Step 5: Sync Application

```bash
# For staging (auto-sync enabled)
argocd app sync <service-name>-staging

# For production (manual sync required)
argocd app sync <service-name>-production
```

### Step 6: Verify Deployment

```bash
# Check pods
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service-name>

# Check logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service-name> --tail=100

# Check health
kubectl port-forward -n <namespace> svc/<service-name> 8080:80
curl http://localhost:8080/health
```

---

## Deployment Phases

### Phase 1: Core Services (Week 1-2)

Deploy in order:

1. **Gateway Service** (Day 1-2)
   ```bash
   cd argocd/applications/gateway/
   # Update staging/tag.yaml
   git commit -am "Deploy gateway to staging"
   git push
   argocd app sync gateway-staging
   ```

2. **User Service** (Day 2-3)
3. **Catalog Service** (Day 3-4)
4. **Customer Service** (Day 4-5)
5. **Pricing Service** (Day 5-6)
6. **Warehouse Service** (Day 6-7)
7. **Location Service** (Day 7-8)

**Monitor each service for 24 hours before deploying next**

### Phase 2: Business Services (Week 3-4)

8. **Order Service** (Day 1-2) - Monitor 48 hours
9. **Payment Service** (Day 3-4) - Monitor 48 hours
10. **Promotion Service** (Day 5-6)
11. **Shipping Service** (Day 7-8)

### Phase 3: Support Services (Week 5)

12. **Fulfillment Service** (Day 1-2)
13. **Notification Service** (Day 3-4)
14. **Search Service** (Day 5-6)
15. **Review Service** (Day 7)

### Phase 4: Frontend Services (Week 6)

16. **Admin Panel** (Day 1-2)
17. **Frontend** (Day 3-4) - Performance testing

### Additional Services (Week 7)

18. **Common Operations Service** (Day 1)

---

## Production Rollout (Week 8-10)

Deploy to production gradually:

### Week 8: First Batch (4 services)
- Gateway, User, Catalog, Customer

### Week 9: Second Batch (4 services)
- Order, Payment, Pricing, Warehouse

### Week 10: Final Batch (10 services)
- All remaining services

**Monitor each batch for 48 hours before next deployment**

---

## Rollback Procedure

### Quick Rollback (< 5 minutes)

```bash
# Option 1: Rollback via ArgoCD
argocd app rollback <service-name>-production

# Option 2: Update tag to previous version
echo "image:\n  tag: previous-version" > production/tag.yaml
git commit -am "Rollback <service-name>"
git push origin main
```

### Full Rollback (< 30 minutes)

```bash
# Revert to manual deployment
kubectl apply -f <service-name>/deploy/local/

# Update DNS/routing if needed

# Investigate issue

# Fix and re-deploy via ArgoCD
```

---

## Monitoring

### Health Checks

```bash
# Check application health
argocd app get <service-name>-staging

# Check sync status
argocd app sync-status <service-name>-staging

# Check pod status
kubectl get pods -n <namespace> -l app.kubernetes.io/name=<service-name>
```

### Logs

```bash
# View logs
kubectl logs -n <namespace> -l app.kubernetes.io/name=<service-name> -f

# View events
kubectl get events -n <namespace> --sort-by='.lastTimestamp'
```

### Metrics

```bash
# Port forward to service
kubectl port-forward -n <namespace> svc/<service-name> 8080:80

# Check metrics endpoint
curl http://localhost:8080/metrics
```

---

## Troubleshooting

### Application Not Syncing

```bash
# Check sync status
argocd app get <service-name>-staging

# Force sync
argocd app sync <service-name>-staging --force

# Check ArgoCD logs
kubectl logs -n argocd -l app.kubernetes.io/name=argocd-application-controller
```

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod -n <namespace> <pod-name>

# Check logs
kubectl logs -n <namespace> <pod-name>

# Check events
kubectl get events -n <namespace> --field-selector involvedObject.name=<pod-name>
```

### Secrets Issues

```bash
# Verify secrets exist
kubectl get secrets -n <namespace>

# Check secret content (base64 encoded)
kubectl get secret <service-name>-secrets -n <namespace> -o yaml

# Re-encrypt secrets
sops -e -i staging/secrets.yaml
git commit -am "Update secrets"
git push
```

---

## Best Practices

### Before Deployment
- [ ] Review Helm chart configuration
- [ ] Encrypt all secrets with SOPS
- [ ] Set correct image tag
- [ ] Test in staging first
- [ ] Prepare rollback plan

### During Deployment
- [ ] Monitor pod startup
- [ ] Check health endpoints
- [ ] Verify service connectivity
- [ ] Check logs for errors
- [ ] Monitor metrics

### After Deployment
- [ ] Monitor for 24-48 hours
- [ ] Check error rates
- [ ] Verify integrations
- [ ] Update documentation
- [ ] Notify team

---

## Quick Reference

### Common Commands

```bash
# List applications
argocd app list

# Get application details
argocd app get <app-name>

# Sync application
argocd app sync <app-name>

# Rollback application
argocd app rollback <app-name>

# Delete application
argocd app delete <app-name>

# View application logs
argocd app logs <app-name>
```

### Useful kubectl Commands

```bash
# Get pods
kubectl get pods -n <namespace>

# Get services
kubectl get svc -n <namespace>

# Get deployments
kubectl get deploy -n <namespace>

# Port forward
kubectl port-forward -n <namespace> svc/<service> 8080:80

# Execute command in pod
kubectl exec -it -n <namespace> <pod-name> -- /bin/sh
```

---

For more details, see [ArgoCD Documentation](https://argo-cd.readthedocs.io/)

