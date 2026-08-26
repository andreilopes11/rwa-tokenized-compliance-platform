# Phase 5 — Marketplace E2E path

Scripted coverage (runs via `stack.ps1 verify` / Maven):

| Step | Test |
|------|------|
| Scenarios 1–9 (create/publish/ownership/catalog/invite/KYC/pause/preflight) | `Phase5ContractLinkageE2ETest` |
| Full happy path + private deny + audit/chain txs | `Phase5MarketplaceHappyPathTest` |
| Marketplace ACL / probes | `MarketplaceAclServiceTest` |
| Rate limit on catalog probe | `RateLimitInterceptorTest` (`GET /api/assets` → 429) |
| Transfer preflight reason codes | `TransferPreflightServiceTest` |
| On-chain pause/revoke/non-compliant | `TrexComplianceSecurityTest` (forge) |
| Frontend marketplace / BFF roles | vitest (`InvestorDashboard`, `middleware-auth`, `SaAssetsScreen`) |

## Mandatory scenarios (IMPLEMENTATION-PROMPTS §7)

1. Admin A creates DRAFT and publishes; suite addresses exist and bind to shared IR.
2. Admin B cannot list or mutate Admin A’s offering (`AssetOwnershipException` / generic 403).
3. Investor sees PUBLIC ACTIVE only — not DRAFT / PAUSED / CLOSED.
4. PRIVATE is absent from catalog; detail (and unknown id) returns generic `MARKETPLACE_FORBIDDEN`.
5. Invite (grant) unlocks catalog/detail; soft-revoke keeps history and blocks future access.
6. KYC pending / pending-chain blocks subscribe; confirmed receipt releases.
7. Pause / non-verified recipient block on chain hooks.
8. Failed preflight returns deny codes (no wallet signature path).
9. Non-DRAFT create rejected; cross-admin grant and path/body probes denied.

## Commands

```powershell
# Full cross-repo verify (forge + mvn + vitest)
.\root\scripts\stack.ps1 verify

# Phase 5 backend slice
cd rwa-tokenized-compliance-system-backend
mvn -Dtest=Phase5ContractLinkageE2ETest,Phase5MarketplaceHappyPathTest,TransferPreflightServiceTest,MarketplaceAclServiceTest,RateLimitInterceptorTest test
```

## Local Anvil + BFF smoke

1. Start Anvil and deploy shared IR (`DeployTREX` / stack sync).
2. Optional live suite deploy: `APP_BLOCKCHAIN_SUITE_DEPLOY_ENABLED=true` + agent keys.
3. Or run backend with `app.blockchain.enabled=false` (DisabledBlockchainGateway simulates deploy).
4. Start frontend BFF; register SUPER_ADMIN + INVESTOR; walk create → publish → invite → KYC → subscribe → preflight → pause.

## Rate limit / private probe

- Catalog and asset reads share `RateLimitInterceptor` → **429** when exceeded.
- Private ACL failures always return **403** with code `MARKETPLACE_FORBIDDEN` (no existence leak).
- Subscribe/redeem without linkage return **403** with code `NOT_LINKED`.
