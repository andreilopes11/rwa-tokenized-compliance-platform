# Phase 6 — Production readiness & G1–G10 status

Updated: 2026-08-26. Derived from `IMPLEMENTATION-PROMPTS.md` §8–9.

## Gate status

| Gate | Criterion | Status | Notes |
|------|-----------|--------|-------|
| G1 | T-REX hooks, revoke, pause, Forge | **Done** | Blockchain `npm run test:security` |
| G2 | Two roles, scopes, tenant, ownership, linkage | **Done** | SUPER_ADMIN + INVESTOR; `created_by` linkage |
| G3 | KYC states + receipt-before-verified | **Done** | Oracle / ForceSync path |
| G4 | Bounded retry + ForceSync A≠B | **Done** | Worker + four-eyes tests |
| G5 | PUBLIC/PRIVATE, invites, no enumeration | **Done** | Phase 5 E2E scenarios |
| G6 | Two workspaces, BFF, cookies, a11y | **Done** | `/dashboard` + `/governance`; Vitest |
| G7 | Prod profile, Swagger off, CORS, secrets | **Done** | HTTPS CORS fail-fast; Swagger off; graceful shutdown |
| G8 | KMS/HSM real or fail-closed | **Partial** | Fail-closed gate + stub signer; EIP-155 cloud signing not wired |
| G9 | Audit, tx, health, metrics, logs, rate limits | **Done** | CSV export, Micrometer domain meters, auth/mutation limits, readiness |
| G10 | Deploy, DR/restore, external audit | **Pending** | Runbooks present; restore drill / external audit not executed |

## Production checklist (ops)

1. Rotate JWT, document encryption key, RPC credentials before go-live.
2. Set `CORS_ALLOWED_ORIGINS` to HTTPS Vercel origin(s) only.
3. Set `APP_BLOCKCHAIN_REQUIRE_KMS_SIGNER=true` and KMS key ids (or keep Sepolia-only with documented exception).
4. Deploy order: blockchain addresses → backend → frontend BFF; smoke after each.
5. Verify `/actuator/health/liveness` (ping) and `/actuator/health/readiness` (db+blockchain+kycProvider).
6. Confirm Prometheus scrapes `rwa.*` meters; audit CSV via `/api/admin/audit-events/export`.
7. Execute PostgreSQL backup restore drill and record evidence (see Execution Guide §5).
8. Complete [secret-rotation-checklist.md](secret-rotation-checklist.md) before go-live.
9. Follow [6-incident-response.md](../6-incident-response.md) for pause / contain / rotate / reconcile.

## Commands

```powershell
.\root\scripts\verify.ps1
```

Or component-wise as in `IMPLEMENTATION-PROMPTS.md` §8.
