# Deployment Procedures

Step-by-step deployment guide for VaultGuard RWA production environments.

## Deployment Architecture

```
┌─────────────┐
│  Sepolia    │  1. Deploy contracts first
│  Testnet    │     (addresses needed by backend)
└─────────────┘
       ↓
┌─────────────┐
│   AWS EB    │  2. Deploy backend with contract addresses
│  (Backend)  │     (API URL needed by frontend)
└─────────────┘
       ↓
┌─────────────┐
│   Vercel    │  3. Deploy frontend with backend URL
│ (Frontend)  │     (no secrets, BFF only)
└─────────────┘
```

## Pre-Deployment Checklist

### Security Review

- [ ] No private keys in repository
- [ ] No hardcoded secrets in code
- [ ] Environment variables documented
- [ ] Database password rotated from dev/test values
- [ ] JWT secret generated (not reused from dev)
- [ ] Document encryption key generated
- [ ] CORS origins limited to production domains
- [ ] Swagger/OpenAPI disabled in production profile
- [ ] Legacy admin token disabled
- [ ] Rate limiting configured

### Code Review

- [ ] All tests passing (forge + maven + vitest)
- [ ] Phase 5 E2E tests green
- [ ] No `console.log` or debug statements
- [ ] Error messages are user-safe
- [ ] Audit events for privileged actions
- [ ] Authorization checks on protected endpoints
- [ ] Contract linkage enforced
- [ ] KYC state machine correct

### Configuration Review

- [ ] `application.yml` production profile configured
- [ ] Frontend `publicRuntime` has correct values
- [ ] Chain ID matches target network (11155111 for Sepolia)
- [ ] Contract addresses from deployment recorded
- [ ] RPC URL from trusted provider (Alchemy/Infura)
- [ ] Database connection string secure

## 1. Blockchain Deployment (Sepolia)

### Prerequisites

- Sepolia ETH in deployer account (get from faucet)
- Alchemy or Infura RPC URL
- Private key for deployer (NEVER commit)

### Step 1.1: Configure Deployment

```powershell
cd rwa-tokenized-compliance-system-blockchain

# Copy example config
copy config\sepolia.json.example config\sepolia.json

# Edit config/sepolia.json (DO NOT COMMIT)
# {
#   "rpcUrl": "https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY",
#   "chainId": 11155111,
#   "adminPrivateKey": "0x...",  # Deployer key
#   "gasPrice": "auto"
# }
```

### Step 1.2: Deploy Base T-REX

```powershell
# Deploy shared IdentityRegistry + base contracts
npm run deploy:sepolia

# Output will show deployed addresses:
# IdentityRegistry: 0x...
# ImplementationAuthority: 0x...
# ClaimTopicsRegistry: 0x...
# TrustedIssuersRegistry: 0x...
# IdentityRegistryStorage: 0x...
```

### Step 1.3: Record Addresses

```powershell
# Addresses saved to:
cat deployments\11155111.json

# Commit this file (public addresses only):
git add deployments\11155111.json
git commit -m "chore: record Sepolia deployment addresses"
```

### Step 1.4: Deploy First Offering Suite

```powershell
# Deploy token + compliance for first offering
# This happens via backend API on offering publish
# But can be tested standalone:

forge script script/DeployAdditionalTrexToken.s.sol:DeployAdditionalTrexToken \
  --rpc-url $RPC_URL \
  --private-key $DEPLOYER_KEY \
  --broadcast \
  --verify

# Records token + modular compliance addresses
```

### Step 1.5: Verify Contracts

```powershell
# Verify on Etherscan
forge verify-contract $CONTRACT_ADDRESS \
  src/IdentityRegistry.sol:IdentityRegistry \
  --chain-id 11155111 \
  --etherscan-api-key $ETHERSCAN_KEY

# Or use script:
npm run verify:sepolia
```

**Sepolia deployment outputs:**
- IdentityRegistry address
- Base implementation addresses
- Block numbers and transaction hashes
- Gas used per transaction

## 2. Backend Deployment (AWS Elastic Beanstalk)

### Prerequisites

- AWS CLI configured
- EB CLI installed: `pip install awsebcli`
- Neon PostgreSQL database created
- Elastic Beanstalk environment created

### Step 2.1: Prepare Application Package

```powershell
cd rwa-tokenized-compliance-system-backend

# Build JAR
mvn clean package -DskipTests

# Verify JAR exists
ls target\rwa-backend-*.jar
```

### Step 2.2: Create Procfile

```powershell
# Create Procfile in project root
echo "web: java -Dserver.port=5000 -jar target/rwa-backend-*.jar" > Procfile
```

### Step 2.3: Create Deployment ZIP

```powershell
# Create deployment package
Compress-Archive -Path Procfile,target\rwa-backend-*.jar -DestinationPath deploy.zip
```

