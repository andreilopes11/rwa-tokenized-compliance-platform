# Monitoring and Observability

Monitoring strategy for VaultGuard RWA production systems.

## Monitoring Stack

| Component | Tool | Purpose |
|-----------|------|---------|
| Backend API | AWS CloudWatch | Logs, metrics, alarms |
| Frontend | Vercel Analytics | Web vitals, errors, performance |
| Database | Neon Dashboard | Query performance, connections |
| Blockchain | Alchemy Dashboard | RPC usage, transaction status |
| Uptime | External service (e.g., Pingdom) | Availability monitoring |

## Key Metrics

### Backend (CloudWatch)

**Health Metrics:**
- API response time (p50, p95, p99)
- Error rate (4xx, 5xx)
- Request rate (req/min)
- JVM memory usage
- Database connection pool

**Business Metrics:**
- KYC approvals/day
- Successful token transfers
- Oracle retry attempts
- ForceSync invocations
- Failed transactions

**Alarms:**
```
Critical:
- Error rate > 5% for 5 minutes
- p95 latency > 2000ms for 10 minutes
- Health check failing
- Database connection pool exhausted

Warning:
- Error rate > 2% for 10 minutes
- p95 latency > 1000ms for 15 minutes
- Memory usage > 80%
```

### Frontend (Vercel Analytics)

**Core Web Vitals:**
- LCP (Largest Contentful Paint) < 2.5s
- FID (First Input Delay) < 100ms
- CLS (Cumulative Layout Shift) < 0.1

**Error Tracking:**
- JavaScript errors
- Failed API calls
- Network timeouts

**User Metrics:**
- Page load time
- Time to interactive
- Route changes
- Bounce rate

### Database (Neon)

**Performance:**
- Query execution time
- Slow query log (> 1s)
- Connection count
- Cache hit ratio

**Capacity:**
- Storage used vs available
- Connection limit usage
- CPU and memory usage

### Blockchain (Alchemy)

**RPC Metrics:**
- Requests per second
- Rate limit usage (% of quota)
- Failed requests
- Average response time

**Transaction Monitoring:**
- Pending transactions
- Failed transactions
- Gas used vs estimated
- Reorg detection

## Logging Strategy

### Log Levels

```
ERROR:  Requires immediate action (e.g., oracle exhausted, DB down)
WARN:   Attention needed (e.g., retry attempt, high latency)
INFO:   Normal operations (e.g., KYC approved, offering created)
DEBUG:  Detailed diagnostics (local/staging only)
```

### Structured Logging

**Backend:**
```java
// Good: Structured with context
log.info("KYC approved", Map.of(
  "wallet", wallet,
  "admin", adminId,
  "identityHash", hash
));

// Bad: Unstructured
log.info("KYC approved for " + wallet);
```

**Log Aggregation:**
- CloudWatch Logs Insights for querying
- Export to S3 for long-term retention
- Consider ELK stack for advanced analysis

### Sensitive Data

**Never log:**
- Private keys
- Passwords
- JWT tokens (full)
- Raw PII (names, SSN, documents)

**Safe to log:**
- Wallet addresses (public)
- Identity hashes
- Transaction hashes
- User IDs (UUIDs)

## Audit Trail

### Events to Audit

| Event | Fields |
|-------|--------|
| KYC approval | Admin ID, wallet, timestamp, identity hash |
| KYC revocation | Admin ID, wallet, reason |
| Offering created | Admin ID, offering ID, visibility |
| Invite granted | Admin ID, offering ID, investor wallet |
| Oracle failure | Wallet, retry count, error |
| ForceSync | Initiator ID, approver ID, wallet, tx hash |
| Admin action | Admin ID, action type, target, timestamp |

### Audit Table Schema

```sql
CREATE TABLE audit_events (
  id UUID PRIMARY KEY,
  event_type VARCHAR(50) NOT NULL,
  actor_id UUID NOT NULL,
  target_type VARCHAR(50),
  target_id VARCHAR(100),
  details JSONB,
  ip_address INET,
  timestamp TIMESTAMP NOT NULL,
  INDEX idx_actor_timestamp (actor_id, timestamp),
  INDEX idx_event_type (event_type),
  INDEX idx_target (target_type, target_id)
);
```

### Audit Queries

```sql
-- Admin actions last 24h
SELECT event_type, COUNT(*)
FROM audit_events
WHERE actor_id = :admin_id
  AND timestamp > NOW() - INTERVAL '24 hours'
GROUP BY event_type;

-- ForceSync history
SELECT *
FROM audit_events
WHERE event_type = 'FORCE_SYNC'
ORDER BY timestamp DESC
LIMIT 50;

-- Failed oracle attempts
SELECT target_id AS wallet, details->>'error' AS error, COUNT(*)
FROM audit_events
WHERE event_type = 'ORACLE_FAILURE'
  AND timestamp > NOW() - INTERVAL '7 days'
GROUP BY wallet, error;
```

## Dashboards

### CloudWatch Dashboard

**Panels:**
1. API Health (response time, error rate)
2. Request Volume (req/min by endpoint)
3. Database Metrics (connections, query time)
4. JVM Metrics (heap, GC pauses)
5. Business KPIs (KYC approvals, transfers)
6. Alarms Status

### Vercel Dashboard

**Panels:**
1. Deployment Status
2. Core Web Vitals (LCP, FID, CLS)
3. Error Rate
4. Top Pages (traffic)
5. Geographic Distribution
6. Device Breakdown

### Custom Grafana (Optional)

```
Datasources:
- CloudWatch (backend metrics)
- PostgreSQL (audit queries)
- Prometheus (custom metrics)

Dashboards:
- System Health Overview
- Business Operations
- Security Events
- Blockchain Interactions
```

