# Product Reviews Customer Journey

**Version**: 1.0  
**Last Updated**: 2026-01-31  
**Category**: Customer Journey  
**Status**: Active

## Overview

Complete product review and rating customer journey covering review submission, moderation, helpful voting, and review-based product discovery to enhance customer trust and product selection confidence.

## Participants

### Primary Actors
- **Customer**: Submits reviews, rates products, votes on review helpfulness
- **Content Moderator**: Reviews and approves/rejects submitted reviews
- **Product Manager**: Monitors review quality and product feedback
- **Customer Service**: Handles review-related inquiries and disputes

### Systems/Services
- **Review Service**: Core review and rating management
- **Order Service**: Purchase verification for review eligibility
- **Catalog Service**: Product information and review integration
- **User Service**: Customer authentication and profile management
- **Notification Service**: Review-related communications
- **Analytics Service**: Review performance and sentiment analysis

## Prerequisites

### Business Prerequisites
- Customer has purchased and received the product
- Order status is "delivered" or "completed"
- Customer account is active and verified
- Review submission window is open (within 90 days of delivery)

### Technical Prerequisites
- Review service operational with moderation workflow
- Integration with order service for purchase verification
- Content moderation tools and rules configured
- Notification system for review communications

## Workflow Steps

### Main Flow: Complete Review Journey

1. **Review Eligibility Check**
   - **Actor**: Customer
   - **System**: Review Service
   - **Input**: Product ID, customer ID, order verification
   - **Output**: Review eligibility confirmed
   - **Duration**: 200-500ms

2. **Review Submission**
   - **Actor**: Customer
   - **System**: Review Service
   - **Input**: Rating, title, content, photos, pros/cons
   - **Output**: Review submitted for moderation
   - **Duration**: 2-5 seconds

3. **Automatic Content Moderation**
   - **Actor**: Review Service
   - **System**: Content moderation engine
   - **Input**: Review content, moderation rules
   - **Output**: Auto-moderation decision (approve/flag/reject)
   - **Duration**: 1-3 seconds

4. **Manual Moderation (if flagged)**
   - **Actor**: Content Moderator
   - **System**: Review Service
   - **Input**: Flagged review, moderation guidelines
   - **Output**: Manual moderation decision
   - **Duration**: 5-30 minutes

5. **Review Publication**
   - **Actor**: Review Service
   - **System**: Catalog Service integration
   - **Input**: Approved review, product association
   - **Output**: Review published and visible to customers
   - **Duration**: 1-2 seconds

6. **Review Discovery**
   - **Actor**: Other Customers
   - **System**: Review Service
   - **Input**: Product page visit, review filters
   - **Output**: Reviews displayed with ratings and sorting
   - **Duration**: 100-300ms

7. **Helpful Voting**
   - **Actor**: Customer
   - **System**: Review Service
   - **Input**: Review ID, helpful/not helpful vote
   - **Output**: Vote recorded, review helpfulness updated
   - **Duration**: 200-800ms

8. **Review Analytics**
   - **Actor**: Review Service
   - **System**: Analytics Service
   - **Input**: Review metrics, customer interactions
   - **Output**: Review performance analytics updated
   - **Duration**: 100-500ms

### Alternative Flow 1: Review Update Journey

**Trigger**: Customer wants to update their existing review
**Steps**:
1. Verify customer ownership of review
2. Check update eligibility (within 30 days)
3. Allow review content modification
4. Re-trigger moderation process if significant changes
5. Update published review with revision history
6. Notify customers who found review helpful

### Alternative Flow 2: Review Dispute Resolution

**Trigger**: Customer or business disputes review content
**Steps**:
1. Receive dispute report with reason
2. Flag review for manual investigation
3. Review dispute evidence and guidelines
4. Make dispute resolution decision
5. Take appropriate action (edit, remove, or maintain)
6. Notify all parties of resolution

### Alternative Flow 3: Incentivized Review Campaign

**Trigger**: Marketing campaign encourages reviews with rewards
**Steps**:
1. Identify eligible customers for review campaign
2. Send personalized review invitation with incentive
3. Track campaign participation and completion
4. Validate review quality and authenticity
5. Award incentives for approved reviews
6. Measure campaign effectiveness and ROI

### Error Handling

#### Error Scenario 1: Purchase Verification Failure
**Trigger**: Cannot verify customer purchased the product
**Impact**: Customer cannot submit review, potential frustration
**Resolution**:
1. Check order service connectivity and data
2. Provide manual verification option
3. Allow review submission with verification pending
4. Follow up with customer service for resolution
5. Update verification logic if systematic issue

#### Error Scenario 2: Content Moderation System Down
**Trigger**: Automatic moderation service unavailable
**Impact**: Reviews cannot be processed, submission delays
**Resolution**:
1. Queue reviews for processing when service recovers
2. Implement basic keyword filtering as fallback
3. Route all reviews to manual moderation temporarily
4. Notify customers of potential delays
5. Scale manual moderation team if needed

