# VaultGuard RWA — Foundation Rules

> **Status:** Normative product / architecture foundation.  
> **Derived specs (implementation must follow):** [`FUNCTIONAL.md`](FUNCTIONAL.md) · [`TECHNICAL.md`](TECHNICAL.md) · [`PHASED-IMPLEMENTATION-PROMPT.md`](PHASED-IMPLEMENTATION-PROMPT.md)  
> **Conflict rule:** update this file first, then refresh derived specs. Do not invent features outside these docs.  
> **Code rule:** illustrative snippets do not belong here — live code lives in the three repos under `com.rwa`, T-REX, and Next.js feature folders.

---

## 1. Product identity

|           |                                                                                                                                             |
| --------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **Name**  | **VaultGuard RWA**                                                                                                                          |
| **Why**   | *Vault* = custody; *Guard* = compliance/AML. Institutional trust for banks and investors.                                                   |
| **Core**  | Marketplace of admin-created tokenized RWA contracts with **off-chain KYC/AML** and **on-chain permissioned transfers** (ERC-3643 / T-REX). |
| **Repos** | `…-blockchain` · `…-backend` · `…-frontend` · `root/scripts`                                                                                |

**Out of scope unless this file is updated first:** `RESTRICTED` visibility · invite-token product · anonymous catalog · investor-created offerings · secondary P2P order book · tax/corporate-action modules · additional roles beyond the two below.

---

## 2. Roles & access model

VaultGuard RWA has exactly **two roles**. `COMPLIANCE_OFFICER` and `AUDITOR` are **removed** — their duties are absorbed by `SUPER_ADMIN`.

### 2.1 Role matrix

| Role            | Intent                      | On-chain (via agents / oracle)                                                     | Backend                                                                                                                                                                                        | Must never                                                                                                                |
| --------------- | --------------------------- | ---------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| **SUPER_ADMIN** | Contract manager & guardian | Identity register/remove via oracle/signer; pause; ForceSync signer; oracle config | Create/publish/pause/close **own** contracts; visibility & private ACL; **invite/revoke** investors; KYC approve/reject/revoke; subscribe/redeem approve; oracle health; ForceSync; read audit | Hold end-user private keys; write raw PII on-chain; act on contracts it does not administer                               |
| **INVESTOR**    | End user                    | `transfer` when compliant                                                          | Own KYC upload; own portfolio; browse **linked** contracts; subscribe/redeem when eligible                                                                                                     | See other users’ PII; self-approve KYC; create/manage offerings; governance; discover PRIVATE contracts without an invite |

### 2.2 Contract-linkage rule (golden rule)

**Every user only accesses contracts linked to them.**

| Role            | A contract is "linked" when…                                                                                                                              |
| --------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **SUPER_ADMIN** | it was created/administered by that admin (`created_by`)                                                                                                  |
| **INVESTOR**    | it is `PUBLIC` and `ACTIVE`, **or** the investor was invited (private grant), **or** the investor already contracted it (holds a position / subscription) |

No user may list, read, or act on a contract that is not linked to them (default deny + generic 403).

### 2.3 Other golden rules (non-negotiable)

1. Investor never approves own KYC (only SUPER_ADMIN approves).  
2. **Solidity knows wallet + identity hash only** — never the person or raw document.  
3. **Java is the only layer that knows the person and documents.**  
4. Invites to PRIVATE contracts are issued **only by SUPER_ADMIN**.  
5. ForceSync requires two distinct SUPER_ADMIN accounts (A initiates, B ≠ A approves) + HSM/KMS-ready signer.  
6. API/UI are advisory for token movement; **on-chain `canTransfer` / `isVerified` is final**.

### 2.4 Access boundaries

| Boundary                       | Rule                                                                                           |
| ------------------------------ | ---------------------------------------------------------------------------------------------- |
| Token suite (ERC-3643 / T-REX) | Identity mutations via authorized oracle/compliance agent; pause via governance agent          |
| Document gateway               | SUPER_ADMIN (or own-docs scope) only; signing txs generated by backend — never by the end user |
| Oracle                         | Reads Java approval → writes registry; if oracle is down, chain state stays cold               |
| Marketplace visibility         | Off-chain only: `PUBLIC` \| `PRIVATE` — not encoded on-chain                                   |
| Contract linkage               | SUPER_ADMIN = `created_by`; INVESTOR = public OR invite OR contracted                          |

---

## 3. Fallback & resilience scenarios

### Scenario 1 — Oracle fails after off-chain approve

| Layer  | Behavior                                                                             |
| ------ | ------------------------------------------------------------------------------------ |
| Auto   | Bounded retry with backoff; status stays pending-chain / failed-on-chain             |
| Manual | SUPER_ADMIN ForceSync (four-eyes between two admins + HSM/KMS)                       |
| UX     | Show “Pending on blockchain”; **Buy/subscribe stay blocked until `onChainVerified`** |

### Scenario 2 — Transfer to newly non-compliant recipient

