# Execution Guide

Comprehensive operational documentation for VaultGuard RWA development, deployment, and maintenance.

## Overview

This directory contains practical guides for operating the VaultGuard RWA system across all environments and lifecycle stages. Start with the local development setup, then follow the workflow and testing guides before moving to deployment.

## Guide Index

### Development

| Guide                                                      | Purpose                                | Audience       |
| ---------------------------------------------------------- | -------------------------------------- | -------------- |
| [1. Local Development Setup](1-local-development-setup.md) | Complete environment setup on Windows  | All developers |
| [2. Development Workflow](2-development-workflow.md)       | Day-to-day development practices       | Developers     |
| [3. Testing Guide](3-testing-guide.md)                     | Test strategy and execution            | Developers, QA |
| [8. Quick Reference](8-quick-reference.md)                 | Essential commands and troubleshooting | All roles      |

### Operations

| Guide                                                      | Purpose                                | Audience                 |
| ---------------------------------------------------------- | -------------------------------------- | ------------------------ |
| [4. Deployment Procedures](4-deployment-procedures.md)     | Production deployment step-by-step     | DevOps, Release managers |
| [5. Operational Runbooks](5-operational-runbooks.md)       | Common operational tasks               | DevOps, SRE              |
| [6. Troubleshooting Guide](6-troubleshooting-guide.md)     | Problem diagnosis and resolution       | DevOps, Support          |
| [7. Monitoring and Alerting](7-monitoring-and-alerting.md) | Observability setup and alert response | DevOps, SRE              |

### Scripts

| Script                                                     | Purpose                           | Usage                                       |
| ---------------------------------------------------------- | --------------------------------- | ------------------------------------------- |
| [stack.ps1](scripts/stack.ps1)                             | Main orchestration script         | `.\root\scripts\stack.ps1 [command]`        |
| [stop.ps1](scripts/stop.ps1)                               | Stop all services                 | `.\root\scripts\stop.ps1`                   |
| [clean-projects.ps1](scripts/clean-projects.ps1)           | Clean build artifacts             | `.\root\scripts\clean-projects.ps1 [-Full]` |
| [smoke-sepolia-local.ps1](scripts/smoke-sepolia-local.ps1) | Verify Sepolia local wiring       | `.\root\scripts\smoke-sepolia-local.ps1`    |
| [e2e-phase5.md](scripts/e2e-phase5.md)                     | Phase 5 end-to-end test scenarios | Manual test execution                       |

## Quick Start Paths

### New Developer Onboarding

1. **Setup** → [1-local-development-setup.md](1-local-development-setup.md)
2. **Workflow** → [2-development-workflow.md](2-development-workflow.md)
3. **Testing** → [3-testing-guide.md](3-testing-guide.md)
4. **Reference** → [8-quick-reference.md](8-quick-reference.md)

### Production Deployment

1. **Pre-deployment** → [4-deployment-procedures.md](4-deployment-procedures.md) (checklist)
2. **Deploy** → [4-deployment-procedures.md](4-deployment-procedures.md) (procedures)
3. **Verify** → [4-deployment-procedures.md](4-deployment-procedures.md) (validation)
4. **Monitor** → [7-monitoring-and-alerting.md](7-monitoring-and-alerting.md)

### Incident Response

1. **Diagnose** → [6-troubleshooting-guide.md](6-troubleshooting-guide.md)
2. **Execute** → [5-operational-runbooks.md](5-operational-runbooks.md)
3. **Monitor** → [7-monitoring-and-alerting.md](7-monitoring-and-alerting.md)
4. **Quick Fix** → [8-quick-reference.md](8-quick-reference.md) (emergency procedures)

## System Architecture Recap

```
┌──────────────────────────────────────────────────────────┐
│                  VaultGuard RWA Stack                    │
├──────────────────────────────────────────────────────────┤
│  Frontend (Vercel)                                       │
│  ├─ Next.js App Router                                   │
│  ├─ BFF (HttpOnly JWT cookies)                           │
│  └─ Two workspaces: /dashboard · /governance             │
├──────────────────────────────────────────────────────────┤
│  Backend (AWS Elastic Beanstalk)                         │
│  ├─ Spring Boot API (com.rwa)                            │
│  ├─ PostgreSQL (Neon)                                    │
│  ├─ Oracle Worker (bounded retry)                        │
│  └─ Blockchain Gateway (TransactionSigner)               │
├──────────────────────────────────────────────────────────┤
│  Blockchain (Sepolia / Mainnet)                          │
│  ├─ Shared IdentityRegistry                              │
│  ├─ Per-offering Token (ERC-3643)                        │
│  └─ Per-offering ModularCompliance                       │
└──────────────────────────────────────────────────────────┘
```

## Environment Matrix

| Environment          | Frontend       | Backend        | Blockchain           | Database        |
| -------------------- | -------------- | -------------- | -------------------- | --------------- |
| **Local (Anvil)**    | localhost:3000 | localhost:8080 | Anvil 127.0.0.1:8545 | H2 (embedded)   |
| **Local (Sepolia)**  | localhost:3000 | localhost:8080 | Sepolia via Alchemy  | H2 (embedded)   |
| **Production**       | Vercel HTTPS   | AWS EB HTTPS   | Sepolia via Alchemy  | Neon PostgreSQL |
| **Future (Mainnet)** | Vercel HTTPS   | AWS EB HTTPS   | Mainnet via Alchemy  | Neon PostgreSQL |

