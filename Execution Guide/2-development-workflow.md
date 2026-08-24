# Development Workflow

Standard development practices and workflows for VaultGuard RWA.

## Branch Strategy

### Main Branches

- **`main`**: Production-ready code; protected branch
- **`develop`**: Integration branch for features
- **Feature branches**: `feature/description` from develop
- **Fix branches**: `fix/description` from develop or main

### Branch Protection Rules

**Main branch:**
- Requires pull request review
- Requires passing CI checks
- No direct pushes
- No force pushes

**Develop branch:**
- Requires pull request
- Requires passing tests
- Fast-forward merges preferred

## Feature Development Process

### 1. Create Feature Branch

```powershell
# Update develop
git checkout develop
git pull origin develop

# Create feature branch
git checkout -b feature/marketplace-invite-ui
```

### 2. Make Changes

Follow the phased implementation approach:

**Phase order** (see `_docs/PHASED-IMPLEMENTATION-PROMPT.md`):
1. Contracts (blockchain)
2. Backend services (backend)
3. Oracle + ForceSync (backend)
4. Frontend workspaces (frontend)
5. Marketplace ACL + E2E (integration)
6. Production gates (configuration)

**Work incrementally:**
- One phase at a time
- Write tests for each phase
- Verify before moving forward

### 3. Code Style and Conventions

**Backend (Java):**
```java
// Package structure: com.rwa.{layer}
package com.rwa.service;

// Class naming: PascalCase
public class MarketplaceAclService {
    // Method naming: camelCase
    public boolean validateLinkage(String userId, Long offeringId) {
        // Implementation
    }
}
```

**Frontend (TypeScript):**
```typescript
// File naming: kebab-case
// marketplace-card.tsx

// Component naming: PascalCase
export function MarketplaceCard({ offering }: MarketplaceCardProps) {
  // Implementation
}

// Hook naming: camelCase with 'use' prefix
export function useMarketplaceQuery() {
  // Implementation
}
```

**Solidity:**
```solidity
// Contract naming: PascalCase
contract IdentityRegistry {
    // Function naming: camelCase
    function registerIdentity(
        address wallet,
        bytes32 identityHash,
        uint16 country
    ) external {
        // Implementation
    }
}
```

### 4. Write Tests

**Backend tests:**
```powershell
cd rwa-tokenized-compliance-system-backend

# Run all tests
mvn test

# Run specific test
mvn -Dtest=MarketplaceLinkageServiceTest test

# Run phase-specific tests
mvn -Dtest=Phase5MarketplaceHappyPathTest test
```

**Frontend tests:**
```powershell
cd rwa-tokenized-compliance-system-frontend

# Run all tests
npm run test

# Run specific test file
npm run test marketplace-card.test.tsx

# Run with coverage
npm run test:coverage
```

**Contract tests:**
```powershell
cd rwa-tokenized-compliance-system-blockchain

# Run all tests
npm run test

# Run security tests
npm run test:security

# Run specific test
forge test --match-test testCannotTransferWhenRevoked
```

### 5. Commit Changes

**Commit message format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process or tooling changes

**Examples:**
```bash
git commit -m "feat(marketplace): add private invite grant UI

Implements SUPER_ADMIN invite management for private offerings.
- Add InviteManagementPanel component
- Integrate with POST /api/assets/{id}/invites
- Add revoke functionality
- Include audit trail display

Closes #123"

git commit -m "fix(kyc): show pending-on-chain state in UI

Previously UI showed 'Approved' immediately after admin approval,
before on-chain verification. Now correctly displays 'Pending on
blockchain' state during APPROVED_PENDING_CHAIN.

Refs: ADR-010, BR-14"
```

### 6. Push and Create PR

```powershell
# Push feature branch
git push -u origin feature/marketplace-invite-ui

# Create PR via GitHub CLI
gh pr create --title "Add private invite management UI" `
  --body "Implements SUPER_ADMIN invite grant/revoke for private offerings." `
  --base develop

# Or create PR via GitLab CLI
glab mr create --title "Add private invite management UI" `
  --description "Implements SUPER_ADMIN invite grant/revoke for private offerings." `
  --target-branch develop
```

