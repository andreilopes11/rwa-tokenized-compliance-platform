# Quick Reference Guide

Essential commands, URLs, and troubleshooting for VaultGuard RWA.

## Table of Contents

1. [Local Development](#local-development)
2. [Stack Management](#stack-management)
3. [Environment URLs](#environment-urls)
4. [Common Commands](#common-commands)
5. [Emergency Procedures](#emergency-procedures)
6. [Health Checks](#health-checks)
7. [Troubleshooting Index](#troubleshooting-index)

---

## Local Development

### Prerequisites Check

```powershell
# Verify all required tools
node --version    # Need 20+
java -version     # Need 21+
mvn --version     # Need 3.9+
git --version     # Any recent
forge --version   # Optional (Anvil mode only)
```

### Quick Start (Sepolia - Recommended)

```powershell
# 1. One-time: Copy secrets
copy rwa-tokenized-compliance-system-blockchain\config\sepolia.json.example `
     rwa-tokenized-compliance-system-blockchain\config\sepolia.json
# Edit sepolia.json with real RPC URL and private key

# 2. Sync and start
.\root\scripts\stack.ps1 sync --chain sepolia
.\root\scripts\stack.ps1 up --chain sepolia --skip-deps

# 3. Verify
.\root\scripts\smoke-sepolia-local.ps1
```

### Quick Start (Anvil - Full Local)

```powershell
# Start everything
.\root\scripts\stack.ps1

# Or individual services
.\root\scripts\stack.ps1 start blockchain
.\root\scripts\stack.ps1 start backend
.\root\scripts\stack.ps1 start frontend
```

---

## Stack Management

### Core Commands

| Command | Purpose |
|---------|--------|
| `.\root\scripts\stack.ps1` | Check deps, install, start all (Anvil) |
| `.\root\scripts\stack.ps1 up --chain sepolia` | Start FE+BE on Sepolia (no Anvil) |
| `.\root\scripts\stack.ps1 sync --chain sepolia` | Write Sepolia config to local runtime |
| `.\root\scripts\stack.ps1 deps` | Install deps only (no start) |
| `.\root\scripts\stack.ps1 start --skip-deps` | Fast restart (assumes deps OK) |
| `.\root\scripts\stack.ps1 status` | Show running services |
| `.\root\scripts\stack.ps1 verify` | Run all tests |
| `.\root\scripts\stop.ps1` | Stop all services |
| `.\root\scripts\clean-projects.ps1` | Remove build artifacts |
| `.\root\scripts\clean-projects.ps1 -Full` | Deep clean (includes node_modules) |

### Service-Specific Start

```powershell
# Blockchain only
.\root\scripts\stack.ps1 start blockchain

# Backend only
.\root\scripts\stack.ps1 start backend

# Frontend only
.\root\scripts\stack.ps1 start frontend
```

### Force Dependency Update

```powershell
# Update all dependencies (npm + maven)
.\root\scripts\stack.ps1 up --update
```

---

## Environment URLs

### Local Development

| Service | URL | Notes |
|---------|-----|-------|
| **Frontend** | http://localhost:3000 | Main app |
| **Governance** | http://localhost:3000/governance | SUPER_ADMIN workspace |
| **Backend API** | http://localhost:8080 | Spring Boot |
| **Swagger UI** | http://localhost:8080/swagger-ui.html | Local profile only |
| **Actuator** | http://localhost:8080/actuator | Health, info, metrics |
| **Anvil RPC** | http://127.0.0.1:8545 | Local blockchain (if running) |

### Production (Example)

| Service | URL | Notes |
|---------|-----|-------|
| **Frontend** | https://app.vaultguard.com | Vercel |
| **Backend API** | https://api.vaultguard.com | Elastic Beanstalk |
| **Health Check** | https://api.vaultguard.com/actuator/health/readiness | Public endpoint |
| **Sepolia Explorer** | https://sepolia.etherscan.io | Verify transactions |

---

## Common Commands

### Backend (Spring Boot)

```powershell
cd rwa-tokenized-compliance-system-backend

# Build
mvn clean install
mvn clean package -DskipTests  # Skip tests for faster build

# Run
mvn spring-boot:run

# Test
mvn test                                           # All tests
mvn -Dtest=Phase5MarketplaceHappyPathTest test    # Specific test
mvn -Dtest="*Security*" test                      # Pattern match

# Update dependencies
mvn clean install -U

# Check for dependency vulnerabilities
mvn dependency:tree
mvn versions:display-dependency-updates
```

### Frontend (Next.js)

```powershell
cd rwa-tokenized-compliance-system-frontend

# Install
npm install
npm ci  # Clean install from package-lock.json

# Run
npm run dev         # Development server
npm run build       # Production build
npm run start       # Serve production build

# Test
npm run test        # Vitest
npm run test:watch  # Watch mode
npm run test:ui     # Vitest UI

# Lint
npm run lint
npm run lint:fix

# Clean
Remove-Item -Recurse -Force .next, node_modules
```

### Blockchain (Foundry)

```powershell
cd rwa-tokenized-compliance-system-blockchain

# Install
npm install

# Test
npm run test                # All tests
npm run test:security       # Security-focused tests
forge test --match-test testCannotTransferToNonCompliant  # Specific test

# Deploy
npm run local:up            # Anvil + deploy
npm run deploy:sepolia      # Deploy to Sepolia (requires config)

# Anvil (standalone)
npm run anvil               # Start Anvil on 8545
Get-Process -Name "anvil" | Stop-Process  # Stop Anvil

# Verify contracts
npm run verify:sepolia
```

---

## Emergency Procedures

### Stop Everything Immediately

```powershell
# Graceful stop
.\root\scripts\stop.ps1

# Force kill all
Get-Process -Name "java", "node", "anvil" | Stop-Process -Force
```

### Emergency Rollback (Production)

**Backend:**
```powershell
eb deploy vaultguard-production --version "previous-version-label"
```

**Frontend:**
- Vercel Dashboard → Deployments → Previous deployment → Promote to Production

### Pause Token Transfers (Emergency)

```solidity
// Via backend API (SUPER_ADMIN only)
POST /api/assets/{id}/pause

// Direct contract call (if API unavailable)
cast send $TOKEN_ADDRESS "pause()" \
  --rpc-url $RPC_URL \
  --private-key $GOVERNANCE_KEY
```

### Database Connection Issues

```powershell
# Check connections
curl http://localhost:8080/actuator/health/db

# Restart backend (clears connection pool)
.\root\scripts\stack.ps1 start backend

# Check Neon Console for outages
# https://console.neon.tech/
```

---

## Health Checks

### Local Development

```powershell
# Backend readiness
curl http://localhost:8080/actuator/health/readiness
# Expected: {"status":"UP"}

# Backend profile
curl http://localhost:8080/actuator/info
# Should show: {"profiles":["local"]}

# Frontend
curl http://localhost:3000
# Expected: 200 OK (HTML)

# Database
curl http://localhost:8080/actuator/health/db
# Expected: {"status":"UP"}

# Blockchain (if using Anvil)
curl -X POST http://127.0.0.1:8545 \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

### Production

```powershell
# Backend health
curl https://api.vaultguard.com/actuator/health/readiness

# Frontend
curl https://app.vaultguard.com

# Full E2E (requires auth)
# See: scripts/e2e-phase5.md
```

---

## Troubleshooting Index

### "Port already in use"

```powershell
# Stop services
.\root\scripts\stop.ps1

# Or kill specific ports
Get-Process -Id (Get-NetTCPConnection -LocalPort 8080).OwningProcess | Stop-Process
Get-Process -Id (Get-NetTCPConnection -LocalPort 3000).OwningProcess | Stop-Process
Get-Process -Id (Get-NetTCPConnection -LocalPort 8545).OwningProcess | Stop-Process
```

### "Command not found: forge/anvil"

```powershell
# Option 1: Install Foundry
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/install | iex
foundryup

# Option 2: Use Sepolia instead (no Foundry needed)
.\root\scripts\stack.ps1 up --chain sepolia
```

### "Cannot connect to database"

- **Local**: Uses embedded H2 (no external DB needed)
- **Production**: Check Neon Console for outages
- Verify `SPRING_DATASOURCE_URL` in environment variables

### "Maven dependency errors"

```powershell
cd rwa-tokenized-compliance-system-backend
mvn clean install -U

# Or through stack script
.\root\scripts\stack.ps1 up --update
```

### "Frontend build errors"

```powershell
cd rwa-tokenized-compliance-system-frontend
Remove-Item -Recurse -Force .next, node_modules
npm install
npm run dev
```

### "Sepolia RPC not responding"

```powershell
# Check RPC provider status
# Alchemy: https://status.alchemy.com/
# Infura: https://status.infura.io/

# Test RPC directly
curl -X POST $RPC_URL \
  -H "Content-Type: application/json" \
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'

# Verify sepolia.json configuration
cat rwa-tokenized-compliance-system-blockchain\config\sepolia.json
```

### "Transaction stuck/pending"

```powershell
# Check transaction on Etherscan
# https://sepolia.etherscan.io/tx/0x...

# Check Alchemy Dashboard
# Alchemy Dashboard → App → Mempool

# Backend oracle logs
curl http://localhost:8080/actuator/logfile | Select-String "oracle"
```

### "KYC stuck in APPROVED_PENDING_CHAIN"

```powershell
# Check oracle worker logs
curl http://localhost:8080/actuator/logfile | Select-String "oracle\|identity"

# Check pending transactions
curl http://localhost:8080/actuator/metrics/oracle.pending.count

# Manual ForceSync (if oracle failed)
# See: _docs/FUNCTIONAL.md section 5 (Fallbacks)
```

---

## Configuration Files

### Backend

- `application.yml` — Main config (profiles: local, production, sepolia)
- `.local-runtime/stack.env` — Generated by stack.ps1 sync
- `.backend.env` — Local overrides (gitignored)

### Frontend

- `src/config/publicRuntime.ts` — Client-side config
- `src/config/serverRuntime.ts` — BFF-only config
- `.env.local` — Local overrides (gitignored)

### Blockchain

- `config/local.json` — Anvil addresses (committed)
- `config/sepolia.json` — Sepolia RPC + key (gitignored)
- `deployments/11155111.json` — Sepolia addresses (committed)

---

## Key Environment Variables

### Backend (Required)

```bash
SPRING_PROFILES_ACTIVE=local|production|sepolia
APP_BLOCKCHAIN_CHAIN_ID=31337|11155111
APP_BLOCKCHAIN_RPC_URL=http://127.0.0.1:8545|https://...
APP_BLOCKCHAIN_IDENTITY_REGISTRY_ADDRESS=0x...
APP_BLOCKCHAIN_TOKEN_ADDRESS=0x...
APP_BLOCKCHAIN_MODULAR_COMPLIANCE_ADDRESS=0x...
APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY=0x...  # NEVER commit
```

### Frontend (Required)

```bash
NEXT_PUBLIC_CHAIN_ID=31337|11155111
NEXT_PUBLIC_RPC_URL=http://127.0.0.1:8545|https://...
NEXT_PUBLIC_IDENTITY_REGISTRY_ADDRESS=0x...
NEXT_PUBLIC_TOKEN_ADDRESS=0x...
BACKEND_API_BASE_URL=http://localhost:8080|https://...
```

---

## Useful SQL Queries

### Check KYC Status

```sql
SELECT 
  u.email,
  k.status,
  k.on_chain_verified,
  k.transaction_hash,
  k.updated_at
FROM users u
JOIN kyc_requests k ON u.id = k.user_id
WHERE k.status IN ('APPROVED', 'APPROVED_PENDING_CHAIN')
ORDER BY k.updated_at DESC;
```

### Check Offering Status

```sql
SELECT 
  name,
  visibility,
  status,
  token_address,
  created_by,
  created_at
FROM asset_offerings
WHERE status = 'ACTIVE'
ORDER BY created_at DESC;
```

### Check Oracle Queue

```sql
SELECT 
  COUNT(*) as pending_count,
  MIN(updated_at) as oldest_pending
FROM kyc_requests
WHERE status = 'APPROVED_PENDING_CHAIN';
```

---

## Support Resources

### Documentation

- **Specifications**: `_docs/` (FUNCTIONAL.md, TECHNICAL.md, based_rules.md)
- **ADRs**: `ADRs/` (architectural decisions)
- **Diagrams**: `Diagrams/` (PlantUML C4 diagrams)
- **Execution Guide**: This directory

### External References

- **T-REX/ERC-3643**: https://github.com/TokenySolutions/T-REX
- **Spring Boot**: https://docs.spring.io/spring-boot/docs/current/reference/html/
- **Next.js**: https://nextjs.org/docs
- **Foundry**: https://book.getfoundry.sh/

### Repository Links

- **Main**: https://github.com/andreilopes11/rwa-tokenized-compliance-system
- **Backend**: https://github.com/andreilopes11/rwa-tokenized-compliance-system-backend
- **Frontend**: https://github.com/andreilopes11/rwa-tokenized-compliance-system-frontend
- **Blockchain**: https://github.com/andreilopes11/rwa-tokenized-compliance-system-blockchain
- **Docs (this repo)**: https://github.com/andreilopes11/rwa-tokenized-compliance-platform

---

## Cheat Sheet Summary

```powershell
# Start local dev (Sepolia)
.\root\scripts\stack.ps1 sync --chain sepolia
.\root\scripts\stack.ps1 up --chain sepolia --skip-deps

# Stop everything
.\root\scripts\stop.ps1

# Run tests
.\root\scripts\stack.ps1 verify

# Clean build artifacts
.\root\scripts\clean-projects.ps1

# Deep clean
.\root\scripts\clean-projects.ps1 -Full

# Health check
curl http://localhost:8080/actuator/health/readiness

# View logs (Windows)
Get-Content -Path "logs\backend.log" -Tail 50 -Wait
```

---

For detailed procedures, see other guides in this directory.
</contents>