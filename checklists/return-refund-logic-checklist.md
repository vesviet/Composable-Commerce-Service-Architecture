# 🔄 Return & Refund Logic Checklist

**Service:** Order/Return Service  
**Created:** 2025-11-19  
**Priority:** 🔴 **High**

---

## 🎯 Overview

Return & refund management directly impacts customer satisfaction and retention. Efficient handling reduces support burden and improves trust.

**Key Metrics:**
- Return request processing: <24h
- Refund processing: <48h after receipt
- Return approval rate: Track for fraud
- Refund accuracy: 100%

---

## 1. Return Request Initiation

### Requirements

- [ ] **R1.1** Check return eligibility (time window: 30 days)
- [ ] **R1.2** Validate order status (delivered, not already returned)
- [ ] **R1.3** Support partial returns (select specific items)
- [ ] **R1.4** Collect return reason
- [ ] **R1.5** Upload proof (photos/videos for damage claims)
- [ ] **R1.6** Generate return authorization number
- [ ] **R1.7** Create return shipping label

### Implementation

```go
type ReturnRequest struct {
    ID                  string
    OrderID             string
    CustomerID          string
    
    // Items
    Items               []ReturnItem
    
    // Reason
    ReturnReason        string  // "defective", "wrong_item", "not_as_described", "changed_mind"
    Description         string
    Photos              []string
    
    // Return method
    ReturnMethod        string  // "ship_back", "drop_off"
    ReturnLabelURL      string
    TrackingNumber      string
    
    // Status
    Status              string  // "pending_approval", "approved", "rejected", "received", "completed"
    
    // Refund
    RefundAmount        float64
    RefundMethod        string
    RefundStatus        string
    
    CreatedAt           time.Time
    UpdatedAt           time.Time
}

type ReturnItem struct {
    OrderItemID         string
    ProductID           string
    Quantity            int
    ReturnReason        string
    Condition           string  // "unopened", "opened", "damaged"
}

func (uc *ReturnUseCase) CreateReturnRequest(ctx context.Context, req *CreateReturnRequest) (*ReturnRequest, error) {
    // 1. Get order
    order, err := uc.orderClient.GetOrder(ctx, req.OrderID)
    if err != nil {
        return nil, err
    }
    
    // 2. Check eligibility
    if !uc.isReturnEligible(order) {
        return nil, &ReturnError{
            Code:    "NOT_ELIGIBLE",
            Message: "Order is not eligible for return",
            Reason:  uc.getIneligibilityReason(order),
        }
    }
    
    // 3. Validate items
    if err := uc.validateReturnItems(order, req.Items); err != nil {
        return nil, err
    }
    
    // 4. Calculate refund amount
    refundAmount := uc.calculateRefundAmount(order, req.Items)
    
    // 5. Generate return label
    returnLabel, err := uc.generateReturnLabel(ctx, order, req.Items)
    if err != nil {
        return nil, err
    }
    
    // 6. Create return request
    returnReq := &ReturnRequest{
        ID:              uuid.New().String(),
        OrderID:         req.OrderID,
        CustomerID:      order.CustomerID,
        Items:           req.Items,
        ReturnReason:    req.ReturnReason,
        Description:     req.Description,
        Photos:          req.Photos,
        ReturnMethod:    "ship_back",
        ReturnLabelURL:  returnLabel.LabelURL,
        TrackingNumber:  returnLabel.TrackingNumber,
        Status:          "pending_approval",
        RefundAmount:    refundAmount,
        RefundMethod:    order.PaymentMethod,
        RefundStatus:    "pending",
        CreatedAt:       time.Now(),
        UpdatedAt:       time.Now(),
    }
    
    if err := uc.repo.CreateReturnRequest(ctx, returnReq); err != nil {
        return nil, err
    }
    
    // 7. Notify customer
    uc.sendReturnConfirmation(ctx, returnReq)
    
    return returnReq, nil
}

func (uc *ReturnUseCase) isReturnEligible(order *Order) bool {
    // Check return window (30 days)
    if order.DeliveredAt == nil {
        return false
    }
    
    daysSinceDelivery := time.Since(*order.DeliveredAt).Hours() / 24
    if daysSinceDelivery > 30 {
        return false
    }
    
    // Check order status
    if order.Status != "delivered" {
        return false
    }
    
    // Check if already returned
    if order.ReturnStatus == "returned" {
        return false
    }
    
    return true
}
```

