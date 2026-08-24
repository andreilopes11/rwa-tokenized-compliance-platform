# ADR-009: Design System and Institutional Branding

- **Status:** Accepted
- **Date:** 2026-08-22
- **Decision owners:** Design and Product

## Context

Financial institutions require design systems that convey trust, professionalism, and clarity. Generic AI-generated palettes (purple gradients, cream-terracotta combinations, emoji decoration) undermine institutional credibility. The interface must scale across investor and administrative workspaces while maintaining consistent brand identity.

## Decision

Establish VaultGuard RWA design system with:

**Brand positioning:**

- Product name **VaultGuard RWA** appears at hero level on marketing and login surfaces
- Workspaces (`/dashboard`, `/governance`) use calm, institutional styling
- Brand conveys custody (Vault) and compliance (Guard) for banking trust

**Design tokens** (CSS custom properties with `--vg-*` prefix):

```css
--vg-bg: #0f1419 (deep slate)
--vg-surface: #1a222c (raised slate)
--vg-text: #e8eef4 (soft white)
--vg-muted: #8b9aab (muted steel)
--vg-accent: #2f6fed (trust blue)
--vg-accent-soft: #1e3a5f (muted blue)
--vg-success: #1f8a5b (forest green)
--vg-warning: #c49214 (amber)
--vg-danger: #c23b3b (crimson)
--vg-border: #2a3542 (subtle border)
--vg-radius: 8px
--vg-font-display: "Source Serif 4", Georgia, serif
--vg-font-body: "IBM Plex Sans", system-ui, sans-serif
--vg-font-mono: "IBM Plex Mono", ui-monospace, monospace
```

**Component principles:**

- Cards only wrap interactions (forms, confirmations) or marketplace offerings
- One purpose per section: single headline, brief support text, one primary action
- Hierarchy through typography and spacing, not decorative elements
- Motion limited to 2-3 purposeful transitions per critical flow
- Dark theme default with light theme overrides using same token names

**Typography scale:**

- Display (Source Serif 4): hero headlines, marketing
- Body (IBM Plex Sans): interface text, labels, descriptions
- Mono (IBM Plex Mono): addresses, hashes, code samples

## Consequences

- All interface components reference `--vg-*` tokens exclusively; no ad-hoc hex values
- Theme switching requires only token value overrides, not component changes
- Institutional aesthetic differentiates VaultGuard from consumer fintech products
- Design system documentation lives in `src/app/globals.css` as canonical source
- Component library (`shared/ui`) provides primitives without business logic
- Accessibility compliance follows WCAG 2.1 AA standards (contrast, focus indicators, labels)

## References

- `_docs/based_rules.md` sections 7 (UI-01 through UI-13)
- `_docs/FUNCTIONAL.md` section 7
- `_docs/TECHNICAL.md` section 7