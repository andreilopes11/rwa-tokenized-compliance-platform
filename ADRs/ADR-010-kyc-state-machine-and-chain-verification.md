# ADR-010: KYC State Machine and Chain Verification

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Compliance and Engineering

## Context

Off-chain KYC approval and on-chain identity registration are distinct operations with potential failure modes between them. The system must never silently grant on-chain verification status without actual blockchain confirmation, while clearly communicating intermediate states to users and administrators.

## Decision

Implement an explicit KYC state machine with clear boundaries between off-chain and on-chain verification:

**States:**

- `SUBMITTED` / `IN_REVIEW`: Document review in progress; investor sees pending status
- `APPROVED_PENDING_CHAIN`: SUPER_ADMIN approved off-chain; oracle queued but not yet confirmed on-chain
- `APPROVED`: Off-chain approved AND on-chain verified (`onChainVerified=true`); investor may subscribe/transfer
- `REJECTED`: Documents rejected by SUPER_ADMIN; investor may resubmit
- `REVOKED`: Previously approved identity revoked; blocks all token operations
- `FAILED_ON_CHAIN`: Oracle retry exhausted without blockchain confirmation; requires ForceSync

**Gating rules:**

- Subscribe, redeem, and transfer operations require `status=APPROVED` AND `onChainVerified=true`
- UI shows "Pending on blockchain" message during `APPROVED_PENDING_CHAIN` state
- Purchase and transfer controls remain disabled until full chain verification
- Backend never sets `onChainVerified=true` without transaction receipt and block confirmation

**Oracle workflow:**

1. SUPER_ADMIN approves KYC → state becomes `APPROVED_PENDING_CHAIN`
2. Oracle worker picks up approval → calls `registerIdentity` on IdentityRegistry
3. Transaction submitted → worker polls for receipt with bounded retry (exponential backoff)
4. Receipt confirmed → state becomes `APPROVED`, `onChainVerified=true`, `transactionHash` stored
5. Retry exhausted without success → state becomes `FAILED_ON_CHAIN`, alerts SUPER_ADMIN

**Recovery path:**

- `FAILED_ON_CHAIN` identities require ForceSync (four-eyes approval between two SUPER_ADMIN accounts)
- ForceSync operations are audited with initiator, approver, timestamp, and transaction hash
- Manual recovery uses HSM/KMS signer in production environments

## Consequences

- Clear separation between off-chain approval and on-chain verification prevents silent failures
- Investors understand when blockchain operations are pending vs complete
- Failed oracle writes are visible to administrators and require explicit remediation
- Audit trail captures all state transitions including failures and manual interventions
- UI must handle and display all intermediate states appropriately
- Backend services must validate both status and `onChainVerified` flag before allowing token operations

## References

- `_docs/based_rules.md` sections 3 (Scenario 1), 6 (FUN-06)
- `_docs/FUNCTIONAL.md` section 5
- `_docs/TECHNICAL.md` sections 2 (INV-04, INV-07), 5, 6
- ADR-004: Oracle Retry and Four-Eyes ForceSync