**Test Scenarios:**
- Valid return request created
- Return outside 30-day window rejected
- Partial return handled
- Return label generated
- Refund amount calculated correctly

---

## 2. Return Approval Workflow

### Requirements

- [ ] **R2.1** Auto-approve low-value returns (<$50)
- [ ] **R2.2** Manual review for high-value returns
- [ ] **R2.3** Check return history (fraud detection)
- [ ] **R2.4** Notify customer of approval/rejection
- [ ] **R2.5** Set return deadline (14 days to ship back)

### Implementation

```go
func (uc *ReturnUseCase) ProcessReturnApproval(ctx context.Context, returnID string) error {
    returnReq, err := uc.repo.GetReturnRequest(ctx, returnID)
    if err != nil {
        return err
    }
    
    // Auto-approval logic
    if returnReq.RefundAmount < 50 {
        return uc.approveReturn(ctx, returnReq, "auto")
    }
    
    // Check return history (fraud check)
    returnHistory, _ := uc.getCustomerReturnHistory(ctx, returnReq.CustomerID)
    
    if len(returnHistory) > 5 {  // More than 5 returns in 6 months
        returnReq.Status = "pending_manual_review"
        returnReq.FraudRiskLevel = "high"
        uc.repo.UpdateReturnRequest(ctx, returnReq)
        uc.notifyCSTeam(ctx, returnReq)
        return nil
    }
    
    // Auto-approve
    return uc.approveReturn(ctx, returnReq, "auto")
}

func (uc *ReturnUseCase) approveReturn(ctx context.Context, returnReq *ReturnRequest, approvedBy string) error {
    returnReq.Status = "approved"
    returnReq.ApprovedBy = approvedBy
    returnReq.ApprovedAt = timePtr(time.Now())
    returnReq.ReturnDeadline = timePtr(time.Now().Add(14 * 24 * time.Hour))
    
    uc.repo.UpdateReturnRequest(ctx, returnReq)
    uc.sendReturnApprovalEmail(ctx, returnReq)
    
    return nil
}
```

---

## 3. Return Receipt & Inspection

### Requirements

- [ ] **R3.1** Scan return tracking number
- [ ] **R3.2** Inspect item condition
- [ ] **R3.3** Verify item matches return request
- [ ] **R3.4** Document issues (damage, missing items)
- [ ] **R3.5** Take photos for records
- [ ] **R3.6** Update inventory

### Implementation

```go
func (uc *ReturnUseCase) ReceiveReturn(ctx context.Context, req *ReceiveReturnRequest) error {
    returnReq, err := uc.repo.GetReturnRequest(ctx, req.ReturnID)
    if err != nil {
        return err
    }
    
    // Mark as received
    returnReq.Status = "received"
    returnReq.ReceivedAt = timePtr(time.Now())
    returnReq.InspectedBy = req.InspectorID
    
    // Inspect each item
    for i, item := range returnReq.Items {
        inspection := req.InspectionResults[i]
        
        item.InspectionResult = inspection
        item.ActualCondition = inspection.Condition
        item.Approved = inspection.Approved
        
        if !inspection.Approved {
            item.RejectionReason = inspection.RejectionReason
        }
    }
    
    // Determine refund eligibility
    approvedItems := uc.getApprovedItems(returnReq.Items)
    returnReq.FinalRefundAmount = uc.calculateFinalRefund(approvedItems)
    
    uc.repo.UpdateReturnRequest(ctx, returnReq)
    
    // Restock approved items
    uc.restockItems(ctx, approvedItems)
    
    return nil
}
```

---

## 4. Refund Processing

### Requirements

