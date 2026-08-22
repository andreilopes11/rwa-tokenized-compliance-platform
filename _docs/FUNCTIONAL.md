# VaultGuard RWA — Functional Specification

Derived from [`based_rules.md`](based_rules.md).  
How to implement: [`TECHNICAL.md`](TECHNICAL.md).

**Product:** VaultGuard RWA — institutional marketplace of admin-created tokenized RWA contracts with off-chain KYC/AML and on-chain permissioned transfers (ERC-3643 / T-REX).  
**Brand intent:** Vault (custody) + Guard (compliance) — trust for banks and investors.

> **Two roles only.** `COMPLIANCE_OFFICER` and `AUDITOR` are **removed**; their duties are absorbed by `SUPER_ADMIN`.

---

## 1. Glossary

| Term                    | Definition                                                                                          |
| ----------------------- | --------------------------------------------------------------------------------------------------- |
| **Contract / offering** | Admin-created tokenized RWA quota (`AssetOffering`) backed by one ERC-3643 token suite              |
| **Marketplace**         | Authenticated catalog of `ACTIVE` contracts **linked** to the caller                                |
| **Visibility**          | Discovery ACL: `PUBLIC` \| `PRIVATE` only (off-chain; not encoded on-chain)                         |
| **Linkage**             | A contract a user may access: SUPER_ADMIN = `created_by`; INVESTOR = public OR invite OR contracted |
| **Invite**              | SUPER_ADMIN grant of PRIVATE contract access to an investor (`identityHash` / wallet)               |
| **Identity**            | Off-chain person + documents; on-chain only `identityHash` / verified wallet                        |
| **Oracle**              | Trusted bridge: reads Java approval → writes registry on-chain                                      |
| **On-chain final**      | Transfer/mint legality decided by the token suite at execution                                      |
| **ForceSync**           | Four-eyes recovery between two SUPER_ADMIN accounts when oracle cannot write identity               |

---

## 2. Roles & access model

Aligns with based_rules §2.

| Role            | Intent                      | May                                                                                                                                                                                                                            | Must never                                                                                                                |
| --------------- | --------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| **SUPER_ADMIN** | Contract manager & guardian | Create/publish/pause/close **own** contracts; visibility & private ACL; **invite/revoke** investors; KYC approve/reject/revoke; subscribe/redeem approve; oracle health; ForceSync (four-eyes); read audit; HSM/key ops config | Hold end-user private keys; write raw PII on-chain; act on contracts it does not administer                               |
| **INVESTOR**    | End user                    | Own KYC upload; own portfolio; browse **linked** contracts; subscribe/redeem when eligible; transfer when allowed                                                                                                              | See other users’ PII; self-approve KYC; create/manage offerings; governance; discover PRIVATE contracts without an invite |

### Golden rules

1. Investor never approves own KYC (only SUPER_ADMIN approves).  
2. Solidity knows **wallet + identity hash**, never the person or raw document.  
3. Java is the only layer that knows the person and documents.  
4. Invites to PRIVATE contracts are issued **only by SUPER_ADMIN**.  
5. ForceSync requires two distinct SUPER_ADMIN accounts (A initiates, B ≠ A approves).  
6. On-chain checks are final; API/UI are advisory.  
7. **Contract linkage:** users only see/act on contracts linked to them.

### Workspaces

| Role        | Route         |
| ----------- | ------------- |
| INVESTOR    | `/dashboard`  |
| SUPER_ADMIN | `/governance` |

One role per session. Legacy `/admin` · `/compliance` · `/audit` → `/governance`.

---

## 3. Marketplace model

| Visibility | Discover                   | Subscribe / redeem     |
| ---------- | -------------------------- | ---------------------- |
| `PUBLIC`   | Any authenticated investor | After KYC gate (BR-14) |
| `PRIVATE`  | Invited investors only     | Same + KYC gate        |

- Non-grantees must not learn PRIVATE contracts exist (generic deny).  
- **Linkage always applies:** SUPER_ADMIN sees only `created_by` contracts; INVESTOR sees public + invited + contracted.  
- Visibility is discovery/ACL only; transfer legality stays on-chain.  
- **Out of scope:** `RESTRICTED`, invitation tokens, anonymous catalog, investor-created contracts, roles beyond the two.

### Offering lifecycle