| Layer | Behavior                                                                 |
| ----- | ------------------------------------------------------------------------ |
| Chain | Reverts at execution if destination not allowed                          |
| UX    | Preflight before wallet signature; never prompt sign on failed preflight |

### Scenario 3 — Sensitive data scrape

| Layer | Behavior                                  |
| ----- | ----------------------------------------- |
| API   | JWT + ownership / linkage → generic `403` |
| Chain | No KYC PII — hash or verified flag only   |
| Audit | Log denied access attempts                |

---

## 4. Implementation order

Build in this order (see also [`PHASED-IMPLEMENTATION-PROMPT.md`](PHASED-IMPLEMENTATION-PROMPT.md)):

1. **Contracts (Foundry T-REX)** — IdentityRegistry, ModularCompliance, Token hooks, pause; forge tests for non-compliant transfer / revoke / pause. Prefer **shared IdentityRegistry**; token + compliance **per contract**.  
2. **Backend (Spring `com.rwa`)** — two-role RBAC, KYC (hash + encrypted store), sanctions adapter, `TransactionSigner` abstraction (env → KMS), marketplace ACL + contract linkage.  
3. **Oracle + ForceSync** — Bounded retry worker; four-eyes ForceSync; audit + `blockchain_transactions`.  
4. **Frontend (Next.js BFF)** — Two workspaces; KYC poll; Buy only when `APPROVED` + `onChainVerified` + linkage; transfer preflight; design tokens + feature folders.

---

## 5. Security rules (foundation)

| ID     | Rule                                                                                                                                                      |
| ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------- |
| SEC-01 | Default deny on mutating APIs: role + scope + ownership + contract linkage                                                                                |
| SEC-02 | No raw PII or document bytes on-chain                                                                                                                     |
| SEC-03 | No plaintext private keys in git, docs, or frontend; production prefers KMS/HSM                                                                           |
| SEC-04 | JWT access + refresh; HttpOnly cookies via BFF; never expose admin/signing keys to browser                                                                |
| SEC-05 | Dual enforcement: BFF path matrix **and** backend interceptor                                                                                             |
| SEC-06 | Tenant header default-deny (`X-Tenant-Id` must match JWT grants)                                                                                          |
| SEC-07 | Never escalate marketplace ACL / linkage from client probe params                                                                                         |
| SEC-08 | Rate-limit sensitive auth, approve/invite, and mutation routes                                                                                            |
| SEC-09 | Production: Swagger/OpenAPI off; legacy admin token off                                                                                                   |
| SEC-10 | Auth UX: email + password + role — **no MFA code and no admin invite code** on login/register; residual MFA/invite config is legacy and must not drive UX |
| SEC-11 | SoD compensation: with two roles, protect sensitive ops via multi-admin ForceSync four-eyes, append-only audit (hash chain), and rate-limits              |

---

## 6. Functional rules (foundation)

| ID     | Rule                                                                                                                      |
| ------ | ------------------------------------------------------------------------------------------------------------------------- |
| FUN-01 | Only SUPER_ADMIN creates/publishes contracts and manages visibility/ACL/invites                                           |
| FUN-02 | Marketplace: `PUBLIC` = any authenticated investor; `PRIVATE` = invited investors only (generic deny for non-grantees)    |
| FUN-03 | Subscribe/redeem require `APPROVED` + `onChainVerified` + linkage                                                         |
| FUN-04 | Catalog lists only contracts **linked** to the caller (SUPER_ADMIN: created_by; INVESTOR: public OR invite OR contracted) |
| FUN-05 | KYC bound to authenticated session wallet                                                                                 |
| FUN-06 | Oracle outage ≠ on-chain approval                                                                                         |
| FUN-07 | Pause stops all token movement                                                                                            |
| FUN-08 | Privileged actions are auditable (API + chain tx when applicable)                                                         |
| FUN-09 | KYC provider is swappable via adapter                                                                                     |
| FUN-10 | One role per session; workspaces: `/dashboard` (INVESTOR) · `/governance` (SUPER_ADMIN)                                   |
| FUN-11 | SUPER_ADMIN sees/acts only on contracts it administers; investor sees only linked contracts                               |

---

## 7. UI / UX rules (foundation)

| ID    | Rule                                                                                                                       |
| ----- | -------------------------------------------------------------------------------------------------------------------------- |
| UI-01 | Brand **VaultGuard RWA** is hero-level on marketing/login; workspaces stay calm and institutional                          |
| UI-02 | One job per section: one headline, short support, one primary action                                                       |
| UI-03 | Cards only when they wrap an interaction (forms, confirms) or a marketplace contract                                       |
| UI-04 | Design tokens `--vg-*` only — no ad-hoc hex; institutional palette (trust blue, not purple-glow / cream-terracotta tropes) |
| UI-05 | Hide controls the role must never use (role chrome); investor never sees management controls                               |
| UI-06 | Errors: user-safe copy only — no stack traces in UI body                                                                   |
| UI-07 | All password fields use shared `PasswordInput` with show/hide (eye) toggle and accessible labels                           |
| UI-08 | Transfer: debounce preflight; refresh before sign; never prompt signature on failed preflight                              |
| UI-09 | KYC poll 5–15s with jitter until terminal or verified, then stop                                                           |
| UI-10 | Motion: 2–3 purposeful transitions max per critical flow — no decorative noise                                             |
| UI-11 | i18n: `en` / `es` / `pt`; map backend errors to message keys; no orphan compliance/audit copy                              |
| UI-12 | Theme: dark ops console default + light override via same `--vg-*` variables                                               |
| UI-13 | Every logged-in header shows logo + role badge + in-header menu (`WorkspaceAppHeader`)                                     |

