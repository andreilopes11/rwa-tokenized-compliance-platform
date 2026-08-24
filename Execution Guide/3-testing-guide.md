# Testing Guide

Comprehensive testing strategy and procedures for VaultGuard RWA.

## Testing Philosophy

**Principles:**
- Write tests before or alongside implementation
- Test behavior, not implementation details
- Each phase has explicit test gates
- Authorization and linkage are critical test paths
- On-chain behavior is final authority

## Test Pyramid

```
        /\        E2E Tests (few)
       /  \       - Full stack integration
      /    \      - Critical user journeys
     /------\     
    / Integr \    Integration Tests (some)
   /  -ation  \   - API + database
  /    Tests   \  - Oracle + blockchain
 /--------------\ 
/     Unit       \ Unit Tests (many)
\     Tests      / - Business logic
 \              /  - Authorization rules
  \            /   - State machines
   \----------/
```

## Test Categories by Repository

### Blockchain Tests (Foundry)

**Location:** `rwa-tokenized-compliance-system-blockchain/test/`

**Types:**
- Unit tests: Individual contract functions
- Security tests: Non-compliant paths, access control
- Integration tests: Multi-contract workflows

**Running tests:**
```powershell
cd rwa-tokenized-compliance-system-blockchain

# All tests
forge test

# Security suite only
forge test --match-path test/security/*

# Specific test
forge test --match-test testCannotTransferWhenRevoked

# With gas reporting
forge test --gas-report

# With verbosity (traces)
forge test -vvv
```

**Example test:**
```solidity
// test/security/TrexComplianceSecurityTest.t.sol
function testCannotTransferWhenRevoked() public {
    // Setup: Register and approve wallet
    vm.prank(complianceAgent);
    identityRegistry.registerIdentity(
        investorWallet,
        keccak256("investor-hash"),
        840
    );
    
    // Mint tokens
    vm.prank(lifecycleAgent);
    token.mint(investorWallet, 1000e18);
    
    // Revoke identity
    vm.prank(complianceAgent);
    identityRegistry.deleteIdentity(investorWallet);
    
    // Attempt transfer - should revert
    vm.prank(investorWallet);
    vm.expectRevert("Sender not verified");
    token.transfer(recipientWallet, 100e18);
}
```

**Key test scenarios:**
- ✓ Non-compliant sender cannot transfer
- ✓ Non-compliant recipient cannot receive
- ✓ Revoked wallet cannot send or receive
- ✓ Paused token blocks all transfers
- ✓ Only authorized agents can register/delete identities
- ✓ Compliance modules enforce rules at transfer time

### Backend Tests (JUnit + Spring)

**Location:** `rwa-tokenized-compliance-system-backend/src/test/java/`

**Types:**
- Unit tests: Service layer logic
- Integration tests: API + database + blockchain
- Security tests: Authorization, linkage, ownership

**Running tests:**
```powershell
cd rwa-tokenized-compliance-system-backend

# All tests
mvn test

# Specific test class
mvn -Dtest=MarketplaceLinkageServiceTest test

# Specific test method
mvn -Dtest=MarketplaceLinkageServiceTest#validateLinkage_SuperAdmin_Success test

# Phase-specific tests
mvn -Dtest=Phase5MarketplaceHappyPathTest test

# With coverage report
mvn clean test jacoco:report
# Report: target/site/jacoco/index.html
```

