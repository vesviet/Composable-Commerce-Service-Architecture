# Shipping & Logistics Workflow

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Category**: Operational Flows  
**Status**: Active

## Overview

Multi-carrier shipping and delivery tracking workflow covering carrier selection, rate calculation, label generation, shipment tracking, and delivery management across multiple logistics providers.

**Used in**: [Browse to Purchase (Customer Journey)](../customer-journey/browse-to-purchase.md) — Phase 5.2 (rates, label, handover), Phase 6.1 (tracking, delivery). This workflow doc provides the detailed shipping steps; the customer journey doc shows shipping within the fulfillment and delivery phases.

## Participants

### Primary Actors
- **Fulfillment Staff**: Prepares packages for shipment
- **Customer**: Receives shipment tracking and delivery
- **Delivery Driver**: Handles final delivery
- **Customer Service**: Handles delivery issues and inquiries

### Systems/Services
- **Shipping Service**: Core shipping logic and carrier integration
- **Fulfillment Service**: Package preparation and handover
- **Location Service**: Address validation and delivery zones
- **Notification Service**: Shipping updates and delivery alerts
- **Analytics Service**: Shipping performance metrics
- **Gateway Service**: API routing and rate limiting

## Prerequisites

### Business Prerequisites
- Order confirmed and ready for fulfillment
- Package prepared with accurate weight and dimensions
- Delivery address validated and confirmed
- Shipping method selected by customer

### Technical Prerequisites
- Carrier API integrations active and healthy
- Shipping service operational with rate cache
- Label printing system configured
- Tracking webhook endpoints configured

## Workflow Steps

### Main Flow: Standard Shipping Process

1. **Shipping Request Initiation**
   - **Actor**: Fulfillment Service
   - **System**: Shipping Service
   - **Input**: Order ID, package details, delivery address
   - **Output**: Shipping request validated and queued
   - **Duration**: 100-200ms

2. **Address Validation**
   - **Actor**: Shipping Service
   - **System**: Location Service
   - **Input**: Delivery address, postal code
   - **Output**: Validated address, delivery zone
   - **Duration**: 200-500ms

3. **Carrier Selection**
   - **Actor**: Shipping Service
   - **System**: Internal carrier selection engine
   - **Input**: Package details, delivery zone, service level
   - **Output**: Optimal carrier and service selected
   - **Duration**: 50-150ms

4. **Rate Calculation**
   - **Actor**: Shipping Service
   - **System**: Carrier API (Giao Hang Nhanh, Viettel Post, etc.)
   - **Input**: Package weight, dimensions, origin, destination
   - **Output**: Shipping cost, estimated delivery time
   - **Duration**: 500ms - 2 seconds

5. **Shipment Creation**
   - **Actor**: Shipping Service
   - **System**: Carrier API
   - **Input**: Shipment details, sender/receiver info
   - **Output**: Tracking number, shipment ID
   - **Duration**: 1-3 seconds

6. **Label Generation**
   - **Actor**: Shipping Service
   - **System**: Carrier API
   - **Input**: Shipment ID, label format preferences
   - **Output**: Shipping label PDF, barcode
   - **Duration**: 1-2 seconds

7. **Package Handover**
   - **Actor**: Fulfillment Staff
   - **System**: Fulfillment Service
   - **Input**: Package with shipping label attached
   - **Output**: Package handed over to carrier
   - **Duration**: 2-5 minutes

8. **Tracking Activation**
   - **Actor**: Shipping Service
   - **System**: Carrier tracking system
   - **Input**: Tracking number, shipment details
   - **Output**: Tracking activated, initial status set
   - **Duration**: 1-5 minutes

9. **Customer Notification**
   - **Actor**: Shipping Service
   - **System**: Notification Service
   - **Input**: Tracking number, estimated delivery
   - **Output**: Shipping confirmation sent to customer
   - **Duration**: 1-3 seconds

### Alternative Flow 1: Express Shipping

**Trigger**: Customer selects express/same-day delivery
**Steps**:
1. Validate express delivery availability for address
2. Check express carrier capacity and cutoff times
3. Calculate express shipping rates with surcharges
4. Priority queue for express shipment processing
5. Expedited label generation and pickup scheduling
6. Return to main flow step 7

### Alternative Flow 2: International Shipping

**Trigger**: Delivery address is outside Vietnam
**Steps**:
1. Validate international shipping eligibility
2. Generate customs declaration forms
3. Calculate duties and taxes
4. Select international carrier (DHL, FedEx, EMS)
5. Create international shipping documentation
6. Return to main flow step 6

### Alternative Flow 3: Bulk Shipment Processing

**Trigger**: Multiple orders ready for shipment simultaneously
**Steps**:
1. Batch shipment request validation
2. Optimize carrier selection across all shipments
3. Bulk rate calculation for cost optimization
4. Generate multiple labels in batch
5. Coordinate bulk pickup with carriers
6. Return to main flow step 8

### Error Handling

#### Error Scenario 1: Carrier API Unavailable
**Trigger**: Primary carrier API is down or unresponsive
**Impact**: Cannot create shipments or generate labels
**Resolution**:
1. Failover to secondary carrier automatically
2. Use cached rates if available
3. Queue shipment requests for retry
4. Notify operations team of carrier issues
5. Manual processing fallback if needed

