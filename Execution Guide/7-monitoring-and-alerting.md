# Monitoring and Alerting Guide

Comprehensive monitoring setup for VaultGuard RWA production environment across all three tiers.

## Monitoring Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Monitoring Stack                         │
├─────────────────────────────────────────────────────────────┤
│  CloudWatch     │  Vercel Analytics  │  Alchemy Dashboard   │
│  (Backend/AWS)  │  (Frontend)        │  (Blockchain)        │
└─────────────────────────────────────────────────────────────┘
         ↓                 ↓                      ↓
┌─────────────────────────────────────────────────────────────┐
│              Alerting & Incident Response                   │
│  PagerDuty / Slack / Email / SMS                            │
└─────────────────────────────────────────────────────────────┘
```

## 1. Backend Monitoring (AWS CloudWatch)

### Key Metrics

**Application Health:**
- `/actuator/health` endpoint availability (target: 99.9%)
- API response time p50/p95/p99 (target: p95 < 500ms)
- Error rate (target: < 0.1%)
- Request throughput (requests/minute)

**Infrastructure:**
- EC2 instance CPU utilization (alert: > 80%)
- Memory usage (alert: > 85%)
- Disk usage (alert: > 80%)
- Network I/O

**Database (Neon PostgreSQL):**
- Connection pool utilization (alert: > 90%)
- Query execution time (alert: p95 > 1s)
- Active connections count
- Database size growth rate

**Blockchain Integration:**
- RPC call success rate (target: > 99%)
- Transaction confirmation time (target: < 5min for Sepolia)
- Oracle worker queue depth (alert: > 100 pending)
- Failed on-chain writes (alert: any occurrence)

### CloudWatch Log Groups

```bash
# Application logs
/aws/elasticbeanstalk/vaultguard-production/application.log

# Web server logs
/aws/elasticbeanstalk/vaultguard-production/web.log

# Custom metrics
VaultGuard/API/RequestCount
VaultGuard/API/Latency
VaultGuard/Oracle/RetryCount
VaultGuard/Oracle/FailureCount
```

### CloudWatch Alarms

```yaml
Alarms:
  HighErrorRate:
    Metric: HTTPCode_Backend_5XX
    Threshold: 10 errors in 5 minutes
    Action: SNS -> PagerDuty
    
  HighLatency:
    Metric: TargetResponseTime
    Threshold: p95 > 1000ms for 3 datapoints
    Action: SNS -> Slack
    
  DatabaseConnectionFailure:
    Metric: Custom/DB/ConnectionFailures
    Threshold: > 0 in 1 minute
    Action: SNS -> PagerDuty (critical)
    
  OracleWorkerStalled:
    Metric: Custom/Oracle/QueueDepth
    Threshold: > 100 for 10 minutes
    Action: SNS -> Slack + PagerDuty
    
  DiskSpaceLow:
    Metric: DiskSpaceUtilization
    Threshold: > 80%
    Action: SNS -> Email
```

### Custom Metrics Publishing

**Spring Boot Micrometer integration:**

```java
// In application.yml
management:
  metrics:
    export:
      cloudwatch:
        namespace: VaultGuard
        batch-size: 20
        step: 1m

// Custom metrics in code
@Component
public class OracleMetrics {
    private final MeterRegistry registry;
    
    public void recordOracleRetry() {
        registry.counter("oracle.retry.count").increment();
    }
    
    public void recordOracleFailure() {
        registry.counter("oracle.failure.count").increment();
    }
}
```

## 2. Frontend Monitoring (Vercel Analytics)

### Core Web Vitals

- **LCP (Largest Contentful Paint)**: Target < 2.5s
- **FID (First Input Delay)**: Target < 100ms
- **CLS (Cumulative Layout Shift)**: Target < 0.1
- **TTFB (Time to First Byte)**: Target < 600ms

### Custom Events

```typescript
// Track critical user journeys
import { track } from '@vercel/analytics';

// KYC submission
track('kyc_submitted', {
  wallet: truncatedWallet,
  timestamp: Date.now()
});

// Offering subscription
track('subscription_initiated', {
  offeringId: id,
  amount: amount
});

// Transfer preflight
track('transfer_preflight', {
  success: result.success,
  errorCode: result.errorCode
});
```

### Error Tracking

```typescript
// In error boundary or API error handler
import { track } from '@vercel/analytics';

