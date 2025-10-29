# Customer Service

## Description
Service that manages customer information, profiles and preferences.

## Outbound Data
- Customer profile and personal info
- Shipping and billing addresses
- Customer group and segment
- Loyalty points and tier status
- Customer preferences and settings

## Consumers (Services that use this data)

### Order Service
- **Purpose**: Get billing and shipping details
- **Data Received**: Customer addresses, payment methods, order preferences

### Promotion Service
- **Purpose**: Enable personalized discounts
- **Data Received**: Customer segment, loyalty status, purchase history

### Notification Service
- **Purpose**: Send targeted messages
- **Data Received**: Customer contact preferences, communication settings

## Data Sources
- **Order Service**: Order history and purchase behavior
- **Promotion Service**: Promotion usage history

## Main APIs
- `GET /customers/{id}` - Get customer information
- `PUT /customers/{id}` - Update customer information
- `GET /customers/{id}/addresses` - Get customer addresses
- `POST /customers/{id}/addresses` - Add new address
- `GET /customers/{id}/preferences` - Get preferences
- `GET /customers/{id}/loyalty` - Get loyalty status