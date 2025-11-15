# Fulfillment Service - Constants & Status Transitions

> **Purpose:** Define all constants and valid status transitions  
> **Location:** `internal/constants/constants.go`

---

## Fulfillment Status Constants

### internal/constants/fulfillment_status.go

```go
package constants

// FulfillmentStatus represents the status of a fulfillment
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

// String returns the string representation of FulfillmentStatus
func (s FulfillmentStatus) String() string {
    return string(s)
}

// IsValid checks if the status is valid
func (s FulfillmentStatus) IsValid() bool {
    switch s {
    case FulfillmentStatusPending,
        FulfillmentStatusPlanning,
        FulfillmentStatusPicking,
        FulfillmentStatusPicked,
        FulfillmentStatusPacking,
        FulfillmentStatusPacked,
        FulfillmentStatusReady,
        FulfillmentStatusShipped,
        FulfillmentStatusCompleted,
        FulfillmentStatusCancelled:
        return true
    }
    return false
}

// IsTerminal checks if the status is terminal (cannot transition further)
func (s FulfillmentStatus) IsTerminal() bool {
    return s == FulfillmentStatusCompleted || s == FulfillmentStatusCancelled
}

// IsCancellable checks if fulfillment can be cancelled from this status
func (s FulfillmentStatus) IsCancellable() bool {
    return s != FulfillmentStatusShipped && 
           s != FulfillmentStatusCompleted && 
           s != FulfillmentStatusCancelled
}
```

---

## Status Transitions

### Valid Transitions Map

```go
// FulfillmentStatusTransitions defines valid status transitions
var FulfillmentStatusTransitions = map[FulfillmentStatus][]FulfillmentStatus{
    FulfillmentStatusPending: {
        FulfillmentStatusPlanning,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPlanning: {
        FulfillmentStatusPicking,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPicking: {
        FulfillmentStatusPicked,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPicked: {
        FulfillmentStatusPacking,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPacking: {
        FulfillmentStatusPacked,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusPacked: {
        FulfillmentStatusReady,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusReady: {
        FulfillmentStatusShipped,
        FulfillmentStatusCancelled,
    },
    FulfillmentStatusShipped: {
        FulfillmentStatusCompleted,
    },
    FulfillmentStatusCompleted: {}, // Terminal state
    FulfillmentStatusCancelled: {}, // Terminal state
}

// CanTransitionTo checks if transition from current status to new status is valid
func (s FulfillmentStatus) CanTransitionTo(newStatus FulfillmentStatus) bool {
    allowedStatuses, exists := FulfillmentStatusTransitions[s]
    if !exists {
        return false
    }
    
    for _, allowed := range allowedStatuses {
        if allowed == newStatus {
            return true
        }
    }
    
    return false
}

// GetAllowedTransitions returns all valid transitions from current status
func (s FulfillmentStatus) GetAllowedTransitions() []FulfillmentStatus {
    return FulfillmentStatusTransitions[s]
}
```

---

## Status Transition Diagram

```
pending
  ↓ (assign warehouse, generate picklist)
  ├─→ planning
  │     ↓ (start picking)
  │   picking
  │     ↓ (confirm picked)
  │   picked
  │     ↓ (start packing)
  │   packing
  │     ↓ (confirm packed)
  │   packed
  │     ↓ (ready for carrier)
  │   ready
  │     ↓ (handover to shipping)
  │   shipped
  │     ↓ (delivery confirmed)
  │   completed ✓ (terminal)
  │
  └─→ cancelled ✗ (terminal, can cancel from any status before shipped)
```

---

## Picklist Status Constants

```go
// PicklistStatus represents the status of a picklist
type PicklistStatus string

const (
    PicklistStatusPending     PicklistStatus = "pending"
    PicklistStatusAssigned    PicklistStatus = "assigned"
    PicklistStatusInProgress  PicklistStatus = "in_progress"
    PicklistStatusCompleted   PicklistStatus = "completed"
    PicklistStatusCancelled   PicklistStatus = "cancelled"
)

// PicklistStatusTransitions defines valid picklist status transitions
var PicklistStatusTransitions = map[PicklistStatus][]PicklistStatus{
    PicklistStatusPending: {
        PicklistStatusAssigned,
        PicklistStatusCancelled,
    },
    PicklistStatusAssigned: {
        PicklistStatusInProgress,
        PicklistStatusCancelled,
    },
    PicklistStatusInProgress: {
        PicklistStatusCompleted,
        PicklistStatusCancelled,
    },
    PicklistStatusCompleted: {},  // Terminal state
    PicklistStatusCancelled: {},  // Terminal state
}
```

