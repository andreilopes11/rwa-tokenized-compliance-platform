# VaultGuard RWA Documentation

**Foundation:** [`based_rules.md`](based_rules.md) — product identity, two-role model, contract-linkage rule, fallbacks, SEC / FUN / UI / TEC rules.  
**Roles:** `SUPER_ADMIN` (all management + KYC + lifecycle + audit + invites) and `INVESTOR` (linked contracts only). `COMPLIANCE_OFFICER` / `AUDITOR` are **removed**.  
**Derived specs** (implementation must follow these; if conflict, update `based_rules` first):

| Document                                                             | Purpose                                                            |
| -------------------------------------------------------------------- | ------------------------------------------------------------------ |
| [`FUNCTIONAL.md`](FUNCTIONAL.md)                                     | Product rules, roles, marketplace, screens, UX, acceptance         |
| [`TECHNICAL.md`](TECHNICAL.md)                                       | Architecture, API, chain, security, performance, UI system, deploy |
| [`PHASED-IMPLEMENTATION-PROMPT.md`](PHASED-IMPLEMENTATION-PROMPT.md) | Lean agent/dev phases (contracts → backend → oracle → UI)          |

**Rule:** do not invent features outside these docs. Prefer minimal diffs; no plaintext secrets in docs or examples. No large illustrative Solidity/Java dumps in docs — point to the repos.

## Repositories

| Path                                         | Role                                                 |
| -------------------------------------------- | ---------------------------------------------------- |
| `rwa-tokenized-compliance-system-blockchain` | ERC-3643 / T-REX, deploy, forge tests                |
| `rwa-tokenized-compliance-system-backend`    | Spring Boot API (`com.rwa`), KYC, ACL, oracle, audit |
| `rwa-tokenized-compliance-system-frontend`   | Role workspaces, BFF, Wagmi, `--vg-*` UI             |
| `root/scripts`                               | Local stack (`stack.ps1` / `stack.sh`)               |

## Quick anchors

| Topic                                                    | Where                                            |
| -------------------------------------------------------- | ------------------------------------------------ |
| Two-role model                                           | based_rules §2 · FUNCTIONAL §2                   |
| Contract linkage (created_by / public·invite·contracted) | based_rules §2.2 / §2.4 · FUNCTIONAL §3          |
| Marketplace PUBLIC/PRIVATE + invites                     | FUNCTIONAL §3                                    |
| Fallbacks / ForceSync                                    | based_rules §3 · FUNCTIONAL §5                   |
| Auth (no MFA/invite) + password eyes                     | based_rules SEC-10 / UI-07 · FUNCTIONAL BR-17/18 |
| Header (logo + role + menu)                              | based_rules UI-13 · TECHNICAL §7                 |
| Design tokens & componentization                         | TECHNICAL §7                                     |
| Phase prompts                                            | PHASED-IMPLEMENTATION-PROMPT                     |
