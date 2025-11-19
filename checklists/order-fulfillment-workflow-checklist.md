# 📦 Order Fulfillment Workflow Checklist

**Service:** Fulfillment Service  
**Created:** 2025-11-19  
**Status:** 🟡 **Implementation Required**  
**Priority:** 🔴 **High**

---

## 📋 Table of Contents

1. [Overview](#overview)
2. [Fulfillment States & Workflow](#fulfillment-states--workflow)
3. [Picking Process](#picking-process)
4. [Packing Process](#packing-process)
5. [Quality Control](#quality-control)
6. [Shipping Label Generation](#shipping-label-generation)
7. [Multi-Package Orders](#multi-package-orders)
8. [Exception Handling](#exception-handling)
9. [Performance Optimization](#performance-optimization)
10. [Testing Scenarios](#testing-scenarios)

---

## 🎯 Overview

Order fulfillment là post-purchase critical path. Tốc độ và độ chính xác trực tiếp ảnh hưởng đến customer satisfaction.

**Key Requirements:**
- **Speed:** Process order trong 24h
- **Accuracy:** >99.9% order accuracy
- **Efficiency:** Optimize picking routes
- **Tracking:** Real-time status updates
- **Scalability:** Handle peak seasons

**Critical Metrics:**
- Order-to-ship time: <24h
- Pick accuracy: >99.9%
- Pack accuracy: >99.9%
- On-time shipment: >95%
- Damage rate: <0.1%

---

## 1. Fulfillment States & Workflow

### 1.1 Fulfillment State Machine

**States:**

```
awaiting_fulfillment → picking → packing → ready_to_ship → shipped → delivered
         ↓               ↓          ↓
     cancelled    pick_failed  pack_failed
```

**Requirements:**

- [ ] **R1.1.1** Track fulfillment state
- [ ] **R1.1.2** Validate state transitions
- [ ] **R1.1.3** Log state changes
- [ ] **R1.1.4** Publish state events
- [ ] **R1.1.5** Handle state rollbacks

**Implementation:**

```go
type FulfillmentStatus string

const (
    StatusAwaitingFulfillment FulfillmentStatus = "awaiting_fulfillment"
    StatusPicking             FulfillmentStatus = "picking"
    StatusPacked              FulfillmentStatus = "packing"
    StatusReadyToShip         FulfillmentStatus = "ready_to_ship"
    StatusShipped             FulfillmentStatus = "shipped"
    StatusDelivered           FulfillmentStatus = "delivered"
    StatusCancelled           FulfillmentStatus = "cancelled"
    StatusPickFailed          FulfillmentStatus = "pick_failed"
    StatusPackFailed          FulfillmentStatus = "pack_failed"
)

type Fulfillment struct {
    ID              string
    OrderID         string
    OrderNumber     string
    WarehouseID     string
    
    // Items
    Items           []FulfillmentItem
    
    // Assignment
    PickerID        *string
    PackerID        *string
    
    // Status
    Status          FulfillmentStatus
    
    // Picking
    PickListID      *string
    PickStartedAt   *time.Time
    PickCompletedAt *time.Time
    
    // Packing
    PackageCount    int
    Packages        []Package
    PackStartedAt   *time.Time
    PackCompletedAt *time.Time
    
    // Shipping
    ShippingLabelURL *string
    TrackingNumber   *string
    ShippedAt        *time.Time
    
    // Quality
    QCCheckedAt     *time.Time
    QCCheckedBy     *string
    QCPassed        bool
    
    // Timestamps
    CreatedAt       time.Time
    UpdatedAt       time.Time
}

type FulfillmentItem struct {
    ID              string
    ProductID       string
    VariantID       *string
    SKU             string
    ProductName     string
    Quantity        int
    
    // Warehouse location
    BinLocation     string
    ZoneID          string
    
    // Picking
    PickedQuantity  int
    PickerNotes     string
    
    // Status
    Status          string  // "pending", "picked", "packed", "substituted"
    SubstituteFor   *string // If this is a substitute item
}

func (uc *FulfillmentUseCase) CreateFulfillment(ctx context.Context, orderID string) (*Fulfillment, error) {
    // 1. Get order details
    order, err := uc.orderClient.GetOrder(ctx, orderID)
    if err != nil {
        return nil, err
    }
    
    // 2. Select warehouse (closest to shipping address)
    warehouse, err := uc.selectWarehouse(ctx, order.ShippingAddress, order.Items)
    if err != nil {
        return nil, err
    }
    
    // 3. Get stock locations for items
    items := []FulfillmentItem{}
    for _, orderItem := range order.Items {
        location, err := uc.inventoryClient.GetStockLocation(ctx, warehouse.ID, orderItem.ProductID)
        if err != nil {
            return nil, err
        }
        
        items = append(items, FulfillmentItem{
            ID:          uuid.New().String(),
            ProductID:   orderItem.ProductID,
            VariantID:   orderItem.VariantID,
            SKU:         orderItem.SKU,
            ProductName: orderItem.ProductName,
            Quantity:    orderItem.Quantity,
            BinLocation: location.BinLocation,
            ZoneID:      location.ZoneID,
            Status:      "pending",
        })
    }
    
    // 4. Create fulfillment
    fulfillment := &Fulfillment{
        ID:          uuid.New().String(),
        OrderID:     order.ID,
        OrderNumber: order.OrderNumber,
        WarehouseID: warehouse.ID,
        Items:       items,
        Status:      StatusAwaitingFulfillment,
        CreatedAt:   time.Now(),
        UpdatedAt:   time.Now(),
    }
    
    // 5. Save fulfillment
    if err := uc.repo.CreateFulfillment(ctx, fulfillment); err != nil {
        return nil, err
    }
    
    // 6. Publish event
    uc.publishEvent(ctx, "fulfillment.created", fulfillment)
    
    return fulfillment, nil
}
```

**Test Scenarios:**

- [ ] **T1.1.1** Create fulfillment from order
- [ ] **T1.1.2** Select nearest warehouse
- [ ] **T1.1.3** Get stock locations
- [ ] **T1.1.4** State transition validation
- [ ] **T1.1.5** Events published correctly

---

## 2. Picking Process

### 2.1 Pick List Generation

**Requirements:**

- [ ] **R2.1.1** Generate optimized pick list
- [ ] **R2.1.2** Group by warehouse zone
- [ ] **R2.1.3** Sort by pick path
- [ ] **R2.1.4** Batch multiple orders
- [ ] **R2.1.5** Assign to picker

**Implementation:**

```go
type PickList struct {
    ID              string
    WarehouseID     string
    PickerID        *string
    
    // Items grouped by zone
    Zones           []PickZone
    TotalItems      int
    
    // Status
    Status          string  // "pending", "in_progress", "completed", "cancelled"
    
    // Tracking
    StartedAt       *time.Time
    CompletedAt     *time.Time
    DurationSeconds int
    
    CreatedAt       time.Time
}

type PickZone struct {
    ZoneID          string
    ZoneName        string
    Items           []PickItem
    PickSequence    int  // Order to pick zones
}

type PickItem struct {
    FulfillmentID   string
    ItemID          string
    ProductID       string
    SKU             string
    ProductName     string
    Quantity        int
    BinLocation     string
    ImageURL        string
    
    // Pick status
    Picked          bool
    PickedQuantity  int
    PickedAt        *time.Time
    Notes           string
}

func (uc *FulfillmentUseCase) GeneratePickList(ctx context.Context, warehouseID string, fulfillmentIDs []string) (*PickList, error) {
    // 1. Get all fulfillments
    fulfillments := []*Fulfillment{}
    for _, id := range fulfillmentIDs {
        f, err := uc.repo.GetFulfillment(ctx, id)
        if err != nil {
            return nil, err
        }
        fulfillments = append(fulfillments, f)
    }
    
    // 2. Group items by zone
    zoneMap := make(map[string]*PickZone)
    
    for _, fulfillment := range fulfillments {
        for _, item := range fulfillment.Items {
            zone, exists := zoneMap[item.ZoneID]
            if !exists {
                zoneInfo, _ := uc.warehouseClient.GetZone(ctx, item.ZoneID)
                zone = &PickZone{
                    ZoneID:   item.ZoneID,
                    ZoneName: zoneInfo.Name,
                    Items:    []PickItem{},
                }
                zoneMap[item.ZoneID] = zone
            }
            
            zone.Items = append(zone.Items, PickItem{
                FulfillmentID: fulfillment.ID,
                ItemID:        item.ID,
                ProductID:     item.ProductID,
                SKU:           item.SKU,
                ProductName:   item.ProductName,
                Quantity:      item.Quantity,
                BinLocation:   item.BinLocation,
            })
        }
    }
    
    // 3. Convert map to sorted zones
    zones := []PickZone{}
    for _, zone := range zoneMap {
        zones = append(zones, *zone)
    }
    
    // 4. Optimize pick path (zone sequence)
    zones = uc.optimizePickPath(zones)
    
    // 5. Create pick list
    pickList := &PickList{
        ID:          uuid.New().String(),
        WarehouseID: warehouseID,
        Zones:       zones,
        TotalItems:  uc.countTotalItems(zones),
        Status:      "pending",
        CreatedAt:   time.Now(),
    }
    
    if err := uc.repo.CreatePickList(ctx, pickList); err != nil {
        return nil, err
    }
    
    return pickList, nil
}

func (uc *FulfillmentUseCase) optimizePickPath(zones []PickZone) []PickZone {
    // Sort zones by physical location to minimize walking distance
    // This is a simple implementation - can use more advanced algorithms
    
    // Get zone layout from warehouse service
    zoneLayout := uc.getZoneLayout(zones)
    
    // Use nearest neighbor algorithm
    optimized := []PickZone{}
    visited := make(map[string]bool)
    
    // Start from receiving area (zone A)
    currentZone := "A"
    
    for len(optimized) < len(zones) {
        // Find nearest unvisited zone
        nearestZone := uc.findNearestZone(currentZone, zones, visited, zoneLayout)
        if nearestZone != nil {
            nearestZone.PickSequence = len(optimized) + 1
            optimized = append(optimized, *nearestZone)
            visited[nearestZone.ZoneID] = true
            currentZone = nearestZone.ZoneID
        } else {
            break
        }
    }
    
    return optimized
}
```

**Test Scenarios:**

- [ ] **T2.1.1** Generate pick list for single order
- [ ] **T2.1.2** Batch multiple orders
- [ ] **T2.1.3** Items grouped by zone
- [ ] **T2.1.4** Pick path optimized
- [ ] **T2.1.5** Total items calculated

---

### 2.2 Picking Execution

**Requirements:**

- [ ] **R2.2.1** Assign pick list to picker
- [ ] **R2.2.2** Scanner integration (barcode)
- [ ] **R2.2.3** Verify picked items
- [ ] **R2.2.4** Handle substitutions
- [ ] **R2.2.5** Track pick time

**Implementation:**

```go
func (uc *FulfillmentUseCase) StartPicking(ctx context.Context, pickListID, pickerID string) error {
    pickList, err := uc.repo.GetPickList(ctx, pickListID)
    if err != nil {
        return err
    }
    
    if pickList.Status != "pending" {
        return ErrPickListNotPending
    }
    
    // Assign to picker
    pickList.PickerID = &pickerID
    pickList.Status = "in_progress"
    pickList.StartedAt = timePtr(time.Now())
    
    if err := uc.repo.UpdatePickList(ctx, pickList); err != nil {
        return err
    }
    
    // Update fulfillments
    for _, zone := range pickList.Zones {
        for _, item := range zone.Items {
            uc.updateFulfillmentStatus(ctx, item.FulfillmentID, StatusPicking)
        }
    }
    
    uc.publishEvent(ctx, "picking.started", pickList)
    
    return nil
}

func (uc *FulfillmentUseCase) PickItem(ctx context.Context, req *PickItemRequest) error {
    // 1. Validate barcode scan
    if req.ScannedBarcode != req.ExpectedSKU {
        return &PickError{
            Code:    "BARCODE_MISMATCH",
            Message: fmt.Sprintf("Scanned: %s, Expected: %s", req.ScannedBarcode, req.ExpectedSKU),
        }
    }
    
    // 2. Get pick list
    pickList, err := uc.repo.GetPickList(ctx, req.PickListID)
    if err != nil {
        return err
    }
    
    // 3. Find and update item
    for i := range pickList.Zones {
        for j := range pickList.Zones[i].Items {
            item := &pickList.Zones[i].Items[j]
            
            if item.ItemID == req.ItemID {
                item.Picked = true
                item.PickedQuantity = req.Quantity
                item.PickedAt = timePtr(time.Now())
                item.Notes = req.Notes
                
                // Update fulfillment item
                uc.updateFulfillmentItem(ctx, item.FulfillmentID, item.ItemID, req.Quantity)
                
                break
            }
        }
    }
    
    // 4. Check if pick list completed
    if uc.isPickListComplete(pickList) {
        pickList.Status = "completed"
        pickList.CompletedAt = timePtr(time.Now())
        pickList.DurationSeconds = int(time.Since(*pickList.StartedAt).Seconds())
        
        uc.publishEvent(ctx, "picking.completed", pickList)
    }
    
    return uc.repo.UpdatePickList(ctx, pickList)
}

func (uc *FulfillmentUseCase) SubstituteItem(ctx context.Context, req *SubstituteItemRequest) error {
    // When original item is out of stock, picker can substitute
    
    // 1. Validate substitute item
    substituteProduct, err := uc.catalogClient.GetProduct(ctx, req.SubstituteProductID)
    if err != nil {
        return err
    }
    
    // 2. Check if substitution is allowed
    if !uc.isSubstitutionAllowed(req.OriginalProductID, req.SubstituteProductID) {
        return ErrSubstitutionNotAllowed
    }
    
    // 3. Get customer preference
    customerAcceptsSubstitution, err := uc.checkCustomerSubstitutionPreference(ctx, req.FulfillmentID)
    if err != nil || !customerAcceptsSubstitution {
        // Mark as pick failed, need customer approval
        return uc.markPickFailed(ctx, req.FulfillmentID, req.ItemID, "Out of stock, customer approval needed for substitution")
    }
    
    // 4. Record substitution
    return uc.recordSubstitution(ctx, req)
}
```

**Test Scenarios:**

- [ ] **T2.2.1** Start picking successfully
- [ ] **T2.2.2** Pick item with barcode scan
- [ ] **T2.2.3** Barcode mismatch detected
- [ ] **T2.2.4** Pick wrong quantity flagged
- [ ] **T2.2.5** Substitute item successfully
- [ ] **T2.2.6** Substitution rejected by customer
- [ ] **T2.2.7** Pick list completed
- [ ] **T2.2.8** Pick duration tracked

---

## 3. Packing Process

### 3.1 Packing Station

**Requirements:**

- [ ] **R3.1.1** Select appropriate package size
- [ ] **R3.1.2** Add packing materials
- [ ] **R3.1.3** Generate packing slip
- [ ] **R3.1.4** Scan items for verification
- [ ] **R3.1.5** Weigh package
- [ ] **R3.1.6** Take photo for proof

**Implementation:**

```go
type Package struct {
    ID              string
    FulfillmentID   string
    PackageNumber   int  // 1 of 2, 2 of 2, etc.
    
    // Packaging
    BoxSize         string  // "small", "medium", "large", "custom"
    BoxDimensions   Dimensions
    ActualWeight    float64  // kg
    VolumetricWeight float64
    
    // Contents
    Items           []PackedItem
    
    // Packing slip
    PackingSlipURL  string
    
    // Shipping
    ShippingLabelURL string
    TrackingNumber   string
    
    // Quality
    PhotoURL        string
    PackedBy        string
    PackedAt        time.Time
}

type PackedItem struct {
    ItemID          string
    ProductID       string
    SKU             string
    Quantity        int
    Verified        bool
    ScannedAt       *time.Time
}

type Dimensions struct {
    Length  float64  // cm
    Width   float64
    Height  float64
}

func (uc *FulfillmentUseCase) StartPacking(ctx context.Context, fulfillmentID, packerID string) error {
    fulfillment, err := uc.repo.GetFulfillment(ctx, fulfillmentID)
    if err != nil {
        return err
    }
    
    // Validate picking is complete
    if fulfillment.Status != StatusPicked {
        return ErrPickingNotComplete
    }
    
    // Update status
    fulfillment.Status = StatusPacking
    fulfillment.PackerID = &packerID
    fulfillment.PackStartedAt = timePtr(time.Now())
    
    if err := uc.repo.UpdateFulfillment(ctx, fulfillment); err != nil {
        return err
    }
    
    uc.publishEvent(ctx, "packing.started", fulfillment)
    
    return nil
}

func (uc *FulfillmentUseCase) SelectPackageSize(ctx context.Context, items []FulfillmentItem) string {
    // Calculate total volume
    totalVolume := 0.0
    for _, item := range items {
        product, _ := uc.catalogClient.GetProduct(ctx, item.ProductID)
        itemVolume := product.Dimensions.Length * product.Dimensions.Width * product.Dimensions.Height
        totalVolume += itemVolume * float64(item.Quantity)
    }
    
    // Select box size
    if totalVolume < 1000 { // cm³
        return "small"
    } else if totalVolume < 5000 {
        return "medium"
    } else if totalVolume < 20000 {
        return "large"
    } else {
        return "custom"
    }
}

func (uc *FulfillmentUseCase) PackItem(ctx context.Context, req *PackItemRequest) error {
    // Verify item by scanning
    if req.ScannedSKU != req.ExpectedSKU {
        return &PackError{
            Code:    "SKU_MISMATCH",
            Message: "Scanned item doesn't match expected",
        }
    }
    
    // Get package
    pkg, err := uc.repo.GetPackage(ctx, req.PackageID)
    if err != nil {
        return err
    }
    
    // Add item to package
    pkg.Items = append(pkg.Items, PackedItem{
        ItemID:    req.ItemID,
        ProductID: req.ProductID,
        SKU:       req.ScannedSKU,
        Quantity:  req.Quantity,
        Verified:  true,
        ScannedAt: timePtr(time.Now()),
    })
    
    return uc.repo.UpdatePackage(ctx, pkg)
}

func (uc *FulfillmentUseCase) WeighPackage(ctx context.Context, packageID string, weight float64) error {
    pkg, err := uc.repo.GetPackage(ctx, packageID)
    if err != nil {
        return err
    }
    
    // Calculate expected weight
    expectedWeight := uc.calculateExpectedWeight(pkg.Items)
    
    // Allow 5% variance
    variance := math.Abs(weight - expectedWeight) / expectedWeight
    
    if variance > 0.05 {
        return &PackError{
            Code:    "WEIGHT_MISMATCH",
            Message: fmt.Sprintf("Weight variance %.1f%% exceeds threshold", variance*100),
            ExpectedWeight: expectedWeight,
            ActualWeight:   weight,
        }
    }
    
    pkg.ActualWeight = weight
    pkg.VolumetricWeight = uc.calculateVolumetricWeight(pkg.BoxDimensions)
    
    return uc.repo.UpdatePackage(ctx, pkg)
}

func (uc *FulfillmentUseCase) CompletePacking(ctx context.Context, fulfillmentID string) error {
    fulfillment, err := uc.repo.GetFulfillment(ctx, fulfillmentID)
    if err != nil {
        return err
    }
    
    // Verify all items packed
    if !uc.allItemsPacked(fulfillment) {
        return ErrNotAllItemsPacked
    }
    
    // Generate packing slips
    for i := range fulfillment.Packages {
        pkg := &fulfillment.Packages[i]
        
        slipURL, err := uc.generatePackingSlip(ctx, fulfillment, pkg)
        if err != nil {
            return err
        }
        pkg.PackingSlipURL = slipURL
    }
    
    // Update status
    fulfillment.Status = StatusReadyToShip
    fulfillment.PackCompletedAt = timePtr(time.Now())
    
    if err := uc.repo.UpdateFulfillment(ctx, fulfillment); err != nil {
        return err
    }
    
    uc.publishEvent(ctx, "packing.completed", fulfillment)
    
    return nil
}
```

**Test Scenarios:**

- [ ] **T3.1.1** Select package size correctly
- [ ] **T3.1.2** Pack item with verification
- [ ] **T3.1.3** SKU mismatch detected
- [ ] **T3.1.4** Package weight verified
- [ ] **T3.1.5** Weight variance exceeds threshold
- [ ] **T3.1.6** Packing slip generated
- [ ] **T3.1.7** Multi-package order handled

---

## 4. Quality Control

### 4.1 QC Checks

**Requirements:**

- [ ] **R4.1.1** Random sample QC (10% of orders)
- [ ] **R4.1.2** High-value order QC (100% over threshold)
- [ ] **R4.1.3** Photo verification
- [ ] **R4.1.4** Item count verification
- [ ] **R4.1.5** Defect detection

**Implementation:**

```go
func (uc *FulfillmentUseCase) PerformQC(ctx context.Context, fulfillmentID, qcCheckerID string) (*QCResult, error) {
    fulfillment, err := uc.repo.GetFulfillment(ctx, fulfillmentID)
    if err != nil {
        return nil, err
    }
    
    result := &QCResult{
        FulfillmentID: fulfillmentID,
        CheckerID:     qcCheckerID,
        Checks:        []QCCheck{},
        Passed:        true,
        CheckedAt:     time.Now(),
    }
    
    // 1. Verify item count
    expectedCount := 0
    for _, item := range fulfillment.Items {
        expectedCount += item.Quantity
    }
    
    actualCount := 0
    for _, pkg := range fulfillment.Packages {
        for _, item := range pkg.Items {
            actualCount += item.Quantity
        }
    }
    
    if expectedCount != actualCount {
        result.Passed = false
        result.Checks = append(result.Checks, QCCheck{
            Type:    "item_count",
            Passed:  false,
            Message: fmt.Sprintf("Expected %d items, found %d", expectedCount, actualCount),
        })
    }
    
    // 2. Verify all items scanned
    for _, pkg := range fulfillment.Packages {
        for _, item := range pkg.Items {
            if !item.Verified {
                result.Passed = false
                result.Checks = append(result.Checks, QCCheck{
                    Type:    "item_verification",
                    Passed:  false,
                    Message: fmt.Sprintf("Item %s not verified", item.SKU),
                })
            }
        }
    }
    
    // 3. Check package weight
    for _, pkg := range fulfillment.Packages {
        if pkg.ActualWeight == 0 {
            result.Passed = false
            result.Checks = append(result.Checks, QCCheck{
                Type:    "package_weight",
                Passed:  false,
                Message: "Package not weighed",
            })
        }
    }
    
    // 4. Visual inspection (photo required)
    for _, pkg := range fulfillment.Packages {
        if pkg.PhotoURL == "" {
            result.Passed = false
            result.Checks = append(result.Checks, QCCheck{
                Type:    "photo_verification",
                Passed:  false,
                Message: "Package photo missing",
            })
        }
    }
    
    // Update fulfillment
    fulfillment.QCCheckedAt = &result.CheckedAt
    fulfillment.QCCheckedBy = &qcCheckerID
    fulfillment.QCPassed = result.Passed
    
    uc.repo.UpdateFulfillment(ctx, fulfillment)
    
    return result, nil
}
```

**Test Scenarios:**

- [ ] **T4.1.1** QC check passes
- [ ] **T4.1.2** Item count mismatch detected
- [ ] **T4.1.3** Unverified item detected
- [ ] **T4.1.4** Package weight missing
- [ ] **T4.1.5** Photo verification missing

---

## 5. Shipping Label Generation

**Requirements:**

- [ ] **R5.1.1** Generate label via carrier API
- [ ] **R5.1.2** Include tracking number
- [ ] **R5.1.3** Print label at packing station
- [ ] **R5.1.4** Attach label to package
- [ ] **R5.1.5** Update order with tracking

**Implementation:**

```go
func (uc *FulfillmentUseCase) GenerateShippingLabel(ctx context.Context, packageID string) (*ShippingLabel, error) {
    pkg, err := uc.repo.GetPackage(ctx, packageID)
    if err != nil {
        return nil, err
    }
    
    fulfillment, err := uc.repo.GetFulfillment(ctx, pkg.FulfillmentID)
    if err != nil {
        return nil, err
    }
    
    order, err := uc.orderClient.GetOrder(ctx, fulfillment.OrderID)
    if err != nil {
        return nil, err
    }
    
    // Create shipment via carrier
    shipment, err := uc.shippingClient.CreateShipment(ctx, &CreateShipmentRequest{
        OrderID:         order.ID,
        PackageID:       pkg.ID,
        
        // Origin
        FromAddress:     uc.warehouseAddress,
        
        // Destination
        ToAddress:       order.ShippingAddress,
        
        // Package details
        Weight:          pkg.ActualWeight,
        Dimensions:      pkg.BoxDimensions,
        
        // Service
        ServiceLevel:    order.ShippingMethod.ServiceLevel,
        CarrierAccount:  order.ShippingMethod.CarrierAccount,
    })
    
    if err != nil {
        return nil, err
    }
    
    // Update package
    pkg.ShippingLabelURL = shipment.LabelURL
    pkg.TrackingNumber = shipment.TrackingNumber
    
    uc.repo.UpdatePackage(ctx, pkg)
    
    // Update order with tracking
    uc.orderClient.UpdateTracking(ctx, order.ID, shipment.TrackingNumber)
    
    return &ShippingLabel{
        LabelURL:       shipment.LabelURL,
        TrackingNumber: shipment.TrackingNumber,
    }, nil
}
```

**Test Scenarios:**

- [ ] **T5.1.1** Label generated successfully
- [ ] **T5.1.2** Tracking number created
- [ ] **T5.1.3** Label URL accessible
- [ ] **T5.1.4** Order updated with tracking

---

## 📊 Success Criteria

- [ ] ✅ Order-to-ship time <24h (p95)
- [ ] ✅ Pick accuracy >99.9%
- [ ] ✅ Pack accuracy >99.9%
- [ ] ✅ On-time shipment >95%
- [ ] ✅ Damage rate <0.1%
- [ ] ✅ QC pass rate >98%
- [ ] ✅ Test coverage >85%

---

**Status:** Ready for Implementation  
**Next Steps:** Implement picking optimization and QC automation