---

## Package Type Constants

```go
// PackageType represents the type of package
type PackageType string

const (
    PackageTypeBox       PackageType = "box"
    PackageTypeEnvelope  PackageType = "envelope"
    PackageTypePallet    PackageType = "pallet"
    PackageTypeBag       PackageType = "bag"
    PackageTypeCustom    PackageType = "custom"
)
```

---

## COD Constants

```go
// COD related constants
const (
    DefaultCODCurrency = "VND"
    MaxCODAmount       = 50000000.0 // 50 million VND
    MinCODAmount       = 10000.0    // 10 thousand VND
)
```

---

## Priority Constants

```go
// Priority levels for picklists
const (
    PriorityLow      = 0
    PriorityNormal   = 5
    PriorityHigh     = 10
    PriorityUrgent   = 15
    PriorityCritical = 20
)
```

---

## Validation Helper

```go
// ValidateStatusTransition validates if status transition is allowed
func ValidateStatusTransition(currentStatus, newStatus FulfillmentStatus) error {
    if !currentStatus.IsValid() {
        return fmt.Errorf("invalid current status: %s", currentStatus)
    }
    
    if !newStatus.IsValid() {
        return fmt.Errorf("invalid new status: %s", newStatus)
    }
    
    if currentStatus.IsTerminal() {
        return fmt.Errorf("cannot transition from terminal status: %s", currentStatus)
    }
    
    if !currentStatus.CanTransitionTo(newStatus) {
        return fmt.Errorf("invalid status transition: %s -> %s", currentStatus, newStatus)
    }
    
    return nil
}
```

---

## Usage Example

```go
package biz

import "gitlab.com/ta-microservices/fulfillment/internal/constants"

func (uc *FulfillmentUseCase) UpdateStatus(ctx context.Context, id string, newStatus string) error {
    // Get current fulfillment
    fulfillment, err := uc.repo.GetByID(ctx, id)
    if err != nil {
        return err
    }
    
    currentStatus := constants.FulfillmentStatus(fulfillment.Status)
    targetStatus := constants.FulfillmentStatus(newStatus)
    
    // Validate transition
    if err := constants.ValidateStatusTransition(currentStatus, targetStatus); err != nil {
        return err
    }
    
    // Update status
    fulfillment.Status = string(targetStatus)
    return uc.repo.Update(ctx, fulfillment)
}
```

---

## Status Transition Rules

| From Status | To Status | Trigger | Validation |
|-------------|-----------|---------|------------|
| `pending` | `planning` | Warehouse assigned | Warehouse must exist |
| `planning` | `picking` | Picklist generated | Picklist must be created |
| `picking` | `picked` | All items picked | Quantities must match |
| `picked` | `packing` | Start packing | Items must be picked |
| `packing` | `packed` | Packing complete | Package must be created |
| `packed` | `ready` | Ready for ship | Package details complete |
| `ready` | `shipped` | Carrier pickup | Tracking number assigned |
| `shipped` | `completed` | Delivery confirmed | Delivery proof required |
| `any` | `cancelled` | Cancellation | Only before shipped |

---

## Error Messages

```go
var (
    ErrInvalidStatus           = errors.New("invalid fulfillment status")
    ErrInvalidStatusTransition = errors.New("invalid status transition")
    ErrTerminalStatus          = errors.New("cannot transition from terminal status")
    ErrCannotCancel            = errors.New("fulfillment cannot be cancelled at this stage")
    ErrAlreadyCancelled        = errors.New("fulfillment is already cancelled")
    ErrAlreadyCompleted        = errors.New("fulfillment is already completed")
)
```

---

## Summary

**Status Constants:** 10 statuses (8 active + 2 terminal)
**Valid Transitions:** Defined in map for validation
**Helper Methods:** IsValid(), IsTerminal(), IsCancellable(), CanTransitionTo()
**Validation:** ValidateStatusTransition() for business logic
**Usage:** Import from `internal/constants` package
