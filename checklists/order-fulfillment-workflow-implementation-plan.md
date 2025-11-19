# 🚀 Order Fulfillment Workflow - Implementation Plan

**Created:** 2025-01-27  
**Status:** 📋 **Planning**  
**Priority:** 🔴 **High**  
**⚠️ IMPORTANT: Delete this file after implementation is complete**

---

## 📋 Overview

This document outlines the implementation plan for missing features in the Order Fulfillment Workflow checklist.

**Total Missing Features:** 23 requirements  
**Estimated Implementation Time:** 4-6 weeks  
**Priority Order:** High → Medium → Low

---

## 🎯 Implementation Phases

### Phase 1: Critical Features (Week 1-2)
- Quality Control System
- Exception Handling
- Barcode Validation

### Phase 2: Optimization (Week 3-4)
- Pick Path Optimization
- Weight Verification
- Packing Slip Generation

### Phase 3: Enhancements (Week 5-6)
- Substitution Handling
- Photo Verification
- Batch Picking
- Performance Metrics

---

## 🔴 Phase 1: Critical Features

### 1.1 Quality Control System

**Priority:** 🔴 **Critical**  
**Estimated Time:** 3-4 days  
**Dependencies:** None

#### Requirements to Implement

- [ ] **R4.1.1** Random sample QC (10% of orders)
- [ ] **R4.1.2** High-value order QC (100% over threshold)
- [ ] **R4.1.3** Photo verification
- [ ] **R4.1.4** Item count verification
- [ ] **R4.1.5** Defect detection

#### Implementation Steps

**Step 1: Add QC Fields to Fulfillment Model**

**File:** `fulfillment/internal/model/fulfillment.go`

```go
// Add to Fulfillment struct
QCCheckedAt     *time.Time `gorm:"type:timestamp with time zone"`
QCCheckedBy     *string    `gorm:"type:uuid"`
QCPassed        bool       `gorm:"default:false"`
QCRequired      bool       `gorm:"default:false"`
QCReason        string     `gorm:"type:varchar(50)"` // "random", "high_value", "manual"
```

**Migration:** Create `011_add_qc_fields.sql`

```sql
ALTER TABLE fulfillments
ADD COLUMN qc_checked_at TIMESTAMP WITH TIME ZONE,
ADD COLUMN qc_checked_by UUID,
ADD COLUMN qc_passed BOOLEAN DEFAULT FALSE,
ADD COLUMN qc_required BOOLEAN DEFAULT FALSE,
ADD COLUMN qc_reason VARCHAR(50);

CREATE INDEX idx_fulfillments_qc_required ON fulfillments(qc_required) WHERE qc_required = TRUE;
```

**Step 2: Create QC Models**

**File:** `fulfillment/internal/model/qc_result.go` (NEW)

```go
package model

import (
    "time"
)

type QCResult struct {
    ID            string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    FulfillmentID string    `gorm:"type:uuid;not null;index"`
    CheckerID     string    `gorm:"type:uuid;not null"`
    Passed        bool      `gorm:"not null"`
    Reason        string    `gorm:"type:varchar(50)"` // "random", "high_value", "manual"
    Checks        []QCCheck `gorm:"foreignKey:QCResultID"`
    CheckedAt      time.Time `gorm:"not null;default:now()"`
    CreatedAt     time.Time `gorm:"not null;default:now()"`
    UpdatedAt     time.Time `gorm:"not null;default:now()"`
}

type QCCheck struct {
    ID         string    `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    QCResultID string    `gorm:"type:uuid;not null;index"`
    Type       string    `gorm:"type:varchar(50);not null"` // "item_count", "item_verification", "package_weight", "photo_verification", "defect"
    Passed     bool      `gorm:"not null"`
    Message    string    `gorm:"type:text"`
    CreatedAt  time.Time `gorm:"not null;default:now()"`
}
```

**Migration:** Create `012_create_qc_results_table.sql`

**Step 3: Add QC Configuration**

**File:** `fulfillment/internal/constants/qc.go` (NEW)

```go
package constants

const (
    // QC Sampling Rates
    QCRandomSampleRate = 0.10  // 10%
    QCHighValueThreshold = 1000000.0 // 1M VND
    
    // QC Check Types
    QCCheckTypeItemCount       = "item_count"
    QCCheckTypeItemVerification = "item_verification"
    QCCheckTypePackageWeight    = "package_weight"
    QCCheckTypePhotoVerification = "photo_verification"
    QCCheckTypeDefect          = "defect"
    
    // QC Reasons
    QCReasonRandom    = "random"
    QCReasonHighValue = "high_value"
    QCReasonManual    = "manual"
)
```

**Step 4: Implement QC Usecase**

**File:** `fulfillment/internal/biz/qc/qc.go` (NEW)

```go
package qc

