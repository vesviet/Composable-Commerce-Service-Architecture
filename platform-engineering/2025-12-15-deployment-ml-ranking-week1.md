# Microservices Implementation - Daily Checklist

**Last Updated**: 2025-12-14 22:07  
**Session**: Search Service Improvements & ML Ranking Foundation

---

## ✅ Completed Today (2025-12-14)

### 1. Gateway Refactoring
- [x] Phases 1-4 complete
- [x] Reduced config: 894 → 798 lines (-12.7%)
- [x] YAML anchors & middleware presets
- [x] Committed: `e298a82`
- [x] Pushed to GitLab

### 2. Payment Settings Migration
- [x] All 10 phases complete
- [x] Backend, Gateway, Tests, Migration scripts
- [x] Committed: `ff2dbbb`
- [x] Pushed to GitLab
- [x] Ready for deployment

### 3. Search Quick Wins
- [x] Quick Win #1: Popularity Boosting implemented
- [x] Quick Win #2: Query Logging foundation
- [x] Committed: `3de7013`
- [x] Pushed to GitLab
- [x] ML Ranking Phase 1 plan approved

### 4. Documentation
- [x] Search enterprise review created
- [x] ML Ranking Phase 1 plan created
- [x] 14 total artifacts created

**Total**: 5 repositories updated, 3 major features shipped

---

## 🚀 Tomorrow: Deployment & Verification

### Priority 1: Deploy Committed Changes

#### Gateway Service
- [ ] Verify CI/CD build passed
- [ ] Deploy to staging
- [ ] Test new route organization
- [ ] Verify no breaking changes
- [ ] Deploy to production

#### Payment Service
- [ ] Run migration on staging:
  ```bash
  kubectl exec -it payment-service-staging-xxx -- \
    ./migrate -path=/migrations -database="$DATABASE_URL" up
  ```
- [ ] Deploy payment service to staging
- [ ] Test payment settings API
- [ ] Test admin panel toggle
- [ ] Test frontend filtering
- [ ] Run migration on production
- [ ] Deploy to production

#### Search Service
- [ ] Run migration 011 on staging:
  ```bash
  kubectl exec -it search-service-staging-xxx -- \
    ./migrate -path=/migrations -database="$DATABASE_URL" up
  ```
- [ ] Verify popularity tables created:
  - `product_popularity`
  - `product_popularity_events`
- [ ] Deploy search service to staging
- [ ] Test popularity boosting (manual search)
- [ ] Deploy to production

### Priority 2: Monitoring & Verification

#### Metrics to Watch
- [ ] Gateway: Response times unchanged
- [ ] Payment: Settings API response < 100ms
- [ ] Search: CTR baseline measurement
  - Current CTR: ___% (measure today)
  - Target CTR: +3-5% in 1 week
- [ ] No error rate increase

#### Health Checks
- [ ] All services healthy in ArgoCD
- [ ] Database migrations successful
- [ ] No increased P95 latency
- [ ] Cache hit rates normal

---

## 🎯 Tomorrow: ML Ranking Phase 1 - Week 1

### Task 1.1: Elasticsearch LTR Plugin Setup (4h)

- [ ] **1.1.1** SSH to Elasticsearch server
  ```bash
  ssh elasticsearch-prod-1
  ```

- [ ] **1.1.2** Download LTR plugin
  ```bash
  cd /usr/share/elasticsearch
  sudo bin/elasticsearch-plugin install \
    https://github.com/o19s/elasticsearch-learning-to-rank/releases/download/v1.5.8/ltr-plugin-v1.5.8-es8.11.0.zip
  ```

- [ ] **1.1.3** Restart Elasticsearch
  ```bash
  sudo systemctl restart elasticsearch
  # Wait for cluster to be green
  curl -X GET "localhost:9200/_cluster/health?wait_for_status=green&timeout=50s"
  ```

- [ ] **1.1.4** Verify plugin installed
  ```bash
  curl -X GET "localhost:9200/_cat/plugins?v"
  # Should show: search-1 ltr-plugin 1.5.8
  ```

- [ ] **1.1.5** Create feature store
  ```bash
  curl -X PUT "localhost:9200/_ltr"
  ```

- [ ] **1.1.6** Test with sample feature
  ```bash
  curl -X PUT "localhost:9200/_ltr/_featureset/test" -H 'Content-Type: application/json' -d'
  {
    "featureset": {
      "features": [
        {
          "name": "title_score",
          "params": ["query_text"],
          "template": {
            "match": {"name": "{{query_text}}"}
          }
        }
      ]
    }
  }'
  ```

- [ ] **1.1.7** Document setup process
  - Create `docs/elasticsearch-ltr-setup.md`
  - Note any issues encountered

**Estimated**: 4 hours

### Task 1.2: Feature Definition (6h)

- [ ] **1.2.1** Create feature struct
  - File: `internal/biz/ml/features.go`
  - Define all 30 features