**Test structure:**
```java
@SpringBootTest
@ActiveProfiles("test")
class MarketplaceLinkageServiceTest {
    
    @Autowired
    private MarketplaceLinkageService linkageService;
    
    @Autowired
    private AssetOfferingRepository offeringRepo;
    
    @Test
    void validateLinkage_SuperAdmin_CreatedBy_Success() {
        // Given: SUPER_ADMIN user
        UserContext admin = createSuperAdmin("admin-123");
        AssetOffering offering = createOffering("offering-1", admin.getUserId());
        
        // When: Validate linkage
        boolean linked = linkageService.validateLinkage(
            admin.getUserId(),
            offering.getId(),
            UserRole.SUPER_ADMIN
        );
        
        // Then: Linked (created_by match)
        assertTrue(linked);
    }
    
    @Test
    void validateLinkage_SuperAdmin_NotCreatedBy_Denied() {
        // Given: SUPER_ADMIN user
        UserContext admin = createSuperAdmin("admin-123");
        // Offering created by different admin
        AssetOffering offering = createOffering("offering-1", "admin-456");
        
        // When: Validate linkage
        boolean linked = linkageService.validateLinkage(
            admin.getUserId(),
            offering.getId(),
            UserRole.SUPER_ADMIN
        );
        
        // Then: Not linked
        assertFalse(linked);
    }
    
    @Test
    void validateLinkage_Investor_Public_Success() {
        // Given: INVESTOR user, PUBLIC ACTIVE offering
        UserContext investor = createInvestor("investor-123");
        AssetOffering offering = createPublicOffering();
        
        // When: Validate linkage
        boolean linked = linkageService.validateLinkage(
            investor.getUserId(),
            offering.getId(),
            UserRole.INVESTOR
        );
        
        // Then: Linked (public offering)
        assertTrue(linked);
    }
    
    @Test
    void validateLinkage_Investor_PrivateNotInvited_Denied() {
        // Given: INVESTOR user, PRIVATE offering without invite
        UserContext investor = createInvestor("investor-123");
        AssetOffering offering = createPrivateOffering();
        // No invite granted
        
        // When: Validate linkage
        boolean linked = linkageService.validateLinkage(
            investor.getUserId(),
            offering.getId(),
            UserRole.INVESTOR
        );
        
        // Then: Not linked
        assertFalse(linked);
    }
}
```

**Key test scenarios:**
- ✓ Two-role authorization on all protected endpoints
- ✓ Contract linkage enforced (created_by, public, invited, contracted)
- ✓ KYC state machine transitions
- ✓ Oracle retry with bounded backoff
- ✓ ForceSync four-eyes validation
- ✓ Ownership validation on document access
- ✓ Audit events recorded for privileged actions
- ✓ Generic 403 responses for non-linked resources

**Phase-specific tests:**
```java
// Phase 5: Marketplace happy path
@Test
void phase5_HappyPath_CreatePublicInviteSubscribe() {
    // 1. SUPER_ADMIN creates PRIVATE + PUBLIC offerings
    // 2. Grant investor on PRIVATE
    // 3. Publish both → ACTIVE
    // 4. Investor KYC → approve → oracle → APPROVED + onChainVerified
    // 5. Grantee lists both; non-grantee lists PUBLIC only
    // 6. Non-grantee GET private → 403 MARKETPLACE_FORBIDDEN
    // 7. Subscribe PUBLIC → approve → mint → audit events
    // 8. Preflight transfer → check reasons
}
```

### Frontend Tests (Vitest + React Testing Library)

**Location:** `rwa-tokenized-compliance-system-frontend/src/__tests__/`

**Types:**
- Component tests: UI rendering and interaction
- Hook tests: Custom hooks behavior
- Integration tests: BFF + role guards

**Running tests:**
```powershell
cd rwa-tokenized-compliance-system-frontend

# All tests
npm run test

# Watch mode
npm run test:watch

# With coverage
npm run test:coverage

# Specific test file
npm run test marketplace-card.test.tsx

# UI mode (browser-based)
npm run test:ui
```

**Test structure:**
```typescript
// src/__tests__/components/marketplace-card.test.tsx
import { render, screen, fireEvent } from '@testing-library/react'
import { MarketplaceCard } from '@/features/investor/components/marketplace-card'

describe('MarketplaceCard', () => {
  const mockOffering = {
    id: 1,
    name: 'Test Offering',
    visibility: 'PUBLIC',
    status: 'ACTIVE',
    minimumInvestment: 10000,
  }
  
  it('renders offering details', () => {
    render(<MarketplaceCard offering={mockOffering} />)
    
    expect(screen.getByText('Test Offering')).toBeInTheDocument()
    expect(screen.getByText('Public')).toBeInTheDocument()
    expect(screen.getByText('$10,000')).toBeInTheDocument()
  })
  
  it('disables subscribe when not eligible', () => {
    const notEligible = { ...mockOffering, canSubscribe: false }
    render(<MarketplaceCard offering={notEligible} />)
    
    const button = screen.getByRole('button', { name: /subscribe/i })
    expect(button).toBeDisabled()
  })
  
  it('shows pending-chain status', () => {
    const pending = {
      ...mockOffering,
      kycStatus: 'APPROVED_PENDING_CHAIN',
      canSubscribe: false,
    }
    render(<MarketplaceCard offering={pending} />)
    
    expect(screen.getByText(/pending on blockchain/i)).toBeInTheDocument()
  })
})
```