import (
    "context"
    "math/rand"
    "time"
    
    "gitlab.com/ta-microservices/fulfillment/internal/constants"
    "gitlab.com/ta-microservices/fulfillment/internal/model"
    // ... other imports
)

type QCUsecase struct {
    repo          QCRepo
    fulfillmentRepo FulfillmentRepo
    eventPub      EventPublisher
    log           *log.Helper
}

// ShouldPerformQC determines if QC is required
func (uc *QCUsecase) ShouldPerformQC(ctx context.Context, fulfillment *model.Fulfillment) (bool, string) {
    // Check if already QC'd
    if fulfillment.QCCheckedAt != nil {
        return false, ""
    }
    
    // High-value order: 100% QC
    if fulfillment.CODAmount != nil && *fulfillment.CODAmount >= constants.QCHighValueThreshold {
        return true, constants.QCReasonHighValue
    }
    
    // Random sample: 10%
    if rand.Float64() < constants.QCRandomSampleRate {
        return true, constants.QCReasonRandom
    }
    
    return false, ""
}

// PerformQC performs quality control check
func (uc *QCUsecase) PerformQC(ctx context.Context, fulfillmentID, checkerID string) (*model.QCResult, error) {
    // Get fulfillment with packages and items
    fulfillment, err := uc.fulfillmentRepo.FindByID(ctx, fulfillmentID)
    if err != nil {
        return nil, err
    }
    
    result := &model.QCResult{
        ID:            uuid.New().String(),
        FulfillmentID: fulfillmentID,
        CheckerID:     checkerID,
        Passed:        true,
        Checks:        []model.QCCheck{},
        CheckedAt:     time.Now(),
    }
    
    // 1. Verify item count
    expectedCount := 0
    for _, item := range fulfillment.Items {
        expectedCount += item.QuantityOrdered
    }
    
    actualCount := 0
    for _, pkg := range fulfillment.Packages {
        for _, item := range pkg.Items {
            actualCount += item.QuantityPacked
        }
    }
    
    if expectedCount != actualCount {
        result.Passed = false
        result.Checks = append(result.Checks, model.QCCheck{
            Type:    constants.QCCheckTypeItemCount,
            Passed:  false,
            Message: fmt.Sprintf("Expected %d items, found %d", expectedCount, actualCount),
        })
    } else {
        result.Checks = append(result.Checks, model.QCCheck{
            Type:   constants.QCCheckTypeItemCount,
            Passed: true,
        })
    }
    
    // 2. Verify all items scanned
    for _, pkg := range fulfillment.Packages {
        for _, item := range pkg.Items {
            // Check if item was verified (scanned)
            // This requires adding Verified field to PackageItem
            // For now, assume all items in package are verified
        }
    }
    
    // 3. Check package weight
    for _, pkg := range fulfillment.Packages {
        if pkg.WeightKg == 0 {
            result.Passed = false
            result.Checks = append(result.Checks, model.QCCheck{
                Type:    constants.QCCheckTypePackageWeight,
                Passed:  false,
                Message: fmt.Sprintf("Package %s not weighed", pkg.ID),
            })
        }
    }
    
    // 4. Visual inspection (photo required)
    for _, pkg := range fulfillment.Packages {
        // Check if photo exists (requires PhotoURL field in Package)
        // For now, skip if PhotoURL not implemented
    }
    
    // Save QC result
    if err := uc.repo.Create(ctx, result); err != nil {
        return nil, err
    }
    
    // Update fulfillment
    now := time.Now()
    fulfillment.QCCheckedAt = &now
    fulfillment.QCCheckedBy = &checkerID
    fulfillment.QCPassed = result.Passed
    
    if err := uc.fulfillmentRepo.Update(ctx, fulfillment); err != nil {
        return nil, err
    }
    
    // Publish QC event
    if uc.eventPub != nil {
        uc.eventPub.PublishQCPerformed(ctx, result)
    }
    
    return result, nil
}
```

**Step 5: Add QC Service**

**File:** `fulfillment/internal/service/qc_service.go` (NEW)

```go
package service

// PerformQC performs quality control check
func (s *FulfillmentService) PerformQC(ctx context.Context, req *v1.PerformQCRequest) (*v1.PerformQCResponse, error) {
    // Implementation
}
```

**Step 6: Add QC Proto**

**File:** `fulfillment/api/fulfillment/v1/fulfillment.proto`

```protobuf
// Add to FulfillmentService
rpc PerformQC(PerformQCRequest) returns (PerformQCResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/qc"
    body: "*"
  };
}

message PerformQCRequest {
  string fulfillment_id = 1;
  string checker_id = 2;
}

message PerformQCResponse {
  bool success = 1;
  QCResult qc_result = 2;
}

message QCResult {
  string id = 1;
  string fulfillment_id = 2;
  string checker_id = 3;
  bool passed = 4;
  string reason = 5;
  repeated QCCheck checks = 6;
  google.protobuf.Timestamp checked_at = 7;
}