---

## 8. Technical rules (foundation)

| ID     | Rule                                                                                                                                               |
| ------ | -------------------------------------------------------------------------------------------------------------------------------------------------- |
| TEC-01 | Stack: Foundry T-REX · Spring Boot (`com.rwa`) · Next.js App Router + BFF · `root/scripts`                                                         |
| TEC-02 | Prefer shared IdentityRegistry; resolve token/compliance **per contract**                                                                          |
| TEC-03 | Backend layers: `api` → `service` → `persistence` / `blockchain`; controllers hold no business policy                                              |
| TEC-04 | Frontend: `features/{auth,investor,governance,assets}/` + `shared/ui` + `shared/api`                                                               |
| TEC-05 | BFF: cookies → Bearer + `X-Investor-Wallet` + `X-Tenant-Id`; strip ACL/linkage probe params                                                        |
| TEC-06 | Config: no `.env` committed in repos — `application.yml` profiles · `publicRuntime` / `serverRuntime` · `config/local.json` (+ gitignored sepolia) |
| TEC-07 | Wait for receipt before setting `onChainVerified` / `transactionHash`                                                                              |
| TEC-08 | `TransactionSigner` injectable: env key (local) → KMS/HSM (production gate)                                                                        |
| TEC-09 | Agents use separate keys: compliance (oracle), governance (pause), lifecycle, transfer manager — never end-user keys                               |
| TEC-10 | Catalog: indexed tenant query; page limit ≤ 100; no N+1; index admin `created_by` and ACL                                                          |
| TEC-11 | Local orchestration via `root/scripts/stack.ps1` / `stack.sh`                                                                                      |
| TEC-12 | Deploy order: chain → backend (EB/production) → frontend (Vercel BFF); no private keys on Vercel                                                   |
| TEC-13 | Contract creation deploys a per-contract token suite (`DeployAdditionalTrexToken`) on the shared IR; suite addresses persisted per offering        |

---

## 9. Componentization principles

### Blockchain

- T-REX modules: Token · IdentityRegistry (shared) · ModularCompliance (per contract) · compliance modules (pause, limits, jurisdiction as needed).  
- Governance helpers (e.g. ForceSyncGovernor 2-of-N) keep four-eyes on-chain where applicable.  
- Legacy MVP under `src/legacy/` is non-production.

### Backend

- Package root: `com.rwa` (`api`, `auth`, `service`, `blockchain`, `persistence`, `config`, `audit`, `tenancy`).  
- Two roles only; SUPER_ADMIN scopes = union of governance + KYC + lifecycle + audit.  
- Oracle worker + ForceSync service are first-class; audit append-only.  
- Profiles: `local` · `production` · `sepolia` overlay in single `application.yml`.

### Frontend

- Thin `app/` routes; business UI in `features/*` — only `investor` and `governance` workspaces.  
- Shared primitives: `AuthShell`, `LegalPageShell`, `WorkspaceShell`, `WorkspaceAppHeader`, `WorkspacePanel`, `ExperienceFooter`, `Button`, `Alert`, `PasswordInput`, theme/locale chrome.  
- Never put marketplace ACL, linkage, or SoD solely in the client.

---

## 10. Document map

| Document                                                             | Owns                                                                                     |
| -------------------------------------------------------------------- | ---------------------------------------------------------------------------------------- |
| **This file**                                                        | Product identity, two-role model, linkage rule, fallbacks, SEC/FUN/UI/TEC foundation IDs |
| [`FUNCTIONAL.md`](FUNCTIONAL.md)                                     | Screens, business rule IDs (BR-*), acceptance, detailed UX                               |
| [`TECHNICAL.md`](TECHNICAL.md)                                       | Architecture, API, invariants, tokens, deploy checklist, G1–G10                          |
| [`PHASED-IMPLEMENTATION-PROMPT.md`](PHASED-IMPLEMENTATION-PROMPT.md) | Lean agent phase prompts                                                                 |
| [`README.md`](README.md)                                             | Index + repo table                                                                       |

> **Removed roles:** `COMPLIANCE_OFFICER` and `AUDITOR` are no longer part of the product. Duties (KYC decisions, lifecycle approval, audit read) are absorbed by `SUPER_ADMIN`. Reintroduce only by updating this file first.