**BFF middleware tests:**
```typescript
// src/__tests__/middleware/auth.test.ts
import { testMiddleware } from '@/lib/test-utils'
import { authMiddleware } from '@/middleware/auth'

describe('Auth Middleware', () => {
  it('allows INVESTOR to access /dashboard', async () => {
    const request = createMockRequest('/dashboard', {
      cookies: { jwt: createInvestorToken() }
    })
    
    const response = await testMiddleware(authMiddleware, request)
    
    expect(response.status).toBe(200)
  })
  
  it('blocks INVESTOR from /governance', async () => {
    const request = createMockRequest('/governance', {
      cookies: { jwt: createInvestorToken() }
    })
    
    const response = await testMiddleware(authMiddleware, request)
    
    expect(response.status).toBe(403)
  })
  
  it('allows SUPER_ADMIN to access /governance', async () => {
    const request = createMockRequest('/governance', {
      cookies: { jwt: createSuperAdminToken() }
    })
    
    const response = await testMiddleware(authMiddleware, request)
    
    expect(response.status).toBe(200)
  })
})
```

**Key test scenarios:**
- ✓ Role-based route guards (INVESTOR → /dashboard, SUPER_ADMIN → /governance)
- ✓ Password visibility toggle (PasswordInput component)
- ✓ KYC polling stops at terminal states
- ✓ Transfer preflight before wallet signature
- ✓ Marketplace cards show correct eligibility
- ✓ WorkspaceAppHeader displays role badge
- ✓ Private offerings hidden from non-invited investors

## Integration Testing

### Full Stack Smoke Test (Sepolia Local)

**Script:** `root/scripts/smoke-sepolia-local.ps1`

```powershell
# Start services against Sepolia
.\root\scripts\stack.ps1 up --chain sepolia

# Run smoke tests
.\root\scripts\smoke-sepolia-local.ps1
```

**Checks:**
- Backend connects to Sepolia RPC
- Contract addresses resolve correctly
- Profile configuration is correct
- No localhost RPC references in Sepolia mode
- Health endpoints respond

### E2E Test Suite (Phase 5)

**Documentation:** `Execution Guide/scripts/e2e-phase5.md`

**Scenarios:**
1. SUPER_ADMIN creates offerings (PRIVATE + PUBLIC)
2. Grant investor on PRIVATE
3. Publish → ACTIVE
4. Investor KYC flow → APPROVED + onChainVerified
5. Catalog linkage (grantee sees both, non-grantee sees PUBLIC only)
6. Non-grantee access private → 403 MARKETPLACE_FORBIDDEN
7. Subscribe PUBLIC → lifecycle approve → mint
8. Audit trail validation
9. Transfer preflight checks

**Running E2E tests:**
```powershell
# Full verify (all repos)
.\root\scripts\stack.ps1 verify

# Backend phase 5 tests
cd rwa-tokenized-compliance-system-backend
mvn -Dtest=Phase5MarketplaceHappyPathTest test
```

## Test Data Management

### Test Fixtures

**Backend:**
```java
// test/java/com/rwa/fixtures/TestFixtures.java
public class TestFixtures {
    public static AssetOffering createPublicOffering() {
        return AssetOffering.builder()
            .name("Test Public Offering")
            .visibility(Visibility.PUBLIC)
            .status(OfferingStatus.ACTIVE)
            .minimumInvestment(new BigDecimal("10000"))
            .createdBy("admin-123")
            .build();
    }
    
    public static UserContext createInvestor(String userId) {
        return new UserContext(
            userId,
            UserRole.INVESTOR,
            "tenant-123",
            "investor@example.com",
            "0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb"
        );
    }
}
```

