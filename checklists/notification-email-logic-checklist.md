# 📧 Notification & Email Logic Checklist

**Service:** Notification Service  
**Created:** 2025-11-19  
**Priority:** 🟡 **Medium**

---

## 🎯 Overview

Notifications là primary communication channel với customers. Proper implementation drives engagement và reduces support burden.

**Channels:**
- Email (transactional + marketing)
- SMS
- Push notifications
- In-app notifications

---

## 1. Transactional Emails

### Requirements

- [ ] **R1.1** Order confirmation email
- [ ] **R1.2** Shipping confirmation email
- [ ] **R1.3** Delivery confirmation email
- [ ] **R1.4** Order cancellation email
- [ ] **R1.5** Refund confirmation email
- [ ] **R1.6** Password reset email
- [ ] **R1.7** Email verification email
- [ ] **R1.8** Payment receipt email

### Implementation

```go
type EmailTemplate struct {
    ID          string
    Name        string
    Subject     string
    HTMLBody    string
    TextBody    string
    Variables   []string
}

func (ns *NotificationService) SendOrderConfirmation(ctx context.Context, order *Order) error {
    email := &Email{
        To:       order.CustomerEmail,
        Template: "order_confirmation",
        Subject:  fmt.Sprintf("Order Confirmation - %s", order.OrderNumber),
        Data: map[string]interface{}{
            "order_number":    order.OrderNumber,
            "order_date":      order.CreatedAt.Format("Jan 2, 2006"),
            "items":           order.Items,
            "subtotal":        order.Subtotal,
            "shipping":        order.ShippingAmount,
            "tax":             order.TaxAmount,
            "total":           order.Total,
            "shipping_address": order.ShippingAddress,
            "tracking_url":    ns.getTrackingURL(order.ID),
        },
    }
    
    return ns.emailClient.Send(ctx, email)
}

func (ns *NotificationService) SendShippingConfirmation(ctx context.Context, shipment *Shipment) error {
    order, _ := ns.orderClient.GetOrder(ctx, shipment.OrderID)
    
    email := &Email{
        To:       order.CustomerEmail,
        Template: "shipping_confirmation",
        Subject:  "Your order has shipped!",
        Data: map[string]interface{}{
            "order_number":     order.OrderNumber,
            "tracking_number":  shipment.TrackingNumber,
            "carrier":          shipment.Carrier,
            "estimated_delivery": shipment.EstimatedDelivery,
            "tracking_url":     shipment.TrackingURL,
        },
    }
    
    return ns.emailClient.Send(ctx, email)
}
```

---

## 2. Marketing Emails

### Requirements

- [ ] **R2.1** Welcome email series
- [ ] **R2.2** Abandoned cart recovery
- [ ] **R2.3** Product recommendations
- [ ] **R2.4** Promotional campaigns
- [ ] **R2.5** Newsletter
- [ ] **R2.6** Price drop alerts
- [ ] **R2.7** Back-in-stock alerts
- [ ] **R2.8** Birthday offers

### Implementation

```go
func (ns *NotificationService) SendAbandonedCart(ctx context.Context, cart *Cart) error {
    customer, _ := ns.customerClient.GetCustomer(ctx, cart.CustomerID)
    
    // Check if customer opted in for marketing emails
    if !customer.EmailPreferences.Marketing {
        return nil
    }
    
    // Calculate cart value
    cartValue := 0.0
    for _, item := range cart.Items {
        cartValue += item.Price * float64(item.Quantity)
    }
    
    // Determine incentive (if high-value cart)
    incentive := ""
    if cartValue > 100 {
        incentive = "10% off your order"
    }
    
    email := &Email{
        To:       customer.Email,
        Template: "abandoned_cart",
        Subject:  "You left something in your cart!",
        Data: map[string]interface{}{
            "customer_name": customer.FirstName,
            "cart_items":    cart.Items,
            "cart_total":    cartValue,
            "incentive":     incentive,
            "checkout_url":  ns.getCheckoutURL(cart.ID),
        },
    }
    
    return ns.emailClient.Send(ctx, email)
}

func (ns *NotificationService) SendPriceDropAlert(ctx context.Context, alert *PriceAlert) error {
    product, _ := ns.catalogClient.GetProduct(ctx, alert.ProductID)
    customer, _ := ns.customerClient.GetCustomer(ctx, alert.CustomerID)
    
    email := &Email{
        To:       customer.Email,
        Template: "price_drop_alert",
        Subject:  fmt.Sprintf("Price drop on %s!", product.Name),
        Data: map[string]interface{}{
            "customer_name":  customer.FirstName,
            "product_name":   product.Name,
            "old_price":      alert.PreviousPrice,
            "new_price":      alert.CurrentPrice,
            "discount_percent": ((alert.PreviousPrice - alert.CurrentPrice) / alert.PreviousPrice) * 100,
            "product_url":    ns.getProductURL(product.ID),
            "product_image":  product.MainImage,
        },
    }
    
    return ns.emailClient.Send(ctx, email)
}
```

