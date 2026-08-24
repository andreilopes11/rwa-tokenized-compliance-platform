# Local Development Setup

Complete guide for setting up VaultGuard RWA development environment on Windows.

## Prerequisites

### Required Software

| Tool            | Version | Purpose                           | Download                                                |
| --------------- | ------- | --------------------------------- | ------------------------------------------------------- |
| Git for Windows | Latest  | Version control + bash            | https://git-scm.com/download/win                        |
| Node.js         | 20+     | Frontend runtime                  | https://nodejs.org/                                     |
| Java JDK        | 21+     | Backend runtime                   | https://adoptium.net/                                   |
| Maven           | 3.9+    | Backend build                     | https://maven.apache.org/download.cgi                   |
| Foundry         | Latest  | Smart contracts (Anvil mode only) | https://book.getfoundry.sh/getting-started/installation |

### Optional Tools

- **VS Code** with extensions: PlantUML, Solidity, Java Extension Pack
- **PostgreSQL Client** (psql) for database inspection
- **MetaMask** or similar wallet extension for frontend testing

### Verify Installation

```powershell
# Check versions
node --version          # Should be 20.x or higher
java -version           # Should be 21.x
mvn --version           # Should be 3.9.x
git --version           # Any recent version
forge --version         # Only needed for Anvil mode
```

## Repository Setup

### Clone Main Repository

```powershell
# Clone main repo (contains all submodules)
git clone https://github.com/andreilopes11/rwa-tokenized-compliance-system.git
cd rwa-tokenized-compliance-system

# Initialize submodules if not already present
git submodule update --init --recursive
```

### Repository Structure

```
rwa-tokenized-compliance-system/
├── rwa-tokenized-compliance-system-blockchain/  # Foundry contracts
├── rwa-tokenized-compliance-system-backend/     # Spring Boot API
├── rwa-tokenized-compliance-system-frontend/    # Next.js + BFF
├── root/
│   └── scripts/                                 # Orchestration scripts
├── _docs/                                        # Specifications
└── README.md
```

## Configuration

### Option 1: Full Local Stack (Anvil)

Runs complete local environment with Anvil blockchain.

```powershell
# Start everything (checks deps, installs, starts services)
.\root\scripts\stack.ps1

# Or use individual commands
.\root\scripts\stack.ps1 deps        # Install dependencies only
.\root\scripts\stack.ps1 start       # Start services (assumes deps installed)
```

**Services started:**
- Anvil local blockchain: http://127.0.0.1:8545
- Spring Boot API: http://localhost:8080
- Next.js frontend: http://localhost:3000
- Governance workspace: http://localhost:3000/governance

**Access:**
- Swagger UI: http://localhost:8080/swagger-ui.html (local profile only)
- API health: http://localhost:8080/actuator/health

### Option 2: Frontend + Backend Against Sepolia (Recommended)

Uses live Sepolia testnet, same contracts as production. No local blockchain needed.

#### Step 1: Configure Sepolia Secrets

```powershell
# Copy example config
copy rwa-tokenized-compliance-system-blockchain\config\sepolia.json.example `
     rwa-tokenized-compliance-system-blockchain\config\sepolia.json

# Edit sepolia.json with real values:
# - rpcUrl: Your Alchemy/Infura Sepolia RPC URL
# - adminPrivateKey: Sepolia test account private key (NEVER commit this)
# - Addresses: From deployed contracts (see DEPLOY-SEPOLIA.md)
```

**sepolia.json structure:**
```json
{
  "rpcUrl": "https://eth-sepolia.g.alchemy.com/v2/YOUR_KEY",
  "chainId": 11155111,
  "adminPrivateKey": "0x...",
  "identityRegistryAddress": "0x...",
  "tokenAddress": "0x...",
  "modularComplianceAddress": "0x..."
}
```

#### Step 2: Sync Environment

```powershell
# Sync Sepolia addresses to local runtime config
.\root\scripts\stack.ps1 sync --chain sepolia

# This creates/updates:
# - .local-runtime/stack.env (backend env vars)
# - frontend contract addresses in config
```

#### Step 3: Start Services

```powershell
# Start API + UI (skip blockchain since using Sepolia)
.\root\scripts\stack.ps1 up --chain sepolia --skip-deps

# Or if deps need update:
.\root\scripts\stack.ps1 up --chain sepolia
```

#### Step 4: Verify Wiring

```powershell
# Smoke test Sepolia local setup
.\root\scripts\smoke-sepolia-local.ps1

# Checks:
# - Backend connects to Sepolia RPC
# - Contract addresses resolve
# - Profile is correct (local with Sepolia config)
# - No localhost RPC references
```

## Common Commands

### Stack Management

```powershell
# Full start with dependency check
.\root\scripts\stack.ps1 up

# Start with force dependency update
.\root\scripts\stack.ps1 up --update

# Start specific service only
.\root\scripts\stack.ps1 start blockchain
.\root\scripts\stack.ps1 start backend
.\root\scripts\stack.ps1 start frontend