### Step 2.4: Configure Environment Variables

Set in EB Console (Configuration → Environment Properties):

**Required:**
```bash
SPRING_PROFILES_ACTIVE=production

# Database (Neon PostgreSQL)
SPRING_DATASOURCE_URL=jdbc:postgresql://YOUR_NEON_HOST/vaultguard
SPRING_DATASOURCE_USERNAME=your_username
SPRING_DATASOURCE_PASSWORD=YOUR_ROTATED_PASSWORD

# CORS
CORS_ALLOWED_ORIGINS=https://your-frontend.vercel.app,https://www.yourdomain.com

# Blockchain (Sepolia)
APP_BLOCKCHAIN_CHAIN_ID=11155111
APP_BLOCKCHAIN_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY
APP_BLOCKCHAIN_IDENTITY_REGISTRY_ADDRESS=0x... # From step 1.3
APP_BLOCKCHAIN_TOKEN_ADDRESS=0x...              # From step 1.4
APP_BLOCKCHAIN_MODULAR_COMPLIANCE_ADDRESS=0x... # From step 1.4

# Admin key (rotate for mainnet)
APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY=0x... # Sepolia admin key
APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=false # true for mainnet

# Security
APP_AUTH_JWT_SECRET=GENERATE_NEW_SECRET_64_CHARS
APP_AUTH_JWT_ACCESS_TOKEN_EXPIRY_MS=900000
APP_AUTH_JWT_REFRESH_TOKEN_EXPIRY_MS=604800000
APP_DOCUMENTS_ENCRYPTION_KEY=GENERATE_NEW_KEY_32_BYTES

# Features
APP_SWAGGER_ENABLED=false
APP_LEGACY_ADMIN_TOKEN_ENABLED=false

# Oracle
APP_ORACLE_RETRY_MAX_ATTEMPTS=5
APP_ORACLE_RETRY_BACKOFF_MS=5000
```

**Generate secrets:**
```powershell
# JWT secret (64 random chars)
-join ((48..57) + (65..90) + (97..122) | Get-Random -Count 64 | % {[char]$_})

# Encryption key (32 bytes, base64)
$bytes = New-Object byte[] 32
[System.Security.Cryptography.RNGCryptoServiceProvider]::Create().GetBytes($bytes)
[Convert]::ToBase64String($bytes)
```

### Step 2.5: Deploy to EB

```powershell
# Initialize EB (first time only)
eb init -p "Corretto 21" -r us-east-1 vaultguard-api

# Create environment (first time only)
eb create vaultguard-production \
  --instance-type t3.medium \
  --envvars "$(cat env-vars.txt)"

# Deploy update
eb deploy vaultguard-production --staged

# Or upload ZIP via EB Console:
# Elastic Beanstalk → Environment → Upload and deploy
```

### Step 2.6: Verify Deployment

```powershell
# Check health
curl https://your-eb-env.elasticbeanstalk.com/actuator/health/readiness

# Expected:
# {"status":"UP"}

# Check profile
curl https://your-eb-env.elasticbeanstalk.com/actuator/info

# Should show:
# {"profiles":["production"]}

# Test authentication
curl -X POST https://your-eb-env.elasticbeanstalk.com/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@example.com","password":"test","role":"SUPER_ADMIN"}'
```

**Backend deployment outputs:**
- EB environment URL
- Health check status
- Active Spring profile
- Database migration success

## 3. Frontend Deployment (Vercel)

### Prerequisites

- Vercel account connected to GitHub
- Repository pushed to GitHub
- Backend deployed and URL known

### Step 3.1: Configure Project in Vercel

**Via Vercel Dashboard:**

1. Import GitHub repository
2. Select `rwa-tokenized-compliance-system-frontend` directory
3. Framework preset: Next.js
4. Build command: `npm run build`
5. Output directory: `.next`

### Step 3.2: Set Environment Variables

**In Vercel Project Settings → Environment Variables:**

**Public (browser-accessible):**
```bash
NEXT_PUBLIC_CHAIN_ID=11155111
NEXT_PUBLIC_RPC_URL=https://eth-sepolia.g.alchemy.com/v2/YOUR_PUBLIC_KEY
NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=0x... # From blockchain deployment
NEXT_PUBLIC_TOKEN_ADDRESS=0x...
NEXT_PUBLIC_MODULAR_COMPLIANCE_ADDRESS=0x...
NEXT_PUBLIC_APP_NAME=VaultGuard RWA
NEXT_PUBLIC_APP_ENV=production
```

**Server-only (BFF):**
```bash
BACKEND_API_BASE_URL=https://your-eb-env.elasticbeanstalk.com
NODE_ENV=production
```

