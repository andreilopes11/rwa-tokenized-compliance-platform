# Incident response (Phase 6 / G10)

Companion to [5-operational-runbooks.md](../5-operational-runbooks.md).

## Immediate actions

1. **Pause** — Governance pause on affected offering token(s); set offering status PAUSED.
2. **Contain** — Tighten CORS / revoke refresh tokens / disable ForceSync if signer compromised.
3. **Rotate** — JWT secret, document encryption key, RPC credentials, agent keys (never commit).
4. **Replay / reconcile** — Oracle retry queue + ForceSync four-eyes for `FAILED_ON_CHAIN` / pending receipts.
5. **Audit** — Export CSV (`/api/admin/audit-events/export`) and retain with integrity hash.

## DR / restore drill (record results)

| Step | Owner | Result | Date |
|------|-------|--------|------|
| Snapshot PostgreSQL | | _pending_ | |
| Restore to staging | | _pending_ | |
| Smoke login + /me + KYC + publish + subscribe | | _pending_ | |
| External security review | | _pending_ | |

G10 remains **pending** until restore and external audit rows are filled.