# Fast restart (assumes deps unchanged)
.\root\scripts\stack.ps1 start --skip-deps

# Check service status
.\root\scripts\stack.ps1 status

# Stop all services
.\root\scripts\stop.ps1

# Run all tests (forge + maven + vitest)
.\root\scripts\stack.ps1 verify
```

### Project Cleanup

```powershell
# Remove build artifacts
.\root\scripts\clean-projects.ps1

# Deep clean (includes node_modules, .local-runtime, deployments)
.\root\scripts\clean-projects.ps1 -Full
```

### Individual Repo Operations

```powershell
# Backend
cd rwa-tokenized-compliance-system-backend
mvn clean install
mvn spring-boot:run
mvn test
mvn -Dtest=Phase5MarketplaceHappyPathTest test

# Frontend
cd rwa-tokenized-compliance-system-frontend
npm install
npm run dev
npm run build
npm run test

# Blockchain
cd rwa-tokenized-compliance-system-blockchain
npm install
npm run local:up          # Start Anvil + deploy
npm run test              # All tests
npm run test:security     # Security-focused tests
npm run deploy:sepolia    # Deploy to Sepolia (requires config)
```

## Environment Variables

### Backend (.local-runtime/stack.env)

Generated by `stack.ps1 sync`:

```bash
SPRING_PROFILES_ACTIVE=local
APP_BLOCKCHAIN_CHAIN_ID=31337              # Or 11155111 for Sepolia
APP_BLOCKCHAIN_RPC_URL=http://127.0.0.1:8545
APP_BLOCKCHAIN_IDENTITY_REGISTRY_ADDRESS=0x...
APP_BLOCKCHAIN_TOKEN_ADDRESS=0x...
APP_BLOCKCHAIN_MODULAR_COMPLIANCE_ADDRESS=0x...
APP_BLOCKCHAIN_ADMIN_PRIVATE_KEY=0x...     # Local/test key only
```

### Frontend (publicRuntime.ts + serverRuntime.ts)

**Public runtime** (browser):
```typescript
export const publicRuntime = {
  chainId: 31337,  // Or 11155111 for Sepolia
  rpcUrl: 'http://127.0.0.1:8545',
  identityRegistryAddress: '0x...',
  tokenAddress: '0x...',
  // ... other public config
}
```

**Server runtime** (BFF only):
```typescript
export const serverRuntime = {
  backendApiBaseUrl: process.env.BACKEND_API_BASE_URL || 'http://localhost:8080',
  // ... other server-only config
}
```

## Troubleshooting

### "Port already in use"

```powershell
# Stop all services
.\root\scripts\stop.ps1

# Or manually kill processes
Get-Process -Name "java", "node" | Stop-Process -Force
Get-Process -Name "anvil" | Stop-Process -Force
```

### "Command not found: forge/anvil"

```powershell
# Install Foundry (requires curl)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
iwr -useb https://raw.githubusercontent.com/foundry-rs/foundry/master/foundryup/install | iex
foundryup

# Or use Anvil mode is optional — use Sepolia instead
.\root\scripts\stack.ps1 up --chain sepolia
```

### "Cannot connect to database"

```powershell
# Backend uses embedded H2 in local profile (no external DB needed)
# Check application.yml profile is 'local'
# For Sepolia mode with local profile, H2 is still used
```

### "Maven dependency errors"

```powershell
# Force Maven dependency update
cd rwa-tokenized-compliance-system-backend
mvn clean install -U

# Or through stack script
.\root\scripts\stack.ps1 up --update
```

### "Frontend build errors"

```powershell
# Clear Next.js cache and reinstall
cd rwa-tokenized-compliance-system-frontend
Remove-Item -Recurse -Force .next, node_modules
npm install
npm run dev
```

### "Sepolia RPC not responding"

```powershell
# Check Alchemy/Infura dashboard for rate limits
# Verify RPC URL in sepolia.json
# Test RPC directly:
curl -X POST $RPC_URL `
  -H "Content-Type: application/json" `
  -d '{"jsonrpc":"2.0","method":"eth_blockNumber","params":[],"id":1}'
```

## Next Steps

- **Development workflow**: See [2-development-workflow.md](2-development-workflow.md)
- **Testing guide**: See [3-testing-guide.md](3-testing-guide.md)
- **Deployment**: See [4-deployment-procedures.md](4-deployment-procedures.md)
- **Phase 5 E2E**: See [scripts/e2e-phase5.md](scripts/e2e-phase5.md)

## Security Notes

### Never Commit:
- `config/sepolia.json` (contains private key)
- `.env` files with real secrets
- Production database credentials
- Mainnet private keys

### Safe to Commit:
- `config/local.json` (Anvil test addresses)
- `sepolia-addresses.json` (public contract addresses)
- `.env.example` files (templates)
- `application.yml` with profile-based defaults

## Support

For issues:
1. Check [Troubleshooting](#troubleshooting) section above
2. Review error logs in console output
3. Consult repository-specific README files
4. Check [_docs/TECHNICAL.md](../_docs/TECHNICAL.md) for architecture details