# Teacher Zoom implementation and verification

## Implemented application behavior

- Teaching eligibility is separate from staff permissions. Owners remain `STUDIO` members and appear once in the teaching roster. Last-teacher removal is protected, including admin controls.
- Per-member Zoom bindings, hashed expiring single-use OAuth/request state, intended-user checks, explicit verified-identity confirmation, Fernet-authenticated token encryption, refresh rotation, reconnect states and signed deauthorization handling replace organization-wide S2S credentials.
- A backend-only `disabled` / `mock` / `live` provider mode chooses the adapter. Mock mode is rejected outside development/tests. Every mock identity/meeting is labeled, and `production_ready` stays false.
- Studio settings manage shared defaults, an active default host, fallback, and versioned updates. Generic profile saves cannot forge Zoom status or alter identity/defaults. OAuth is optional for teacher creation and studio onboarding. Shared host-key/S2S/test-room endpoints return explicit retirement messages.
- Teacher table Zoom column, account dialog, authorization request link, optional edit control, complete detail popup, owner badge, teacher self-service and keyboard row access share one API state.
- Meetings persist their host binding/version, verified host email, settings snapshot, operation key and lifecycle state. Creation persists intent before the provider call, serializes on studio/occurrence locks, and blocks duplicate retry after an ambiguous response. Reconciliation searches a unique marker in the provider meeting topic. An uncertain response without a match stays blocked for manual provider inspection; it never creates a speculative second room.
- Host overlap checks use the resolved account, including fallback shared by different teachers. One simultaneous meeting is assumed. Reschedule/cancel operations use the saved connection. Changing teachers acknowledges the existing meeting-host impact; moving the Zoom host is a separate previewed operation preserving the old meeting ID/link/settings in class history.
- Participant access returns join information only. A fresh start URL is fetched only when the authenticated requester owns the saved Zoom binding. Neither the studio owner nor an assigned teacher receives another teacher's Zoom start URL merely through their application role. Host URLs are not cached in occurrence rows or agenda responses.
- Existing future settings updates have an explicit preview/apply endpoint with individual failures/retries and provider-restriction reporting. Recording defaults are retained as legacy data but new meetings request no automatic recording.
- Disconnect purges the binding's token material immediately, pauses default-host provisioning, retains class history, and queues encrypted provider revocation for retry. Pending provider-revocation credentials are retained at most 24 hours; expiry requires manual removal in Marketplace. Unconfirmed candidate credentials expire after five minutes and are purged by maintenance, with revocation where it will not revoke an active binding. The deployment includes the maintenance worker and an owner retry action.

## Database cutover

`018_zoom_settings` now points to the actual predecessor `016_consolidate_passwords`; `019_class_packages` and `020_teaching_capability` are preserved. New `021_teacher_zoom_oauth` creates private authorization tables and host fields, disables legacy integration operations, and pauses automatic provisioning. Existing Zoom meeting IDs/links remain. Old S2S secrets are **not** falsely converted into OAuth grants and are **not** copied to an encrypted-looking column. The migration intentionally leaves legacy credential bytes untouched until an explicit, backed-up purge procedure.

After real OAuth acceptance, inspect which legacy meetings require owner reconciliation, then use the separately documented administrative purge command. Deleting a local binding or replacing a meeting does not claim that the previous remote Zoom meeting was deleted. A downgrade does not automatically restore deprecated credentials, active flags or automatic provisioning.

Only disposable databases were migrated during implementation. No UAT/production data, branch refs or remote branches were modified.

## Mock demo

From `progressrooms-api`, run:

```sh
.venv/bin/python -m scripts.seed_zoom_demo
```

This creates only `/private/tmp/progressrooms-zoom-demo.db` and a mode-0600 `/private/tmp/progressrooms-zoom-demo.env`. It does not use the studio database. Synthetic owner: `owner@zoom-demo.example.com`; teachers: `teacher1@zoom-demo.example.com` / `teacher2@zoom-demo.example.com`; student: `student@zoom-demo.example.com`. Demo-only password: `ZoomDemoOnly2026!`.

