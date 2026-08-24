# Operational Runbooks

Step-by-step procedures for common operational tasks and incident response.

## Table of Contents

1. [KYC Approval Operations](#kyc-approval-operations)
2. [Oracle Recovery (ForceSync)](#oracle-recovery-forcesync)
3. [Offering Lifecycle Management](#offering-lifecycle-management)
4. [Emergency Pause Procedures](#emergency-pause-procedures)
5. [User Access Issues](#user-access-issues)
6. [Database Operations](#database-operations)
7. [Blockchain Transaction Issues](#blockchain-transaction-issues)
8. [Performance Degradation](#performance-degradation)

---

## KYC Approval Operations

### Standard KYC Approval Flow

**When:** Investor submits KYC documents  
**Who:** SUPER_ADMIN  
**Duration:** 5-15 minutes (plus oracle processing time)

#### Step 1: Review KYC Submission

```
1. Login to /governance workspace
2. Navigate to KYC Queue
3. Select pending submission
4. Review:
   - Identity documents (passport, driver's license)
   - Proof of address
   - Sanctions check results
   - Accreditation status (if required)
```

#### Step 2: Approve or Reject

**If approving:**
```
1. Click "Approve" button
2. Confirm action in modal
3. Status changes to APPROVED_PENDING_CHAIN
4. Oracle worker picks up approval automatically
5. Monitor oracle status (should complete in <5 min)
6. Status changes to APPROVED when on-chain verified
```

**If rejecting:**
```
1. Click "Reject" button
2. Enter rejection reason
3. Confirm action
4. Status changes to REJECTED
5. Investor receives notification (can resubmit)
```

#### Step 3: Verify On-Chain Registration

```bash
# Query backend for identity status
curl -X GET $BACKEND_URL/api/admin/investors/$WALLET/compliance-profile \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Check response:
# {
#   "status": "APPROVED",
#   "onChainVerified": true,
#   "transactionHash": "0x...",
#   "verifiedAt": "2026-08-22T15:30:00Z"
# }
```

**Expected timeline:**
- Approval: Immediate
- Oracle pickup: <30 seconds
- Transaction submit: <2 minutes
- Block confirmation: 1-3 minutes (Sepolia)
- Total: 3-6 minutes typical

#### Troubleshooting

**Status stuck at APPROVED_PENDING_CHAIN:**
1. Check oracle worker logs
2. Verify RPC connectivity
3. Check admin account has sufficient ETH for gas
4. If >15 minutes, proceed to ForceSync

**Transaction reverted:**
1. Check if wallet already registered
2. Verify compliance agent has registerIdentity permission
3. Check IdentityRegistry contract not paused
4. Review transaction revert reason in block explorer

---

## Oracle Recovery (ForceSync)

### When to Use ForceSync

**Indicators:**
- KYC status stuck at APPROVED_PENDING_CHAIN for >15 minutes
- Oracle retry exhausted (status = FAILED_ON_CHAIN)
- RPC provider outage during approval window
- Nonce mismatch preventing transaction broadcast

**Prerequisites:**
- Two distinct SUPER_ADMIN accounts (A and B)
- Admin A and B both have access to /governance
- HSM/KMS signing configured (production)
- Incident documented before starting

### Step 1: Initiate ForceSync (Admin A)

```
1. Login to /governance as Admin A
2. Navigate to Oracle Health → ForceSync
3. Search for failed identity by wallet address
4. Click "Initiate ForceSync"
5. Review details:
   - Wallet address
   - Identity hash
   - Country code
   - Original approval timestamp
6. Enter justification: "Oracle retry exhausted after RPC timeout"
7. Confirm initiation
8. Status: FORCE_SYNC_INITIATED
9. Note ForceSync request ID
```

### Step 2: Approve ForceSync (Admin B)

**Important:** Admin B ≠ Admin A (different user accounts)

```
1. Login to /governance as Admin B (different account)
2. Navigate to Oracle Health → ForceSync → Pending Approvals
3. Review ForceSync request:
   - Request ID
   - Initiator (should be Admin A)
   - Wallet address
   - Justification
   - Timestamp
4. Verify:
   - Legitimate failure (check logs)
   - Correct wallet address
   - Identity hash matches KYC record
5. Click "Approve ForceSync"
6. Enter second approval justification
7. Confirm approval
8. System submits transaction via HSM/KMS
9. Wait for confirmation (1-3 minutes)
10. Status changes to APPROVED with onChainVerified=true
```

### Step 3: Verify Recovery

```bash
# Check on-chain verification
curl -X GET $BACKEND_URL/api/admin/investors/$WALLET/compliance-profile \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Verify blockchain transaction
curl -X GET $BACKEND_URL/api/admin/blockchain-transactions/$TX_HASH \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Check audit trail
curl -X GET $BACKEND_URL/api/admin/audit/force-sync/$REQUEST_ID \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

### Step 4: Document Incident

```markdown
## ForceSync Incident Report

**Date:** 2026-08-22 15:30 UTC
**Request ID:** FS-12345
**Wallet:** 0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb

**Root Cause:**
Alchemy RPC timeout during oracle retry window. Bounded retry exhausted after 5 attempts with exponential backoff.

**Initiator:** admin-a@vaultguard.com
**Approver:** admin-b@vaultguard.com
**Transaction:** 0xabcd...1234
**Resolution Time:** 18 minutes from failure to recovery

**Actions Taken:**
1. Verified RPC status (restored after 10 min outage)
2. Initiated ForceSync with four-eyes approval
3. Identity registered successfully via HSM signer
4. Investor notified of resolution

**Prevention:**
- Consider secondary RPC failover
- Increase oracle retry window during known RPC instability
- Add alerting for pending-chain duration >10 min
```

---

## Offering Lifecycle Management

### Creating a New Offering

**Who:** SUPER_ADMIN  
**Duration:** 15-30 minutes (including contract deployment)

#### Step 1: Draft Offering

```
1. Login to /governance
2. Navigate to Offerings → Create New
3. Fill offering details:
   - Name: "Real Estate Fund Series A"
   - Symbol: "REFSA"
   - Description: "..."
   - Minimum Investment: $10,000
   - Maximum Investment: $1,000,000
   - Total Supply: 1,000,000 tokens
   - Visibility: PUBLIC or PRIVATE
4. Upload legal documents
5. Save as DRAFT
6. Status: DRAFT (not visible in marketplace)
```

#### Step 2: Review and Publish

```
1. Review DRAFT offering details
2. Verify legal documents uploaded
3. Click "Publish Offering"
4. Confirm publication
5. System deploys T-REX token suite:
   - Token contract
   - ModularCompliance contract
   - Links to shared IdentityRegistry
6. Wait for deployment confirmation (2-5 minutes)
7. Status changes to ACTIVE
8. Contract addresses recorded
9. Offering visible in marketplace (if PUBLIC)
```

**Deployment transaction flow:**
```
Deploy Token → Deploy ModularCompliance → Link to IR → Set compliance rules → Transfer ownership
```

#### Step 3: Configure Compliance Rules (Optional)

```
1. Navigate to Offering → Compliance Settings
2. Configure modules:
   - Max holders: 500
   - Max balance per holder: 100,000 tokens
   - Transfer restrictions: None (or add rules)
3. Save compliance configuration
4. Rules enforce at transfer time
```

### Managing Private Offering Access

**Scenario:** Grant investor access to PRIVATE offering

#### Step 1: Grant Invite

```
1. Navigate to Offering → Access Control
2. Click "Grant Invite"
3. Enter investor details:
   - Wallet address: 0x...
   - OR Identity hash: 0x...
4. Confirm grant
5. Investor added to allowlist
6. Offering now visible to investor
```

#### Step 2: Revoke Invite (if needed)

```
1. Navigate to Offering → Access Control
2. Find investor in granted list
3. Click "Revoke Access"
4. Confirm revocation
5. Offering hidden from investor marketplace
6. Note: Does not affect existing positions
```

### Pausing an Offering

**When:** Security incident, regulatory issue, or emergency

```
1. Navigate to Offering → Actions
2. Click "Pause Offering"
3. Enter pause reason: "Security review in progress"
4. Confirm pause
5. System calls token.pause()
6. Wait for transaction confirmation
7. Status: PAUSED
8. Effects:
   - All transfers blocked
   - Subscribe/redeem disabled
   - Marketplace shows "Paused" badge
```

### Unpausing an Offering

```
1. Verify issue resolved
2. Navigate to Offering → Actions
3. Click "Unpause Offering"
4. Enter unpause justification
5. Confirm unpause
6. System calls token.unpause()
7. Status: ACTIVE
8. Normal operations resume
```

### Closing an Offering

**When:** Offering lifecycle complete, redemption period ended

```
1. Navigate to Offering → Actions
2. Click "Close Offering"
3. Confirm closure
4. Status: CLOSED
5. Effects:
   - No new subscriptions
   - Existing positions maintain
   - Transfers still allowed (if not paused)
   - Marketplace shows "Closed" badge
```

---

## Emergency Pause Procedures

### Scenario: Security Incident Detected

**Severity:** High  
**Response Time:** Immediate (<5 minutes)

#### Immediate Actions

```
1. Identify affected offering(s)
2. Login to /governance (all available admins)
3. Navigate to Emergency → Pause All (if multiple offerings)
   OR Offering → Pause (if single offering)
4. Enter incident ID and description
5. Confirm mass pause
6. Verify all offerings show PAUSED status
7. Verify blockchain transactions confirmed
```

#### Communication

```
1. Post status page update: "Service temporarily paused for maintenance"
2. Email admins: "Emergency pause activated - [Incident ID]"
3. Do NOT disclose security details publicly until patched
4. Notify legal/compliance team
```

#### Investigation

```
1. Review audit logs for suspicious activity
2. Check blockchain transactions for anomalies
3. Verify authorization checks not bypassed
4. Check for compromised admin accounts
5. Review error logs for attack patterns
```

#### Resolution

```
1. Identify and fix root cause
2. Deploy patch if code issue
3. Rotate credentials if compromise suspected
4. Test fix in staging environment
5. Document incident fully
6. Unpause offerings one at a time
7. Monitor closely for 24 hours
8. Post-incident review within 48 hours
```

---

## User Access Issues

### Investor Cannot See Offering

**Symptoms:** Investor reports offering missing from marketplace

#### Diagnosis

```sql
-- Check offering status and visibility
SELECT id, name, status, visibility, created_by
FROM asset_offerings
WHERE id = ?;

-- Check if investor is invited (if PRIVATE)
SELECT *
FROM marketplace_acl
WHERE asset_id = ? AND (identity_hash = ? OR wallet_address = ?);

-- Check if investor has position (contracted)
SELECT *
FROM investor_positions
WHERE asset_id = ? AND wallet_address = ?;
```

#### Resolution

**If offering is PRIVATE and investor not invited:**
```
1. Verify investor should have access
2. Grant invite via /governance → Offering → Access Control
3. Confirm offering now visible to investor
```

**If offering is DRAFT or CLOSED:**
```
1. Explain to investor: "Offering not currently active"
2. If should be active, publish offering
```

**If offering is PUBLIC ACTIVE but investor can't see:**
```
1. Check investor role (must be INVESTOR not SUPER_ADMIN)
2. Verify JWT token valid
3. Check browser cache (clear and retry)
4. Review backend logs for query errors
```

### Investor Cannot Subscribe

**Symptoms:** Subscribe button disabled or returns error

#### Diagnosis

```bash
# Check KYC status
curl -X GET $BACKEND_URL/api/investors/$WALLET/kyc-status \
  -H "Authorization: Bearer $TOKEN"

# Expected for subscribe:
# {
#   "status": "APPROVED",
#   "onChainVerified": true
# }
```

#### Resolution

**If status is APPROVED_PENDING_CHAIN:**
```
1. Check oracle worker status
2. If >15 min, initiate ForceSync (see above)
3. Notify investor of pending blockchain confirmation
```

**If status is SUBMITTED or IN_REVIEW:**
```
1. Expedite KYC review if appropriate
2. Notify investor: "KYC approval in progress"
```

**If status is APPROVED but onChainVerified=false:**
```
1. Check blockchain_transactions table for failed tx
2. Retry oracle write or ForceSync
3. Verify IdentityRegistry contract accessible
```

**If not linked to offering:**
```
1. Verify offering is PUBLIC or investor invited
2. Grant invite if PRIVATE and investor eligible
```

---

## Database Operations

### Backup and Restore

**Neon PostgreSQL automatic backups:**
```
1. Navigate to Neon dashboard
2. Select project → Backups
3. Backups taken automatically every 24h
4. Point-in-time recovery available (last 7 days)
```

**Manual backup:**
```bash
pg_dump -h $NEON_HOST -U $NEON_USER -d vaultguard > backup_$(date +%Y%m%d).sql
```

**Restore from backup:**
```bash
psql -h $NEON_HOST -U $NEON_USER -d vaultguard < backup_20260822.sql
```

### Common Queries

**Find user by email:**
```sql
SELECT id, email, role, created_at
FROM users
WHERE email = 'investor@example.com';
```

**Check KYC status:**
```sql
SELECT wallet_address, status, on_chain_verified, approved_at
FROM kyc_requests
WHERE wallet_address = '0x...';
```

**List offerings by admin:**
```sql
SELECT id, name, status, visibility
FROM asset_offerings
WHERE created_by = 'admin-123'
ORDER BY created_at DESC;
```

**Audit trail for specific action:**
```sql
SELECT event_type, user_id, resource_type, resource_id, created_at
FROM audit_events
WHERE resource_id = '42'
ORDER BY created_at DESC
LIMIT 50;
```

---

## Blockchain Transaction Issues

### Transaction Stuck Pending

**Symptoms:** Transaction submitted but not confirming

#### Diagnosis

```bash
# Check transaction status on block explorer
curl "https://api-sepolia.etherscan.io/api?module=transaction&action=gettxreceiptstatus&txhash=0x...&apikey=$ETHERSCAN_KEY"

# Check if transaction in mempool
curl -X POST $RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_getTransactionByHash","params":["0x..."],"id":1}'
```

#### Resolution

**If gas price too low:**
```
1. Transaction may eventually confirm (wait 15-30 min)
2. For urgent: speed up via higher gas (if supported)
3. For oracle: retry with higher gas will happen automatically
```

**If nonce mismatch:**
```
1. Check admin account pending transactions
2. Wait for pending tx to clear
3. Oracle will retry with correct nonce
```

### Transaction Reverted

**Symptoms:** Transaction confirmed but reverted on-chain

#### Diagnosis

```bash
# Get revert reason from block explorer
# Or decode via ethers:
const receipt = await provider.getTransactionReceipt(txHash);
if (receipt.status === 0) {
  // Transaction reverted
  // Check logs for revert reason
}
```

#### Common Revert Reasons

| Revert Reason | Cause | Resolution |
|---------------|-------|------------|
| "Already registered" | Wallet already in IdentityRegistry | Check if duplicate registration attempt |
| "Not authorized" | Caller lacks permission | Verify compliance agent address correct |
| "Contract paused" | Token or IR paused | Check pause status, unpause if appropriate |
| "Insufficient gas" | Gas limit too low | Increase gas limit in signer config |

---

## Performance Degradation

### Slow API Responses

**Symptoms:** API latency >2 seconds

#### Step 1: Identify Bottleneck

```bash
# Check backend health
curl $BACKEND_URL/actuator/health

# Check metrics
curl $BACKEND_URL/actuator/metrics/http.server.requests

# Check database connection pool
curl $BACKEND_URL/actuator/metrics/hikaricp.connections.active
```

#### Step 2: Common Causes

**Database slow:**
```sql
-- Find slow queries
SELECT query, mean_exec_time, calls
FROM pg_stat_statements
ORDER BY mean_exec_time DESC
LIMIT 10;

-- Check for missing indexes
SELECT schemaname, tablename, indexname
FROM pg_indexes
WHERE tablename IN ('asset_offerings', 'kyc_requests', 'marketplace_acl');
```

**RPC slow:**
```
1. Check Alchemy/Infura dashboard for rate limits
2. Review RPC latency metrics
3. Consider upgrading RPC tier
4. Add secondary RPC failover
```

**Memory pressure:**
```
1. Check EB instance metrics in CloudWatch
2. Review heap usage: actuator/metrics/jvm.memory.used
3. Consider scaling up instance type
4. Review connection pool settings
```

#### Step 3: Immediate Mitigation

```
1. Scale up EB instances (increase count or size)
2. Clear unnecessary data (old audit logs if retention passed)
3. Restart application (only if necessary)
4. Enable database connection pooling if not already
```

---

## Escalation Paths

| Issue Type | Severity | Response Time | Escalate To |
|------------|----------|---------------|-------------|
| KYC approval | Low | 24 hours | Compliance team |
| Oracle failure | Medium | 4 hours | Engineering on-call |
| Security incident | High | 30 minutes | Security team + CTO |
| Data breach | Critical | Immediate | Security + Legal + Executive |
| Contract vulnerability | Critical | Immediate | Security + Engineering lead |

## Next Steps

- **Incident response**: [6-incident-response.md](6-incident-response.md)
- **Monitoring guide**: [7-monitoring-and-alerting.md](7-monitoring-and-alerting.md)
- **Disaster recovery**: [8-disaster-recovery.md](8-disaster-recovery.md)