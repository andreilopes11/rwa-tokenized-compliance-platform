# Phase 5 — Marketplace E2E path

Scripted coverage lives in backend unit tests (runs via `stack.ps1 verify`):

| Step | Test |
|------|------|
| Full happy path + private deny + audit/chain txs | `Phase5MarketplaceHappyPathTest` |
| Marketplace ACL / probes | `MarketplaceAclServiceTest` |
| Rate limit on catalog probe | `RateLimitInterceptorTest` (`GET /api/assets` → 429) |
| Transfer preflight reason codes | `TransferPreflightServiceTest` |
| On-chain pause/revoke/non-compliant | `TrexComplianceSecurityTest` (forge) |
| Frontend marketplace split / BFF roles | vitest (`InvestorDashboard`, `middleware-auth`, `SaAssetsScreen`) |

## Happy path (service / API semantics)

1. SUPER_ADMIN creates **PRIVATE** + **PUBLIC** DRAFT offerings (with `tokenAddress`)
2. Grant investor on PRIVATE by `identityHash`
3. Publish both → ACTIVE
4. Investor KYC submit → compliance officer approve → oracle/`authorizeIdentity` → `APPROVED` + `onChainVerified`
5. Grantee lists both; non-grantee lists PUBLIC only
6. Non-grantee `GET /api/assets/{privateId}` → **403** `MARKETPLACE_FORBIDDEN` (generic message)
7. Subscribe PUBLIC → officer approve → mint → `blockchain_transactions` + `SUBSCRIPTION_*` audit
8. `POST /api/investors/{wallet}/transfers/preflight` → allow/deny (`RECIPIENT_NOT_COMPLIANT`, `TOKEN_PAUSED`, …)
9. Wallet transfer is signed client-side; chain `canTransfer` is final

## Commands

```powershell
# Full cross-repo verify (forge + mvn + vitest)
.\root\scripts\stack.ps1 verify

# Phase 5 backend slice only
cd rwa-tokenized-compliance-system-backend
mvn -Dtest=Phase5MarketplaceHappyPathTest,TransferPreflightServiceTest,MarketplaceAclServiceTest,RateLimitInterceptorTest test
```

## Rate limit / private probe

- Catalog and asset reads share `RateLimitInterceptor` (10 req/min per client IP) → **429** JSON when exceeded.
- Private ACL failures always return **403** with code `MARKETPLACE_FORBIDDEN` (no existence leak).