message QCCheck {
  string type = 1;
  bool passed = 2;
  string message = 3;
}
```

**Step 7: Auto-trigger QC**

**File:** `fulfillment/internal/biz/fulfillment/fulfillment.go`

Add to `MarkReadyToShip()`:

```go
// Check if QC is required
if uc.qcUsecase != nil {
    shouldQC, reason := uc.qcUsecase.ShouldPerformQC(ctx, fulfillment)
    if shouldQC {
        fulfillment.QCRequired = true
        fulfillment.QCReason = reason
        // Don't mark ready until QC passed
        return fmt.Errorf("QC required before shipping: %s", reason)
    }
}
```

#### Testing

- [ ] Test random sampling (10% rate)
- [ ] Test high-value QC (100% threshold)
- [ ] Test item count mismatch detection
- [ ] Test package weight missing detection
- [ ] Test QC pass/fail scenarios

---

### 1.2 Exception Handling

**Priority:** 🔴 **Critical**  
**Estimated Time:** 2-3 days  
**Dependencies:** None

#### Requirements to Implement

- [ ] **R7.1** Handle pick failures
- [ ] **R7.2** Handle pack failures
- [ ] **R7.3** Retry logic

#### Implementation Steps

**Step 1: Add Failure Statuses**

**File:** `fulfillment/internal/constants/fulfillment_status.go`

```go
const (
    // ... existing statuses
    FulfillmentStatusPickFailed FulfillmentStatus = "pick_failed"
    FulfillmentStatusPackFailed FulfillmentStatus = "pack_failed"
)

// Update transitions
var FulfillmentStatusTransitions = map[FulfillmentStatus][]FulfillmentStatus{
    // ... existing transitions
    FulfillmentStatusPicking: {
        FulfillmentStatusPicked,
        FulfillmentStatusPickFailed,  // Add
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPacking: {
        FulfillmentStatusPacked,
        FulfillmentStatusPackFailed,  // Add
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPickFailed: {
        FulfillmentStatusPicking,  // Retry
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPackFailed: {
        FulfillmentStatusPacking,  // Retry
        FulfillmentStatusCancelled,
    },
}
```

**Migration:** Update constraint in `001_create_fulfillments_table.sql`

```sql
ALTER TABLE fulfillments
DROP CONSTRAINT IF EXISTS chk_fulfillment_status;

ALTER TABLE fulfillments
ADD CONSTRAINT chk_fulfillment_status CHECK (
    status IN ('pending', 'planning', 'picking', 'picked', 'packing', 'packed', 
               'ready', 'shipped', 'completed', 'cancelled', 'pick_failed', 'pack_failed')
);
```

**Step 2: Add Failure Fields**

**File:** `fulfillment/internal/model/fulfillment.go`

```go
// Add to Fulfillment struct
PickFailedAt    *time.Time `gorm:"type:timestamp with time zone"`
PickFailedReason string    `gorm:"type:text"`
PickRetryCount  int        `gorm:"default:0"`
PackFailedAt    *time.Time `gorm:"type:timestamp with time zone"`
PackFailedReason string    `gorm:"type:text"`
PackRetryCount  int        `gorm:"default:0"`
MaxRetries      int        `gorm:"default:3"`
```

**Migration:** Create `013_add_failure_fields.sql`

**Step 3: Implement Failure Handling**

**File:** `fulfillment/internal/biz/fulfillment/fulfillment.go`

```go
// MarkPickFailed marks fulfillment as pick failed
func (uc *FulfillmentUseCase) MarkPickFailed(ctx context.Context, id string, reason string) error {
    fulfillment, err := uc.repo.FindByID(ctx, id)
    if err != nil {
        return err
    }
    
    if fulfillment.Status != constants.FulfillmentStatusPicking {
        return fmt.Errorf("cannot mark pick failed from status: %s", fulfillment.Status)
    }
    
    oldStatus := string(fulfillment.Status)
    now := time.Now()
    
    fulfillment.Status = constants.FulfillmentStatusPickFailed
    fulfillment.PickFailedAt = &now
    fulfillment.PickFailedReason = reason
    fulfillment.PickRetryCount++
    fulfillment.UpdatedAt = time.Now()
    
    if err := uc.repo.Update(ctx, fulfillment); err != nil {
        return err
    }
    
    // Publish event
    if uc.eventPub != nil {
        uc.eventPub.PublishFulfillmentStatusChanged(ctx, fulfillment, oldStatus, string(fulfillment.Status), reason)
    }
    
    return nil
}

// MarkPackFailed marks fulfillment as pack failed
func (uc *FulfillmentUseCase) MarkPackFailed(ctx context.Context, id string, reason string) error {
    // Similar to MarkPickFailed
}

// RetryPick retries picking after failure
func (uc *FulfillmentUseCase) RetryPick(ctx context.Context, id string) error {
    fulfillment, err := uc.repo.FindByID(ctx, id)
    if err != nil {
        return err
    }
    
    if fulfillment.Status != constants.FulfillmentStatusPickFailed {
        return fmt.Errorf("cannot retry pick from status: %s", fulfillment.Status)
    }
    
    if fulfillment.PickRetryCount >= fulfillment.MaxRetries {
        return fmt.Errorf("max retries (%d) exceeded", fulfillment.MaxRetries)
    }
    
    // Reset to picking status
    oldStatus := string(fulfillment.Status)
    fulfillment.Status = constants.FulfillmentStatusPicking
    fulfillment.PickFailedAt = nil
    fulfillment.PickFailedReason = ""
    fulfillment.UpdatedAt = time.Now()
    
    if err := uc.repo.Update(ctx, fulfillment); err != nil {
        return err
    }
    
    // Publish event
    if uc.eventPub != nil {
        uc.eventPub.PublishFulfillmentStatusChanged(ctx, fulfillment, oldStatus, string(fulfillment.Status), "retry")
    }
    
    return nil
}

// RetryPack retries packing after failure
func (uc *FulfillmentUseCase) RetryPack(ctx context.Context, id string) error {
    // Similar to RetryPick
}
```

**Step 4: Add Proto Endpoints**

**File:** `fulfillment/api/fulfillment/v1/fulfillment.proto`

```protobuf
// Mark pick failed
rpc MarkPickFailed(MarkPickFailedRequest) returns (MarkPickFailedResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/pick-failed"
    body: "*"
  };
}

// Mark pack failed
rpc MarkPackFailed(MarkPackFailedRequest) returns (MarkPackFailedResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/pack-failed"
    body: "*"
  };
}

// Retry pick
rpc RetryPick(RetryPickRequest) returns (RetryPickResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/retry-pick"
    body: "*"
  };
}

