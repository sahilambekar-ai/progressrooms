# FEAT-21 — Environment startup, developer UI gating and UAT account bootstrap

Implemented locally on dev, 25 October 2026. Not pushed or deployed remotely.

## Behavior and implementation

- Web `DeveloperModeProvider.tsx`: developer controls and developer-only content require a localhost hostname, a development build, and the dev target. Production builds, hosted UAT/prod, and local UAT/prod modes return disabled context even with a saved developer-mode preference.
- Web `scripts/start-environment.mjs`, `package.json`, `next.config.mjs`: `npm start dev|uat|prod` (case-insensitive) starts a local frontend against the selected backend using an origin-local API proxy. Browser API URLs remain `/api/v1`; API_URL selects the backend for server-rendered pages and the communication proxy. Separate caches prevent target contamination; target process variables override `.env.local`. `--check` prints a non-secret target summary. `npm start` retains production next-start behavior. Remote modes use HTTPS. These commands do not deploy code or seed remote databases.
- API `app/validation_seed.py`: explicit optional admin bootstrap via VALIDATION_ADMIN_ENABLED/VALIDATION_ADMIN_EMAIL. Stable per-environment password derived from the existing private seed secret. Creates an admin only when absent; initializes a missing password for a matching active admin. Existing passwords are preserved; existing roles are not escalated; disabled admins are not reactivated. The single-admin database constraint remains intact.
- API `deploy/setup-uat-validation.sh`, deployment workflow and `uat.sh`: after user promotion, deployment supplies a helper which installs private UAT seed settings, seeds missing validation data and recreates only the UAT API. Shares deployment lock, validates profile/secret/path and makes a mode-0600 config backup. Works with existing persistent data volume; no migrations or volume resets are performed by this setup helper.
- Existing private UAT/prod `.env` files and credential Markdown documents now include admin bootstrap. Existing seed secrets and all 68 original accounts' passwords are unchanged. Private files stay ignored and mode 0600; no credentials are committed. Server-generated credential document after seeding is authoritative for an existing admin.

## Verification

- `npm start dev -- --check`, `npm start UAT -- --check`, `npm start prod -- --check`: correct targets, isolated caches, developer controls disabled for both remote modes.
- `npm run typecheck`.
- `bash -n deploy/setup-uat-validation.sh`, `bash -n deploy/uat.sh`, Python compile.
- Targeted API seed, admin-management, account-role and authentication tests: 19 passed, including repeatable seed, studio/teacher/student password login, optional admin creation and password login, preserved passwords and role escalation refusal.
- Browser-tested local UAT mode at localhost:3001/login: no developer floating icon or developer credential controls.
- Attempted UAT verification, but hostname resolution for uat.progressrooms.com failed from this machine; external web fetch also could not reach it. No claim that the VPS has been seeded. Follow the commands in API deploy/README.md after promotion. No production database changes performed.

## Manual checks after deployment

1. Open hosted UAT in a browser that previously enabled developer mode. Floating developer controls must remain absent. Repeat on a production build.
2. Install the original private UAT seed config with the helper. Download the post-seed credential document privately. Sign in normally as owner, teacher, student and super admin. Repeat the helper; no duplicated users, studios or password resets should occur.
3. Locally run each frontend target, inspect /api/v1 requests, and verify the selected API. For UAT/prod, the frontend proxies remote requests without changing VPS CORS. Verify that normal local dev still displays developer controls.
4. If the domain does not resolve, fix DNS/connectivity before treating authentication failures as missing data. Seed failures produce actionable messages and never replace an existing admin.