---

## 3. SMS Notifications

### Requirements

- [ ] **R3.1** Order status updates
- [ ] **R3.2** Delivery tracking
- [ ] **R3.3** OTP for authentication
- [ ] **R3.4** Promotional SMS (with consent)
- [ ] **R3.5** SMS opt-out support
- [ ] **R3.6** SMS delivery tracking

### Implementation

```go
func (ns *NotificationService) SendDeliveryNotification(ctx context.Context, shipment *Shipment) error {
    order, _ := ns.orderClient.GetOrder(ctx, shipment.OrderID)
    customer, _ := ns.customerClient.GetCustomer(ctx, order.CustomerID)
    
    // Check SMS consent
    if !customer.SMSConsent {
        return nil
    }
    
    message := fmt.Sprintf(
        "Your order #%s will be delivered today. Track: %s",
        order.OrderNumber,
        ns.getShortenedTrackingURL(shipment.TrackingNumber),
    )
    
    return ns.smsClient.Send(ctx, &SMS{
        To:      customer.PhoneNumber,
        Message: message,
    })
}

func (ns *NotificationService) SendOTP(ctx context.Context, phoneNumber, code string) error {
    message := fmt.Sprintf(
        "Your verification code is: %s. Valid for 5 minutes.",
        code,
    )
    
    return ns.smsClient.Send(ctx, &SMS{
        To:      phoneNumber,
        Message: message,
    })
}
```

---

## 4. Push Notifications

### Requirements

- [ ] **R4.1** Order updates
- [ ] **R4.2** Promotional offers
- [ ] **R4.3** Abandoned cart reminders
- [ ] **R4.4** Price alerts
- [ ] **R4.5** Push notification settings
- [ ] **R4.6** Device token management
- [ ] **R4.7** Segmented push campaigns

### Implementation

```go
func (ns *NotificationService) SendPushNotification(ctx context.Context, req *PushRequest) error {
    // Get device tokens
    devices, err := ns.deviceClient.GetCustomerDevices(ctx, req.CustomerID)
    if err != nil {
        return err
    }
    
    notification := &PushNotification{
        Title:    req.Title,
        Body:     req.Body,
        ImageURL: req.ImageURL,
        Data:     req.Data,
        DeepLink: req.DeepLink,
    }
    
    // Send to all devices
    for _, device := range devices {
        if device.PushEnabled {
            ns.pushClient.Send(ctx, device.Token, notification)
        }
    }
    
    return nil
}
```

---

## 5. In-App Notifications

### Requirements

- [ ] **R5.1** Order status changes
- [ ] **R5.2** New messages
- [ ] **R5.3** Promotions
- [ ] **R5.4** Product updates
- [ ] **R5.5** Mark as read
- [ ] **R5.6** Notification center
- [ ] **R5.7** Real-time delivery (WebSocket)

### Implementation

```go
type InAppNotification struct {
    ID          string
    CustomerID  string
    Type        string  // "order", "message", "promotion"
    Title       string
    Body        string
    ImageURL    string
    ActionURL   string
    Read        bool
    CreatedAt   time.Time
}

func (ns *NotificationService) CreateInAppNotification(ctx context.Context, req *CreateNotificationRequest) error {
    notification := &InAppNotification{
        ID:         uuid.New().String(),
        CustomerID: req.CustomerID,
        Type:       req.Type,
        Title:      req.Title,
        Body:       req.Body,
        ImageURL:   req.ImageURL,
        ActionURL:  req.ActionURL,
        Read:       false,
        CreatedAt:  time.Now(),
    }
    
    // Save to database
    ns.repo.CreateNotification(ctx, notification)
    
    // Send real-time via WebSocket
    ns.websocketClient.SendToUser(req.CustomerID, map[string]interface{}{
        "type":         "new_notification",
        "notification": notification,
    })
    
    return nil
}

func (ns *NotificationService) GetNotifications(ctx context.Context, customerID string, unreadOnly bool) ([]*InAppNotification, error) {
    return ns.repo.GetNotifications(ctx, &GetNotificationsRequest{
        CustomerID:   customerID,
        UnreadOnly:   unreadOnly,
        Limit:        50,
    })
}

func (ns *NotificationService) MarkAsRead(ctx context.Context, notificationID string) error {
    return ns.repo.UpdateNotification(ctx, notificationID, map[string]interface{}{
        "read": true,
        "read_at": time.Now(),
    })
}
```

