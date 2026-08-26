# Secret rotation checklist (Phase 6 / go-live)

Complete before production cutover. Do **not** commit real values.

| Secret | Env var | Rotated | Date | Owner |
|--------|---------|---------|------|-------|
| JWT signing | `APP_AUTH_JWT_SECRET` | ☐ | | |
| Document encryption | `APP_DOCUMENTS_ENCRYPTION_KEY` | ☐ | | |
| RPC credentials | `RPC_URL` / provider key | ☐ | | |
| Admin invite (if used) | `APP_AUTH_ADMIN_INVITE_CODE` | ☐ | | |
| Bootstrap admin password | `APP_AUTH_BOOTSTRAP_ADMIN_PASSWORD` | ☐ | | |
| KMS key id / from | `APP_BLOCKCHAIN_KMS_KEY_ID`, `APP_BLOCKCHAIN_KMS_FROM_ADDRESS` | ☐ | | |
| CORS origins | `CORS_ALLOWED_ORIGINS` (HTTPS only) | ☐ | | |
| Legacy admin API token | Disabled in production (`legacy-token-enabled: false`) | ☐ N/A | | |

After rotation: restart backend, invalidate sessions (users re-login), smoke `/api/auth/login` + `/me`.
