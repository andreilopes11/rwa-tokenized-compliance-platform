# ADR-003: Shared Identity Registry with Per-Offering T-REX Suites

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Blockchain Architecture

## Context

Each tokenized RWA offering needs isolated compliance and lifecycle behavior, while identities should remain consistent across the marketplace. Deploying a complete identity registry for every offering would duplicate wallet verification state and increase operational complexity.

## Decision

Deploy a base T-REX system with a shared `IdentityRegistry`. On publishing each offering, deploy a per-offering token and `ModularCompliance` through `DeployAdditionalTrexToken`. Persist the suite addresses on the offering and mark it `ACTIVE` only after the deployment receipt is confirmed.

Use compliance hooks for verification, revocation, pause, and any configured limits or jurisdiction modules. Visibility (`PUBLIC` or `PRIVATE`) remains an off-chain marketplace concern.

## Consequences

- Wallet identity state can be reused across offerings.
- Compliance and token configuration remain isolated per offering.
- The backend must resolve token and compliance addresses per contract.
- Deployment is part of publish and must be auditable and retryable.

## References

- `_docs/based_rules.md` TEC-02 and TEC-13
- `_docs/FUNCTIONAL.md` sections 3 and 5
- `_docs/TECHNICAL.md` section 5
