# Architecture Decision Records (ADRs)

This directory contains architecture decisions for the VaultGuard RWA system. Each ADR documents a significant architectural choice, its context, the decision made, and its consequences.

## Index

| ADR                                                                   | Title                                                   | Status   | Date       |
| --------------------------------------------------------------------- | ------------------------------------------------------- | -------- | ---------- |
| [ADR-001](ADR-001-hybrid-compliance-architecture.md)                  | Hybrid Compliance Architecture                          | Accepted | 2026-08-22 |
| [ADR-002](ADR-002-two-role-rbac-and-contract-linkage.md)              | Two-Role RBAC and Contract Linkage                      | Accepted | 2026-08-22 |
| [ADR-003](ADR-003-trex-suite-and-shared-identity-registry.md)         | Shared Identity Registry with Per-Offering T-REX Suites | Accepted | 2026-08-22 |
| [ADR-004](ADR-004-oracle-and-forcesync-recovery.md)                   | Oracle Retry and Four-Eyes ForceSync                    | Accepted | 2026-08-22 |
| [ADR-005](ADR-005-bff-and-backend-security-boundary.md)               | BFF and Backend Security Boundary                       | Accepted | 2026-08-22 |
| [ADR-006](ADR-006-production-readiness-and-deployment-order.md)       | Deployment Order and Production Gates                   | Accepted | 2026-08-22 |
| [ADR-007](ADR-007-marketplace-visibility-and-invite-model.md)         | Marketplace Visibility and Invite Model                 | Accepted | 2026-08-22 |
| [ADR-008](ADR-008-password-visibility-and-auth-simplification.md)     | Password Visibility and Auth Simplification             | Accepted | 2026-08-22 |
| [ADR-009](ADR-009-design-system-and-institutional-branding.md)        | Design System and Institutional Branding                | Accepted | 2026-08-22 |
| [ADR-010](ADR-010-kyc-state-machine-and-chain-verification.md)        | KYC State Machine and Chain Verification                | Accepted | 2026-08-22 |
| [ADR-011](ADR-011-workspace-consolidation-and-role-chrome.md)         | Workspace Consolidation and Role Chrome                 | Accepted | 2026-08-22 |
| [ADR-012](ADR-012-deployment-orchestration-and-environment-matrix.md) | Deployment Orchestration and Environment Matrix         | Accepted | 2026-08-24 |
| [ADR-013](ADR-013-production-deployment-topology.md)                  | Production Deployment Topology                          | Accepted | 2026-08-24 |

## ADR Categories

### Security & Authorization
- ADR-001: Hybrid Compliance Architecture
- ADR-002: Two-Role RBAC and Contract Linkage
- ADR-005: BFF and Backend Security Boundary
- ADR-007: Marketplace Visibility and Invite Model
- ADR-008: Password Visibility and Auth Simplification

### Blockchain & Smart Contracts
- ADR-003: Shared Identity Registry with Per-Offering T-REX Suites
- ADR-004: Oracle Retry and Four-Eyes ForceSync
- ADR-010: KYC State Machine and Chain Verification

### User Experience & Design
- ADR-008: Password Visibility and Auth Simplification
- ADR-009: Design System and Institutional Branding
- ADR-011: Workspace Consolidation and Role Chrome

### Operations & Deployment
- ADR-004: Oracle Retry and Four-Eyes ForceSync
- ADR-006: Deployment Order and Production Gates
- ADR-012: Deployment Orchestration and Environment Matrix
- ADR-013: Production Deployment Topology

## Creating New ADRs

When documenting a new architectural decision:

1. **Copy the template structure** from existing ADRs
2. **Number sequentially** (ADR-012, ADR-013, etc.)
3. **Include required sections:**
   - Status (Proposed | Accepted | Deprecated | Superseded)
   - Date (YYYY-MM-DD)
   - Decision owners (roles/teams)
   - Context (why this decision is needed)
   - Decision (what was decided)
   - Consequences (impacts and tradeoffs)
   - References (related docs and ADRs)
4. **Update this index** with the new ADR
5. **Reference from specs** (`_docs/`) where relevant

## Status Definitions

- **Proposed:** Under discussion, not yet implemented
- **Accepted:** Approved and implemented (or implementation in progress)
- **Deprecated:** No longer recommended but still in use
- **Superseded:** Replaced by a newer ADR (reference the superseding ADR)

## References

ADRs derive from and support the normative documentation:
- [`_docs/based_rules.md`](../_docs/based_rules.md) — Foundation rules (SEC, FUN, UI, TEC)
- [`_docs/FUNCTIONAL.md`](../_docs/FUNCTIONAL.md) — Product and business rules
- [`_docs/TECHNICAL.md`](../_docs/TECHNICAL.md) — Implementation specifications
- [`_docs/PHASED-IMPLEMENTATION-PROMPT.md`](../_docs/PHASED-IMPLEMENTATION-PROMPT.md) — Development phases