- [ ] **R4.1** Process refund to original payment method
- [ ] **R4.2** Support partial refunds
- [ ] **R4.3** Deduct restocking fee (if applicable)
- [ ] **R4.4** Deduct return shipping cost (customer fault)
- [ ] **R4.5** Issue store credit option
- [ ] **R4.6** Track refund status
- [ ] **R4.7** Notify customer when refund processed

### Implementation

```go
func (uc *ReturnUseCase) ProcessRefund(ctx context.Context, returnID string) error {
    returnReq, err := uc.repo.GetReturnRequest(ctx, returnID)
    if err != nil {
        return err
    }
    
    if returnReq.Status != "received" {
        return ErrReturnNotReceived
    }
    
    // Calculate final refund
    refundAmount := returnReq.FinalRefundAmount
    
    // Deduct restocking fee if applicable
    if uc.shouldChargeRestockingFee(returnReq) {
        restockingFee := refundAmount * 0.15  // 15%
        refundAmount -= restockingFee
        returnReq.RestockingFee = restockingFee
    }
    
    // Process refund via payment service
    refund, err := uc.paymentClient.ProcessRefund(ctx, &RefundRequest{
        OrderID:      returnReq.OrderID,
        Amount:       refundAmount,
        Reason:       "return",
        RefundMethod: returnReq.RefundMethod,
    })
    
    if err != nil {
        return err
    }
    
    // Update return request
    returnReq.Status = "completed"
    returnReq.RefundStatus = "processed"
    returnReq.RefundID = refund.ID
    returnReq.RefundedAt = timePtr(time.Now())
    
    uc.repo.UpdateReturnRequest(ctx, returnReq)
    
    // Notify customer
    uc.sendRefundConfirmation(ctx, returnReq)
    
    return nil
}
```

---

## 5. Exchange Handling

### Requirements

- [ ] **R5.1** Support exchange for same item (different size/color)
- [ ] **R5.2** Support exchange for different item (same price)
- [ ] **R5.3** Handle price difference (charge/refund)
- [ ] **R5.4** Create new order for exchange item
- [ ] **R5.5** Link exchange to original return

### Implementation

```go
type ExchangeRequest struct {
    ReturnID            string
    NewProductID        string
    NewVariantID        string
    PriceDifference     float64
    AdditionalCharge    bool
}

func (uc *ReturnUseCase) ProcessExchange(ctx context.Context, req *ExchangeRequest) (*Order, error) {
    returnReq, err := uc.repo.GetReturnRequest(ctx, req.ReturnID)
    if err != nil {
        return nil, err
    }
    
    // Get new product price
    newProduct, err := uc.catalogClient.GetProduct(ctx, req.NewProductID)
    if err != nil {
        return nil, err
    }
    
    // Calculate price difference
    priceDiff := newProduct.Price - returnReq.RefundAmount
    
    // Create new order for exchange
    order, err := uc.orderClient.CreateExchangeOrder(ctx, &CreateExchangeOrderRequest{
        OriginalOrderID: returnReq.OrderID,
        ReturnID:        returnReq.ID,
        ProductID:       req.NewProductID,
        VariantID:       req.NewVariantID,
        Amount:          newProduct.Price,
        ShippingFree:    true,  // Free shipping for exchanges
    })
    
    if err != nil {
        return nil, err
    }
    
    // Handle price difference
    if priceDiff > 0 {
        // Customer needs to pay difference
        uc.paymentClient.ChargeAdditional(ctx, order.ID, priceDiff)
    } else if priceDiff < 0 {
        // Refund difference to customer
        uc.paymentClient.RefundDifference(ctx, returnReq.OrderID, -priceDiff)
    }
    
    // Update return status
    returnReq.Status = "exchanged"
    returnReq.ExchangeOrderID = order.ID
    uc.repo.UpdateReturnRequest(ctx, returnReq)
    
    return order, nil
}
```

---

## 📊 Success Criteria

- [ ] ✅ Return processing <24h
- [ ] ✅ Refund processing <48h
- [ ] ✅ Return approval rate >95%
- [ ] ✅ Inspection accuracy >99%
- [ ] ✅ Customer satisfaction >4.5/5
- [ ] ✅ Fraud detection rate >80%

---

**Status:** Ready for Implementation