`DRAFT` → publish (deploys per-contract token suite) → `ACTIVE` → optional `PAUSED` / `CLOSED`.  
Only **SUPER_ADMIN** creates, publishes, sets visibility, and grants/revokes private access (`identityHash` required).

---

## 4. Business rules

| ID    | Rule                                                                                    | Foundation      |
| ----- | --------------------------------------------------------------------------------------- | --------------- |
| BR-01 | Wallet must be on-chain compliant to receive tokens                                     | FUN / TEC       |
| BR-02 | Both parties must remain compliant for transfer (checked at execution)                  | Scenario 2      |
| BR-03 | No raw KYC/PII on-chain — hashes/references only                                        | SEC-02          |
| BR-04 | Revoked wallets cannot send or receive                                                  | FUN             |
| BR-05 | Privileged actions are auditable (API + chain tx when applicable)                       | FUN-08          |
| BR-06 | Pause stops all token movement                                                          | FUN-07          |
| BR-07 | KYC provider is swappable via adapter                                                   | FUN-09          |
| BR-08 | Investor KYC bound to authenticated session wallet                                      | FUN-05          |
| BR-09 | Investor cannot self-approve KYC                                                        | Golden          |
| BR-10 | Only SUPER_ADMIN runs governance ops (create/pause/ForceSync/KYC/lifecycle)             | Golden          |
| BR-11 | Oracle outage ≠ on-chain approval (stay pending / failed-on-chain)                      | FUN-06          |
| BR-12 | Subscribe/redeem require `APPROVED` + `onChainVerified` + linkage                       | FUN-03          |
| BR-13 | Only SUPER_ADMIN creates/publishes contracts and manages visibility/ACL/invites         | FUN-01          |
| BR-14 | Marketplace linkage uses JWT-bound identity/wallet only (no client probe escalation)    | SEC-07          |
| BR-15 | Catalog lists only contracts **linked** to the caller                                   | FUN-04 / FUN-11 |
| BR-16 | SUPER_ADMIN sees/acts only on contracts it administers (`created_by`)                   | FUN-11          |
| BR-17 | Auth forms: email + password (+ role); **no MFA code and no invite code** in product UX | SEC-10          |
| BR-18 | All password fields expose show/hide via shared `PasswordInput`                         | UI-07           |
| BR-19 | Every logged-in header shows logo + role badge + in-header menu                         | UI-13           |

---

## 5. KYC & fallbacks

| State                     | Meaning                        | Buy / transfer                          |
| ------------------------- | ------------------------------ | --------------------------------------- |
| `SUBMITTED` / `IN_REVIEW` | Off-chain review               | Disabled                                |
| `APPROVED_PENDING_CHAIN`  | Admin approved; oracle pending | Disabled — show “Pending on blockchain” |
| `APPROVED`                | Receipt + chain confirm        | Enabled if linked                       |
| `REJECTED` / `REVOKED`    | Denied / removed               | Disabled                                |
| `FAILED_ON_CHAIN`         | Chain write failed             | Disabled; ops fallback                  |

**Scenario 1 clarification:** UI must show pending-chain clearly; **purchase remains blocked until `onChainVerified`**. Off-chain approval alone is never enough.

### Fallback matrix

| Scenario                                  | Automatic                     | Manual                                      | UX                           |
| ----------------------------------------- | ----------------------------- | ------------------------------------------- | ---------------------------- |
| Oracle fails after admin approve          | Bounded retry with backoff    | SUPER_ADMIN ForceSync (four-eyes + HSM/KMS) | Pending-on-chain banner      |
| Transfer to newly non-compliant recipient | Chain reverts at execution    | —                                           | Preflight before wallet sign |
| Third-party document scrape               | JWT + ownership/linkage → 403 | Audit event                                 | Generic forbidden            |

---

## 6. Screens

### Auth

| ID       | Behavior                                                                                      |
| -------- | --------------------------------------------------------------------------------------------- |
| AUTH-S01 | Login: role (investor / super admin) + email + password; `PasswordInput` with eye toggle      |
| AUTH-S02 | Register: email + password + confirm (+ wallet when required); strength meter on new password |
| AUTH-S03 | No MFA step and no admin invite field in UI or BFF payloads                                   |

### Investor `/dashboard`

