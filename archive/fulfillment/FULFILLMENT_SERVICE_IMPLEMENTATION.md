# Fulfillment Service - Implementation Guide

> **Framework:** go-kratos v2.7+  
> **Pattern:** Clean Architecture + DDD  
> **Status:** 🔴 Not Implemented

---

## Architecture Layers

```
┌─────────────────────────────────────────┐
│         API Layer (Service)             │  ← HTTP/gRPC handlers
├─────────────────────────────────────────┤
│      Business Logic (Use Cases)         │  ← Fulfillment logic
├─────────────────────────────────────────┤
│     Data Access (Repositories)          │  ← Database operations
├─────────────────────────────────────────┤
│    External Services (Clients)          │  ← Service integrations
└─────────────────────────────────────────┘
```

---

## Core Models

### internal/model/fulfillment.go

```go
package model

import (
    "time"
    "gorm.io/gorm"
)

type FulfillmentStatus string

const (
    FulfillmentStatusPending    FulfillmentStatus = "pending"
    FulfillmentStatusPlanning   FulfillmentStatus = "planning"
    FulfillmentStatusPicking    FulfillmentStatus = "picking"
    FulfillmentStatusPicked     FulfillmentStatus = "picked"
    FulfillmentStatusPacking    FulfillmentStatus = "packing"
    FulfillmentStatusPacked     FulfillmentStatus = "packed"
    FulfillmentStatusReady      FulfillmentStatus = "ready"
    FulfillmentStatusShipped    FulfillmentStatus = "shipped"
    FulfillmentStatusCompleted  FulfillmentStatus = "completed"
    FulfillmentStatusCancelled  FulfillmentStatus = "cancelled"
)

type Fulfillment struct {
    ID          string            `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    OrderID     string            `gorm:"type:uuid;not null;index"`
    OrderNumber string            `gorm:"type:varchar(50);not null"`
    Status      FulfillmentStatus `gorm:"type:varchar(20);not null;default:'pending'"`
    WarehouseID *string           `gorm:"type:uuid;index"`
    
    // Assignment
    AssignedPickerID *string `gorm:"type:uuid"`
    AssignedPackerID *string `gorm:"type:uuid"`
    PicklistID       *string `gorm:"type:uuid"`
    PackageID        *string `gorm:"type:uuid"`
    
    // COD
    RequiresCODCollection bool    `gorm:"default:false"`
    CODAmount            *float64 `gorm:"type:decimal(15,2)"`
    CODCurrency          string   `gorm:"type:varchar(3);default:'VND'"`
    
    // Timestamps
    PlannedAt   *time.Time `gorm:"type:timestamp"`
    PickedAt    *time.Time `gorm:"type:timestamp"`
    PackedAt    *time.Time `gorm:"type:timestamp"`
    ReadyAt     *time.Time `gorm:"type:timestamp"`
    ShippedAt   *time.Time `gorm:"type:timestamp"`
    CompletedAt *time.Time `gorm:"type:timestamp"`
    CancelledAt *time.Time `gorm:"type:timestamp"`
    
    // Relations
    Items []FulfillmentItem `gorm:"foreignKey:FulfillmentID"`
    
    // Metadata
    Notes    string         `gorm:"type:text"`
    Metadata JSONB          `gorm:"type:jsonb;default:'{}'"`
    
    CreatedAt time.Time      `gorm:"not null;default:now()"`
    UpdatedAt time.Time      `gorm:"not null;default:now()"`
    DeletedAt gorm.DeletedAt `gorm:"index"`
}

type FulfillmentItem struct {
    ID              string  `gorm:"primaryKey;type:uuid;default:gen_random_uuid()"`
    FulfillmentID   string  `gorm:"type:uuid;not null;index"`
    OrderItemID     string  `gorm:"type:uuid;not null"`
    ProductID       string  `gorm:"type:uuid;not null;index"`
    ProductSKU      string  `gorm:"type:varchar(100);not null"`
    ProductName     string  `gorm:"type:varchar(255);not null"`
    VariantID       *string `gorm:"type:uuid"`
    
    // Quantities
    QuantityOrdered int `gorm:"not null"`
    QuantityPicked  int `gorm:"default:0"`
    QuantityPacked  int `gorm:"default:0"`
    
    // Location
    WarehouseLocation string `gorm:"type:varchar(50)"`
    BinLocation       string `gorm:"type:varchar(50)"`
    
    // Pricing
    UnitPrice  float64 `gorm:"type:decimal(15,2);not null"`
    TotalPrice float64 `gorm:"type:decimal(15,2);not null"`
    
    CreatedAt time.Time `gorm:"not null;default:now()"`
    UpdatedAt time.Time `gorm:"not null;default:now()"`
}

func (Fulfillment) TableName() string {
    return "fulfillments"
}

