# ADR-012: Deployment Orchestration and Environment Matrix

- **Status:** Accepted
- **Date:** 2026-08-24
- **Decision owners:** DevOps and Platform Engineering

## Context

VaultGuard RWA consists of three independent deployable units (blockchain, backend, frontend) requiring coordinated deployment with environment-specific configurations. Local development needs Anvil or Sepolia options, while production requires strict deployment order and secret management.

## Decision

### Deployment Order

1. **Blockchain first** → deploy contracts, record addresses
2. **Backend second** → use contract addresses, expose API URL
3. **Frontend last** → use backend URL and contract addresses

### Local Orchestration

- Single PowerShell script (`root/scripts/stack.ps1`) manages all three repos
- Two modes: full Anvil or Sepolia remote chain
- Unified environment sync via `.local-runtime/stack.env`
- Clean separation: no committed secrets

### Production Stack

| Component  | Platform              | Secrets Management                              |
| ---------- | --------------------- | ----------------------------------------------- |
| Blockchain | Sepolia testnet       | Gitignored `config/sepolia.json`                |
| Backend    | AWS Elastic Beanstalk | EB environment variables                        |
| Frontend   | Vercel                | Project environment variables (no signing keys) |
| Database   | Neon PostgreSQL       | JDBC URL in EB config                           |

### Environment Matrix

**Backend:**

- `local`: H2 embedded, Anvil or Sepolia RPC
- `production`: Neon PostgreSQL, Sepolia/mainnet RPC, Swagger off, KMS gate

**Frontend:**

- `publicRuntime.ts`: browser-accessible config (chain ID, RPC, contract addresses)
- `serverRuntime.ts`: BFF-only (backend API URL)

## Consequences

### Positive

- Clear deployment sequence prevents misconfiguration
- Single orchestration script simplifies local setup
- Secrets never committed to git
- Environment-specific profiles in single `application.yml`

### Negative

- Manual coordination required for initial deploy
- Backend and frontend must be redeployed if contract addresses change
- Local Sepolia mode requires manual RPC key management

### Mitigations

- Deployment guides with explicit order
- Smoke test scripts verify wiring
- Address changes are rare (only on re-deploy)

## References

- `_docs/TECHNICAL.md` §10 (Deploy & ops)
- `_docs/based_rules.md` TEC-06, TEC-11, TEC-12
- [ADR-006](ADR-006-production-readiness-and-deployment-order.md)
- Main repo: `root/scripts/stack.ps1`, `DEPLOY-EB.md`, `DEPLOY-VERCEL.md`, `DEPLOY-SEPOLIA.md`