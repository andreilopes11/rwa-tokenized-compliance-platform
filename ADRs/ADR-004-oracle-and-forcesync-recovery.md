# ADR-004: Oracle Retry and Four-Eyes ForceSync

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Operations and Security

## Context

Off-chain KYC approval and an on-chain registry write are separate systems. RPC outages, transaction failures, or signer problems must not silently turn an approval into an on-chain verification. Recovery must also compensate for the product's two-role model.

## Decision

Use a bounded asynchronous oracle worker with backoff. Keep identities in `APPROVED_PENDING_CHAIN` until a receipt and chain confirmation are recorded; use `FAILED_ON_CHAIN` after retry exhaustion. Allow `ForceSync` only as a scoped, audited two-step operation: administrator A initiates and a distinct administrator B approves. Broadcast through the injectable `TransactionSigner`, with KMS/HSM required by the production gate.

Record API audit events and `blockchain_transactions` for every chain write, including failures and ForceSync actions.

## Consequences

- The product clearly distinguishes off-chain approval from chain verification.
- Recovery requires two administrator sessions and cannot be self-approved.
- Local development may use an environment signer; production must fail closed without the configured KMS/HSM path.
- Operational dashboards need oracle health and retry visibility.

## References

- `_docs/based_rules.md` section 3 and SEC-11
- `_docs/FUNCTIONAL.md` section 5
- `_docs/TECHNICAL.md` sections 2, 5, 8, and 10