---

## 6. Notification Preferences

### Requirements

- [ ] **R6.1** Email preferences (transactional, marketing, newsletter)
- [ ] **R6.2** SMS preferences
- [ ] **R6.3** Push notification preferences
- [ ] **R6.4** Frequency control
- [ ] **R6.5** Do Not Disturb hours
- [ ] **R6.6** Unsubscribe management
- [ ] **R6.7** Preference center

### Implementation

```go
type NotificationPreferences struct {
    CustomerID  string
    
    // Email
    EmailTransactional bool  // Always true (required)
    EmailMarketing     bool
    EmailNewsletter    bool
    EmailPriceAlerts   bool
    
    // SMS
    SMSConsent         bool
    SMSOrderUpdates    bool
    SMSPromotions      bool
    
    // Push
    PushEnabled        bool
    PushOrderUpdates   bool
    PushPromotions     bool
    PushPriceAlerts    bool
    
    // Frequency
    EmailFrequency     string  // "immediate", "daily", "weekly"
    
    // DND
    DNDEnabled         bool
    DNDStartHour       int    // 22 (10 PM)
    DNDEndHour         int    // 8 (8 AM)
    
    UpdatedAt          time.Time
}

func (ns *NotificationService) UpdatePreferences(ctx context.Context, customerID string, prefs *NotificationPreferences) error {
    // Validate preferences
    if !prefs.EmailTransactional {
        return ErrTransactionalEmailRequired
    }
    
    prefs.CustomerID = customerID
    prefs.UpdatedAt = time.Now()
    
    return ns.repo.UpdatePreferences(ctx, prefs)
}

func (ns *NotificationService) ShouldSend(ctx context.Context, customerID string, channel, type string) bool {
    prefs, _ := ns.repo.GetPreferences(ctx, customerID)
    
    // Check DND hours
    if prefs.DNDEnabled && ns.isDNDTime(prefs) {
        return false
    }
    
    // Check channel preferences
    switch channel {
    case "email":
        if type == "marketing" && !prefs.EmailMarketing {
            return false
        }
    case "sms":
        if type == "promotion" && !prefs.SMSPromotions {
            return false
        }
    case "push":
        if !prefs.PushEnabled {
            return false
        }
    }
    
    return true
}
```

---

## 7. Delivery Management

### Requirements

- [ ] **R7.1** Queue management
- [ ] **R7.2** Retry failed sends (3 attempts)
- [ ] **R7.3** Track delivery status
- [ ] **R7.4** Handle bounces
- [ ] **R7.5** Rate limiting
- [ ] **R7.6** Batch sending
- [ ] **R7.7** Delivery analytics

### Implementation

```go
type NotificationQueue struct {
    ID          string
    Type        string  // "email", "sms", "push"
    Recipient   string
    Template    string
    Data        map[string]interface{}
    Status      string  // "queued", "sending", "sent", "failed"
    Attempts    int
    LastAttempt *time.Time
    Error       string
    CreatedAt   time.Time
}

func (ns *NotificationService) QueueNotification(ctx context.Context, notification *NotificationQueue) error {
    notification.ID = uuid.New().String()
    notification.Status = "queued"
    notification.Attempts = 0
    notification.CreatedAt = time.Now()
    
    return ns.queueRepo.Add(ctx, notification)
}

func (ns *NotificationService) ProcessQueue(ctx context.Context) {
    for {
        // Get pending notifications
        notifications, _ := ns.queueRepo.GetPending(ctx, 100)
        
        for _, notification := range notifications {
            // Check rate limit
            if ns.isRateLimited(notification.Type) {
                continue
            }
            
            // Send notification
            err := ns.send(ctx, notification)
            
            if err != nil {
                notification.Attempts++
                notification.LastAttempt = timePtr(time.Now())
                notification.Error = err.Error()
                
                if notification.Attempts >= 3 {
                    notification.Status = "failed"
                } else {
                    notification.Status = "queued"
                }
            } else {
                notification.Status = "sent"
            }
            
            ns.queueRepo.Update(ctx, notification)
        }
        
        time.Sleep(1 * time.Second)
    }
}
```

---

## 📊 Success Criteria

- [ ] ✅ Email delivery rate >95%
- [ ] ✅ SMS delivery rate >98%
- [ ] ✅ Push notification delivery <5s
- [ ] ✅ Unsubscribe rate <2%
- [ ] ✅ Bounce rate <5%
- [ ] ✅ Notification queue processing <1min

---

**Status:** Ready for Implementation
