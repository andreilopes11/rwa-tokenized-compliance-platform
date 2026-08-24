# System Diagrams

This directory contains PlantUML C4 diagrams documenting the VaultGuard RWA architecture at multiple levels of abstraction.

## Diagram Index

| Diagram                                                      | Type          | Purpose                                              |
| ------------------------------------------------------------ | ------------- | ---------------------------------------------------- |
| [1. C4 Context](1.C4-Context%20Diagram.puml)                 | C4 Context    | System boundaries, external actors, key integrations |
| [2. C4 Container](2.C4-Container%20Diagram.puml)             | C4 Container  | Major application containers and their interactions  |
| [3. C4 Component](3.C4-Component%20Diagram.puml)             | C4 Component  | Internal components within Spring Boot API           |
| [4. KYC State Machine](4.KYC-State-Machine.puml)             | State Diagram | KYC approval workflow and state transitions          |
| [5. Contract Linkage Model](5.Contract-Linkage-Model.puml)   | Conceptual    | Contract access rules and enforcement points         |
| [6. Deployment Architecture](6.Deployment-Architecture.puml) | C4 Deployment | Production deployment topology and configuration     |
| [7. Deployment Sequence](7.Deployment-Sequence.puml)         | Sequence      | Step-by-step production deployment flow              |

## Viewing Diagrams

### Online Viewers

1. **PlantUML Online Editor**: https://www.plantuml.com/plantuml/uml/
   - Paste diagram source code
   - View rendered diagram
   - Export as PNG/SVG

2. **VS Code Extensions**:
   - PlantUML (jebbs.plantuml)
   - Markdown Preview Enhanced

### Local Rendering

```bash
# Install PlantUML (requires Java)
npm install -g node-plantuml

# Render single diagram
puml generate "1.C4-Context Diagram.puml" -o output.png

# Render all diagrams
puml generate *.puml -o ./rendered/
```

## Diagram Descriptions

### 1. C4 Context Diagram

**Level:** System Context  
**Audience:** Business stakeholders, architects  
**Shows:**
- VaultGuard RWA system as a black box
- Two user roles: Investor and Super Admin
- External systems: KYC/AML Provider, EVM T-REX Network, Investor Wallet
- Key interactions and data flows

**Key Points:**
- Two-role model (SUPER_ADMIN consolidates admin/compliance/auditor)
- Hybrid compliance: off-chain KYC + on-chain transfer enforcement
- Contract linkage: users only see/access linked offerings

### 2. C4 Container Diagram

**Level:** Container (application-level)  
**Audience:** Technical leads, architects, senior developers  
**Shows:**
- Next.js frontend with BFF (two workspaces: /dashboard, /governance)
- Spring Boot API (com.rwa package)
- PostgreSQL database
- Oracle worker (bounded retry + ForceSync)
- Blockchain gateway (Web3 + TransactionSigner)
- Communication protocols and data stores

**Key Points:**
- BFF security boundary (HttpOnly JWT, header injection, linkage probe stripping)
- Default-deny authorization (role + scope + ownership + linkage)
- Separate oracle worker for async identity registration
- Injectable TransactionSigner (env → KMS/HSM)

### 3. C4 Component Diagram

**Level:** Component (code-level)  
**Audience:** Developers, code reviewers  
**Shows:**
- BFF components: role path guard, backend proxy
- API components: auth, authorization interceptor, services
- Service layer: marketplace linkage, KYC, lifecycle, oracle, preflight, audit
- Persistence and blockchain gateway components
- Internal communication flows

**Key Points:**
- Dual authorization enforcement (BFF + backend interceptor)
- Marketplace service enforces contract linkage on all queries
- KYC state machine with APPROVED_PENDING_CHAIN
- Oracle with bounded retry and ForceSync four-eyes
- Audit service records all privileged actions and chain writes

### 4. KYC State Machine

**Level:** Behavioral  
**Audience:** Product, compliance, developers  
**Shows:**
- Complete KYC lifecycle from submission to approval/rejection/revocation
- Distinct APPROVED_PENDING_CHAIN state before on-chain verification
- Oracle retry workflow
- ForceSync recovery path (four-eyes between two admins)
- Business rules for each state

**Key Points:**
- Off-chain approval ≠ on-chain verification until receipt confirmed
- Subscribe/redeem/transfer require APPROVED + onChainVerified
- FAILED_ON_CHAIN state requires manual ForceSync recovery
- Investor cannot self-approve KYC (only SUPER_ADMIN approves)

### 5. Contract Linkage Model