Start the mock API:

```sh
.venv/bin/python -c "from dotenv import load_dotenv; load_dotenv('/private/tmp/progressrooms-zoom-demo.env', override=True); import uvicorn; uvicorn.run('app.main:app', host='127.0.0.1', port=8005, access_log=False)"
```

From `progressrooms-web`:

```sh
NEXT_PUBLIC_API_URL=http://localhost:8005/api/v1 npm run dev -- --hostname 127.0.0.1 --port 3005
```

Open `http://localhost:3005/login`. Demo teacher 1 has a personal simulated identity; teacher 2 uses the owner's simulated fallback. Connect/reconnect follows the same request, callback and explicit confirmation application path. Mock room links lead to a local simulation screen, never a counterfeit real Zoom URL. Seeded class times are relative to initial seeding; create new sample classes when the initial ones are past.

## Verification commands

```sh
# API
.venv/bin/pytest -q
.venv/bin/alembic heads
# Isolated PostgreSQL only; tests create and remove unique disposable schemas.
ZOOM_TEST_POSTGRES_URL=postgresql+asyncpg://USER:PASSWORD@HOST:PORT/TEST_DATABASE .venv/bin/pytest tests/test_zoom_postgres.py -q
# Web
npm run check
npm run lint -- --no-cache
npm run build
```

The live adapter is tested with `httpx.MockTransport`, covering backend Basic auth, code exchange, verified `/users/me` identity, refresh, create, fresh start URL, update, delete and revoke. No real Zoom API key or account is used. PostgreSQL tests verify simultaneous refresh rotates once and simultaneous provisioning creates once. Normal CI runs those tests against its disposable PostgreSQL service.

Live Zoom account, license, account-locked settings and Marketplace notification acceptance remain pending the values in [the Marketplace checklist](zoom-marketplace-setup-2026-10-21.md). These are not claimed complete by mock tests.

## Explicit legacy-secret purge after live acceptance

Preview without reading secret values:

```sh
.venv/bin/python -m app.modules.zoom.legacy --organization STUDIO_UUID
```

After a backup and successful live OAuth acceptance for that studio, an administrator may explicitly run:

```sh
.venv/bin/python -m app.modules.zoom.legacy --organization STUDIO_UUID --purge --acknowledge-backup-and-live-acceptance
```

The command refuses a purge without an active live connection. It clears only that studio's legacy integration credential bytes/shared host key, preserves OAuth grants and historical class records, and does not print tokens. This purge was not run during mock implementation.

## Recorded verification outcome

- **139 backend tests passed**, including three isolated PostgreSQL tests covering concurrent refresh, concurrent creation and database rejection of cross-studio default-host substitution.
- PostgreSQL migration testing passed for `020 → 021`, populated synthetic legacy credentials/meeting history, downgrade/upgrade, and repeat upgrade at head. Existing IDs and links survived; legacy calls were disabled without inventing OAuth grants. The earlier fresh database migration chain through `020` also passed.
- Frontend type check, lint and production build passed. Lint/build retain existing hook-dependency and image-component warnings; there are no blocking errors. The build needed network access for the project's existing Google Fonts.
- Browser checks passed for synthetic owner sign-in, personal/fallback teacher badges, full teacher details, authorization request link generation/copy availability, mock OAuth redirect, verified-identity confirmation, and saving shared defaults. [Saved preview](zoom-mock-preview-2026-10-21.png).
- Added direct regression coverage for class-batch provider cancellation, host replacement audit history, partial future-setting failures, provider restrictions, mode cutover cleanup, and student responses never fetching or containing a host/start URL. Already-current future settings are skipped during apply/retry.
- Class deletion cancels saved remote meetings through their original connection before completing locally; a provider failure remains visible and can be retried, with repeated remote deletes treated idempotently. Changing recurring rules when future Zoom meetings are already provisioned requires explicit occurrence rescheduling. Inactive classes cannot provision or open meetings.
- All four repositories remain on `dev`. No commit, push, promotion PR, live configuration or deployment was performed. Existing uncommitted work was preserved.
