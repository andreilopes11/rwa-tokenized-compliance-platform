# ADR-005: BFF and Backend Security Boundary

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Application Security

## Context

The browser needs workspace and wallet context but must never receive signing keys or become the authority for tenant, role, or marketplace linkage. Browser-visible route guards alone are vulnerable to direct API calls and parameter tampering.

## Decision

Use a Next.js BFF with HttpOnly JWT cookies. The BFF forwards a Bearer token plus the JWT-bound `X-Investor-Wallet` and `X-Tenant-Id` headers, strips linkage-probe parameters, and applies a role-path matrix. Spring Boot independently enforces default-deny authorization, ownership, tenant grants, and linkage through its authorization interceptor and services. Production disables Swagger/OpenAPI and legacy admin tokens.

## Consequences

- Signing keys remain in backend or KMS infrastructure, never in the browser or Vercel.
- The wallet in request path/body must match the authenticated session wallet.
- Safe, generic forbidden errors reduce private-resource enumeration.
- BFF and backend authorization require separate tests.

## References

- `_docs/based_rules.md` SEC-01 through SEC-10 and TEC-04 through TEC-08
- `_docs/TECHNICAL.md` sections 3, 4, and 8
