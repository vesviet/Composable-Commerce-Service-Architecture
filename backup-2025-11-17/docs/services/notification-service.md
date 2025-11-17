# Notification Service

## Description
Service that processes and sends notifications to customers and admins through multiple channels.

## Inbound Data
- Triggered events from Order Service
- Shipping updates from Shipping Service
- Promotion notifications from Promotion Service
- Customer events from Customer Service

## Outbound Data
- Email notifications
- SMS messages
- Push notifications
- Webhook notifications
- In-app notifications

## Consumers (Recipients)
- **Customers**: Order updates, shipping notifications, promotions
- **Admins**: System alerts, order notifications, inventory alerts

## Event Sources

### Order Service
- Order confirmation
- Order status changes
- Payment confirmations
- Cancellation notifications

### Shipping Service
- Shipping confirmations
- Delivery updates
- Delivery completion
- Return notifications

### Promotion Service
- New promotion alerts
- Expiring promotions
- Personalized offers

## Main APIs
- `POST /notifications/send` - Send notification
- `GET /notifications/{customerId}` - Get customer notifications
- `POST /notifications/templates` - Create notification template
- `PUT /notifications/{id}/read` - Mark notification as read
- `GET /notifications/preferences/{customerId}` - Get notification preferences