# Phased Implementation Prompt — VaultGuard RWA

Lean agent/dev guide.  
**Foundation:** [`based_rules.md`](based_rules.md)  
**Specs:** [`FUNCTIONAL.md`](FUNCTIONAL.md) + [`TECHNICAL.md`](TECHNICAL.md)

Do not invent features outside those docs. Two roles only (SUPER_ADMIN + INVESTOR). No RESTRICTED / invitation-token product / anonymous catalog / investor-created contracts / plaintext keys / MFA-as-required product UX / roles beyond the two.

---

## Master prompt (paste once)

```text
You are implementing VaultGuard RWA — institutional RWA marketplace with
off-chain KYC/AML and on-chain ERC-3643 / T-REX final enforcement.

Read fully before coding:
- _docs/based_rules.md
- _docs/FUNCTIONAL.md
- _docs/TECHNICAL.md

Repos: blockchain, backend, frontend, root/scripts

Non-negotiable (based_rules + specs):
1. Two roles only: SUPER_ADMIN (absorbs all management + KYC + lifecycle + audit + invites) and INVESTOR. Officer/Auditor removed.
2. Investor never self-approves KYC; investor never reaches governance.
3. Contract linkage: SUPER_ADMIN sees only created_by; INVESTOR sees public OR invite OR contracted.
4. Solidity knows wallet + identityHash only — never raw PII.
5. Oracle / signer writes identity on-chain; ForceSync is four-eyes (two admins) + HSM/KMS-ready.
6. On-chain canTransfer / isVerified is final; API/UI advisory.
7. Marketplace: SUPER_ADMIN-only create/publish/visibility/invite; PUBLIC|PRIVATE; JWT-bound linkage.
8. Subscribe requires APPROVED + onChainVerified + linkage.
9. Auth UX: email + password + role only — no MFA/invite fields; PasswordInput on all password fields.
10. Follow TECHNICAL UI tokens (--vg-*) + WorkspaceAppHeader; minimal diffs; tests per phase gate.

Work ONE PHASE at a time. Summarize, test, stop and wait.
```

---

## Phase order (based_rules §4)

```text
Phase A  Contracts (Solidity / T-REX)     ← based_rules step 1
Phase B  Backend security & services      ← based_rules step 2
Phase C  Oracle + ForceSync resilience    ← based_rules step 3
Phase D  Frontend workspaces + UX         ← based_rules step 4
Phase E  Marketplace ACL + E2E verify     ← product layer
Phase F  Production gate (trex, KMS, ops)
```

---

## Phase A — Contracts

```text
Execute Phase A only (blockchain).
Implement/harden ERC-3643 style suite: identity register/remove, canTransfer hooks,
pause, forge tests (non-compliant transfer reverts; revoke blocks; pause blocks).
Visibility stays off-chain. Prefer shared IdentityRegistry for marketplace tokens.
Run forge test / test:security. Stop with results.
```

**Exit:** forge green; non-compliant path proven.

---

## Phase B — Backend

```text
Execute Phase B only (backend).
Two-role RBAC: UserRole = {INVESTOR, SUPER_ADMIN} (legacy ADMIN → SUPER_ADMIN);
RoleScopePolicy gives SUPER_ADMIN the union (governance + KYC + lifecycle + audit).
Flyway migration: role CHECK + migrate existing officer/auditor rows → SUPER_ADMIN;
add asset_offerings.created_by (+ index tenant_id,created_by,status).
ApiAuthorizationInterceptor: retarget kyc/lifecycle/assets/force-sync/audit to SUPER_ADMIN;
fix /api/admin/investors/*/compliance-profile gap; drop or enforce GOVERNANCE_ORACLE.
Linkage: governance list filtered by created_by; investor catalog = public OR invite OR contracted.
KYC service (hash docs, no raw PII), sanctions adapter, TransactionSigner abstraction, ownership on docs.
Auth DTOs: no mfaCode / inviteCode on login/register.
States: APPROVED_PENDING_CHAIN / FAILED_ON_CHAIN; never silent onChainVerified.
Tests: two-role 403s, linkage deny, ownership deny. Stop with results.
```

**Exit:** two-role RBAC + linkage + KYC state tests green.

---

## Phase C — Oracle & ForceSync

```text
Execute Phase C only.
Bounded oracle retry; ForceSync initiate ≠ approve principal; HSM/KMS-ready signer path.
Audit + blockchain_transactions on chain writes. Stop with results.
```

**Exit:** dual-approval + retry tests green.

---

## Phase D — Frontend

```text
Execute Phase D only (frontend).
Two workspaces only: /dashboard (INVESTOR) and /governance (SUPER_ADMIN).
Remove features/compliance + features/audit and routes /compliance /audit;
consolidate KYC queue, lifecycle approve, oracle, ForceSync, audit-read into /governance.
Every logged-in header uses WorkspaceAppHeader (logo + role badge + in-header menu).
Auth: AuthShell + PasswordInput on all password fields; no MFA/invite UI.
Investor: KYC poll, marketplace cards (linked only), Buy only when APPROVED+verified+linkage,
transfer preflight before sign. Governance: my-contracts table (created_by), create wizard, invites.
BFF/middleware: two-role path matrix; Bearer + X-Investor-Wallet; strip linkage probes.
i18n: remove orphan compliance/audit copy. Apply --vg-* tokens; hide role-forbidden controls.
Vitest for critical gates. Stop with results.
```

**Exit:** two-workspace role chrome + KYC/buy + linkage + password visibility covered by tests.

---

## Phase E — Marketplace + verify

```text
Execute Phase E only.
PUBLIC/PRIVATE catalog with linkage (admin created_by; investor public/invite/contracted);
SUPER_ADMIN invite grant/revoke; re-check linkage on subscribe.
Contract creation deploys per-contract suite (DeployAdditionalTrexToken) on publish.
Happy path + private/non-linked deny; rate-limit/generic 403.
Run stack verify (or project-equivalent). Fix blockers only. Stop with evidence.
```

**Exit:** E2E path proven (create → invite → subscribe); non-linked deny proven; verify green or failures listed.

---

## Phase F — Production readiness

```text
Execute Phase F only.
Confirm production profile: trex, Swagger off, KMS env gate, no legacy admin token.
Config in application.yml / publicRuntime+serverRuntime / config/local.json (no committed `.env`).
Update TECHNICAL checklist done/remaining. G1–G10 readiness table.
No mainnet deploy unless asked.
```

**Exit:** readiness report + explicit blockers.  
**Living report:** [`TECHNICAL.md`](TECHNICAL.md) §10 checklist + G1–G10 table.

---

## Agent rules

| Do                                        | Don’t                                                               |
| ----------------------------------------- | ------------------------------------------------------------------- |
| Read based_rules + FUNCTIONAL + TECHNICAL | Paste large unrelated code into docs                                |
| Minimal diff; match style                 | Drive-by refactors                                                  |
| Phase tests                               | Skip role / linkage tests                                           |
| Stop after each phase                     | Start next without confirmation                                     |
| English code/comments as repo             | Commit secrets                                                      |
| Use PasswordInput for passwords           | Reintroduce MFA/invite UX without based_rules update                |
| Keep two roles only                       | Reintroduce COMPLIANCE_OFFICER / AUDITOR without based_rules update |
