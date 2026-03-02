# Loyalty & Rewards Customer Journey

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Category**: Customer Journey  
**Status**: Active

## Overview

Complete customer loyalty and rewards journey covering account creation, points earning, tier progression, reward redemption, and referral programs to enhance customer retention and lifetime value.

## Participants

### Primary Actors
- **Customer**: Earns points, redeems rewards, participates in loyalty program
- **Marketing Manager**: Manages loyalty campaigns and reward offerings
- **Customer Service**: Assists with loyalty account issues and redemptions
- **System Administrator**: Configures loyalty rules and monitors program health

### Systems/Services
- **Loyalty Service**: Core loyalty program management
- **Customer Service**: Customer profile and segmentation
- **Order Service**: Purchase tracking for points earning
- **Notification Service**: Loyalty communications and alerts
- **Analytics Service**: Loyalty program performance metrics
- **Gateway Service**: API routing and authentication

## Prerequisites

### Business Prerequisites
- Customer account created and verified
- Loyalty program terms and conditions accepted
- Points earning rules and reward catalog configured
- Customer segmentation and tier structure defined

### Technical Prerequisites
- Loyalty service operational with points calculation
- Integration with order and payment systems
- Notification channels configured for loyalty communications
- Analytics tracking for loyalty program metrics

## Workflow Steps

### Main Flow: Complete Loyalty Journey

1. **Loyalty Account Creation**
   - **Actor**: Customer
   - **System**: Loyalty Service
   - **Input**: Customer registration, program enrollment
   - **Output**: Loyalty account created with initial tier
   - **Duration**: 2-5 seconds

2. **Welcome Bonus Award**
   - **Actor**: Loyalty Service
   - **System**: Points calculation engine
   - **Input**: New account creation event
   - **Output**: Welcome bonus points awarded
   - **Duration**: 1-3 seconds

3. **Purchase Points Earning**
   - **Actor**: Order Service
   - **System**: Loyalty Service
   - **Input**: Order completion event, purchase amount
   - **Output**: Points earned and added to account
   - **Duration**: 5-10 seconds

4. **Tier Evaluation**
   - **Actor**: Loyalty Service
   - **System**: Tier calculation engine
   - **Input**: Customer spending history, points balance
   - **Output**: Tier status evaluated and updated if needed
   - **Duration**: 2-5 seconds

5. **Reward Browsing**
   - **Actor**: Customer
   - **System**: Loyalty Service
   - **Input**: Customer request for available rewards
   - **Output**: Personalized reward catalog displayed
   - **Duration**: 200-500ms

6. **Reward Redemption**
   - **Actor**: Customer
   - **System**: Loyalty Service
   - **Input**: Reward selection, points deduction
   - **Output**: Reward redeemed, points deducted
   - **Duration**: 3-8 seconds

7. **Referral Program Participation**
   - **Actor**: Customer
   - **System**: Loyalty Service
   - **Input**: Referral code sharing, friend registration
   - **Output**: Referral bonus points awarded
   - **Duration**: 1-3 seconds

8. **Loyalty Communications**
   - **Actor**: Loyalty Service
   - **System**: Notification Service
   - **Input**: Loyalty events, customer preferences
   - **Output**: Personalized loyalty notifications sent
   - **Duration**: 2-5 seconds

### Alternative Flow 1: Tier Upgrade Journey

**Trigger**: Customer reaches spending threshold for next tier
**Steps**:
1. Automatic tier evaluation after purchase
2. Tier upgrade qualification confirmed
3. Customer tier status updated
4. Tier upgrade benefits activated
5. Congratulatory notification sent
6. Enhanced rewards and benefits available

### Alternative Flow 2: Points Expiration Management

**Trigger**: Customer points approaching expiration date
**Steps**:
1. Points expiration check runs daily
2. Customers with expiring points identified
3. Expiration warning notifications sent
4. Reward suggestions provided to use points
5. Expired points removed from accounts
6. Expiration summary sent to customers

### Alternative Flow 3: Special Campaign Participation

**Trigger**: Limited-time loyalty campaign launched
**Steps**:
1. Campaign eligibility check for customers
2. Bonus points multiplier activated
3. Campaign-specific rewards made available
4. Customer participation tracked
5. Bonus rewards distributed at campaign end
6. Campaign performance analyzed

### Error Handling

#### Error Scenario 1: Points Calculation Error
**Trigger**: Incorrect points awarded for purchase
**Impact**: Customer receives wrong points amount
**Resolution**:
1. Detect points calculation discrepancy
2. Log error details for investigation
3. Correct points balance automatically if possible
4. Notify customer of correction
5. Review and fix calculation rules

#### Error Scenario 2: Reward Redemption Failure
**Trigger**: Reward redemption fails due to system error
**Impact**: Customer cannot redeem earned rewards
**Resolution**:
1. Preserve customer points balance
2. Log redemption failure details
3. Retry redemption automatically
4. If retry fails, queue for manual processing
5. Notify customer of status and resolution