### 7. PR Review Checklist

**For author:**
- [ ] All tests pass locally
- [ ] Code follows style conventions
- [ ] New features have tests
- [ ] Documentation updated if needed
- [ ] No secrets committed
- [ ] No plaintext private keys
- [ ] Authorization checks present
- [ ] Linkage validation included where applicable

**For reviewer:**
- [ ] Code follows two-role model
- [ ] Contract linkage enforced
- [ ] No self-approval of KYC
- [ ] Follows based_rules.md constraints
- [ ] Tests cover success and failure paths
- [ ] Error messages are user-safe
- [ ] No PII in logs or responses
- [ ] Audit events recorded for privileged actions

### 8. Merge

```powershell
# After approval, merge via GitHub/GitLab UI
# Or via CLI
gh pr merge --squash --delete-branch

# Update local develop
git checkout develop
git pull origin develop
```

## Daily Development Tasks

### Starting Work

```powershell
# Update your local repository
git checkout develop
git pull origin develop

# Start development stack
.\root\scripts\stack.ps1 up --chain sepolia --skip-deps

# Or full local if needed
.\root\scripts\stack.ps1 up
```

### During Development

```powershell
# Run tests frequently
cd rwa-tokenized-compliance-system-backend
mvn test -Dtest=YourNewTest

# Check backend logs
# Backend console shows logs automatically

# Check frontend in browser
# http://localhost:3000
# Browser DevTools → Console for errors

# Test API endpoints
curl -X GET http://localhost:8080/api/assets `
  -H "Authorization: Bearer YOUR_TOKEN"
```

### Ending Work

```powershell
# Commit work in progress
git add .
git commit -m "wip: marketplace invite UI in progress"
git push

# Stop services
.\root\scripts\stop.ps1
```

## Common Development Scenarios

### Adding a New API Endpoint

1. **Define in controller** (`api` layer):
```java
@RestController
@RequestMapping("/api/assets/{assetId}/invites")
public class InviteController {
    @PostMapping
    @PreAuthorize("hasRole('SUPER_ADMIN')")
    public ResponseEntity<InviteResponse> grantInvite(
        @PathVariable Long assetId,
        @RequestBody InviteRequest request
    ) {
        // Delegate to service
    }
}
```

2. **Implement service** (`service` layer):
```java
@Service
public class InviteService {
    public InviteResponse grantInvite(Long assetId, String identityHash) {
        // Validate ownership (created_by)
        // Check not already invited
        // Insert invite record
        // Audit event
        return response;
    }
}
```

3. **Add authorization** (`ApiAuthorizationInterceptor`):
```java
private static final Map<String, Set<UserRole>> ROUTE_MATRIX = Map.of(
    "/api/assets/.*/invites", Set.of(UserRole.SUPER_ADMIN)
);
```

4. **Write tests:**
```java
@Test
void grantInvite_Success() {
    // Given: SUPER_ADMIN owns offering
    // When: POST /api/assets/{id}/invites
    // Then: 200, invite created, audit event
}

@Test
void grantInvite_NotOwner_Forbidden() {
    // Given: SUPER_ADMIN does not own offering
    // When: POST /api/assets/{id}/invites
    // Then: 403 FORBIDDEN
}
```

### Adding a New UI Component

1. **Create component** (`features/{domain}/components`):
```typescript
// features/governance/components/invite-management-panel.tsx
export function InviteManagementPanel({ offeringId }: Props) {
  // Implementation
}
```

2. **Add API hook** (`features/{domain}/api`):
```typescript
// features/governance/api/use-invite-mutation.ts
export function useInviteMutation(offeringId: number) {
  return useMutation({
    mutationFn: (identityHash: string) => 
      grantInvite(offeringId, identityHash),
    onSuccess: () => {
      queryClient.invalidateQueries(['invites', offeringId])
    }
  })
}
```

3. **Use design tokens:**
```tsx
<button className="btn-primary">
  Grant Invite
</button>

