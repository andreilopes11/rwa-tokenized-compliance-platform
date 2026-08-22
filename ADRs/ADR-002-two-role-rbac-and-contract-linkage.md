# ADR-002: Two-Role RBAC and Contract Linkage

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Product and Security

## Context

The product has two user journeys and must prevent private-offering enumeration and cross-tenant or cross-owner access. Former `COMPLIANCE_OFFICER` and `AUDITOR` roles add no independent product boundary because their duties belong to the administrator workspace.

## Decision

Define exactly two roles:

- `SUPER_ADMIN`: manages only offerings where `created_by` matches the authenticated administrator; manages KYC, lifecycle, visibility, private grants, ForceSync, oracle health, and audit.
- `INVESTOR`: manages own KYC and portfolio and may access only `ACTIVE` offerings that are public, explicitly invited, or already contracted.

Enforce role, scope, tenant, ownership, and contract linkage in the backend on every read and mutation. The BFF may add an early route guard, but it is never the sole authorization layer. Non-linked and private resources return a generic forbidden response.

## Consequences

- The only workspace routes are `/dashboard` and `/governance`.
- Catalog and subscribe/redeem queries both require linkage; client probe parameters cannot broaden access.
- Existing officer/auditor records and routes require migration or consolidation to `SUPER_ADMIN`.
- Authorization and linkage tests are release gates.

## References

- `_docs/based_rules.md` sections 2 and 5-6
- `_docs/FUNCTIONAL.md` sections 2-4 and 8
- `_docs/TECHNICAL.md` sections 3-4
