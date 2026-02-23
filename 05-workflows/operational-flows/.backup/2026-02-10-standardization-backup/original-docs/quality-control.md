# Quality Control Workflow

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Category**: Operational Flows  
**Status**: Active

## Overview

Fulfillment quality control and inspection processes ensuring product quality, order accuracy, and customer satisfaction through systematic quality assurance checks throughout the fulfillment workflow.

## Participants

### Primary Actors
- **Quality Inspector**: Performs quality checks and inspections
- **Fulfillment Staff**: Prepares orders and handles QC feedback
- **QC Supervisor**: Reviews failed inspections and makes decisions
- **Warehouse Manager**: Oversees quality control operations

### Systems/Services
- **Fulfillment Service**: Triggers QC checks and processes results
- **Warehouse Service**: Provides inventory and product information
- **Analytics Service**: Tracks quality metrics and trends
- **Notification Service**: Alerts for quality issues and failures

## Prerequisites

### Business Prerequisites
- Order picked and packed, ready for quality inspection
- Quality control standards and procedures defined
- Inspection criteria configured for product categories
- Quality control staff trained and available

### Technical Prerequisites
- Fulfillment service operational with QC integration
- Quality control workstations configured
- Barcode scanning equipment functional
- Photo documentation system available

## Workflow Steps

### Main Flow: Standard Quality Control Process

1. **QC Trigger Evaluation**
   - **Actor**: Fulfillment Service
   - **System**: Internal QC rules engine
   - **Input**: Order details, product categories, customer tier
   - **Output**: QC requirement determination
   - **Duration**: 50-100ms

2. **QC Assignment**
   - **Actor**: Fulfillment Service
   - **System**: QC workload balancer
   - **Input**: QC requirement, inspector availability
   - **Output**: QC task assigned to inspector
   - **Duration**: 200-500ms

3. **Package Retrieval**
   - **Actor**: Quality Inspector
   - **System**: Fulfillment Service
   - **Input**: QC task ID, package location
   - **Output**: Package retrieved for inspection
   - **Duration**: 2-5 minutes

4. **Order Verification**
   - **Actor**: Quality Inspector
   - **System**: Fulfillment Service
   - **Input**: Package contents, order details
   - **Output**: Order accuracy verified
   - **Duration**: 3-8 minutes

5. **Product Quality Inspection**
   - **Actor**: Quality Inspector
   - **System**: QC inspection system
   - **Input**: Product condition, quality criteria
   - **Output**: Quality assessment completed
   - **Duration**: 5-15 minutes

6. **Packaging Quality Check**
   - **Actor**: Quality Inspector
   - **System**: QC inspection system
   - **Input**: Package condition, protection adequacy
   - **Output**: Packaging quality verified
   - **Duration**: 2-5 minutes

7. **Documentation & Photos**
   - **Actor**: Quality Inspector
   - **System**: QC documentation system
   - **Input**: Inspection results, quality issues
   - **Output**: QC report with photos generated
   - **Duration**: 3-7 minutes

8. **QC Decision**
   - **Actor**: Quality Inspector
   - **System**: Fulfillment Service
   - **Input**: Inspection results, quality standards
   - **Output**: Pass/Fail decision recorded
   - **Duration**: 1-2 minutes

9. **Result Processing**
   - **Actor**: Fulfillment Service
   - **System**: Warehouse Service
   - **Input**: QC decision, order ID
   - **Output**: Order status updated, next action triggered
   - **Duration**: 100-300ms

### Alternative Flow 1: High-Value Order Inspection

**Trigger**: Order value exceeds high-value threshold (₫5,000,000)
**Steps**:
1. Mandatory QC flag set for order
2. Senior inspector assignment required
3. Enhanced inspection checklist applied
4. Additional photo documentation required
5. Supervisor approval for QC pass decision
6. Return to main flow step 9

### Alternative Flow 2: Random Quality Sampling

**Trigger**: Random sampling algorithm selects order (10% of orders)
**Steps**:
1. Random QC flag set during fulfillment
2. Standard QC process with sampling notation
3. Additional data collection for quality trends
4. Results contribute to quality statistics
5. No special handling required
6. Return to main flow step 9

### Alternative Flow 3: Customer-Requested Inspection

**Trigger**: Customer specifically requests quality inspection
**Steps**:
1. Customer QC request flag set on order
2. Enhanced inspection with customer-specific criteria
3. Detailed photo documentation
4. Customer notification of inspection completion
5. Premium handling and packaging
6. Return to main flow step 9

### Error Handling

#### Error Scenario 1: QC Inspection Failure
**Trigger**: Product fails quality inspection
**Impact**: Order cannot be shipped, customer delivery delayed
**Resolution**:
1. Document specific quality issues found
2. Remove defective items from package
3. Check inventory for replacement items
4. If replacement available, repack and re-inspect
5. If no replacement, notify customer and offer alternatives

