# ADR-007: Marketplace Visibility and Invite Model

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Product and Security

## Context

The marketplace must support both public offerings available to all authenticated investors and private offerings restricted to selected investors. Private offerings must not be discoverable by non-invited users, preventing enumeration attacks while maintaining a clear authorization model for SUPER_ADMIN to grant access.

## Decision

Implement a two-tier visibility model:

- **PUBLIC**: Any authenticated investor may discover and access these ACTIVE offerings in the marketplace catalog.
- **PRIVATE**: Only explicitly invited investors (via SUPER_ADMIN grant) may discover and access these offerings.

Visibility is stored and enforced off-chain only. Invites are identity-scoped (`identityHash` or wallet address) and managed exclusively by the SUPER_ADMIN who created the offering (`created_by` match required). Non-invited users receive a generic `MARKETPLACE_FORBIDDEN` error when attempting to access private offerings, preventing existence confirmation.

The catalog query enforces linkage: `(PUBLIC AND ACTIVE) OR (invited) OR (already contracted)`. Subscribe and redeem operations re-validate linkage along with KYC and on-chain verification status.

## Consequences

- Private offerings remain invisible to non-invited investors in catalog listings and direct access attempts.
- SUPER_ADMIN must explicitly grant and revoke private access per investor per offering.
- Invite grants are audited and rate-limited to prevent abuse.
- Generic forbidden responses reduce information leakage about private offering existence.
- On-chain transfer compliance remains independent of off-chain visibility rules.

## References

- `_docs/based_rules.md` sections 2.2, 2.4, 5 (SEC-07), 6 (FUN-02, FUN-04)
- `_docs/FUNCTIONAL.md` sections 3, 4, 8
- `_docs/TECHNICAL.md` sections 3, 4, 8