track('error', {
  type: 'api_error',
  endpoint: endpoint,
  status: response.status,
  message: safeErrorMessage
});
```

### Alerts Configuration

**Vercel Dashboard → Project → Analytics → Alerts:**

- Error rate > 1% (5min window)
- 4xx rate > 5% (5min window)
- 5xx rate > 0.5% (5min window)
- Build failure
- Deployment failure

## 3. Blockchain Monitoring (Alchemy Dashboard)

### RPC Metrics

- **Request rate**: Track against rate limits
- **Response time**: Target < 200ms
- **Error rate**: Target < 0.1%
- **Compute units used**: Monitor quota consumption

### Transaction Monitoring

```typescript
// In backend BlockchainGateway
public async monitorTransaction(txHash: string) {
  const maxAttempts = 30; // 5 minutes with 10s intervals
  
  for (let i = 0; i < maxAttempts; i++) {
    const receipt = await provider.getTransactionReceipt(txHash);
    
    if (receipt) {
      metrics.recordTransactionConfirmation({
        txHash,
        confirmations: receipt.confirmations,
        gasUsed: receipt.gasUsed.toString(),
        status: receipt.status
      });
      
      if (receipt.status === 0) {
        alerting.sendAlert('Transaction failed', {
          txHash,
          blockNumber: receipt.blockNumber
        });
      }
      
      return receipt;
    }
    
    await sleep(10000);
  }
  
  metrics.recordTransactionTimeout(txHash);
  alerting.sendAlert('Transaction timeout', { txHash });
}
```

### Smart Contract Events

Monitor emitted events for anomalies:

```solidity
// Events to monitor
event IdentityRegistered(address indexed wallet, bytes32 identityHash);
event IdentityRemoved(address indexed wallet);
event Transfer(address indexed from, address indexed to, uint256 amount);
event Paused(address indexed by);
event ComplianceCheckFailed(address indexed from, address indexed to);
```

**Alert conditions:**
- Unexpected `Paused` event
- High rate of `ComplianceCheckFailed` (> 10/hour)
- `IdentityRemoved` without corresponding backend audit event

## 4. Database Monitoring (Neon Console)

### Key Metrics

- **Connections**: Active vs available
- **Storage**: Used vs provisioned
- **Compute**: CPU and memory usage
- **Query performance**: Slow query log

### Neon Dashboard Alerts

Configure in Neon Console → Project → Settings → Alerts:

```yaml
Alerts:
  - Storage > 80%: Email to ops@vaultguard.com
  - Connection limit > 90%: PagerDuty
  - Compute hours approaching limit: Email
  - Slow query detected (> 5s): Slack notification
```

### Query Performance Monitoring

```sql
-- Enable pg_stat_statements extension
CREATE EXTENSION IF NOT EXISTS pg_stat_statements;

-- View slow queries
SELECT 
  query,
  calls,
  total_exec_time / calls as avg_time_ms,
  mean_exec_time,
  max_exec_time
FROM pg_stat_statements
WHERE mean_exec_time > 100  -- queries averaging > 100ms
ORDER BY mean_exec_time DESC
LIMIT 20;

-- Monitor connection pool
SELECT 
  count(*) as active_connections,
  state,
  wait_event_type
FROM pg_stat_activity
WHERE datname = 'vaultguard'
GROUP BY state, wait_event_type;
```

## 5. Alerting Rules

### Severity Levels

| Level | Response Time | Escalation | Examples |
|-------|--------------|------------|----------|
| **P1 - Critical** | 15 minutes | Immediate PagerDuty | Service down, data loss, security breach |
| **P2 - High** | 1 hour | PagerDuty during business hours | High error rate, oracle stalled |
| **P3 - Medium** | 4 hours | Slack notification | Elevated latency, resource warning |
| **P4 - Low** | Next business day | Email | Informational metrics, capacity planning |

### Alert Routing

```yaml
Routing:
  Critical:
    - PagerDuty: on-call engineer
    - Slack: #vaultguard-incidents
    - SMS: engineering lead
    
  High:
    - PagerDuty: business hours only
    - Slack: #vaultguard-alerts
    
  Medium:
    - Slack: #vaultguard-monitoring
    
  Low:
    - Email: ops@vaultguard.com