**Security notes:**
- NO private keys on Vercel
- NO JWT secrets on Vercel
- NO admin credentials on Vercel
- BFF proxies to backend with HttpOnly cookies

### Step 3.3: Deploy

**Automatic deployment:**
```powershell
# Push to main branch triggers production deploy
git push origin main

# Or create PR for preview deploy
git checkout -b feature/update
git push origin feature/update
gh pr create --base main

# Vercel automatically creates preview URL
```

**Manual deployment:**
```powershell
cd rwa-tokenized-compliance-system-frontend

# Install Vercel CLI
npm i -g vercel

# Deploy to preview
vercel

# Deploy to production
vercel --prod
```

### Step 3.4: Verify Deployment

```powershell
# Check production URL
curl https://your-app.vercel.app

# Verify environment in browser:
# - Open DevTools → Console
# - Check for correct chain ID in network requests
# - Verify backend API calls go to correct EB URL
```

**Test critical paths:**
1. Navigate to https://your-app.vercel.app
2. Register investor account
3. Check /dashboard loads
4. Register admin account
5. Check /governance loads
6. Verify role-based routing

**Frontend deployment outputs:**
- Production URL
- Preview URLs for PRs
- Build logs
- Environment variable confirmation

## Post-Deployment Validation

### End-to-End Smoke Test

```powershell
# 1. Register SUPER_ADMIN
curl -X POST $FRONTEND_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "SecurePass123!",
    "role": "SUPER_ADMIN"
  }'

# 2. Login
curl -X POST $FRONTEND_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "admin@test.com",
    "password": "SecurePass123!",
    "role": "SUPER_ADMIN"
  }' \
  -c cookies.txt

# 3. Create offering (requires auth cookie)
curl -X POST $BACKEND_URL/api/assets \
  -H "Content-Type: application/json" \
  -b cookies.txt \
  -d '{
    "name": "Test Offering",
    "visibility": "PUBLIC",
    "minimumInvestment": 10000
  }'

# 4. Verify health
curl $BACKEND_URL/actuator/health

# 5. Check frontend loads
curl $FRONTEND_URL
```

### Monitoring Setup

**AWS CloudWatch (Backend):**
- Set up log groups for EB environment
- Create alarms for error rate
- Monitor API latency
- Track database connection pool

**Vercel Analytics (Frontend):**
- Enable Web Analytics
- Monitor Core Web Vitals
- Track error rates
- Review build times

**Alchemy Dashboard (Blockchain):**
- Monitor RPC request rate
- Check rate limit usage
- Review failed transactions

## Rollback Procedures

### Backend Rollback

```powershell
# Via EB CLI
eb deploy vaultguard-production --version "previous-version-label"

# Or via Console:
# Elastic Beanstalk → Application versions → Deploy previous version
```

### Frontend Rollback

```powershell
# Via Vercel Dashboard:
# Deployments → Previous deployment → Promote to Production

# Or redeploy previous commit:
git revert HEAD
git push origin main
# Vercel auto-deploys
```

### Database Rollback

```sql
-- If migration fails, Flyway tracks state
-- Manual rollback may be needed for data changes

-- Check migration history
SELECT * FROM flyway_schema_history ORDER BY installed_rank DESC;

-- Restore from backup if needed
-- (Ensure regular backups configured in Neon)
```

## Production Maintenance

### Regular Tasks

**Weekly:**
- Review error logs
- Check disk space (EB instances)
- Monitor database size
- Review failed blockchain transactions

**Monthly:**
- Rotate database passwords
- Review and revoke unused API keys
- Update dependencies with security patches
- Test disaster recovery procedures

**Quarterly:**
- Full security audit
- Performance optimization review
- Capacity planning
- Update runbooks

### Scaling

**Backend (Elastic Beanstalk):**
```powershell
# Auto-scaling configuration
eb config vaultguard-production

# Edit scaling settings:
# MinSize: 2
# MaxSize: 10
# Trigger: CPUUtilization > 70%
```

**Database (Neon):**
- Upgrade compute tier in Neon dashboard
- Enable connection pooling
- Add read replicas if needed

**Frontend (Vercel):**
- Scales automatically
- Review analytics for traffic patterns
- Consider CDN optimization

## Mainnet Deployment (Future)

**Blockers (must complete first):**
1. External security audit
2. Real KMS/HSM signing (EIP-155 compatible)
3. Disaster recovery procedures tested
4. Penetration testing
5. Legal compliance review
6. Insurance coverage

**Additional requirements:**
- Multi-sig governance
- Circuit breakers
- Gradual rollout
- Bug bounty program

## Next Steps

- **Operational runbooks**: [5-operational-runbooks.md](5-operational-runbooks.md)
- **Incident response**: [6-incident-response.md](6-incident-response.md)
- **Monitoring guide**: [7-monitoring-and-alerting.md](7-monitoring-and-alerting.md)