func (FulfillmentItem) TableName() string {
    return "fulfillment_items"
}
```

---

## Business Logic Layer

### internal/biz/fulfillment/fulfillment.go

```go
package fulfillment

import (
    "context"
    "time"
    "github.com/go-kratos/kratos/v2/log"
)

type Fulfillment struct {
    ID          string
    OrderID     string
    OrderNumber string
    Status      string
    WarehouseID *string
    Items       []FulfillmentItem
    CreatedAt   time.Time
    UpdatedAt   time.Time
}

type FulfillmentItem struct {
    ID              string
    ProductID       string
    ProductSKU      string
    ProductName     string
    QuantityOrdered int
    QuantityPicked  int
    QuantityPacked  int
}

// Repository interface
type FulfillmentRepo interface {
    Create(ctx context.Context, f *Fulfillment) error
    GetByID(ctx context.Context, id string) (*Fulfillment, error)
    GetByOrderID(ctx context.Context, orderID string) (*Fulfillment, error)
    Update(ctx context.Context, f *Fulfillment) error
    UpdateStatus(ctx context.Context, id string, status string) error
    List(ctx context.Context, filters map[string]interface{}, page, pageSize int) ([]*Fulfillment, int64, error)
}

// UseCase interface
type FulfillmentUseCase struct {
    repo          FulfillmentRepo
    warehouseRepo WarehouseRepo
    eventPub      EventPublisher
    log           *log.Helper
}

func NewFulfillmentUseCase(
    repo FulfillmentRepo,
    warehouseRepo WarehouseRepo,
    eventPub EventPublisher,
    logger log.Logger,
) *FulfillmentUseCase {
    return &FulfillmentUseCase{
        repo:          repo,
        warehouseRepo: warehouseRepo,
        eventPub:      eventPub,
        log:           log.NewHelper(logger),
    }
}

// CreateFromOrder creates fulfillment from order
func (uc *FulfillmentUseCase) CreateFromOrder(ctx context.Context, orderID string, orderData OrderData) (*Fulfillment, error) {
    uc.log.Infof("Creating fulfillment for order: %s", orderID)
    
    // Create fulfillment
    fulfillment := &Fulfillment{
        OrderID:     orderID,
        OrderNumber: orderData.OrderNumber,
        Status:      "pending",
        Items:       convertOrderItems(orderData.Items),
    }
    
    // Save to database
    if err := uc.repo.Create(ctx, fulfillment); err != nil {
        return nil, err
    }
    
    // Publish event
    uc.eventPub.PublishFulfillmentCreated(ctx, fulfillment)
    
    return fulfillment, nil
}

// StartPlanning assigns warehouse and prepares for picking
func (uc *FulfillmentUseCase) StartPlanning(ctx context.Context, id string) error {
    uc.log.Infof("Starting planning for fulfillment: %s", id)
    
    // Get fulfillment
    fulfillment, err := uc.repo.GetByID(ctx, id)
    if err != nil {
        return err
    }
    
    // Validate status
    if fulfillment.Status != "pending" {
        return ErrInvalidStatus
    }
    
    // Assign warehouse (logic to select best warehouse)
    warehouseID, err := uc.selectWarehouse(ctx, fulfillment)
    if err != nil {
        return err
    }
    
    fulfillment.WarehouseID = &warehouseID
    fulfillment.Status = "planning"
    now := time.Now()
    fulfillment.PlannedAt = &now
    
    // Update
    if err := uc.repo.Update(ctx, fulfillment); err != nil {
        return err
    }
    
    // Publish event
    uc.eventPub.PublishFulfillmentPlanned(ctx, fulfillment)
    
    return nil
}

// GeneratePicklist creates picklist for warehouse staff
func (uc *FulfillmentUseCase) GeneratePicklist(ctx context.Context, id string) error {
    // Implementation
    return nil
}

// ConfirmPicked marks items as picked
func (uc *FulfillmentUseCase) ConfirmPicked(ctx context.Context, id string, pickedItems []PickedItem) error {
    // Implementation
    return nil
}

// ConfirmPacked marks items as packed
func (uc *FulfillmentUseCase) ConfirmPacked(ctx context.Context, id string, packageData PackageData) error {
    // Implementation
    return nil
}

// MarkReadyToShip marks fulfillment ready for shipping
func (uc *FulfillmentUseCase) MarkReadyToShip(ctx context.Context, id string) error {
    // Implementation
    return nil
}

// Helper functions
func (uc *FulfillmentUseCase) selectWarehouse(ctx context.Context, f *Fulfillment) (string, error) {
    // Logic to select best warehouse based on:
    // - Stock availability
    // - Distance to customer
    // - Warehouse capacity
    // - Priority rules
    return "warehouse-uuid", nil
}