// CSS using tokens
.btn-primary {
  background: var(--vg-accent);
  color: var(--vg-text);
  border-radius: var(--vg-radius);
}
```

4. **Write tests:**
```typescript
describe('InviteManagementPanel', () => {
  it('grants invite on submit', async () => {
    // Given: SUPER_ADMIN user
    // When: Submit invite form
    // Then: API called, success message shown
  })
  
  it('shows error on failure', async () => {
    // Given: API returns error
    // When: Submit invite form
    // Then: Error message displayed
  })
})
```

### Adding a New Smart Contract Function

1. **Implement in Solidity:**
```solidity
function registerIdentity(
    address wallet,
    bytes32 identityHash,
    uint16 country
) external onlyCompliance {
    require(!identities[wallet].verified, "Already registered");
    identities[wallet] = Identity({
        hash: identityHash,
        country: country,
        verified: true
    });
    emit IdentityRegistered(wallet, identityHash);
}
```

2. **Write tests:**
```solidity
function testRegisterIdentity() public {
    vm.prank(complianceAgent);
    registry.registerIdentity(
        testWallet,
        keccak256("test-hash"),
        840 // US
    );
    
    assertTrue(registry.isVerified(testWallet));
}

function testCannotRegisterTwice() public {
    vm.prank(complianceAgent);
    registry.registerIdentity(testWallet, keccak256("hash"), 840);
    
    vm.expectRevert("Already registered");
    vm.prank(complianceAgent);
    registry.registerIdentity(testWallet, keccak256("hash2"), 840);
}
```

3. **Update backend gateway:**
```java
public TransactionReceipt registerIdentity(
    String walletAddress,
    byte[] identityHash,
    int country
) {
    Function function = new Function(
        "registerIdentity",
        Arrays.asList(
            new Address(walletAddress),
            new Bytes32(identityHash),
            new Uint16(country)
        ),
        Collections.emptyList()
    );
    return executeTransaction(identityRegistryAddress, function);
}
```

## Code Review Guidelines

### What to Look For

**Security:**
- Authorization checks on protected endpoints
- Contract linkage validation
- No secrets in code
- Input validation
- SQL injection prevention (use parameterized queries)
- XSS prevention (proper escaping)

**Architecture:**
- Follows two-role model
- Respects layer boundaries (api → service → persistence)
- No business logic in controllers
- No UI logic in shared components

**Correctness:**
- Tests cover happy path and error cases
- Error handling is appropriate
- Edge cases considered
- State transitions validated

**Maintainability:**
- Code is readable and well-structured
- Complex logic has comments
- Magic numbers are constants
- Naming follows conventions

### Providing Feedback

**Good feedback:**
```
❌ "This is wrong"
✅ "This validation is missing ownership check. Per ADR-002, we need to
   verify created_by matches the authenticated admin before allowing
   invite grants. Suggest adding ownershipService.validateOwnership()."

❌ "Bad code"
✅ "This method has high cyclomatic complexity. Consider extracting the
   validation logic into a separate validateInviteRequest() method."
```

## Continuous Integration

CI runs on every push and PR:

**Backend:**
```bash
mvn clean verify
# Runs: compile, tests, security checks
```

**Frontend:**
```bash
npm run lint
npm run build
npm run test
# Runs: linting, build verification, tests
```

**Blockchain:**
```bash
forge test
# Runs: all contract tests including security suite
```

## Debugging Tips

### Backend Debugging

```powershell
# Run with debug port
mvn spring-boot:run -Dspring-boot.run.jvmArguments="-Xdebug -Xrunjdwp:transport=dt_socket,server=y,suspend=n,address=5005"

# Attach debugger in IDE (IntelliJ/Eclipse) to port 5005
```

### Frontend Debugging

```powershell
# Run with debugging
npm run dev

# Use browser DevTools:
# - Console for errors
# - Network tab for API calls
# - React DevTools for component inspection
```

### Contract Debugging

```powershell
# Run with verbosity
forge test -vvv

# Trace specific test
forge test --match-test testRegisterIdentity -vvvv

# Debug with console logs
forge test --match-test testRegisterIdentity -vv
```

## Next Steps

- **Testing guide**: [3-testing-guide.md](3-testing-guide.md)
- **Deployment procedures**: [4-deployment-procedures.md](4-deployment-procedures.md)
- **Operational runbooks**: [5-operational-runbooks.md](5-operational-runbooks.md)