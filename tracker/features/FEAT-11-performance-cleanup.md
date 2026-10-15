# FEAT-11 — Measured performance cleanup

Date: 2026-09-26

## Scope and baseline

Reviewed the main Next.js 14.2.35 application, independent Next.js builder, FastAPI/SQLAlchemy service, dependency manifests, route/component inventory, database access patterns, and Compose deployment. Existing uncommitted changes were retained. No migrations, routes, assets, or database objects were removed.

Production entry points remain `next start`, builder `next start -p 3001` under `/website-builder`, and `uvicorn app.main:app`. Compose contains PostgreSQL and Redis only; no application Dockerfiles or Docker executable were found. There are no frontend test scripts. Existing backend tests use in-memory SQLite, not production PostgreSQL.

Before edits: both production builds and TypeScript checks passed; backend had 45 passing tests (5.33 s), with two existing Pydantic deprecation warnings. Neither frontend had an ESLint configuration, so `next lint` prompted interactively and exited unsuccessfully. Explicitly running Next's core-web-vitals rules found two unescaped-quote errors and six hook warnings in the main app.

## Changes and measurements

| Area | Before | After |
| --- | --- | --- |
| Admin metrics data queries (excluding authentication) | 6 | 1 statement with independent scalar aggregates |
| Student directory data queries (excluding studio/auth resolution) | 2 + number of students on page | 3 on populated pages; 2 on empty pages |
| Enrollment objects materialized for directory | All enrollments for every listed student | One aggregate row per enrolled student |
| Builder template catalog requests per successful page load | Server request plus browser request | Server request; browser fallback only if server returned no templates |
| Default font remote stylesheet | Requested after hydration despite next/font assets | Uses existing self-hosted families |
| Direct runtime npm dependencies, each frontend | 6 | 4 |
| node_modules main / builder (rounded disk usage) | 369 / 366 MiB | 368 / 365 MiB |
| Main shared first-load JS | 87.3 kB | 87.3 kB |
| Main dashboard first-load JS | 148 kB | 148 kB |
| Builder first-load JS | 104 kB | 104 kB |
| Backend suite | 45 passing | 47 passing |

Bundle totals are Next's reported figures; rounded disk usage is not transfer size. The main dashboard route itself moved from 47.4 to 47.5 kB. This work does not claim a browser JavaScript size reduction. Timed post-change builds took 10.05 s (web) and 7.73 s (builder), running concurrently; baseline build duration was not captured, so no build-speed improvement is claimed. Total .next size contains mutable build caches and is not a reliable deployment-size comparison.

Implementation:

- `progressrooms-api/app/modules/students/router.py`: tenant-scoped enrollment totals for only the current page; retains expired enrollments, null-total handling, filters, pagination, and response fields.
- `progressrooms-api/app/modules/admin/router.py`: scalar aggregates preserve count and paid-revenue semantics without multiplying rows through joins. All aggregates now see one statement snapshot.
- `progressrooms-api/app/modules/websites/rendering.py`: append downloaded chunks into a bytearray instead of repeatedly copying the complete immutable buffer. Keeps image validation, limit, URL restrictions, and encoding.
- `progressrooms-web/src/services/themeService.ts`: reuse next/font defaults; retain all selectable alternatives and avoid assigning an identical stylesheet URL again.
- `progressrooms-web/src/components/FontInitializer.tsx` and root layout: isolate initialization from the selector's UI module.
- `progressrooms-builder/src/components/WebsiteEditor.tsx`: reuse the fresh server catalog, preserving the existing client fallback on server failure. No cross-request cache introduced.
- Both manifests/lockfiles: remove `clsx` and `tailwind-merge`. Searched source, configuration, scripts, docs, and manifests including ignored nested repositories; these had no application consumers. Both production builds pass with packages physically removed.
- Both `.eslintrc.json` files and builder lint script: make lint noninteractive and repeatable. Escape two JSX quotes without changing rendered text.

## Verification

- `progressrooms-api/.venv/bin/python -m pytest -q`: 47 passed, two existing warnings (5.80 s).
- New `tests/test_optimization.py` checks aggregate equivalence, SQL statement budgets, cross-tenant exclusion, expired enrollments, null totals, unenrolled students, and an empty page with retained pagination totals.
- Both apps: `npm run typecheck`, `npm run lint`, and `npm run build` pass. Six existing main-app hook warnings and two builder image warnings remain. They are not suppressed; automatically adding effect dependencies could alter request cycles. Builder images include upload previews and are intentionally retained.
- A local DOM-stub smoke check verified default font loading, alternate selection, repeated initialization, switching back, and invalid-selection fallback. This is not browser visual QA.
- Lockfile root runtime dependencies match manifests. No dependency upgrades.

## Manual verification steps

1. Open landing, login, registration, dashboard, student portal, and a public studio page at desktop/mobile widths; compare typography and layout with the prior version.
2. With no saved font preference, confirm the default font uses local Next assets without a dynamic Google stylesheet. Select every alternative, reload, and switch back to default.
3. Open the builder through the dashboard. Confirm template gallery, studio selection, uploads, preview, save, publish, and download. Check only one template-catalog request on a healthy full load; exercise API failure/recovery to check fallback.
4. Compare admin metrics and student-directory values; exercise filters and pagination, including unenrolled students and accounts belonging to multiple studios.
5. Preview a website with a legacy Unsplash image and verify the image appears; confirm invalid/oversized images still fail.

## Retained candidates and limits

- Large dashboard component remains the largest app chunk (~229 kB raw emitted JS). Splitting interactive panels needs browser workflow/visual coverage to ensure no loading/interactivity changes; no architectural rewrite performed.
- Possibly unused exports, state, styles, logo variants, and helper components were retained. Static no-unused diagnostics alone do not prove runtime/operational obsolescence.
- Python requirements retain compatibility drivers, auth extras, and test dependencies because production installation conventions and indirect consumers are not fully established. No clean Python dependency installation was performed.
- No production PostgreSQL query plans, live API latency, server startup, CPU/peak RSS, Docker image sizes, or browser visual equivalence were measured. Query-count gains are validated on the test database, not claims about production latency.
- Baseline/after build and test logs were captured under `/tmp/progressrooms-optimization`; this report records durable results. No database or production deployment was changed.
