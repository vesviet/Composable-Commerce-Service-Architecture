# Production Runbook (Day 2 SRE Operations)

## 🚨 Emergency Contacts & Escalation
- **Primary On-Call**: Tech Lead (techlead@example.com) - +1-555-0100
- **Secondary On-Call**: DevOps Lead (devops@example.com) - +1-555-0101
- **Critical Incident Channel**: Slack `#incidents-critical`

## 📊 Incident Classification
| Severity | Description | Response Time (SLA) | Examples |
|---|---|---|---|
| **P0** | System Down / Data Corruption / Financial Loss | 15 mins | Database unavailable, Double charging customers, Security breach |
| **P1** | Major Feature Broken / Significant Latency | 30 mins | Checkout failing updates, Search down, Latency > 2s |
| **P2** | Minor Feature Broken / UX Degradation | 2 hours | Email notifications delayed, Image loading slow |
| **P3** | Internal Tools / Non-Urgent Bugs | 24 hours | Admin dashboard slow, Typo in UI |

---

## 🛠 Common Incident Scenarios & Mitigation

### 1. High Latency / API Timeouts
**Symptoms**: APM shows p99 latency > 1s, Users report "spinners", High `context deadline exceeded` logs.
**Immediate Actions**:
1. Check Database Load: `kubectl logs -l app=postgresql --tail=100` (High CPU/Memory?)
2. Check Pod Health: `kubectl get pods -n microservices` (CrashLoopBackOff? OOMKilled?)
3. **Mitigation**:
   - Limit traffic (Rate Limiting): Apply tighter Ingress rate limits.
   - Scale Up: `kubectl scale deployment <service-name> --replicas=5 -n microservices`

### 2. Payment Gateway Failure (SAGA-001)
**Symptoms**: Checkout failures with `payment authorization failed` errors, high `failed_compensation` logs.
**Investigation**:
- Check Gateway Status Page (Stripe/PayPal).
- Check Checkout Service Logs: `kubectl logs -l app=checkout -n microservices | grep "payment"`
**Mitigation**:
- **Switch Provider**: Update feature flag `ENABLE_STRIPE=false`, `ENABLE_PAYPAL=true` (if dynamic switching supported).
- **Disable Checkout**: If severe, put site in "Maintenance Mode" via CDN or Ingress.

### 3. Database Connection Saturation
**Symptoms**: Services failing to start, `too many clients` errors in logs.
**Investigation**:
- Check active connections: Execute SQL `SELECT count(*) FROM pg_stat_activity;`
- Identify culprit service: `SELECT application_name, count(*) FROM pg_stat_activity GROUP BY application_name;`
**Mitigation**:
- Kill idle connections: `SELECT pg_terminate_backend(pid) FROM pg_stat_activity WHERE state='idle' AND query_start < NOW() - INTERVAL '5 minutes';`
- Restart culprit service pod to release pool: `kubectl delete pod -l app=<culprit> -n microservices`

### 4. Promotion Abuse (Unlimited Coupons)
**Symptoms**: Unusual spike in `DiscountTotal`, inventory depletion for specific items.
**Investigation**:
- Check Analytics Dashboard: "Sales Velocity by Promo Code".
- Logs: `kubectl logs -l app=checkout | grep "ApplyPromotion"`
**Mitigation**:
- **Emergency Disable**: Add coupon code to `BLACKLISTED_COUPONS` ConfigMap/Secret.
- **Rollback Promotion**: Deactivate campaign via `promotion-admin` CLI or API.

---

## 🔄 Routine Operations (Day 2)

### Deployment Rollback
If a new deployment causes P0/P1 issues:
```bash
# Check revision history
kubectl rollout history deployment/<service-name> -n microservices

# Undo to previous revision
kubectl rollout undo deployment/<service-name> -n microservices
```

### Feature Flag Toggles (via ConfigMap)
1. Edit ConfigMap:
   ```bash
   kubectl edit configmap <service-config> -n microservices
   ```
2. Restart Pods (to pick up changes if not hot-reloaded):
   ```bash
   kubectl rollout restart deployment/<service-name> -n microservices
   ```

### Debugging in Production (Restricted)
**Do NOT use `exec` unless necessary.**
1. Use **Ephemeral Debug Container**:
   ```bash
   kubectl debug -it <pod-name> --image=busybox:1.28 --target=<container-name>
   ```
2. **Port Forward** for private admin endpoints (only from secure bastion):
   ```bash
   kubectl port-forward svc/<service-name> 8080:8080 -n microservices
   ```

---

## 📈 Monitoring & Observability
- **Dashboards**: Grafana (`http://monitoring.cluster.local`)
  - `Global Overview`: Service Health, Error Rates, Request Volume.
  - `Checkout Business Metrics`: Orders/min, payment success rate, discount usage.
  - `PostgreSQL Internals`: Connections, Cache Hit Ratio, Deadlocks.
- **Alerts**: Sent to Slack `#alerts` (Critical PagerDuty for P0).

## 🛡 Security Patching
- **Monthly**: Review container base image vulnerabilities (Trivy scan).
- **Quarterly**: Rotate DB credentials and API keys.
