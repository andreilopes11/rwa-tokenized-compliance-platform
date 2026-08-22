# VaultGuard RWA — Technical Specification

Derived from [`based_rules.md`](based_rules.md). Product rules: [`FUNCTIONAL.md`](FUNCTIONAL.md).

**Stack:** Foundry T-REX (ERC-3643) · Spring Boot (`com.rwa`) · Next.js BFF · `root/scripts`

---

## 1. Architecture

```text
Investor / Super Admin  (two roles only)
              │
     Next.js workspaces + BFF   (/dashboard · /governance)
     (HttpOnly JWT cookies → Bearer + X-Investor-Wallet + X-Tenant-Id)
              ▼
     Spring Boot API (role + scope + ownership + contract linkage)
              │
     ┌────────┼────────┬────────────┐
     ▼        ▼        ▼            ▼
  PostgreSQL  KYC/AML  Oracle    BlockchainGateway
  (PII/audit) adapter  worker    (TransactionSigner)
                                      ▼
                              EVM T-REX suite
                     IdentityRegistry + ModularCompliance + Token
```

**Principle:** Java knows the person; Solidity knows verified wallet + identity hash.  
**Finality:** API/UI advisory for token movement; **on-chain `canTransfer` / identity checks are final**.

| Boundary | Enforce |
|----------|---------|
| Frontend | Route/role guards only — never sole ACL |
| Backend | Default deny: role + scope + ownership + contract linkage |
| Oracle | No `onChainVerified` without receipt + confirm |
| Chain | Hooks at mint/transfer execution |

Prefer **shared IdentityRegistry** across marketplace contracts; resolve token/compliance **per contract**.

---

## 2. Invariants

| ID | Invariant |
|----|-----------|
| INV-01 | Compliance hook before balance mutation — chain final |
| INV-02 | Mint only to verified addresses |
| INV-03 | Revocation does not erase history |
| INV-04 | Off-chain approve ≠ final until on-chain confirm |
| INV-05 | On conflict, chain wins over API/UI |
| INV-06 | PII off-chain only |
| INV-07 | ForceSync dual-approval, scoped, audited |
| INV-08 | Each ACTIVE contract → one token suite address set |
| INV-09 | Contract linkage in list query **and** subscribe/redeem |
| INV-10 | `TransactionSigner` abstractable to HSM/KMS (no hardcoded keys) |
| INV-11 | Two roles only; SUPER_ADMIN scopes = union (governance + KYC + lifecycle + audit) |

---

## 3. RBAC & scopes

Two roles only (based_rules §2). `COMPLIANCE_OFFICER` / `AUDITOR` removed; legacy `ADMIN` → `SUPER_ADMIN`.

| Scope family | Role |
|--------------|------|
| `KYC_SUBMIT` / `KYC_READ_OWN` / `LIFECYCLE_READ_OWN` / `READ_OWN_DOCS` | Investor |
| `KYC_APPROVE` / `KYC_REJECT` / `KYC_REVOKE` / `LIFECYCLE_APPROVE` / `READ_INVESTOR_DOCS` | Super Admin |
| `GOVERNANCE_*` / `FORCE_SYNC_INITIATE` / `FORCE_SYNC_APPROVE` / `AUDIT_READ` | Super Admin |

- Investor wallet in path/body must match JWT; BFF sets `X-Investor-Wallet`.  
- Documents: ownership or SUPER_ADMIN scope; generic `403`.  
- Catalog (investor): `ACTIVE AND (PUBLIC OR invite OR contracted)`; governance: `created_by = admin`.  
- BR-14: never escalate linkage from client probe params.  
- Dual enforcement: BFF path deny + `ApiAuthorizationInterceptor` (route matrix now targets SUPER_ADMIN for kyc/lifecycle/assets/force-sync/audit).  
- Remove or enforce dead `GOVERNANCE_ORACLE` scope; fix `/api/admin/investors/*/compliance-profile` route matrix gap.

**Auth (product):** JWT + refresh; HttpOnly cookies via BFF. Login/register payloads are `{ email, password, role }` only — **no `mfaCode` / `inviteCode`** (based_rules SEC-10). Residual YAML/DB/i18n MFA or invite keys are legacy and must not drive UX. Production disables legacy admin token and public Swagger.

---

## 4. API (essentials)