#### Error Scenario 2: Order Accuracy Failure
**Trigger**: Package contents don't match order
**Impact**: Wrong items would be shipped to customer
**Resolution**:
1. Document discrepancies found
2. Return incorrect items to inventory
3. Pick correct items from warehouse
4. Repack order with correct items
5. Restart QC process from step 4

#### Error Scenario 3: Packaging Damage
**Trigger**: Package or products damaged during handling
**Impact**: Customer would receive damaged goods
**Resolution**:
1. Assess extent of damage
2. If minor, repackage with better protection
3. If major, replace damaged items
4. Use appropriate packaging materials
5. Restart QC process from step 6

## Business Rules

### QC Trigger Rules
- **High-Value Orders**: Orders > ₫5,000,000 require mandatory QC (100%)
- **Random Sampling**: 10% of all orders selected for random QC
- **First-Time Customers**: 25% of first-time customer orders
- **Fragile Items**: Orders containing fragile products (100%)
- **Customer Request**: Customer-requested inspections (100%)

### Quality Standards
- **Product Condition**: No visible damage, defects, or wear
- **Order Accuracy**: 100% match between ordered and packed items
- **Packaging Quality**: Adequate protection for shipping
- **Documentation**: Complete and accurate shipping labels
- **Cleanliness**: Products and packaging clean and presentable

## Integration Points

### Service Integrations
| Service | Integration Type | Purpose | Error Handling |
|---------|------------------|---------|----------------|
| Warehouse Service | Synchronous gRPC | Product information | Cache fallback |
| Analytics Service | Asynchronous Event | Quality metrics | Best effort delivery |
| Notification Service | Asynchronous Event | Quality alerts | Dead letter queue |

### External Integrations
| External System | Integration Type | Purpose | SLA |
|-----------------|------------------|---------|-----|
| Photo Storage | REST API | QC documentation | 99% availability |
| Barcode Scanner | Hardware API | Product verification | 99.9% availability |

## Performance Requirements

### Response Times
- QC assignment: < 1 second
- Inspection completion: 10-30 minutes per order
- QC decision processing: < 500ms
- Result notification: < 2 seconds

### Throughput
- Peak load: 200 QC inspections per hour
- Average load: 80 QC inspections per hour
- Inspector capacity: 6-8 inspections per hour per inspector

### Availability
- Target uptime: 99.5%
- QC system availability during business hours: 99.9%
- Photo documentation success rate: > 98%

## Monitoring & Metrics

### Key Metrics
- **QC Pass Rate**: Percentage of orders passing quality inspection
- **Inspection Time**: Average time per quality inspection
- **Defect Detection Rate**: Percentage of defects caught by QC
- **Inspector Productivity**: Inspections completed per hour per inspector
- **Customer Satisfaction**: Quality-related customer feedback

### Alerts
- **Critical**: QC pass rate < 90%
- **Critical**: QC system downtime during business hours
- **Warning**: Unusual increase in quality failures
- **Info**: Inspector productivity below target

### Dashboards
- Real-time QC operations dashboard
- Quality trends and defect analysis
- Inspector performance dashboard
- Customer quality feedback dashboard

## Testing Strategy

### Test Scenarios
1. **Standard QC Process**: Normal quality inspection flow
2. **High-Value Orders**: Enhanced inspection procedures
3. **Quality Failures**: Various defect scenarios
4. **System Failures**: QC system downtime handling
5. **Peak Load**: High-volume inspection processing

### Test Data
- Orders with various product categories
- Simulated quality defects and issues
- Different customer tiers and requirements
- Mock inspection results and photos

## Troubleshooting

### Common Issues
- **Long Inspection Times**: Review inspection procedures and training
- **High Failure Rates**: Analyze root causes and supplier quality
- **System Slowdowns**: Check QC system performance and capacity
- **Photo Upload Failures**: Verify storage system connectivity

### Debug Procedures
1. Check QC system logs for inspection details
2. Review inspector workload and assignment logic
3. Analyze quality failure patterns and trends
4. Verify photo documentation system status
5. Test barcode scanning equipment functionality

## Changelog

### Version 1.0 (2026-01-31)
- Initial quality control workflow documentation
- Comprehensive QC trigger rules and standards
- Multi-tier inspection process (standard, high-value, random)
- Quality metrics and performance monitoring

## References

- [Fulfillment Service Documentation](../../03-services/operational-services/fulfillment-service.md)
- [Warehouse Service Integration](../../03-services/operational-services/warehouse-service.md)
- [Quality Control Standards](../../06-operations/procedures/quality-control-standards.md)
- [Fulfillment Workflow](./order-fulfillment.md)
