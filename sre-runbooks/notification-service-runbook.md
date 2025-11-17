# Notification Service - SRE Runbook

**Service:** Notification Service  
**Port:** 8009 (HTTP), 9009 (gRPC)  
**Health Check:** `GET /health`  
**Last Updated:** 2025-11-17

## Quick Health Check

```bash
# Check service status
curl http://localhost:8009/health

# Expected response:
# {"status":"ok","service":"notification","version":"1.0.0"}
```

## Common Issues & Quick Fixes

### Issue 1: Email Not Sending

**Symptoms:**
- Emails not delivered
- Email sending failures

**Diagnosis:**
```bash
# Check service logs
docker compose logs notification-service | grep "email"

# Check email provider connectivity
docker compose logs notification-service | grep "SMTP\|SendGrid\|Mailgun"

# Check email queue
docker compose exec postgres psql -U notification_user -d notification_db -c "SELECT * FROM notifications WHERE channel = 'email' AND status = 'PENDING' LIMIT 10;"
```

**Fix:**
1. Verify email provider credentials (SendGrid, Mailgun, etc.):
   ```bash
   # Test SMTP connection
   telnet smtp.sendgrid.net 587
   ```

2. Check email provider status (SendGrid status page)

3. Retry failed emails:
   ```bash
   curl -X POST http://localhost:8009/api/v1/notifications/retry-failed
   ```

### Issue 2: SMS Not Sending

**Symptoms:**
- SMS messages not delivered
- SMS sending failures

**Diagnosis:**
```bash
# Check SMS logs
docker compose logs notification-service | grep "SMS\|Twilio"

# Check SMS provider connectivity
curl https://api.twilio.com/2010-04-01/Accounts

# Check SMS queue
docker compose exec postgres psql -U notification_user -d notification_db -c "SELECT * FROM notifications WHERE channel = 'sms' AND status = 'PENDING' LIMIT 10;"
```

**Fix:**
1. Verify SMS provider credentials (Twilio, etc.)

2. Check SMS provider account balance

3. Verify phone number format

### Issue 3: Push Notification Failures

**Symptoms:**
- Push notifications not delivered
- FCM/APNS errors

**Diagnosis:**
```bash
# Check push notification logs
docker compose logs notification-service | grep "push\|FCM\|APNS"

# Check FCM connectivity
curl -X POST https://fcm.googleapis.com/fcm/send
```

**Fix:**
1. Verify FCM/APNS credentials

2. Check device token validity

3. Verify notification payload format

## Recovery Steps

### Retry Failed Notifications

```bash
# Retry all failed notifications
curl -X POST http://localhost:8009/api/v1/notifications/retry-failed

# Retry specific notification
curl -X POST http://localhost:8009/api/v1/notifications/NOTIFICATION-ID/retry
```

### Database Recovery

```bash
# Backup database
docker compose exec postgres pg_dump -U notification_user notification_db > notification_backup.sql

# Restore from backup
docker compose exec -T postgres psql -U notification_user notification_db < notification_backup.sql
```

## Monitoring & Alerts

### Key Metrics
- `notifications_sent_total` - Total notifications sent
- `notifications_failed_total` - Failed notifications
- `email_sent_total` - Emails sent
- `sms_sent_total` - SMS sent
- `push_sent_total` - Push notifications sent
- `notification_delivery_duration_seconds` - Delivery latency

### Alert Thresholds
- **Email delivery failure > 10%**: Critical
- **SMS delivery failure > 5%**: Warning
- **Push notification failure > 15%**: Warning
- **Notification queue size > 1000**: Warning

## Database Maintenance

### Cleanup Old Notifications

```sql
-- Archive notifications older than 90 days
INSERT INTO notifications_archive 
SELECT * FROM notifications 
WHERE created_at < NOW() - INTERVAL '90 days';

DELETE FROM notifications 
WHERE created_at < NOW() - INTERVAL '90 days';
```

## Emergency Contacts

- **On-Call Engineer**: Check PagerDuty
- **Notification Team Lead**: notification-team@company.com
- **Email Provider Support**: SendGrid/Mailgun support

## Logs Location

```bash
# View notification service logs
docker compose logs -f notification-service

# Search for errors
docker compose logs notification-service | grep ERROR

# Filter by notification type
docker compose logs notification-service | grep "email\|sms\|push"
```