## Key Principles

### Security

- **No private keys on Vercel** — BFF only, no signing keys in browser
- **Default deny** — Role + scope + ownership + contract linkage on every API
- **Secrets rotation** — Rotate DB password, JWT secret, encryption key before go-live
- **Audit trail** — All privileged actions logged with append-only integrity

### Two-Role Model

- **SUPER_ADMIN** — Contract manager, KYC approver, governance, audit read
- **INVESTOR** — End user, own KYC, portfolio, marketplace browse
- **Contract linkage** — Users only see/act on contracts linked to them

### Deployment Order

1. **Blockchain** → Deploy contracts, record addresses
2. **Backend** → Deploy API with contract addresses
3. **Frontend** → Deploy UI with backend URL

Never reverse this order — each tier depends on the previous tier's outputs.

### Resilience

- **Oracle failures** → Bounded retry, then FAILED_ON_CHAIN state
- **ForceSync** → Four-eyes recovery (two SUPER_ADMIN accounts)
- **Preflight** → Advisory checks before wallet signature
- **Chain final** — On-chain compliance hooks are always authoritative

## Common Tasks

### Start Local Development

```powershell
# Recommended: Frontend + Backend against Sepolia
.\root\scripts\stack.ps1 sync --chain sepolia
.\root\scripts\stack.ps1 up --chain sepolia --skip-deps
.\root\scripts\smoke-sepolia-local.ps1
```

### Run All Tests

```powershell
.\root\scripts\stack.ps1 verify
```

### Stop Everything

```powershell
.\root\scripts\stop.ps1
```

### Deploy to Production

```powershell
# 1. Blockchain
cd rwa-tokenized-compliance-system-blockchain
npm run deploy:sepolia

# 2. Backend
cd rwa-tokenized-compliance-system-backend
mvn clean package
eb deploy vaultguard-production

# 3. Frontend
cd rwa-tokenized-compliance-system-frontend
git push origin main  # Vercel auto-deploys
```

### Check Health

```powershell
# Local
curl http://localhost:8080/actuator/health/readiness
curl http://localhost:3000

# Production
curl https://api.vaultguard.com/actuator/health/readiness
curl https://app.vaultguard.com
```

## Documentation Cross-References

### Foundation Documents

- [`_docs/based_rules.md`](../_docs/based_rules.md) — Foundation rules (SEC, FUN, UI, TEC)
- [`_docs/FUNCTIONAL.md`](../_docs/FUNCTIONAL.md) — Product and business rules
- [`_docs/TECHNICAL.md`](../_docs/TECHNICAL.md) — Implementation specifications
- [`_docs/PHASED-IMPLEMENTATION-PROMPT.md`](../_docs/PHASED-IMPLEMENTATION-PROMPT.md) — Development phases

### Architecture

- [`ADRs/`](../ADRs/) — Architectural decision records
- [`Diagrams/`](../Diagrams/) — PlantUML C4 diagrams

### Repository-Specific

- [Backend DEPLOY-EB.md](https://github.com/andreilopes11/rwa-tokenized-compliance-system/blob/main/rwa-tokenized-compliance-system-backend/DEPLOY-EB.md)
- [Frontend DEPLOY-VERCEL.md](https://github.com/andreilopes11/rwa-tokenized-compliance-system/blob/main/rwa-tokenized-compliance-system-frontend/DEPLOY-VERCEL.md)
- [Blockchain DEPLOY-SEPOLIA.md](https://github.com/andreilopes11/rwa-tokenized-compliance-system/blob/main/rwa-tokenized-compliance-system-blockchain/DEPLOY-SEPOLIA.md)

## Glossary

| Term                 | Definition                                                                           |
| -------------------- | ------------------------------------------------------------------------------------ |
| **BFF**              | Backend-For-Frontend — Next.js API routes proxying to Spring Boot                    |
| **Contract linkage** | Access control: SUPER_ADMIN sees created_by; INVESTOR sees public/invited/contracted |
| **ForceSync**        | Four-eyes manual recovery when oracle fails (two SUPER_ADMIN accounts)               |
| **Oracle**           | Trusted worker reading off-chain KYC approval and writing on-chain identity          |
| **T-REX**            | Token for Regulated EXchanges — ERC-3643 implementation                              |
| **Offering**         | Admin-created tokenized RWA quota backed by one ERC-3643 token suite                 |
| **Visibility**       | Discovery ACL: PUBLIC (all investors) or PRIVATE (invited only)                      |

## Support

For issues not covered in these guides:

1. Check [8-quick-reference.md](8-quick-reference.md) troubleshooting index
2. Review [6-troubleshooting-guide.md](6-troubleshooting-guide.md) for detailed diagnostics
3. Consult repository-specific README files
4. Review [`_docs/TECHNICAL.md`](../_docs/TECHNICAL.md) for architecture details
5. Check ADRs for decision context: [`ADRs/`](../ADRs/)

## Maintenance

This directory should be updated:

- **When architecture changes** — Update guides to reflect new components or flows
- **After incidents** — Add new troubleshooting entries based on real issues
- **After deployments** — Update procedures with lessons learned
- **Quarterly** — Review and refresh all guides for accuracy

Last comprehensive review: 2026-08-24
</contents>