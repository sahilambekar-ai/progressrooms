# Progress Rooms review — 2026-09-09

The current application is a foundation release, not the complete product in the specification. Authentication, organization creation, membership checks, plans and trial entitlements are implemented. Catalog, scheduling, public organization pages, commerce, student classes, websites and workers are explicitly planned. Their absence is not an unexpected regression.

Reviewed the sibling specification, its identical in-project copy, implementation plan and tracker, product/architecture/API/security/operations documents, SQL migration, API services, frontend forms/routes, tests and CI/container setup. No separate agent-run/helper file was found in the supplied folder. The tracker references an external `agent_helper_document.md`; its contents could not be checked here. This review does not certify every future-domain invariant or provider integration.

## Findings in priority order

### 1. High — OTP rate limiting groups browser users under the BFF address

Evidence: `progressrooms-web/src/lib/bff.ts:41` sends requests without trusted client-IP context. `progressrooms-api/app/services/auth.py:20` uses the immediate peer address; `app/core/config.py` defaults to 20 OTP requests per IP per hour. The API container explicitly disables proxy-header handling.

With one BFF egress address, 20 successful code requests across all users exhaust that shared budget, and the next unrelated user receives 429. The shared IP advisory lock also serializes their issuance transactions. The deployment documentation acknowledges proxy budgets, but tuning the number alone does not provide per-user-IP protection.

Implement an authenticated/trusted ingress-to-BFF-to-API client identity path, or enforce client-IP limits at trusted ingress and use a deliberate service-level API budget. Never trust arbitrary incoming forwarded headers. Retain the per-email limit. Add a cross-service test with distinct browser client addresses and a spoofed-header rejection case.

### 2. High before deployment — No production bootstrap for required catalog data

Evidence: the only plan inserts are in `progressrooms-api/scripts/seed/seed_data.py:70`; that command refuses production and also creates demo users and a platform administrator. The migration creates tables without catalog rows. `app/services/organizations.py:103` requires an active Starter plan or returns `503 PLAN_UNAVAILABLE`.

Following the production migration instructions on a fresh database therefore leaves an empty plan catalog and prevents organization creation. Add an idempotent production catalog bootstrap/data migration separated from all demo identities, organizations and sample paid prices. Document a separate controlled first-admin bootstrap. Test a fresh production-like install without development fixtures.

### 3. Medium — Scheduling design and schema disagree about overnight classes

Evidence: `docs/07-scheduling/scheduling-engine.md:9` requires an explicit end-day offset for overnight events. `docs/03-database/schema.sql:653` and the identical migration define no such field; line 674 requires `end_time > start_time`.

A 23:00–01:00 class cannot be represented by this schema. Before the scheduling implementation, add a bounded end-day offset and a duration constraint that incorporates it, or explicitly remove overnight support from the initial contract. Update the inventory, schema documentation and migration together. Cover same-day, overnight, invalid duration and DST cases.

### 4. Medium — Readiness accepts an empty or incorrect migration revision

Evidence: `progressrooms-api/app/main.py:88` executes `SELECT version_num FROM alembic_version` but does not inspect the result. An existing empty version table, or a database at a different revision, still produces `{"status":"ready"}`.

Validate the database revision against the application's supported migration head(s), returning 503 for missing/incompatible revisions. Test empty, stale and correct revisions. Use readiness, rather than liveness alone, in rollout traffic checks.

### 5. Medium — Source and architecture do not yet have a committed baseline

Both application repositories report zero commits, with all application sources untracked. The parent specification, architecture and tracker also sit outside either repository. A clone of either repository would currently recover none of this work; even after application commits, the parent documentation would remain outside them.

Create reviewed initial commits with secret exclusions intact. Choose a tracked home for the shared specification/docs/tracker, then establish backup/remotes according to the intended workflow. No commits, remotes or repository restructuring were performed by this review.

## Useful enhancements

- Add real browser tests for OTP entry/recovery, organization creation, student denial, mobile layouts and keyboard navigation. Existing E2E tests use HTTP fetches, and the frontend CI does not run them. Add cross-service CI alongside browser coverage.
- Improve OTP recovery with an explicit resend action and countdown. Today an expired/exhausted code tells users to request a new one, while the visible recovery action is “Use another email”.
- Preserve the requested private URL when redirecting an expired session to login. The login screen understands `next`, but API authentication redirects always send users to `/login`, losing the destination.
- Complete the concurrency contract before mutable domains: APIs specify `revision`, but catalog and occurrence rows have no explicit revision counter. Define the token/storage strategy and stale-write tests. Likewise, settle payment reservation and request-fingerprint persistence before implementing checkout.
- Generate frontend contract types from the exported OpenAPI specification to reduce divergence from manually maintained `src/lib/types.ts`.
- Replace catch-all organization `IntegrityError` handling with a check for the slug uniqueness constraint. Other integrity failures currently become a misleading “address already in use” response.
- Apply request-body limits before buffering. The BFF's 4,096-character check occurs after `request.text()` has loaded the whole request; it is validation, not an ingress memory limit.

## Verification performed

- Specification copies: byte-for-byte identical.
- Ruff: passed.
- Frontend Biome: passed (29 files).
- TypeScript: passed.
- API tests without a database: 4 passed, 7 skipped.
- Created a separate `progressrooms_review_20260909_test` database, applied the existing migration and ran all API tests: **11 passed**. Removed that disposable database afterward. Existing development/test databases were not reset.
- Inspected repository status: zero commits in both repositories.

No new browser E2E, production build, Docker/hosted CI, live email/payment/Zoom or dependency-advisory validation was performed. Earlier tracker results are historical claims, not new results from this review. The findings above are based on local implementation and contract evidence. Application code was not changed.

Recommended sequence: establish the source baseline; correct OTP proxy handling and production bootstrap; strengthen readiness and cross-service tests; reconcile scheduling/concurrency contracts; then implement class management in the existing roadmap order.