Prefix `/api`. Production: OpenAPI off.

| Area | Paths (conceptual) | Guard |
|------|--------------------|-------|
| Auth | register / login / refresh / logout / me | Public / JWT |
| Investor | KYC requests, status, positions, audit, transfer preflight | JWT + wallet ownership |
| Marketplace | `GET /assets` (linked only), `POST .../subscriptions\|redemptions` | JWT + linkage |
| Governance (SUPER_ADMIN) | assets CRUD/publish/visibility/ACL/invite, pause, KYC approve/reject/revoke, lifecycle approve, oracle, ForceSync, audit/chain-tx/export | SUPER_ADMIN + scope |

`/api/admin/**` is SUPER_ADMIN only (KYC + lifecycle + governance + audit merged). Governance list is scoped to `created_by`.

**Errors:** `FORBIDDEN_*`, `MARKETPLACE_FORBIDDEN`, `NOT_LINKED`, `SOD_VIOLATION`, `CHAIN_NOT_READY`, `RECIPIENT_NOT_COMPLIANT`, `TOKEN_PAUSED`, `WRONG_NETWORK`, rate/upstream codes — map to safe UI strings.

Gating: lifecycle/transfer require `status===APPROVED` AND `onChainVerified===true`.

---

## 5. Blockchain (ERC-3643 / T-REX)

Implements based_rules contract layer without embedding Solidity dumps in this doc.

| Module | Duty |
|--------|------|
| Token | Permissioned ERC-20; hooks compliance |
| IdentityRegistry | Wallet ↔ identity |
| ModularCompliance | `canTransfer(from,to,amount)` |
| Modules | Pause, max balance/holders, jurisdiction, suitability as needed |
| Governance | ForceSyncGovernor (2-of-N) where used |
| Deploy | `DeployTREX` (base + shared IR) → **`DeployAdditionalTrexToken`** per new contract (token + ModularCompliance on shared IR) |

**Contract creation:** publishing a new offering deploys a per-contract token suite via `DeployAdditionalTrexToken` on the shared IR; suite addresses (`token`, `identity_registry`, `modular_compliance`) are persisted on the offering and only set `ACTIVE` after receipt.

```text
transfer → ModularCompliance.canTransfer → IR + modules → allow | revert
```

| Check | Authority |
|-------|-----------|
| API preflight / staticcall | Advisory |
| On-chain hook | **Final** |
| Visibility PUBLIC/PRIVATE | Off-chain only |

**Agents (separate keys):** compliance (oracle identity), governance (pause), lifecycle (mint), transfer manager, ForceSync signer. Never reuse end-user keys.

**Backend map:** approve → `registerIdentity`; revoke → `deleteIdentity`; subscribe approve → `mint`; pause → `pause`/`unpause`; status → `isVerified`/`canTransfer`.

Wait for receipt before setting `onChainVerified` / `transactionHash`.

**Config:** `config/local.json` (Anvil); Sepolia addresses in committed `sepolia-addresses.json`; secrets in gitignored `config/sepolia.json` / deploy `.backend.env`.

---

## 6. Backend componentization

| Layer | Responsibility |
|-------|----------------|
| `api` | Controllers, DTOs, validation — no business policy |
| `service` | KYC, compliance, assets, lifecycle, ForceSync, preflight, oracle retry |
| `blockchain` | `BlockchainGateway` + `TransactionSigner` (env vs KMS) |
| `persistence` | JDBC/repos; tenant-scoped SQL |
| `auth` | JWT, `TenantContext`, scopes, SoD interceptor |
| `config` | Profiles (`local` / `production` / `sepolia`) |
| `audit` | Append-only events; chain writes → `blockchain_transactions` |

**Patterns**

- Inject `TransactionSigner` — production requires KMS env gate when mandated.  
- Oracle worker: bounded retry → `FAILED_ON_CHAIN`; ForceSync four-eyes.  
- Catalog: single indexed query; limit ≤ 100; no N+1.  
- Package root: `com.rwa` (not illustrative `com.vaultguard` from old drafts).

---

## 7. Frontend componentization & UI system

### Structure

