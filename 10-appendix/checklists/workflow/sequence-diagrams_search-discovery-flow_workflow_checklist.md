# Search Discovery Flow Workflow Checklist

**Workflow**: search-discovery-flow  
**Category**: sequence-diagrams  
**Diagram**: [search-discovery-flow.mmd](../../../05-workflows/sequence-diagrams/search-discovery-flow.mmd)  
**Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) (§20)  
**Related workflows**: [Search Indexing](../../../05-workflows/integration-flows/search-indexing.md), [Browse to Purchase](../../../05-workflows/customer-journey/browse-to-purchase.md)  
**Last Updated**: 2026-01-31  
**Status**: In Progress

---

## 1. Diagram Validation & Alignment

### 1.1 Sequence Diagram Validation
- [ ] Mermaid syntax is valid and renders correctly
- [ ] All participants clearly identified (Customer, Frontend, Gateway, Search, Catalog, Warehouse, Analytics, Elasticsearch, Redis Cache)
- [ ] Message flow follows logical sequence (Phase 1–8)
- [ ] Synchronous vs asynchronous calls properly indicated
- [ ] Error handling scenarios included (ES down → fallback cache, Catalog down → basic data from index, W timeout → cached inventory, Cache down → no cache)
- [ ] Alternative flows documented (cache hit/miss, authenticated vs anonymous, suggestions, zero results)

### 1.2 Business Process Alignment
- [ ] Diagram matches Search Indexing and Browse to Purchase discovery
- [ ] Phase 1–2: Query, cache check — aligned
- [ ] Phase 3: ES search — aligned
- [ ] Phase 4: Enrichment (CAT GetProductDetails, W GetInventoryStatus) — aligned
- [ ] Phase 5: Personalization (auth vs anonymous) — aligned
- [ ] Phase 6: Cache, response — aligned
- [ ] Phase 7: Analytics, search click — aligned
- [ ] Phase 8: Refinement — aligned
- [ ] Alternatives: suggestions, zero results — aligned

### 1.3 Technical Accuracy
- [ ] Service names match actual service names (S=Search, CAT=Catalog, W=Warehouse, ES=Elasticsearch, CACHE=Redis)
- [ ] API path match (e.g. GET /api/v1/search?q=...&page=1&filters=...)
- [ ] Data flow accurately represented (query → cache check → ES → enrich → personalize → cache → response)

---

## 2. Participating Services

| Service | Role | Diagram participant |
|---------|------|----------------------|
| **Customer** | User | C |
| **Frontend** | UI | F |
| **Gateway** | API routing, rate limiting | G |
| **Search Service** | SearchProducts, cache check, enrich, rank, cache write | S |
| **Catalog Service** | GetProductDetails (enrichment) | CAT |
| **Warehouse Service** | GetInventoryStatus (enrichment) | W |
| **Analytics Service** | Search analytics, search click | A |
| **Elasticsearch** | Execute search query | ES |
| **Redis Cache** | CheckSearchCache, CacheSearchResults | CACHE |

- [ ] All participating services present in diagram
- [ ] Dependency chain validated (G→S→CACHE, S→ES, S→CAT, S→W)
- [ ] Critical path identified (query → cache check → ES search → enrich → personalize → cache → response)

---

## 3. Event & API Flow

### 3.1 Key API Calls
- [ ] GET /api/v1/search?q=...&page=1&filters=... — SearchProducts
- [ ] Search → Catalog: GetProductDetails(product_ids)
- [ ] Search → Warehouse: GetInventoryStatus(product_ids)

### 3.2 Cache Flow
- [ ] Phase 2: CheckSearchCache(query_hash) — cache hit → return cached; cache miss → continue
- [ ] Phase 6: CacheSearchResults(query_hash, results, ttl=300s)
- [ ] Cache valid / cache stale handling

### 3.3 Personalization
- [ ] Authenticated user: preferences, personalization scoring, ranking, recommended products
- [ ] Anonymous user: default ranking, popular products boost

---

## 4. Error Handling & Recovery

- [ ] **ES down**: Fallback cache — aligned with Search Indexing and workflow-review-search-indexing
- [ ] **Catalog down**: Basic data from index — aligned
- [ ] **Warehouse timeout**: Cached inventory — aligned
- [ ] **Cache down**: No cache (direct ES/enrich path) — aligned
- [ ] Error branches or alt blocks present in diagram or documented in workflow doc

---

## 5. Action Items from Review

- [ ] None — diagram **aligned** with Search Indexing and Browse to Purchase discovery; Search Indexing review already validated implementation
- [ ] Use diagram for validation of search-discovery-flow.mmd when workflow docs change

---

## 6. References

- **Workflow doc**: [search-indexing.md](../../../05-workflows/integration-flows/search-indexing.md), [browse-to-purchase.md](../../../05-workflows/customer-journey/browse-to-purchase.md)
- **Review**: [workflow-review-sequence-diagrams.md](../../../07-development/standards/workflow-review-sequence-diagrams.md) — §20 Search Discovery Flow
- **Sequence guide**: [workflow-review-sequence-guide.md](../../../07-development/standards/workflow-review-sequence-guide.md) Phase 4 item 20

---

**Checklist Version**: 1.0  
**Last Updated**: 2026-01-31