| ID      | Behavior                                          |
| ------- | ------------------------------------------------- |
| INV-S01 | Overview / status                                 |
| INV-S02 | Wallet-bound KYC submit + poll                    |
| INV-S03 | KYC + on-chain verified                           |
| INV-S04 | Portfolio positions                               |
| INV-S05 | Public marketplace (ACTIVE PUBLIC)                |
| INV-S06 | Private marketplace (invited only)                |
| INV-S07 | Transfer: debounced preflight → sign; chain final |
| INV-S08 | Own activity                                      |

Only **linked** contracts appear. Subscribe/redeem controls disabled until BR-12.

### Governance `/governance` (SUPER_ADMIN)

Single consolidated workspace absorbing former compliance + audit surfaces:

| ID     | Behavior                                                                     |
| ------ | ---------------------------------------------------------------------------- |
| SA-S01 | Overview: my contracts (`created_by`), oracle health                         |
| SA-S02 | Contracts: create (wizard → deploy suite → publish), visibility, pause/close |
| SA-S03 | Invites: grant/revoke private access per contract                            |
| SA-S04 | KYC queue: approve / reject / revoke                                         |
| SA-S05 | Lifecycle: subscription / redemption approve                                 |
| SA-S06 | Oracle health + ForceSync initiate + second approve (four-eyes)              |
| SA-S07 | Audit: read-only timeline, KYC history, chain txs, export, ForceSync trail   |

SUPER_ADMIN lists only contracts it administers.

---

## 7. UX / UI rules

| Area           | Rule                                                                                                              |
| -------------- | ----------------------------------------------------------------------------------------------------------------- |
| Brand          | Product name **VaultGuard RWA** is a hero-level signal on marketing/login; workspaces stay calm and institutional |
| Header         | Every logged-in header = logo + role badge + in-header menu (`WorkspaceAppHeader`)                                |
| Auth           | Role-based login/register; **no MFA / invite UX** (BR-17); password visibility via `PasswordInput` (BR-18)        |
| Tokens         | Use `--vg-*` design tokens only (see TECHNICAL §7)                                                                |
| Marketplace    | Contracts as cards with visibility badge (Public / Invite) + eligibility state                                    |
| KYC poll       | 5–15s jitter until terminal or verified; then stop                                                                |
| Wallet binding | Session wallet = form wallet = connected wallet on submit                                                         |
| Transfer       | Debounce preflight; refresh before sign; never prompt signature on failed preflight                               |
| Errors         | User-safe copy only (no stack traces / internal codes in UI body)                                                 |
| Role chrome    | Investor never sees management controls; hide anything the role must never use                                    |
| Density        | One job per section: one headline, one short support line, one primary action                                     |
| a11y           | Labels, `aria-invalid` / `aria-describedby`, live regions on alerts; password toggle `aria-pressed`               |
| i18n           | `en` / `es` / `pt`; remove orphan compliance/audit copy                                                           |

Transfer failure meanings: recipient/sender not compliant, token paused, wrong network, chain not ready, wallet rejected.

---

## 8. Acceptance

- [ ] Only SUPER_ADMIN can create/publish contracts, invite, approve KYC, approve lifecycle, pause, ForceSync  
- [ ] SUPER_ADMIN sees only contracts it administers (`created_by`)  
- [ ] PUBLIC ACTIVE visible to any investor; PRIVATE only to invited investors  
- [ ] Non-grantee cannot discover PRIVATE details  
- [ ] Investor sees only linked contracts (public / invite / contracted)  
- [ ] Subscribe blocked without APPROVED + onChainVerified + linkage  
- [ ] Investor cannot self-approve KYC or reach governance  
- [ ] Revoke / pause block token movement on-chain  
- [ ] No raw PII on-chain; document access is ownership/admin-scoped  
- [ ] Login/register have no MFA or invite fields; all password fields have show/hide eyes  
- [ ] No `/compliance` or `/audit` workspace remains  

---

## 9. Out of scope

`RESTRICTED` · invitation-token product · anonymous catalog · investor-created contracts · secondary P2P order book · tax/corporate-action product modules · roles beyond SUPER_ADMIN / INVESTOR · MFA/invite as live product auth.

Reintroduce only by updating [`based_rules.md`](based_rules.md) then this file and [`TECHNICAL.md`](TECHNICAL.md).