| Area | Pattern |
|------|---------|
| `app/` | Thin routes for two workspaces (`/dashboard`, `/governance`) |
| `features/{auth,investor,governance,assets}/` | `api`, `components`, `hooks`, `lib` — **no `compliance` / `audit` folders** |
| `shared/ui` | Primitives (`Button`, `Alert`, `AuthShell`, `WorkspaceAppHeader`, …) — no business ACL |
| `shared/ui/WorkspaceAppHeader` | Logged-in header: logo + role badge + in-header menu |
| `features/auth/components/PasswordInput` | **Required** for every password field (eye toggle, a11y) |
| `shared/api` | Types + error mapping |
| BFF `app/api/backend/[...path]` | Role-path matrix (investor / super admin); strip linkage probe params; attach Bearer + wallet + tenant |
| Config | `publicRuntime.ts` (client) + `serverRuntime.ts` (`BACKEND_API_BASE_URL`, server-only) |

### Design tokens (institutional — avoid generic AI palettes)

```css
:root {
  --vg-bg: #0f1419;
  --vg-surface: #1a222c;
  --vg-text: #e8eef4;
  --vg-muted: #8b9aab;
  --vg-accent: #2f6fed;
  --vg-accent-soft: #1e3a5f;
  --vg-success: #1f8a5b;
  --vg-warning: #c49214;
  --vg-danger: #c23b3b;
  --vg-border: #2a3542;
  --vg-radius: 8px;
  --vg-font-display: "Source Serif 4", Georgia, serif;
  --vg-font-body: "IBM Plex Sans", system-ui, sans-serif;
  --vg-font-mono: "IBM Plex Mono", ui-monospace, monospace;
}
```

Canonical source: `src/app/globals.css` (dark default + light theme overrides same `--vg-*`).

**UI rules**

- Workspaces: calm surfaces, clear hierarchy; brand on login/marketing hero only.  
- No dashboard-in-hero clutter; marketplace sections = one purpose each.  
- Cards only when they wrap an interaction (forms, confirm).  
- Prefer CSS variables over ad-hoc hex.  
- Do not default to purple gradients, cream+terracotta tropes, or emoji decoration.  
- Login/register: `AuthShell` + `PasswordInput` + `Alert`/`Button`; no MFA/invite fields.

### UX hooks

- KYC: poll with jitter; stop at terminal.  
- Transfer: debounce + `refreshBeforeSign`; map preflight codes to i18n.  
- Secure cookies: `httpOnly`, `SameSite=Lax`, `secure` in production.  
- i18n: `en` / `es` / `pt` via `LocaleProvider`.

---

## 8. Security

| Threat | Control |
|--------|---------|
| Non-compliant transfer | On-chain hook |
| Early `onChainVerified` | Pending-chain states until receipt |
| Compromised operator | Scopes + ForceSync four-eyes (two admins) + KMS + rate-limit + audit |
| Oracle failure | Bounded retry; ForceSync with HSM/KMS |
| IDOR / private enum | Ownership + linkage + JWT + generic deny + audit |
| Key leak | No plaintext keys in git; KMS interface + production fail-fast |
| Doc scrape | JWT + `READ_OWN_DOCS` / SUPER_ADMIN scope |
| Browser secret leak | BFF only; no signing keys on Vercel |
| Auth surface | Password + role only; no MFA/invite product path (SEC-10) |
| SoD collapse (2 roles) | Compensate: multi-admin ForceSync four-eyes, append-only audit hash chain, rate-limit approve/invite (SEC-11) |

Fallbacks match FUNCTIONAL §5 / based_rules §3.

---

## 9. Performance

| Area | Rule |
|------|------|
| Catalog (investor) | Indexed `(tenant_id, status, visibility)`; limit ≤ 100 |
| Governance list | Index `(tenant_id, created_by, status)` for admin’s own contracts |
| ACL indexes | `(asset_id, identity_hash)`, `(asset_id, wallet_address)` |
| Preflight | Debounce; staticcall only when needed |
| Oracle | Async worker; never unbounded HTTP wait |
| Identity | Shared IR preferred |

Targets: API 99.9%; p95 < 500 ms excl. chain; attest within 15 min of approve (SLO).

---

## 10. Deploy & ops