## Alerting

### Alert Channels

```
Critical → PagerDuty → On-call engineer
Warning  → Slack #ops-alerts
Info     → Email ops@vaultguard.com
```

### Alert Definitions

**Critical:**
```yaml
# API Down
Condition: Health check failing for 2 consecutive checks
Action: Page on-call, auto-scale if possible

# High Error Rate
Condition: 5xx errors > 5% for 5 minutes
Action: Page on-call, check logs

# Database Unavailable
Condition: Connection failures for 3 minutes
Action: Page on-call + DBA, check Neon status

# Oracle Exhausted
Condition: FAILED_ON_CHAIN event logged
Action: Page on-call, prepare ForceSync
```

**Warning:**
```yaml
# Elevated Error Rate
Condition: 4xx errors > 10% for 10 minutes
Action: Slack alert, investigate client issues

# High Latency
Condition: p95 > 1000ms for 15 minutes
Action: Slack alert, check DB + RPC performance

# RPC Rate Limit Warning
Condition: Alchemy usage > 80% of quota
Action: Slack alert, consider rate limiting or upgrade

# Low Disk Space
Condition: EB instance disk > 80% used
Action: Slack alert, plan cleanup or scale up
```

## Synthetic Monitoring

### Uptime Checks

```yaml
# Health Endpoint
URL: https://api.vaultguard.com/actuator/health
Interval: 1 minute
Expected: 200 OK, {"status":"UP"}
Alert: After 2 consecutive failures

# Frontend Load
URL: https://app.vaultguard.com
Interval: 5 minutes
Expected: 200 OK, page load < 3s
Alert: After 3 consecutive failures
```

### E2E Smoke Tests (Hourly)

```javascript
// Automated test runs every hour
describe('Production Smoke', () => {
  it('can login as investor', async () => {
    // Login with test account
    // Verify dashboard loads
    // Check marketplace accessible
  })
  
  it('can fetch offerings', async () => {
    // API call to /api/assets
    // Verify response time < 500ms
    // Check data structure
  })
  
  it('backend can reach blockchain', async () => {
    // Health check includes chain connectivity
    // Verify latest block number
  })
})
```

## Performance Monitoring

### Backend APM

**Traces to capture:**
- API request → response (full span)
- Database queries (individual)
- Blockchain RPC calls
- External API calls (KYC provider)

**Tools:**
- AWS X-Ray for distributed tracing
- Spring Boot Actuator for metrics
- Micrometer for custom metrics

### Frontend Performance

**Metrics:**
- Route change duration
- API call latency (from browser)
- Component render time
- Bundle size

**Tools:**
- Vercel Analytics
- Browser DevTools Performance
- Lighthouse CI in pipeline

### Database Query Analysis

```sql
-- Slow queries last 24h (via Neon)
SELECT query, calls, total_time, mean_time
FROM pg_stat_statements
WHERE mean_time > 1000  -- > 1 second
ORDER BY total_time DESC
LIMIT 20;

-- Missing indexes
SELECT schemaname, tablename, attname
FROM pg_stats
WHERE schemaname NOT IN ('pg_catalog', 'information_schema')
  AND n_distinct < 0  -- High cardinality
  AND correlation < 0.1;  -- Poor locality
```

## Incident Response Metrics

**MTTD (Mean Time to Detect):**
- Target: < 5 minutes
- Measure: Time from issue start to alert fired

**MTTI (Mean Time to Investigate):**
- Target: < 15 minutes
- Measure: Time from alert to root cause identified

**MTTR (Mean Time to Resolve):**
- Target: < 1 hour for critical, < 4 hours for major
- Measure: Time from alert to issue resolved

**Track via:**
```sql
CREATE TABLE incidents (
  id UUID PRIMARY KEY,
  severity VARCHAR(20),
  detected_at TIMESTAMP,
  investigated_at TIMESTAMP,
  resolved_at TIMESTAMP,
  root_cause TEXT,
  mttd_seconds INT GENERATED ALWAYS AS (EXTRACT(EPOCH FROM investigated_at - detected_at)) STORED,
  mtti_seconds INT GENERATED ALWAYS AS (EXTRACT(EPOCH FROM resolved_at - investigated_at)) STORED,
  mttr_seconds INT GENERATED ALWAYS AS (EXTRACT(EPOCH FROM resolved_at - detected_at)) STORED
);
```

## Capacity Planning

### Metrics to Track

**Backend:**
- Peak requests per minute
- Average response size
- Database connection pool usage
- Memory usage trend

**Database:**
- Storage growth rate (GB/month)
- Connection count trend
- Query execution time trend

**Blockchain:**
- RPC calls per day
- Gas usage per transaction
- Transaction volume trend

### Scaling Triggers

```yaml
# Auto-scaling rules
EB Backend:
  Min instances: 2
  Max instances: 10
  Scale up: CPU > 70% for 5 minutes
  Scale down: CPU < 30% for 10 minutes

# Manual review triggers
Database:
  Storage > 80% → Review data retention policy
  Connections > 80% → Consider connection pooling upgrade
  
RPC:
  Usage > 70% of plan → Upgrade Alchemy tier
```

## Related Documentation

- [Operational Runbooks](5-operational-runbooks.md)
- [Troubleshooting Guide](6-troubleshooting-guide.md)
- [Deployment Procedures](4-deployment-procedures.md)
</ARG>
```

Finalmente, vou atualizar o README do Execution Guide:

```tool
TOOL_NAME: multi_edit
BEGIN_ARG: filepath
"rwa-tokenized-compliance-platform\\Execution Guide\\README.md"