#### Error Scenario 3: Tier Calculation Inconsistency
**Trigger**: Customer tier not updated despite meeting requirements
**Impact**: Customer misses tier benefits and rewards
**Resolution**:
1. Run tier recalculation for affected customer
2. Update tier status and activate benefits
3. Backdate tier benefits if applicable
4. Send tier upgrade notification
5. Review tier calculation logic

## Business Rules

### Points Earning Rules
- **Purchase Points**: 1 point per ₫1,000 spent (base rate)
- **Tier Multipliers**: Bronze 1x, Silver 1.2x, Gold 1.5x, Platinum 2x
- **Category Bonuses**: Electronics 2x, Fashion 1.5x, Books 1.2x
- **Welcome Bonus**: 500 points for new account creation
- **Referral Bonus**: 1,000 points for successful referral

### Tier Progression Rules
- **Bronze**: Default tier (₫0+ spent)
- **Silver**: ₫5,000,000+ spent in 12 months
- **Gold**: ₫15,000,000+ spent in 12 months
- **Platinum**: ₫50,000,000+ spent in 12 months
- **Tier Benefits**: Exclusive discounts, early access, free shipping

### Redemption Rules
- **Minimum Redemption**: 100 points minimum
- **Expiration Period**: Points expire after 24 months
- **Redemption Limits**: Maximum 50% of order value in points
- **Reward Categories**: Discounts, free products, exclusive experiences
- **Transfer Restrictions**: Points cannot be transferred between accounts

## Integration Points

### Service Integrations
| Service | Integration Type | Purpose | Error Handling |
|---------|------------------|---------|----------------|
| Order Service | Event-driven | Purchase tracking | Retry with backoff |
| Customer Service | Synchronous gRPC | Customer data | Cache fallback |
| Notification Service | Asynchronous Event | Loyalty communications | Dead letter queue |
| Analytics Service | Asynchronous Event | Program metrics | Best effort delivery |

### External Integrations
| External System | Integration Type | Purpose | SLA |
|-----------------|------------------|---------|-----|
| Email Provider | REST API | Loyalty emails | 99.9% delivery |
| SMS Provider | REST API | Points notifications | 99.5% delivery |

## Performance Requirements

### Response Times
- Points calculation: < 200ms (P95)
- Reward redemption: < 1 second (P95)
- Tier evaluation: < 500ms (P95)
- Loyalty dashboard load: < 800ms (P95)

### Throughput
- Peak points earning: 5,000 transactions per minute
- Average reward redemptions: 100 per minute
- Concurrent loyalty operations: 1,000 simultaneous

### Availability
- Target uptime: 99.9%
- Points earning success rate: > 99.5%
- Reward redemption success rate: > 98%

## Monitoring & Metrics

### Key Metrics
- **Program Participation Rate**: Percentage of customers enrolled in loyalty program
- **Points Earning Rate**: Average points earned per customer per month
- **Redemption Rate**: Percentage of earned points redeemed
- **Tier Distribution**: Customer distribution across loyalty tiers
- **Customer Lifetime Value**: CLV improvement from loyalty program

### Alerts
- **Critical**: Loyalty service response time > 2 seconds
- **Critical**: Points calculation error rate > 1%
- **Warning**: Unusual redemption patterns detected
- **Info**: Tier upgrade milestone reached

### Dashboards
- Real-time loyalty program performance dashboard
- Customer tier progression and engagement dashboard
- Reward redemption and inventory dashboard
- Loyalty program ROI and business impact dashboard

## Testing Strategy

### Test Scenarios
1. **Complete Journey**: End-to-end loyalty program participation
2. **Points Earning**: Various purchase scenarios and calculations
3. **Tier Progression**: Customer advancement through tiers
4. **Reward Redemption**: Different reward types and redemption flows
5. **Referral Program**: Referral tracking and bonus distribution

### Test Data
- Customer profiles with various spending patterns
- Order data for points calculation testing
- Reward catalog with different redemption options
- Referral scenarios and bonus calculations

## Troubleshooting

### Common Issues
- **Missing Points**: Check order completion events and points calculation
- **Tier Not Updated**: Verify tier calculation logic and spending thresholds
- **Redemption Failures**: Check reward inventory and customer point balance
- **Notification Issues**: Verify notification service integration and preferences

### Debug Procedures
1. Check loyalty service logs for customer-specific events
2. Verify order service integration and event publishing
3. Review points calculation rules and tier thresholds
4. Test reward redemption flow with debug mode
5. Analyze customer journey analytics for patterns

## Changelog

### Version 1.0 (2026-01-31)
- Initial loyalty and rewards customer journey documentation
- Complete points earning and redemption workflow
- Tier progression and referral program integration
- Comprehensive monitoring and analytics

## References

- [Loyalty Service Documentation](../../03-services/operational-services/loyalty-service.md)
- [Customer Service Integration](../../03-services/core-services/customer-service.md)
- [Order Service Integration](../../03-services/core-services/order-service.md)
- [Loyalty Program API](../../04-apis/loyalty-api.md)