| Layer | Production |
|-------|------------|
| Config | Single `application.yml` (local defaults + `production` / `sepolia` documents) |
| Database | Neon PostgreSQL (JDBC; secrets via env in production) |
| Profile | `SPRING_PROFILES_ACTIVE=production` (+ RPC/contracts env) |
| Chain | local `mvp`/`trex` · production/sepolia `trex` |
| Frontend | `publicRuntime` + `serverRuntime` + Vercel `NEXT_PUBLIC_*` / `BACKEND_API_BASE_URL` |
| Blockchain | `config/local.json`; Sepolia deploy via `deploy:sepolia` |
| Local | `.\root\scripts\stack.ps1` + `stack-config.sh` → `.local-runtime/` |

**ForceSync:** A request → B ≠ A approve → HSM/KMS broadcast → receipt → verified.  
**Incident:** detect → triage → contain (pause) → remediate → unpause after root cause.  
**Deploy order:** chain → Elastic Beanstalk backend → Vercel frontend.

### Checklist (living) — Phase F status

| Item | Status |
|------|--------|
| **Two-role model (SUPER_ADMIN + INVESTOR); officer/auditor removed** | **Planned** (role refactor) |
| **Contract linkage enforced (admin `created_by`; investor public/invite/contracted)** | **Planned** |
| **Consolidate `/compliance` + `/audit` into `/governance`** | **Planned** |
| Auth role guard on every mutating route | **Done** (interceptor + tests; matrix to retarget SUPER_ADMIN) |
| Pending-chain until receipt; no silent verify | **Done** |
| Marketplace JWT linkage + re-check on subscribe | **Done** |
| Per-contract suite + shared IR preferred | **Done** |
| Preflight advisory; chain final | **Done** |
| Production Swagger off; trex; KMS gate | **Done** |
| FE feature folders + design tokens (`--vg-*`) | **Done** |
| Password show/hide on all auth password fields | **Done** (`PasswordInput`) |
| Auth without MFA/invite product UX | **Done** |
| Forge security tests green | **Done** |
| Cloud KMS EIP-155 signing (not stub) | **Remaining** |
| External security audit | **Remaining** |
| DR / HA PostgreSQL + runbooks | **Remaining** |
| Mainnet deploy | **N/A** until explicitly requested |

**Must not:** RESTRICTED / invites / anonymous catalog / investor-created contracts / plaintext keys in repo / MFA-as-required product without based_rules update.

### G1–G10 readiness (Phase F)

| Gate | Criterion | Result | Evidence / notes |
|------|-----------|--------|------------------|
| G1 | ERC-3643 / T-REX hooks; forge security green | **Pass** | `npm run test:security`; shared IR tests |
| G2 | Two-role RBAC (investor / super admin) + contract linkage | **Planned** | Retarget `ApiAuthorizationInterceptor` + tests to two roles |
| G3 | KYC states; no silent `onChainVerified` | **Pass** | `ComplianceApplicationServiceTest` |
| G4 | Bounded oracle retry + ForceSync four-eyes | **Pass** | Oracle retry + ForceSync tests |
| G5 | Marketplace PUBLIC/PRIVATE + subscribe ACL | **Pass** | Marketplace happy-path + ACL tests |
| G6 | FE two workspaces (`/dashboard`, `/governance`) + BFF + Vitest gates | **Planned** | Remove compliance/audit UI; retarget role chrome tests |
| G7 | Production: trex, Swagger off, no legacy admin token | **Pass** | Production profile smoke |
| G8 | KMS/HSM signer path (env gate + fail-closed stub) | **Partial** | Gate wired; EIP-155 cloud signing not done |
| G9 | Ops: audit trail, `blockchain_transactions`, rate limits | **Pass** | ForceSync/oracle audits; rate-limit tests |
| G10 | Mainnet / external audit / DR cutover | **N/A** / **Fail** | No mainnet; audit + DR not executed |

**Blockers before mainnet:** G8 EIP-155 KMS; G10 external audit + DR; production PostgreSQL RLS evidence where Docker unavailable.

---

## 11. Repo map

| Repo | Implements |
|------|------------|
| `…-blockchain` | T-REX suite, per-contract deploy, forge tests |
| `…-backend` | API, linkage/ACL, KYC, lifecycle, oracle, audit, signer (two-role RBAC) |
| `…-frontend` | Two workspaces, BFF, marketplace UX, Wagmi, `PasswordInput`, `WorkspaceAppHeader` |
| `root/scripts` | Local orchestration |