#### Error Scenario 2: Address Validation Failure
**Trigger**: Delivery address cannot be validated or is incomplete
**Impact**: Shipment cannot be created, delivery may fail
**Resolution**:
1. Flag order for manual address review
2. Contact customer for address clarification
3. Suggest address corrections if available
4. Hold shipment until address resolved
5. Update order status to "address_verification_needed"

#### Error Scenario 3: Label Printing Failure
**Trigger**: Shipping label cannot be generated or printed
**Impact**: Package cannot be shipped, fulfillment delayed
**Resolution**:
1. Retry label generation with different format
2. Use backup label printing service
3. Generate manual shipping documentation
4. Contact carrier for alternative label options
5. Escalate to fulfillment supervisor

## Business Rules

### Carrier Selection Rules
- **Cost Optimization**: Select lowest cost carrier for standard shipping
- **Service Level**: Match carrier service to customer selection
- **Delivery Zone**: Use carriers with best coverage for destination
- **Package Restrictions**: Respect carrier size and weight limits
- **Performance History**: Prefer carriers with better delivery rates

### Shipping Constraints
- **Cutoff Times**: Respect daily shipping cutoff times
- **Weekend Shipping**: Limited carriers for weekend delivery
- **Holiday Restrictions**: No shipping on national holidays
- **Hazardous Materials**: Special handling for restricted items
- **Insurance Requirements**: Automatic insurance for high-value items

## Integration Points

### Service Integrations
| Service | Integration Type | Purpose | Error Handling |
|---------|------------------|---------|----------------|
| Fulfillment Service | Synchronous gRPC | Package ready notification | Retry with backoff |
| Location Service | Synchronous gRPC | Address validation | Fallback validation |
| Notification Service | Asynchronous Event | Shipping notifications | Dead letter queue |
| Analytics Service | Asynchronous Event | Shipping metrics | Best effort delivery |

### External Integrations
| External System | Integration Type | Purpose | SLA |
|-----------------|------------------|---------|-----|
| Giao Hang Nhanh | REST API | Domestic shipping | 99.5% uptime |
| Viettel Post | REST API | Domestic shipping | 99.0% uptime |
| DHL | REST API | International shipping | 99.9% uptime |
| FedEx | REST API | International shipping | 99.9% uptime |

## Performance Requirements

### Response Times
- Carrier selection: < 200ms (P95)
- Rate calculation: < 2 seconds (P95)
- Label generation: < 3 seconds (P95)
- Tracking update: < 1 second (P95)

### Throughput
- Peak load: 2,000 shipments per hour
- Average load: 500 shipments per hour
- Concurrent label generation: 100 simultaneous

### Availability
- Target uptime: 99.9%
- Carrier failover time: < 30 seconds
- Label generation success rate: > 99%

## Monitoring & Metrics

### Key Metrics
- **Shipment Success Rate**: Percentage of successful shipments created
- **Carrier Performance**: On-time delivery rates by carrier
- **Label Generation Time**: Average time to generate shipping labels
- **Tracking Update Frequency**: Frequency of tracking status updates
- **Delivery Success Rate**: Percentage of successful deliveries

### Alerts
- **Critical**: Carrier API response time > 5 seconds
- **Critical**: Label generation failure rate > 5%
- **Warning**: Unusual shipping volume patterns
- **Info**: New carrier performance issues detected

### Dashboards
- Real-time shipping operations dashboard
- Carrier performance comparison dashboard
- Delivery tracking and exceptions dashboard
- Shipping cost optimization dashboard

## Testing Strategy

### Test Scenarios
1. **Standard Shipping**: Normal domestic shipping flow
2. **Express Delivery**: Same-day and next-day shipping
3. **International Shipping**: Cross-border shipments
4. **Carrier Failover**: Primary carrier failure scenarios
5. **Bulk Processing**: High-volume shipment processing

### Test Data
- Various package sizes and weights
- Domestic and international addresses
- Different service level requirements
- Mock carrier API responses

## Troubleshooting

### Common Issues
- **Tracking Not Updating**: Check carrier webhook configuration
- **High Shipping Costs**: Review carrier selection algorithm
- **Label Printing Errors**: Verify printer configuration and supplies
- **Delivery Delays**: Monitor carrier performance metrics

### Debug Procedures
1. Check shipping service logs for API calls
2. Verify carrier API credentials and endpoints
3. Test address validation with sample addresses
4. Review carrier rate calculation parameters
5. Validate webhook delivery and processing

## Changelog

### Version 1.0 (2026-01-31)
- Initial shipping and logistics workflow documentation
- Multi-carrier integration (domestic and international)
- Comprehensive error handling and failover
- Performance requirements and monitoring

## References

- [Shipping Service Documentation](../../03-services/core-services/shipping-service.md)
- [Fulfillment Service Integration](../../03-services/operational-services/fulfillment-service.md)
- [Location Service Integration](../../03-services/operational-services/location-service.md)
- [Shipping API Specification](../../04-apis/shipping-api.md)