// Retry pack
rpc RetryPack(RetryPackRequest) returns (RetryPackResponse) {
  option (google.api.http) = {
    post: "/api/v1/fulfillments/{fulfillment_id}/retry-pack"
    body: "*"
  };
}
```

#### Testing

- [ ] Test pick failure handling
- [ ] Test pack failure handling
- [ ] Test retry logic (max retries)
- [ ] Test retry after failure
- [ ] Test failure events

---

### 1.3 Barcode Validation

**Priority:** 🔴 **Critical**  
**Estimated Time:** 1-2 days  
**Dependencies:** None

#### Requirements to Implement

- [ ] **R2.2.2** Scanner integration (barcode)
- [ ] **R2.2.3** Verify picked items (enhance with barcode)

#### Implementation Steps

**Step 1: Add Barcode Validation to Picklist**

**File:** `fulfillment/internal/biz/picklist/picklist.go`

Update `ConfirmPicklistItem()`:

```go
// ConfirmPicklistItem confirms a single picklist item with barcode validation
func (uc *PicklistUsecase) ConfirmPicklistItem(ctx context.Context, picklistID string, itemID string, quantityPicked int, scannedBarcode string, pickedBy *string) error {
    // ... existing code to get picklist and item
    
    // Validate barcode
    if scannedBarcode != "" && scannedBarcode != targetItem.ProductSKU {
        return &PickError{
            Code:    "BARCODE_MISMATCH",
            Message: fmt.Sprintf("Scanned barcode '%s' does not match expected SKU '%s'", scannedBarcode, targetItem.ProductSKU),
            ExpectedSKU: targetItem.ProductSKU,
            ScannedBarcode: scannedBarcode,
        }
    }
    
    // ... rest of existing code
}
```

**Step 2: Add PickError Type**

**File:** `fulfillment/internal/biz/picklist/errors.go` (NEW)

```go
package picklist

import "fmt"

type PickError struct {
    Code           string
    Message        string
    ExpectedSKU    string
    ScannedBarcode string
}

func (e *PickError) Error() string {
    return fmt.Sprintf("%s: %s", e.Code, e.Message)
}
```

**Step 3: Update Proto**

**File:** `fulfillment/api/picklist/v1/picklist.proto`

```protobuf
message ConfirmPicklistItemRequest {
  string picklist_id = 1;
  string item_id = 2;
  int32 quantity_picked = 3;
  string scanned_barcode = 4;  // Add this
  string picked_by = 5;
}
```

**Step 4: Add Barcode Validation to Packing**

**File:** `fulfillment/internal/biz/package_biz/package.go`

Similar barcode validation for packing items.

#### Testing

- [ ] Test barcode match success
- [ ] Test barcode mismatch error
- [ ] Test empty barcode (optional)
- [ ] Test barcode validation in packing

---

## 🟡 Phase 2: Optimization

### 2.1 Pick Path Optimization

**Priority:** 🟡 **High**  
**Estimated Time:** 3-4 days  
**Dependencies:** Warehouse zone data

#### Requirements to Implement

- [ ] **R2.1.2** Group by warehouse zone
- [ ] **R2.1.3** Sort by pick path

#### Implementation Steps

**Step 1: Add Zone Information**

**File:** `fulfillment/internal/model/picklist.go`

Already has `warehouse_location`, `bin_location`, `aisle`, `shelf` fields.

**Step 2: Implement Zone Grouping**

**File:** `fulfillment/internal/biz/picklist/picklist.go`

Update `GeneratePicklist()`:

```go
// Group items by zone
zoneMap := make(map[string][]*model.PicklistItem)