**Level:** Conceptual  
**Audience:** Product, security, developers  
**Shows:**
- Linkage rules for SUPER_ADMIN (created_by) and INVESTOR (public + invited + contracted)
- Enforcement points: catalog query, detail access, subscribe/redeem
- Database indexes supporting linkage queries
- Anti-patterns: client probes, existence leaks

**Key Points:**
- Users only access contracts linked to them (golden rule)
- BFF strips linkage-broadening query parameters
- Backend independently validates linkage from JWT context
- Generic 403 responses prevent private offering enumeration

### 6. Deployment Architecture

**Level:** Infrastructure  
**Audience:** DevOps, platform engineers, architects  
**Shows:**
- Production deployment topology: Vercel (frontend) + AWS Elastic Beanstalk (backend)
- Neon PostgreSQL (serverless database)
- Sepolia testnet with T-REX contracts
- Alchemy RPC provider
- External KYC/AML provider
- Environment configuration and secrets management

**Key Points:**
- No signing keys on Vercel (BFF only)
- Backend holds admin private key (rotate for mainnet)
- Shared IdentityRegistry + per-offering token suites
- Deploy order: chain → backend → frontend
- Production gates: trex mode, Swagger off, KMS signer for mainnet

### 7. Deployment Sequence

**Level:** Process flow  
**Audience:** DevOps, release managers  
**Shows:**
- Step-by-step deployment sequence across three tiers
- Phase 1: Blockchain deployment (Foundry → Sepolia)
- Phase 2: Backend deployment (Maven → Elastic Beanstalk)
- Phase 3: Frontend deployment (GitHub → Vercel)
- Phase 4: Verification and smoke testing

**Key Points:**
- Sequential deployment: blockchain addresses needed by backend, backend URL needed by frontend
- Environment variable configuration at each stage
- Health checks and verification steps
- Secrets management: rotation and injection points
- E2E smoke test validates full stack integration

## Maintenance

### Updating Diagrams

When architecture changes:

1. **Update affected diagrams** to reflect new structure
2. **Keep consistency** across abstraction levels
3. **Update this README** if new diagrams are added
4. **Reference from specs** (`_docs/TECHNICAL.md`, ADRs) where relevant
5. **Validate syntax** before committing (use PlantUML preview)

### Diagram Conventions

- **C4 diagrams** use official C4-PlantUML library
- **State diagrams** use PlantUML state syntax with color coding
- **Notes** provide context for key decisions and configurations
- **Legends** included on C4 diagrams via `SHOW_LEGEND()`
- **Color coding**:
  - Light blue: Admin/governance components
  - Light green: Investor/user components
  - Light yellow: Pending/intermediate states
  - Light coral: Error/rejected states
  - Orange: Failed states requiring intervention

## Cross-References

### Related Documentation

- **Architecture decisions**: [`../ADRs/`](../ADRs/)
- **Functional specification**: [`../_docs/FUNCTIONAL.md`](../_docs/FUNCTIONAL.md)
- **Technical specification**: [`../_docs/TECHNICAL.md`](../_docs/TECHNICAL.md)
- **Foundation rules**: [`../_docs/based_rules.md`](../_docs/based_rules.md)

### Key Architecture Decisions

- [ADR-001: Hybrid Compliance Architecture](../ADRs/ADR-001-hybrid-compliance-architecture.md)
- [ADR-002: Two-Role RBAC and Contract Linkage](../ADRs/ADR-002-two-role-rbac-and-contract-linkage.md)
- [ADR-003: Shared Identity Registry](../ADRs/ADR-003-trex-suite-and-shared-identity-registry.md)
- [ADR-005: BFF and Backend Security Boundary](../ADRs/ADR-005-bff-and-backend-security-boundary.md)
- [ADR-010: KYC State Machine](../ADRs/ADR-010-kyc-state-machine-and-chain-verification.md)
- [ADR-011: Workspace Consolidation](../ADRs/ADR-011-workspace-consolidation-and-role-chrome.md)

## Rendering Tips

### PlantUML Preprocessor Variables

Some diagrams use C4-PlantUML includes:

```plantuml
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml
```

These require internet access during rendering. For offline rendering, download the C4 library locally.

### Export Formats

- **PNG**: Good for documentation and presentations
- **SVG**: Scalable, good for web and high-DPI displays
- **ASCII**: Text-based for terminal viewing (limited)

### Troubleshooting

If diagrams fail to render:

1. Check PlantUML syntax with online editor
2. Verify C4-PlantUML include URLs are accessible
3. Ensure Java is installed (PlantUML requirement)
4. Check for missing `@enduml` closing tags
5. Validate special characters are properly escaped