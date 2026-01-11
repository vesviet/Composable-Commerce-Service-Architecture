# gRPC Proto Sharing & Pre-release Versioning Rules (DEV)

**Audience:** All developers working on internal gRPC APIs across microservices.

**Scope:** Internal service-to-service communication (gRPC) and how we version/ship proto changes during development.

---

## 1) Proto files are the contract (must be shared)

- **Rule 1.1** All internal gRPC calls MUST use a shared `.proto` contract.
- **Rule 1.2** If Service A calls Service B via gRPC, Service A MUST depend on Service B’s proto definitions (or a shared proto package), not re-define structs/types locally.

### 1.3 Where proto lives

Use one of these approaches (pick one per service and keep consistent):

- **Option A (preferred):** Service owns its proto under `service/api/<service>/v1/*.proto` and generated stubs are consumed by other services via module dependency.
- **Option B:** Extract shared proto to `common/proto/...` if multiple services truly co-own the schema.

### 1.4 When you change proto

- Update `.proto`
- Re-generate code for the owning service
- Update any consuming services to the new tag/version
- Ensure backward compatibility expectations are met (see Section 3)

---

## 2) Pre-release tag policy (DEV)

We use **pre-release tags** to publish proto changes during development.

- **Rule 2.1** Any change to proto that affects consumers MUST be released with a new **pre-release tag**.
- **Rule 2.2** Consumers must upgrade their dependency to that new tag.

### 2.3 Tag format

Use semantic versioning with a dev pre-release suffix:

- `vMAJOR.MINOR.PATCH-dev.N`

Examples:
- `v1.3.4-dev.1`
- `v1.3.4-dev.2`

---

## 3) Semantic version rules for proto updates

When you change `.proto`, choose version bump using these rules:

### 3.1 PATCH (bugfix / optimization)

Use **PATCH** when:
- Fixing a bug
- Internal optimization
- **No change** to public API contract (no new fields/methods, no changed wire schema)

Examples:
- Server-side validation fixes
- Performance optimizations

Tag example:
- `v1.2.3-dev.1` → `v1.2.4-dev.1`

### 3.2 MINOR (backward compatible API addition)

Use **MINOR** when:
- Adding a **new RPC method**
- Adding a **new message field** that is **optional / safe default**
- Adding a new enum value (if consumers tolerate unknown values safely)

Examples:
- Add `optional string postcode = 5;`
- Add `rpc ValidatePromotions(...)`

Tag example:
- `v1.2.3-dev.1` → `v1.3.0-dev.1`

### 3.3 MAJOR (breaking change)

Use **MAJOR** when:
- Renaming an RPC
- Renaming fields
- Changing field numbers/types
- Removing fields
- Changing response structure in a way that breaks old consumers

Examples:
- Rename `CalculateTax` → `ComputeTax`
- Change `double tax_amount = 1;` to `int64 tax_amount = 1;`

Tag example:
- `v1.2.3-dev.1` → `v2.0.0-dev.1`

---

## 4) Backward compatibility rules (must follow)

- **Rule 4.1** Never change existing field numbers.
- **Rule 4.2** Never reuse removed field numbers (use `reserved`).
- **Rule 4.3** Prefer adding new optional fields with safe defaults.
- **Rule 4.4** For removals/renames: introduce new fields first, support both for at least one dev cycle, then remove in a MAJOR.

---

## 5) Developer checklist (quick)

- [ ] Confirm consumer services import the shared generated proto stubs
- [ ] Update `.proto` only in the owning service (or shared proto package)
- [ ] Re-generate stubs
- [ ] Bump version (patch/minor/major) using rules above
- [ ] Tag using `vMAJOR.MINOR.PATCH-dev.N`
- [ ] Update downstream service dependencies
- [ ] Verify gRPC calls compile + basic integration test passes