for _, item := range fulfillment.Items {
    zoneID := item.WarehouseLocation // Use warehouse_location as zone
    if zoneID == "" {
        zoneID = "DEFAULT" // Fallback zone
    }
    zoneMap[zoneID] = append(zoneMap[zoneID], item)
}

// Get zone layout from warehouse service (if available)
zoneLayout := uc.getZoneLayout(ctx, *fulfillment.WarehouseID)

// Optimize pick path
optimizedZones := uc.optimizePickPath(zoneMap, zoneLayout)
```

**Step 3: Implement Route Optimization**

**File:** `fulfillment/internal/biz/picklist/path_optimizer.go` (NEW)

```go
package picklist

import (
    "sort"
)

type ZoneLayout struct {
    ZoneID     string
    ZoneName   string
    X          float64 // X coordinate in warehouse
    Y          float64 // Y coordinate in warehouse
    Sequence   int     // Default sequence
}

// optimizePickPath optimizes picking route using nearest neighbor
func (uc *PicklistUsecase) optimizePickPath(zoneMap map[string][]*model.PicklistItem, zoneLayout []ZoneLayout) []ZoneGroup {
    // Convert zone map to zone groups
    zoneGroups := make([]ZoneGroup, 0, len(zoneMap))
    
    for zoneID, items := range zoneMap {
        // Get zone layout info
        layout := uc.findZoneLayout(zoneID, zoneLayout)
        
        zoneGroups = append(zoneGroups, ZoneGroup{
            ZoneID:   zoneID,
            ZoneName: layout.ZoneName,
            Items:    items,
            X:        layout.X,
            Y:        layout.Y,
            Sequence: layout.Sequence,
        })
    }
    
    // Sort by sequence if available, otherwise use nearest neighbor
    if uc.hasZoneCoordinates(zoneGroups) {
        zoneGroups = uc.nearestNeighborSort(zoneGroups)
    } else {
        // Fallback: sort by zone ID
        sort.Slice(zoneGroups, func(i, j int) bool {
            return zoneGroups[i].ZoneID < zoneGroups[j].ZoneID
        })
    }
    
    // Assign pick sequence to items
    sequence := 1
    for _, zone := range zoneGroups {
        // Sort items within zone by bin location
        sort.Slice(zone.Items, func(i, j int) bool {
            return zone.Items[i].BinLocation < zone.Items[j].BinLocation
        })
        
        for _, item := range zone.Items {
            item.PickSequence = &sequence
            sequence++
        }
    }
    
    return zoneGroups
}

// nearestNeighborSort sorts zones using nearest neighbor algorithm
func (uc *PicklistUsecase) nearestNeighborSort(zones []ZoneGroup) []ZoneGroup {
    if len(zones) == 0 {
        return zones
    }
    
    // Start from receiving area (0, 0) or first zone
    sorted := []ZoneGroup{zones[0]}
    remaining := zones[1:]
    
    for len(remaining) > 0 {
        current := sorted[len(sorted)-1]
        nearestIdx := 0
        nearestDist := uc.distance(current.X, current.Y, remaining[0].X, remaining[0].Y)
        
        for i := 1; i < len(remaining); i++ {
            dist := uc.distance(current.X, current.Y, remaining[i].X, remaining[i].Y)
            if dist < nearestDist {
                nearestDist = dist
                nearestIdx = i
            }
        }
        
        sorted = append(sorted, remaining[nearestIdx])
        remaining = append(remaining[:nearestIdx], remaining[nearestIdx+1:]...)
    }
    
    return sorted
}