**Frontend:**
```typescript
// src/lib/test-fixtures.ts
export const mockOffering = {
  id: 1,
  name: 'Test Offering',
  visibility: 'PUBLIC' as const,
  status: 'ACTIVE' as const,
  minimumInvestment: 10000,
  createdBy: 'admin-123',
}

export const mockInvestor = {
  id: 'investor-123',
  email: 'investor@example.com',
  role: 'INVESTOR' as const,
  walletAddress: '0x742d35Cc6634C0532925a3b844Bc9e7595f0bEb',
}
```

### Database Test State

**Backend uses in-memory H2 in test profile:**
```yaml
# src/test/resources/application-test.yml
spring:
  datasource:
    url: jdbc:h2:mem:testdb
  jpa:
    hibernate:
      ddl-auto: create-drop
```

**Test isolation:**
```java
@SpringBootTest
@Transactional  // Rollback after each test
class ServiceTest {
    @BeforeEach
    void setUp() {
        // Clean state before each test
        repository.deleteAll();
    }
}
```

## Test Coverage Goals

| Layer | Target | Current |
|-------|--------|---------|
| Backend services | >80% | Track in jacoco |
| Backend controllers | >70% | Track in jacoco |
| Frontend components | >75% | Track in vitest |
| Smart contracts | >90% | Track in forge |
| Critical paths | 100% | Authorization, linkage, KYC state |

**Generate coverage reports:**
```powershell
# Backend
cd rwa-tokenized-compliance-system-backend
mvn clean test jacoco:report
# Open: target/site/jacoco/index.html

# Frontend
cd rwa-tokenized-compliance-system-frontend
npm run test:coverage
# Open: coverage/index.html

# Contracts
cd rwa-tokenized-compliance-system-blockchain
forge coverage
```

## Test Maintenance

### When to Update Tests

- **Breaking changes**: Update affected tests immediately
- **New features**: Write tests before or alongside implementation
- **Bug fixes**: Add regression test reproducing the bug
- **Refactoring**: Ensure tests still pass; update if behavior changed

### Test Smell Checklist

❌ **Avoid:**
- Tests that depend on execution order
- Tests with hardcoded dates/times
- Tests that sleep/wait for arbitrary durations
- Tests that hit external services (use mocks)
- Tests with excessive setup (extract to fixtures)
- Tests that test implementation details instead of behavior

✅ **Prefer:**
- Isolated tests with clear arrange-act-assert
- Descriptive test names explaining scenario
- Mocks for external dependencies
- Parameterized tests for multiple scenarios
- Test fixtures for common setup

## Debugging Failed Tests

### Backend Test Failures

```powershell
# Run with full stack trace
mvn test -X

# Run specific test with debug
mvn -Dtest=FailingTest test -Dmaven.surefire.debug
# Attach debugger to port 5005

# Check test logs
cat target/surefire-reports/FailingTest.txt
```

### Frontend Test Failures

```powershell
# Run with debugging
npm run test -- --reporter=verbose

# Run in UI mode for interactive debugging
npm run test:ui

# Check for async issues
npm run test -- --no-coverage
```

### Contract Test Failures

```powershell
# Run with maximum verbosity
forge test --match-test failingTest -vvvv

# Show stack traces
forge test --match-test failingTest --show-progress

# Check gas usage
forge test --gas-report
```

## Continuous Testing

### Pre-commit Hooks

```bash
# .git/hooks/pre-commit
#!/bin/bash

# Run linting
cd rwa-tokenized-compliance-system-frontend
npm run lint

# Run quick tests
cd ../rwa-tokenized-compliance-system-backend
mvn test -Dtest=*SecurityTest

# If any fail, prevent commit
if [ $? -ne 0 ]; then
  echo "Tests failed. Fix issues before committing."
  exit 1
fi
```

### CI Pipeline

Tests run automatically on:
- Every push to feature branches
- Every pull request
- Merges to develop/main

**Pipeline stages:**
1. Lint and format check
2. Build verification
3. Unit tests
4. Integration tests
5. Security scans
6. Coverage reports

## Next Steps

- **Deployment procedures**: [4-deployment-procedures.md](4-deployment-procedures.md)
- **Operational runbooks**: [5-operational-runbooks.md](5-operational-runbooks.md)
- **Phase 5 E2E details**: [scripts/e2e-phase5.md](scripts/e2e-phase5.md)