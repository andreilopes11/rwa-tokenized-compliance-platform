# ADR-011: Workspace Consolidation and Role Chrome

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Product and UX

## Context

The original architecture defined four roles (ADMIN, COMPLIANCE_OFFICER, AUDITOR, INVESTOR) with separate workspaces. Product evolution revealed that officer and auditor functions belong to the same administrative context, while maintaining artificial role separation added complexity without clear authorization boundaries.

## Decision

Consolidate to exactly two roles and two workspaces:

**Roles:**

- `SUPER_ADMIN`: Unified administrator with all management, KYC, lifecycle, audit, and governance capabilities
- `INVESTOR`: End user with portfolio and marketplace access

**Workspaces:**

- `/dashboard`: Investor interface for KYC, marketplace browsing, portfolio, and transfers
- `/governance`: SUPER_ADMIN interface consolidating all administrative functions previously split across `/admin`, `/compliance`, and `/audit`

**Workspace features:**

*Governance workspace includes:*

- Overview: contracts administered by this admin (`created_by` scope), oracle health
- Contract management: create, publish, pause, close, visibility settings
- Invites: grant/revoke private access per offering
- KYC queue: approve, reject, revoke investor identities
- Lifecycle: approve subscriptions and redemptions
- Oracle operations: health monitoring, ForceSync initiate/approve
- Audit: read-only timeline, KYC history, blockchain transactions, export

*Dashboard workspace includes:*

- Overview: KYC status, wallet connection, quick stats
- KYC: document submission, polling, status display
- Marketplace: public offerings and invited private offerings (linkage-filtered)
- Portfolio: positions, transaction history
- Transfer: preflight validation, wallet signature
- Activity: personal audit trail

**Role chrome:**

- Every authenticated page uses `WorkspaceAppHeader` component
- Header displays: VaultGuard logo, role badge (Investor/Super Admin), in-header menu
- Role-specific navigation: only show controls and routes available to the current role
- Hide management functions entirely in investor workspace (not just disable)
- BFF middleware enforces role-route matrix before backend authorization layer

**Migration:**

- Existing `ADMIN`, `COMPLIANCE_OFFICER`, `AUDITOR` database records migrate to `SUPER_ADMIN`
- Remove `/compliance` and `/audit` routes and feature folders
- Update i18n to remove orphaned compliance/audit strings
- Consolidate scope definitions: SUPER_ADMIN receives union of all governance scopes

## Consequences

- Simplified mental model: two clear user journeys instead of four
- Reduced authorization complexity: role check determines workspace access
- Frontend codebase cleanup: remove three workspace implementations
- Backend authorization: retarget protected routes to `SUPER_ADMIN` role
- Compensating controls for reduced separation: ForceSync four-eyes, audit logging, rate limiting
- Clear upgrade path: existing users mapped to new role structure via migration

## References

- `_docs/based_rules.md` sections 2, 5 (SEC-11), 6 (FUN-10, FUN-11), 7 (UI-13)
- `_docs/FUNCTIONAL.md` sections 2, 6
- `_docs/TECHNICAL.md` sections 3, 7
- ADR-002: Two-Role RBAC and Contract Linkage