func (uc *PicklistUsecase) distance(x1, y1, x2, y2 float64) float64 {
    dx := x2 - x1
    dy := y2 - y1
    return dx*dx + dy*dy // Squared distance (no need for sqrt)
}
```

**Step 4: Update Picklist Generation**

**File:** `fulfillment/internal/biz/picklist/picklist.go`

Update to use optimized path when creating picklist items.

#### Testing

- [ ] Test zone grouping
- [ ] Test route optimization
- [ ] Test pick sequence assignment
- [ ] Test with missing zone data

---

### 2.2 Weight Verification

**Priority:** 🟡 **High**  
**Estimated Time:** 1-2 days  
**Dependencies:** Product weight data from catalog

#### Requirements to Implement

- [ ] **R3.1.5** Weigh package (enhance with verification)

#### Implementation Steps

**Step 1: Add Expected Weight Calculation**

**File:** `fulfillment/internal/biz/package_biz/package.go`

```go
// CalculateExpectedWeight calculates expected weight from items
func (uc *PackageUsecase) CalculateExpectedWeight(ctx context.Context, items []model.PackageItem) (float64, error) {
    totalWeight := 0.0
    
    for _, item := range items {
        // Get product weight from catalog service
        product, err := uc.catalogClient.GetProduct(ctx, item.ProductID)
        if err != nil {
            return 0, err
        }
        
        itemWeight := product.WeightKg * float64(item.QuantityPacked)
        totalWeight += itemWeight
    }
    
    // Add box weight (estimate based on package type)
    boxWeight := uc.getBoxWeight(pkg.PackageType)
    totalWeight += boxWeight
    
    return totalWeight, nil
}

// VerifyPackageWeight verifies package weight against expected
func (uc *PackageUsecase) VerifyPackageWeight(ctx context.Context, packageID string, actualWeight float64) error {
    pkg, err := uc.repo.FindByID(ctx, packageID)
    if err != nil {
        return err
    }
    
    // Calculate expected weight
    expectedWeight, err := uc.CalculateExpectedWeight(ctx, pkg.Items)
    if err != nil {
        return err
    }
    
    // Allow 5% variance
    variance := math.Abs(actualWeight - expectedWeight) / expectedWeight
    
    if variance > 0.05 {
        return &PackError{
            Code:          "WEIGHT_MISMATCH",
            Message:       fmt.Sprintf("Weight variance %.1f%% exceeds 5%% threshold", variance*100),
            ExpectedWeight: expectedWeight,
            ActualWeight:   actualWeight,
        }
    }
    
    // Update package weight
    pkg.WeightKg = actualWeight
    return uc.repo.Update(ctx, pkg)
}
```

**Step 2: Update ConfirmPacked**

**File:** `fulfillment/internal/biz/fulfillment/fulfillment.go`

Add weight verification to `ConfirmPacked()`:

```go
// Verify weight if package usecase available
if uc.packageUsecase != nil {
    if err := uc.packageUsecase.VerifyPackageWeight(ctx, pkg.ID, packageData.WeightKg); err != nil {
        return fmt.Errorf("weight verification failed: %w", err)
    }
}
```

#### Testing

- [ ] Test weight verification success
- [ ] Test weight variance > 5%
- [ ] Test missing product weight
- [ ] Test box weight calculation

---

### 2.3 Packing Slip Generation

**Priority:** 🟡 **High**  
**Estimated Time:** 2-3 days  
**Dependencies:** PDF generation library

#### Requirements to Implement

- [ ] **R3.1.3** Generate packing slip

#### Implementation Steps

**Step 1: Add Packing Slip Field**

**File:** `fulfillment/internal/model/package.go`

```go
// Add to Package struct
PackingSlipURL string `gorm:"type:text"`
```

**Migration:** Create `014_add_packing_slip_url.sql`

**Step 2: Implement Packing Slip Generation**

**File:** `fulfillment/internal/biz/package_biz/packing_slip.go` (NEW)

```go
package package_biz

import (
    "bytes"
    "fmt"
    
    "github.com/jung-kurt/gofpdf"
)