```

## 6. Dashboards

### CloudWatch Dashboard (Backend)

**URL**: AWS Console → CloudWatch → Dashboards → VaultGuard-Production

**Widgets:**
1. **Health Check Status** (line graph, 5min intervals)
2. **API Latency** (p50/p95/p99, 1min intervals)
3. **Error Rate** (4xx/5xx breakdown, 5min intervals)
4. **Request Throughput** (requests/minute)
5. **Database Connections** (active vs max)
6. **Oracle Queue Depth** (pending identities)
7. **EC2 CPU/Memory** (% utilization)
8. **RPC Call Success Rate** (%)

### Vercel Dashboard (Frontend)

**URL**: Vercel Dashboard → Project → Analytics

**Tabs:**
1. **Overview**: Traffic, errors, performance
2. **Web Vitals**: LCP, FID, CLS trends
3. **Custom Events**: User journey tracking
4. **Real User Monitoring**: Geographic distribution

### Alchemy Dashboard (Blockchain)

**URL**: Alchemy Dashboard → App → Metrics

**Tabs:**
1. **Requests**: Rate, response time, errors
2. **Compute Units**: Usage vs quota
3. **Methods**: eth_call, eth_sendTransaction breakdown
4. **Webhooks**: Activity log (if configured)

## 7. Incident Response Integration

### PagerDuty Configuration

```yaml
Services:
  VaultGuard-Backend:
    escalation_policy: Backend-OnCall
    urgency: high
    alert_grouping: intelligent
    
  VaultGuard-Blockchain:
    escalation_policy: Backend-OnCall
    urgency: high
    
  VaultGuard-Frontend:
    escalation_policy: Frontend-OnCall
    urgency: low
```

### Slack Integration

```yaml
Channels:
  #vaultguard-incidents:
    - P1/P2 alerts
    - Incident status updates
    - Postmortem links
    
  #vaultguard-alerts:
    - P3 alerts
    - Deployment notifications
    - Health check summaries
    
  #vaultguard-monitoring:
    - P4 alerts
    - Daily metric summaries
    - Capacity planning reports
```

## 8. Regular Health Checks

### Automated Checks (Every 5 minutes)

```bash
#!/bin/bash
# healthcheck.sh

# Backend health
curl -f https://api.vaultguard.com/actuator/health/readiness || exit 1

# Frontend availability
curl -f https://app.vaultguard.com || exit 1

# Database connectivity (via backend)
curl -f https://api.vaultguard.com/actuator/health/db || exit 1

# Blockchain RPC (via backend)
curl -f https://api.vaultguard.com/actuator/health/blockchain || exit 1
```

### Manual Weekly Checks

- [ ] Review CloudWatch dashboard for anomalies
- [ ] Check Neon storage growth rate
- [ ] Review failed blockchain transactions
- [ ] Verify backup completion (if configured)
- [ ] Check Alchemy rate limit headroom
- [ ] Review error logs for patterns

### Monthly Reviews

- [ ] Analyze p95 latency trends
- [ ] Review capacity planning metrics
- [ ] Update alert thresholds based on growth
- [ ] Test alerting system (send test alerts)
- [ ] Audit access logs for anomalies
- [ ] Review and update runbooks

## 9. Troubleshooting Common Alerts

### "High Error Rate"

1. Check CloudWatch logs for stack traces
2. Identify failing endpoint from metrics
3. Review recent deployments (rollback if needed)
4. Check database connectivity
5. Verify RPC provider status

### "Oracle Worker Stalled"

1. Check oracle worker logs in CloudWatch
2. Verify RPC connectivity to blockchain
3. Check for pending transactions (nonce conflicts)
4. Review database for APPROVED_PENDING_CHAIN records
5. Consider manual ForceSync if persistent

### "Database Connection Failure"

1. Check Neon Console for outages
2. Verify connection string in EB environment
3. Check connection pool exhaustion
4. Review slow queries (may be blocking connections)
5. Restart application if connection pool corrupted

### "Transaction Timeout"

1. Check Alchemy/Infura status page
2. Verify gas price settings (may be too low)
3. Check transaction on Etherscan
4. Review nonce management (potential conflicts)
5. Retry transaction with higher gas if stuck

## Next Steps

- **Operational runbooks**: [5-operational-runbooks.md](5-operational-runbooks.md)
- **Incident response**: [6-troubleshooting-guide.md](6-troubleshooting-guide.md)
- **Deployment procedures**: [4-deployment-procedures.md](4-deployment-procedures.md)
</contents>