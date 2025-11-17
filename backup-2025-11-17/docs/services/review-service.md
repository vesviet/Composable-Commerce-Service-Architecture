# Review Service

## Description
Service that manages product reviews, ratings, and customer feedback.

## Core Responsibilities
- Product review and rating management
- Review moderation and approval workflow
- Review analytics and insights
- Customer feedback collection
- Review spam detection
- Review helpfulness voting

## Outbound Data
- Product reviews and ratings
- Review statistics and analytics
- Moderation status updates
- Customer feedback data
- Review helpfulness scores

## Consumers (Services that use this data)

### Product Service
- **Purpose**: Display product ratings and reviews
- **Data Received**: Average ratings, review counts, featured reviews

### Customer Service
- **Purpose**: Track customer review activity
- **Data Received**: Customer review history, reputation scores

### Search Service
- **Purpose**: Include ratings in search results
- **Data Received**: Product ratings, review counts

### Notification Service
- **Purpose**: Send review-related notifications
- **Data Received**: New review alerts, moderation updates

## Data Sources

### Order Service
- **Purpose**: Verify purchase for review authenticity
- **Data Received**: Purchase verification, order details

### Customer Service
- **Purpose**: Get customer information for reviews
- **Data Received**: Customer profiles, purchase history

### Product Service
- **Purpose**: Validate product information
- **Data Received**: Product details, availability status

## Main APIs
- `POST /reviews` - Submit new review
- `GET /reviews/product/{id}` - Get product reviews
- `GET /reviews/customer/{id}` - Get customer reviews
- `PUT /reviews/{id}/moderate` - Moderate review
- `POST /reviews/{id}/helpful` - Mark review as helpful
- `GET /reviews/analytics` - Get review analytics
- `DELETE /reviews/{id}` - Delete review

## Review Features
- Star rating system (1-5 stars)
- Written review with photos/videos
- Review verification (verified purchase)
- Review moderation workflow
- Spam and fake review detection
- Review helpfulness voting
- Review response from merchants

## Moderation & Quality Control
- Automated content filtering
- Manual review approval process
- Spam detection algorithms
- Inappropriate content flagging
- Review authenticity verification