// GeneratePackingSlip generates PDF packing slip
func (uc *PackageUsecase) GeneratePackingSlip(ctx context.Context, pkg *model.Package, fulfillment *model.Fulfillment) (string, error) {
    // Create PDF
    pdf := gofpdf.New("P", "mm", "A4", "")
    pdf.AddPage()
    
    // Header
    pdf.SetFont("Arial", "B", 16)
    pdf.Cell(40, 10, "PACKING SLIP")
    pdf.Ln(10)
    
    // Order info
    pdf.SetFont("Arial", "", 12)
    pdf.Cell(40, 10, fmt.Sprintf("Order Number: %s", fulfillment.OrderNumber))
    pdf.Ln(5)
    pdf.Cell(40, 10, fmt.Sprintf("Fulfillment: %s", fulfillment.FulfillmentNumber))
    pdf.Ln(5)
    pdf.Cell(40, 10, fmt.Sprintf("Package: %s", pkg.PackageNumber))
    pdf.Ln(10)
    
    // Items table
    pdf.SetFont("Arial", "B", 10)
    pdf.Cell(40, 10, "Items:")
    pdf.Ln(5)
    
    pdf.SetFont("Arial", "", 10)
    for _, item := range pkg.Items {
        pdf.Cell(40, 10, fmt.Sprintf("- %s x%d", item.ProductSKU, item.QuantityPacked))
        pdf.Ln(5)
    }
    
    // Generate PDF bytes
    var buf bytes.Buffer
    err := pdf.Output(&buf)
    if err != nil {
        return "", err
    }
    
    // Upload to storage (S3, etc.)
    url, err := uc.storageClient.Upload(ctx, fmt.Sprintf("packing-slips/%s.pdf", pkg.ID), buf.Bytes())
    if err != nil {
        return "", err
    }
    
    return url, nil
}
```

**Step 3: Update ConfirmPacked**

**File:** `fulfillment/internal/biz/fulfillment/fulfillment.go`

Add packing slip generation:

```go
// Generate packing slip
if uc.packageUsecase != nil {
    slipURL, err := uc.packageUsecase.GeneratePackingSlip(ctx, pkg, fulfillment)
    if err != nil {
        uc.log.WithContext(ctx).Warnf("Failed to generate packing slip: %v", err)
    } else {
        pkg.PackingSlipURL = slipURL
        uc.packageRepo.Update(ctx, pkg)
    }
}
```

#### Testing

- [ ] Test packing slip generation
- [ ] Test PDF format
- [ ] Test storage upload
- [ ] Test with multiple items

---

## 🟢 Phase 3: Enhancements

### 3.1 Substitution Handling

**Priority:** 🟢 **Medium**  
**Estimated Time:** 2-3 days  
**Dependencies:** Customer service, Catalog service

#### Implementation Steps

**Step 1: Add Substitution Fields**

**File:** `fulfillment/internal/model/fulfillment_item.go`

```go
// Add to FulfillmentItem struct
IsSubstitute      bool    `gorm:"default:false"`
SubstituteFor     *string `gorm:"type:uuid"` // Original item ID
SubstituteReason  string  `gorm:"type:text"`
CustomerApproved  *bool   `gorm:"type:boolean"`
```

**Step 2: Implement Substitution Logic**

**File:** `fulfillment/internal/biz/picklist/substitution.go` (NEW)

```go
package picklist

// SubstituteItem handles item substitution
func (uc *PicklistUsecase) SubstituteItem(ctx context.Context, req *SubstituteItemRequest) error {
    // 1. Validate substitute product
    substituteProduct, err := uc.catalogClient.GetProduct(ctx, req.SubstituteProductID)
    if err != nil {
        return err
    }
    
    // 2. Check if substitution is allowed
    if !uc.isSubstitutionAllowed(req.OriginalProductID, req.SubstituteProductID) {
        return ErrSubstitutionNotAllowed
    }
    
    // 3. Get customer preference
    customerAccepts, err := uc.checkCustomerSubstitutionPreference(ctx, req.FulfillmentID)
    if err != nil || !customerAccepts {
        // Mark as pick failed, need customer approval
        return uc.markPickFailed(ctx, req.FulfillmentID, req.ItemID, "Out of stock, customer approval needed")
    }
    
    // 4. Record substitution
    return uc.recordSubstitution(ctx, req)
}
```

#### Testing

- [ ] Test substitution allowed
- [ ] Test substitution not allowed
- [ ] Test customer approval
- [ ] Test customer rejection

---

### 3.2 Photo Verification

**Priority:** 🟢 **Medium**  
**Estimated Time:** 2 days  
**Dependencies:** Storage service

#### Implementation Steps

**Step 1: Add Photo Field**

**File:** `fulfillment/internal/model/package.go`

```go
// Add to Package struct
PhotoURL string `gorm:"type:text"`
```

**Step 2: Add Photo Upload**

**File:** `fulfillment/internal/biz/package_biz/package.go`

```go
// UploadPackagePhoto uploads package photo
func (uc *PackageUsecase) UploadPackagePhoto(ctx context.Context, packageID string, photoData []byte) (string, error) {
    // Upload to storage
    url, err := uc.storageClient.Upload(ctx, fmt.Sprintf("package-photos/%s.jpg", packageID), photoData)
    if err != nil {
        return "", err
    }
    
    // Update package
    pkg, err := uc.repo.FindByID(ctx, packageID)
    if err != nil {
        return "", err
    }
    
    pkg.PhotoURL = url
    return url, uc.repo.Update(ctx, pkg)
}
```

#### Testing

- [ ] Test photo upload
- [ ] Test photo URL storage
- [ ] Test QC photo verification

---

### 3.3 Batch Picking

**Priority:** 🟢 **Medium**  
**Estimated Time:** 2-3 days  
**Dependencies:** None

#### Implementation Steps

**Step 1: Add Batch Picklist Generation**

**File:** `fulfillment/internal/biz/picklist/picklist.go`

```go
// GenerateBatchPicklist generates picklist for multiple fulfillments
func (uc *PicklistUsecase) GenerateBatchPicklist(ctx context.Context, fulfillmentIDs []string, warehouseID string) (string, error) {
    // Get all fulfillments
    fulfillments := []*model.Fulfillment{}
    for _, id := range fulfillmentIDs {
        f, err := uc.fulfillmentRepo.FindByID(ctx, id)
        if err != nil {
            return "", err
        }
        fulfillments = append(fulfillments, f)
    }
    
    // Group items by zone across all fulfillments
    zoneMap := make(map[string][]*model.PicklistItem)
    
    for _, fulfillment := range fulfillments {
        for _, item := range fulfillment.Items {
            zoneID := item.WarehouseLocation
            // Create picklist item
            picklistItem := &model.PicklistItem{
                FulfillmentItemID: item.ID,
                ProductID:         item.ProductID,
                ProductSKU:       item.ProductSKU,
                ProductName:       item.ProductName,
                QuantityToPick:    item.QuantityOrdered,
                WarehouseLocation: item.WarehouseLocation,
                BinLocation:       item.BinLocation,
            }
            zoneMap[zoneID] = append(zoneMap[zoneID], picklistItem)
        }
    }
    
    // Optimize pick path
    optimizedZones := uc.optimizePickPath(zoneMap, nil)
    
    // Create batch picklist
    picklist := &model.Picklist{
        ID:          uuid.New().String(),
        WarehouseID: warehouseID,
        Status:      constants.PicklistStatusPending,
        // ... other fields
    }
    
    // Create picklist items with optimized sequence
    // ...
    
    return picklist.ID, nil
}
```

#### Testing

- [ ] Test batch picklist generation
- [ ] Test multiple fulfillments
- [ ] Test zone grouping across orders
- [ ] Test pick path optimization

---

### 3.4 Performance Metrics

**Priority:** 🟢 **Low**  
**Estimated Time:** 1-2 days  
**Dependencies:** Prometheus/Metrics

#### Implementation Steps

**Step 1: Add Metrics**

**File:** `fulfillment/internal/observability/prometheus/fulfillment_metrics.go` (NEW)

```go
package prometheus