- [ ] **1.2.2** Document features
  - File: `docs/ml-ranking-features.md`
  - Explain each feature category
  - Include calculation formulas

- [ ] **1.2.3** Create feature categories
  - Text Relevance (10 features)
  - Product Quality (8 features)
  - Business Metrics (7 features)
  - Personalization (5 features)

**Estimated**: 6 hours

### Task 1.3: Data Collection Pipeline (6h)

- [ ] **1.3.1** Create migration 012
  - File: `migrations/012_create_ltr_training_data.sql`
  - Tables: `ltr_training_data`, `ltr_feature_cache`, `ltr_query_analytics`

- [ ] **1.3.2** Create repository
  - File: `internal/data/postgres/ltr_training_data.go`
  - Implement TrainingDataRepo interface

- [ ] **1.3.3** Create collector
  - File: `internal/biz/ml/training_data_collector.go`
  - Implement CollectSearchInteraction

- [ ] **1.3.4** Test data collection
  - Run search queries
  - Verify data in `ltr_training_data` table

**Estimated**: 6 hours

---

## 📋 Quick Reference

### Git Commits to Deploy
```bash
# Gateway
git log --oneline -1 gateway/
# e298a82 refactor(gateway): reduce config duplication with YAML anchors

# Payment
git log --oneline -1 payment/
# ff2dbbb feat(payment): implement payment settings management

# Search
git log --oneline -1 search/
# 3de7013 feat(search): implement popularity-based ranking boost
```

### Database Migrations to Run
```
payment: 007_create_payment_settings_table.sql (if not run)
search:  011_add_product_popularity_tracking.sql
search:  012_create_ltr_training_data.sql (tomorrow)
```

### Key Metrics Baseline (Measure Before Deploy)
```
Search CTR:        ___%
Search Zero-Result: ___%
Avg Search Time:   ___ms
Gateway P95:       ___ms
Payment Settings:  N/A (new feature)
```

---

## 🔧 Commands Cheat Sheet

### Deploy Services
```bash
# Staging
argocd app sync gateway-staging
argocd app sync payment-service-staging
argocd app sync search-service-staging

# Production (after staging verification)
argocd app sync gateway-production
argocd app sync payment-service-production
argocd app sync search-service-production
```

### Run Migrations
```bash
# Payment service
kubectl exec -it $(kubectl get pod -l app=payment-service -o name | head -1) -- \
  ./migrate -path=/migrations -database="$DATABASE_URL" up

# Search service
kubectl exec -it $(kubectl get pod -l app=search-service -o name | head -1) -- \
  ./migrate -path=/migrations -database="$DATABASE_URL" up
```

### Check Status
```bash
# ArgoCD
argocd app list | grep -E "gateway|payment|search"

# Pods
kubectl get pods | grep -E "gateway|payment|search"

# Logs
kubectl logs -f deployment/search-service --tail=100
```

### Verify Migrations
```bash
# Connect to DB
kubectl exec -it postgres-0 -- psql -U postgres -d search_db

# Check tables
\dt product_popularity*

# Check data
SELECT COUNT(*) FROM product_popularity;
SELECT COUNT(*) FROM product_popularity_events;
```

---

## 📚 Key Documentation

**Created Artifacts**:
- `search_service_enterprise_review.md` - Enterprise comparison & roadmap
- `search_quick_wins_walkthrough.md` - Quick wins implementation
- `ml_ranking_phase1_plan.md` - ML ranking 8-week plan
- `payment_settings_walkthrough.md` - Payment migration docs
- `payment_testing_guide.md` - Test cases
- `gateway_refactoring_walkthrough.md` - Gateway changes

**Checklists**:
- `payment-settings-migration.md` - All phases ✅
- `gateway-routes-refactoring.md` - All phases ✅

---

## ⏭️ Week 1 Timeline

**Monday**: Deploy + LTR Plugin Setup (Task 1.1)  
**Tuesday**: Feature Definition (Task 1.2)  
**Wednesday**: Data Collection Pipeline (Task 1.3)  
**Thursday**: Test & verify data collection  
**Friday**: Week 1 review, prepare Week 2

---

## 🎯 Success Criteria

### By End of Tomorrow
- [ ] All 3 services deployed to production
- [ ] All migrations run successfully
- [ ] No production incidents
- [ ] Baseline metrics measured
- [ ] LTR plugin installed (optional if time permits)

### By End of Week 1
- [ ] Elasticsearch LTR plugin working
- [ ] 30 features defined and documented
- [ ] Data collection pipeline active
- [ ] First 1000+ training samples collected

### By End of Phase 1 (Week 2)
- [ ] Feature extraction working
- [ ] Search integration complete
- [ ] 10K+ training samples
- [ ] Data export scripts ready

---

**Status**: 🟢 On Track  
**Risk Level**: Low (all code committed, tested locally)  
**Blockers**: None

**Good luck tomorrow! 🚀**