#### Error Scenario 3: Review Spam Attack
**Trigger**: Unusual volume of fake or spam reviews detected
**Impact**: Review quality degraded, customer trust affected
**Resolution**:
1. Implement enhanced spam detection rules
2. Temporarily increase moderation strictness
3. Flag suspicious review patterns for investigation
4. Remove confirmed fake reviews in bulk
5. Strengthen account verification requirements

## Business Rules

### Review Eligibility Rules
- **Purchase Requirement**: Customer must have purchased the product
- **Delivery Confirmation**: Order must be delivered or completed
- **Time Window**: Reviews accepted within 90 days of delivery
- **One Review Per Product**: One review per customer per product
- **Account Standing**: Customer account must be in good standing

### Content Guidelines
- **Rating Scale**: 1-5 stars with half-star increments
- **Title Length**: 5-200 characters required
- **Content Length**: 10-2000 characters required
- **Photo Limit**: Maximum 5 photos per review
- **Language Policy**: Reviews in Vietnamese or English only

### Moderation Rules
- **Auto-Approval**: Reviews with low risk score (< 30 points)
- **Manual Review**: Reviews with medium risk score (30-70 points)
- **Auto-Rejection**: Reviews with high risk score (> 70 points)
- **Profanity Filter**: Automatic detection and flagging
- **Spam Detection**: AI-powered spam and fake review detection

## Integration Points

### Service Integrations
| Service | Integration Type | Purpose | Error Handling |
|---------|------------------|---------|----------------|
| Order Service | Synchronous gRPC | Purchase verification | Retry with timeout |
| Catalog Service | Synchronous gRPC | Product information | Cache fallback |
| User Service | Synchronous gRPC | Customer authentication | Session validation |
| Notification Service | Asynchronous Event | Review notifications | Dead letter queue |
| Analytics Service | Asynchronous Event | Review metrics | Best effort delivery |

### External Integrations
| External System | Integration Type | Purpose | SLA |
|-----------------|------------------|---------|-----|
| Content Moderation API | REST API | Automated content filtering | 99% availability |
| Image Processing | REST API | Photo moderation | 95% availability |

## Performance Requirements

### Response Times
- Review submission: < 3 seconds (P95)
- Review display: < 300ms (P95)
- Helpful voting: < 1 second (P95)
- Moderation decision: < 5 seconds (automated)

### Throughput
- Peak review submissions: 500 per minute
- Average review display: 10,000 per minute
- Concurrent helpful votes: 1,000 per minute

### Availability
- Target uptime: 99.9%
- Review submission success rate: > 98%
- Review display success rate: > 99.5%

## Monitoring & Metrics

### Key Metrics
- **Review Submission Rate**: Reviews submitted per product/order
- **Review Approval Rate**: Percentage of reviews approved after moderation
- **Review Helpfulness**: Average helpful votes per review
- **Review Response Time**: Time from submission to publication
- **Customer Engagement**: Review reading and interaction rates

### Alerts
- **Critical**: Review service response time > 5 seconds
- **Critical**: Review approval rate < 80%
- **Warning**: Unusual spike in review submissions
- **Info**: High-quality review milestone reached

### Dashboards
- Real-time review submission and moderation dashboard
- Review quality and customer engagement dashboard
- Product review performance dashboard
- Review sentiment and business impact dashboard

## Testing Strategy

### Test Scenarios
1. **Complete Review Flow**: End-to-end review submission and publication
2. **Moderation Testing**: Various content types and moderation decisions
3. **Helpful Voting**: Review helpfulness and ranking scenarios
4. **Spam Detection**: Fake review and spam prevention testing
5. **High Load**: Concurrent review submissions and display

### Test Data
- Customer profiles with various purchase histories
- Product catalog with different categories
- Sample review content (positive, negative, neutral)
- Spam and fake review examples

## Troubleshooting

### Common Issues
- **Review Not Appearing**: Check moderation status and approval process
- **Purchase Verification Failed**: Verify order service integration
- **Slow Review Loading**: Check database performance and caching
- **Moderation Delays**: Review moderation queue and staff capacity

### Debug Procedures
1. Check review service logs for submission and processing
2. Verify order service integration and purchase data
3. Review moderation queue and processing times
4. Test content moderation rules and accuracy
5. Analyze review display performance and caching

## Changelog

### Version 1.0 (2026-01-31)
- Initial product reviews customer journey documentation
- Complete review submission and moderation workflow
- Helpful voting and review discovery features
- Comprehensive quality control and spam prevention

## References

- [Review Service Documentation](../../03-services/operational-services/review-service.md)
- [Order Service Integration](../../03-services/core-services/order-service.md)
- [Catalog Service Integration](../../03-services/core-services/catalog-service.md)
- [Review API Specification](../../04-apis/review-api.md)