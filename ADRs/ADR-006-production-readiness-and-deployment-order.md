# ADR-006: Deployment Order and Production Gates

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Platform Operations

## Context

The system spans chain contracts, a Spring Boot API, a Next.js BFF, PostgreSQL, and external KYC infrastructure. A release must avoid advertising an offering before its token suite is usable and must keep environment secrets out of source control.

## Decision

Deploy and verify in this order:

1. Foundry/T-REX contracts and per-offering suites.
2. Spring Boot backend with PostgreSQL and oracle workers.
3. Next.js frontend/BFF.

Use local orchestration from `root/scripts/stack.ps1` or `stack.sh`. Use profile-based configuration and environment-managed secrets; commit only non-secret local or Sepolia address configuration. Production requires T-REX mode, Swagger off, no legacy admin token, and a KMS/HSM signer gate. Mainnet is out of scope until the external audit, disaster-recovery evidence, and cloud signing path are complete.

## Consequences

- Chain addresses and receipts are prerequisites for `ACTIVE` offerings.
- Deployment verification must include backend, frontend, oracle, audit, and authorization checks.
- The remaining production blockers are explicit in `_docs/TECHNICAL.md` G8 and G10.

## References

- `_docs/PHASED-IMPLEMENTATION-PROMPT.md` phases A-F
- `_docs/TECHNICAL.md` sections 9-11