func convertOrderItems(orderItems []OrderItem) []FulfillmentItem {
    items := make([]FulfillmentItem, len(orderItems))
    for i, oi := range orderItems {
        items[i] = FulfillmentItem{
            ProductID:       oi.ProductID,
            ProductSKU:      oi.SKU,
            ProductName:     oi.Name,
            QuantityOrdered: oi.Quantity,
        }
    }
    return items
}
```

---

## Repository Layer

### internal/repository/fulfillment/fulfillment_repo.go

```go
package fulfillment

import (
    "context"
    "gorm.io/gorm"
    "gitlab.com/ta-microservices/fulfillment/internal/model"
)

type fulfillmentRepo struct {
    db *gorm.DB
}

func NewFulfillmentRepo(db *gorm.DB) *fulfillmentRepo {
    return &fulfillmentRepo{db: db}
}

func (r *fulfillmentRepo) Create(ctx context.Context, f *model.Fulfillment) error {
    return r.db.WithContext(ctx).Create(f).Error
}

func (r *fulfillmentRepo) GetByID(ctx context.Context, id string) (*model.Fulfillment, error) {
    var f model.Fulfillment
    err := r.db.WithContext(ctx).
        Preload("Items").
        Where("id = ?", id).
        First(&f).Error
    if err != nil {
        return nil, err
    }
    return &f, nil
}

func (r *fulfillmentRepo) GetByOrderID(ctx context.Context, orderID string) (*model.Fulfillment, error) {
    var f model.Fulfillment
    err := r.db.WithContext(ctx).
        Preload("Items").
        Where("order_id = ?", orderID).
        First(&f).Error
    if err != nil {
        return nil, err
    }
    return &f, nil
}

func (r *fulfillmentRepo) Update(ctx context.Context, f *model.Fulfillment) error {
    return r.db.WithContext(ctx).Save(f).Error
}

func (r *fulfillmentRepo) UpdateStatus(ctx context.Context, id string, status string) error {
    return r.db.WithContext(ctx).
        Model(&model.Fulfillment{}).
        Where("id = ?", id).
        Update("status", status).
        Error
}

func (r *fulfillmentRepo) List(ctx context.Context, filters map[string]interface{}, page, pageSize int) ([]*model.Fulfillment, int64, error) {
    var fulfillments []*model.Fulfillment
    var total int64
    
    query := r.db.WithContext(ctx).Model(&model.Fulfillment{})
    
    // Apply filters
    if orderID, ok := filters["order_id"]; ok {
        query = query.Where("order_id = ?", orderID)
    }
    if status, ok := filters["status"]; ok {
        query = query.Where("status = ?", status)
    }
    if warehouseID, ok := filters["warehouse_id"]; ok {
        query = query.Where("warehouse_id = ?", warehouseID)
    }
    
    // Count total
    query.Count(&total)
    
    // Pagination
    offset := (page - 1) * pageSize
    err := query.
        Preload("Items").
        Offset(offset).
        Limit(pageSize).
        Order("created_at DESC").
        Find(&fulfillments).Error
    
    return fulfillments, total, err
}
```

---

## Service Layer

### internal/service/fulfillment_service.go

```go
package service

import (
    "context"
    v1 "gitlab.com/ta-microservices/fulfillment/api/fulfillment/v1"
    "gitlab.com/ta-microservices/fulfillment/internal/biz/fulfillment"
)

type FulfillmentService struct {
    v1.UnimplementedFulfillmentServiceServer
    uc *fulfillment.FulfillmentUseCase
}

func NewFulfillmentService(uc *fulfillment.FulfillmentUseCase) *FulfillmentService {
    return &FulfillmentService{uc: uc}
}

func (s *FulfillmentService) GetFulfillment(ctx context.Context, req *v1.GetFulfillmentRequest) (*v1.GetFulfillmentResponse, error) {
    f, err := s.uc.GetByID(ctx, req.Id)
    if err != nil {
        return nil, err
    }
    
    return &v1.GetFulfillmentResponse{
        Fulfillment: convertToProto(f),
    }, nil
}

func (s *FulfillmentService) StartPlanning(ctx context.Context, req *v1.StartPlanningRequest) (*v1.StartPlanningResponse, error) {
    err := s.uc.StartPlanning(ctx, req.FulfillmentId)
    if err != nil {
        return nil, err
    }
    
    return &v1.StartPlanningResponse{
        Success: true,
        Message: "Planning started successfully",
    }, nil
}

// More methods...
```

---

## Summary

**Implementation Checklist:**
- ✅ Models defined (Fulfillment, FulfillmentItem)
- ✅ Business logic interfaces (UseCase, Repository)
- ✅ Repository implementation (CRUD operations)
- ✅ Service layer (gRPC/HTTP handlers)
- ⏳ Event integration (next step)
- ⏳ External service clients (Warehouse, Order)
