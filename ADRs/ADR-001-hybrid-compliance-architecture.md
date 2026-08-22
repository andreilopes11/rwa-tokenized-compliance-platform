# ADR-001: Hybrid Compliance Architecture

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Product and Architecture

## Context

VaultGuard RWA must support institutional KYC/AML while preserving permissioned, auditable token transfers. Raw personal data and documents must not be written to a public or shared EVM state. The API and UI may guide a user, but transfer legality must remain enforceable at execution time.

## Decision

Use a hybrid architecture:

- Spring Boot is the system of record for people, documents, KYC/AML decisions, ownership, tenant scope, and audit metadata.
- The blockchain stores only wallet addresses, identity hashes or verification state, token balances, compliance rules, and transaction results.
- A trusted oracle worker bridges an approved off-chain identity to the shared IdentityRegistry.
- ERC-3643/T-REX hooks (`isVerified` and `canTransfer`) are the final authority for mint and transfer legality.

## Consequences

- PII remains off-chain and access-controlled.
- A chain write is asynchronous; approval remains pending until a receipt and confirmation are observed.
- The backend needs an explicit oracle retry and failure state model.
- The UI must treat preflight results as advisory and refresh before signing.

## References

- `_docs/based_rules.md` sections 2-5 and 8
- `_docs/TECHNICAL.md` sections 1, 2, 5, and 8
