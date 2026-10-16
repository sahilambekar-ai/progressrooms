# Application and database simplification — 2026-10-16

Scope: current dev working trees; My Website implementation excluded. Existing uncommitted work was preserved. No Git commits or pushes were made.

## Implemented application changes

- Deferred studio classes, memberships, attendance calendar, billing and studio analytics in the admin dashboard; deferred explore, attendance and checkout in the student portal.
- Split the global communication button from its full panel. The root layout imports only the visibility control; the panel loads on opening, including its direct dashboard entry.
- Extracted studio analytics with its aggregate request and a visible error state. Opening analytics no longer fetches paginated student records and support conversations just to derive counts. Removed unconditional mount-time student/support fetches.
- Removed obsolete sample students, attendance/query handlers, progress state and associated local-storage hydration; cleaned unused imports. TypeScript now checks unused locals and parameters.
- Removed the unreferenced font selector and six-option theme service; the existing root Lora configuration and CSS remain authoritative.
- Consolidated five exact duplicate image files: 750,173 bytes (732.6 KiB). Permanent redirects preserve existing public image URLs, including links from previously generated content. Canonical brand images and website source files were retained.
- Enabled standalone Next output and added sharp 0.34.5 (from the existing package cache) to preserve production image optimization. `npm run build:standalone` includes public/static assets; production needs only the prepared standalone directory, rather than development node_modules and build cache.
- Replaced unused Passlib with the directly used bcrypt dependency (5.0.0, verified installed version). Moved pytest/pytest-asyncio and the SQLite test driver into requirements-dev.txt. Other runtime dependencies, including asyncpg and the synchronous Alembic PostgreSQL driver, remain needed.

## Database decision

Retire `user_auth_methods` and consolidate password credentials into `users.password_hash`. Registration and password reset previously wrote both locations; login used the users column first with a legacy fallback. OTP challenges already use `user_otps`, which stores hashes, expiry, attempt limits and verification state. The retired table therefore duplicated current identity behavior and retained obsolete plaintext OTP mirrors.

Alembic revision `016_consolidate_passwords` (after `015_meetings_and_support`):

1. Locks both authentication tables on PostgreSQL to prevent races during backfill/removal.
2. Rejects providers other than PASSWORD/OTP and conflicting legacy-only password hashes before writing anything.
3. Copies an unambiguous legacy password only when the user's canonical password is missing/empty. Existing canonical hashes win, preserving previous login behavior.
4. Removes the mirror table. ORM exports, registration/reset/login logic and seed scripts now use the single source.
5. Downgrade recreates password mirror rows from users. Legacy plaintext OTP values are intentionally not restored; use the database backup if exact historical recovery is needed. Current hashed OTP challenges remain untouched.

### Tables deliberately retained

| Area | Reason |
| --- | --- |
| Orders, items, payments and webhook events | Purchase intent, line items, payment attempts and deduplication are separate lifecycles. Merging loses retry/history semantics. |
| Organization students and session enrollments | Studio membership/teacher assignment is distinct from purchased class access and validity. |
| Student and teacher attendance | Different subjects, foreign keys and status semantics; combining needs nullable polymorphic references or a larger identity redesign. |
| Recurrence rules, occurrences and occurrence changes | A recurring template is distinct from actual scheduled/cancelled classes and their history. |
| Platform plans/subscriptions and student membership tiers | Studio SaaS entitlements are distinct from student offerings. |
| Session pricing/requirements and organization settings | These one-to-one records have active readers/writers, including public website paths; changing them would broaden the excluded scope. |
| Communication settings, consent, logs, budgets and reminder jobs | Configuration, audit evidence and executable work have different cardinalities and retention. |
| Other unused-looking models | No deletion based solely on absence of application references; external consumers and planned features are not established by this review. |

## Local database rollout

The configured localhost PostgreSQL database was at 015. Read-only preflight found 20 PASSWORD and 1,028 legacy OTP mirror rows, with no unsupported providers or ambiguous legacy-only passwords.

A private custom-format backup was created and its archive inventory verified at `/private/tmp/openroots-progressrooms-before-016.dump` (mode 0600). Keep this backup privately until the change is accepted; it contains the full development database and is outside Git.

Upgrade and downgrade were first exercised on transactional copies of the real authentication tables in a temporary PostgreSQL schema; the test transaction and schema were rolled back. Migration 016 was then applied to the actual local development database. Verification: revision 016, all 1,031 users retained, 21 canonical password accounts, and no user_auth_methods table. No remote database was changed. The old unversioned SQLite file is not the configured database and was left untouched.

For another environment: back up, stop old API writers, verify revision 015 and auth preflight, apply `alembic upgrade head`, then start the matching API code. Old code depends on the removed table and cannot run against revision 016; downgrade before reverting to it. Do not treat this local migration as a production promotion.

## Verification and measurements

- Backend: 102 tests passed (99 existing plus 3 migration tests); two pre-existing Pydantic deprecation warnings.
- Migration tests cover backfill, duplicate identical hashes, preservation of canonical hashes, empty password values, downgrade, unknown providers and ambiguous credentials. PostgreSQL rehearsal additionally verified upgrade/downgrade against real local data.
- Frontend: production compilation, lint and type checks passed. Existing hook-dependency and raw-image lint warnings remain. No new unused-code failures.
- Google Fonts network access was unavailable during build verification. The Next font test hook was pointed to real cached Lora CSS/font files for both measured builds; no font mocking was added to application source or production scripts. A normal clean build still needs its existing Google Fonts access.
- Packaged standalone runtime: login/dashboard/student returned HTTP 200, 18 referenced static assets returned HTTP 200, and all five legacy logo URLs redirected to valid images. After adding sharp, the optimized image endpoint returned HTTP 200 and a valid 595-byte PNG. Browser verified login rendering and opening/closing the deferred communication panel. Its API request failed on the temporary test origin; authenticated communication-provider behavior was not validated by that browser check.
- Controlled comparison: identical optimized source, fonts, assets and configuration, with panel imports changed from static to deferred in an isolated copy. Figures are gzip sizes of the union of layout+route initial JavaScript from app-build-manifest, not a comparison with an unrecorded historical working tree, full eventual downloads or production timing measurements.

| Route | Static panels | Deferred panels | Reduction |
| --- | ---: | ---: | ---: |
| Admin dashboard | 186.25 KiB | 162.82 KiB | 23.43 KiB (12.6%) |
| Student portal | 138.97 KiB | 123.02 KiB | 15.95 KiB (11.5%) |
| Login | 118.47 KiB | 112.41 KiB | 6.06 KiB (5.1%) |

The complete standalone package, including sharp, public files and static assets, is about 46 MiB, compared with roughly 397 MiB of the original local development node_modules. This is packaging scope, not a reduction in required production functionality. Local build/cache disk sizes should not be confused with browser transfer size.
