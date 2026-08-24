# ADR-008: Password Visibility and Auth Simplification

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Product and UX

## Context

Authentication flows must balance security with usability. Industry best practices now recommend allowing password visibility toggles to reduce input errors, while legacy multi-factor authentication and invite-token flows add complexity without clear product value for the current two-role model.

## Decision

Standardize authentication UX around three elements only:

1. **Role selection** (INVESTOR or SUPER_ADMIN)
2. **Email and password** fields
3. **Shared PasswordInput component** with show/hide toggle (eye icon) for all password fields

Remove MFA code entry and admin invite token fields from all authentication flows (login, registration, password reset). Residual configuration keys for MFA or invite codes in YAML, database schemas, or i18n files are legacy artifacts and must not drive product UX.

The `PasswordInput` component must include:

- Accessible label association
- Toggle button with `aria-pressed` state
- Password strength indicator on registration/reset flows
- Consistent styling via `--vg-*` design tokens

## Consequences

- All password fields across the application use the standardized `PasswordInput` component.
- Authentication payloads contain only `{ email, password, role }` without MFA or invite code properties.
- Legacy MFA/invite configuration is inert and may be removed in future cleanup.
- Password visibility improves usability while maintaining security through HttpOnly JWT cookies and backend authorization.
- Compensating security controls include rate limiting, audit logging, and ForceSync four-eyes approval for sensitive operations.

## References

- `_docs/based_rules.md` sections 5 (SEC-10), 7 (UI-07)
- `_docs/FUNCTIONAL.md` sections 6 (AUTH-S01, AUTH-S02, AUTH-S03), 7, 9 (BR-17, BR-18)
- `_docs/TECHNICAL.md` section 7.