import (
    "github.com/prometheus/client_golang/prometheus"
)

var (
    FulfillmentDuration = prometheus.NewHistogramVec(
        prometheus.HistogramOpts{
            Name: "fulfillment_duration_seconds",
            Help: "Time to fulfill order",
        },
        []string{"status"},
    )
    
    PickAccuracy = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "pick_accuracy",
            Help: "Pick accuracy rate",
        },
        []string{"warehouse_id"},
    )
    
    PackAccuracy = prometheus.NewGaugeVec(
        prometheus.GaugeOpts{
            Name: "pack_accuracy",
            Help: "Pack accuracy rate",
        },
        []string{"warehouse_id"},
    )
)
```

**Step 2: Track Metrics**

Update fulfillment usecase to track metrics on status changes.

#### Testing

- [ ] Test metrics collection
- [ ] Test Prometheus export
- [ ] Test accuracy calculations

---

## 📋 Implementation Checklist

### Phase 1: Critical (Week 1-2)
- [ ] Quality Control System
  - [ ] Add QC fields to model
  - [ ] Create QC models
  - [ ] Implement QC usecase
  - [ ] Add QC service
  - [ ] Add QC proto
  - [ ] Auto-trigger QC
- [ ] Exception Handling
  - [ ] Add failure statuses
  - [ ] Add failure fields
  - [ ] Implement failure handling
  - [ ] Add retry logic
- [ ] Barcode Validation
  - [ ] Add barcode validation to picking
  - [ ] Add barcode validation to packing
  - [ ] Add error types

### Phase 2: Optimization (Week 3-4)
- [ ] Pick Path Optimization
  - [ ] Implement zone grouping
  - [ ] Implement route optimization
  - [ ] Update picklist generation
- [ ] Weight Verification
  - [ ] Add expected weight calculation
  - [ ] Add weight verification
- [ ] Packing Slip Generation
  - [ ] Add packing slip field
  - [ ] Implement PDF generation
  - [ ] Add storage upload

### Phase 3: Enhancements (Week 5-6)
- [ ] Substitution Handling
- [ ] Photo Verification
- [ ] Batch Picking
- [ ] Performance Metrics

---

## 🧪 Testing Requirements

### Unit Tests
- [ ] QC sampling logic
- [ ] Exception handling
- [ ] Barcode validation
- [ ] Pick path optimization
- [ ] Weight verification

### Integration Tests
- [ ] QC workflow end-to-end
- [ ] Exception handling workflow
- [ ] Pick path optimization with real data
- [ ] Packing slip generation

### E2E Tests
- [ ] Full fulfillment flow with QC
- [ ] Full fulfillment flow with exceptions
- [ ] Batch picking workflow

---

## 📝 Notes

1. **Dependencies**: Some features require external services (catalog, storage, customer)
2. **Storage**: Packing slips and photos need storage service (S3, etc.)
3. **PDF Library**: Use `github.com/jung-kurt/gofpdf` or similar
4. **Metrics**: Use existing Prometheus setup
5. **Events**: All status changes should publish events

---

## ⚠️ DELETE THIS FILE AFTER IMPLEMENTATION

This file should be deleted once all features are implemented and tested.

---

**Last Updated:** 2025-01-27

