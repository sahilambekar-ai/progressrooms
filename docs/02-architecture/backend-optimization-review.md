# Backend optimization review — 2026-09-29

Scope: current working tree of progressrooms-api, including all API modules, ORM models, schema migrations, core services, seed usage, and tests. Existing uncommitted changes were preserved. This is a source review plus isolated SQLite tests, not a production benchmark or live data inventory.

## Implemented

| Area | Change | Evidence / limit |
| --- | --- | --- |
| Schedule generation | One range-limited timestamp query replaces the duplicate lookup inside the occurrence loop; deduplicate overlapping rules in memory | 11 generated dates use four SELECTs total; repeating the call creates zero rows |
| Schedule updates | Flush pending rule changes, refresh loaded collections, lock parent session during generation | Regression replaces already-loaded rules; PostgreSQL concurrent locking still needs integration testing |
| Conflict checks | Select only an ID with LIMIT 1 | Multiple overlapping occurrences no longer raise MultipleResultsFound |
| Attendance roster | Join users and only the requested occurrence's attendance; explicit organization filter | Two queries excluding completion processing, including unmarked students; historical attendance is not loaded |
| Student calendar | Enrollment subquery replaces materialized IDs and extra round trip | Duplicate active enrollments do not duplicate returned occurrences; unrelated user receives no rows |
| Completion scan | Only load one-on-one sessions with an elapsed occurrence; omit unused instructor collection | Avoids loading future-only sessions and their relationships; existing completion behavior retained |
| Organization / public site | Remove unused settings eager loads | Existing response shape retained |
| OTP request | Stop writing a second, plaintext OTP into user_auth_methods | Hashed user_otps remains authoritative; password fallback and legacy cleanup remain compatible |
| Indexes | Add occurrence (session_id, scheduled_start_at), enrollment (organization_id, user_id), enrollment (session_id, status) | Model metadata and Alembic revision 008 agree; no live migration applied |

Do not infer latency improvements from SELECT counts alone. Use representative PostgreSQL data and EXPLAIN (ANALYZE, BUFFERS) before claiming production speedups. The indexes trade storage and write work for the observed access patterns. Existing single-column indexes were retained pending actual usage measurements.

## Table simplification

35 ORM tables exist. Five candidates have no runtime reader/writer in the current backend:

| Candidate | Current evidence | Removal prerequisites |
| --- | --- | --- |
| user_sessions | JWT authentication does not read or write this table | Confirm no other service uses it and whether server-side session revocation is planned |
| notifications | Model/export only; no notification API or worker | Confirm notification feature is not being built elsewhere |
| organization_domains | Model/export only; website lookup uses organization slug | Confirm no domain provisioning service consumes it |
| media_assets | Model/export only; uploads use filesystem paths and website JSON | Confirm no external asset inventory references it; retain actual files |
| organization_payment_accounts | Model/export and unused seed import; checkout uses global config | Confirm per-studio payment routing is not required |

No tables were dropped: source references cannot establish that deployed tables are empty or unused by external services. For each approved candidate, inspect row counts and foreign keys in the target database, export retained data, remove ORM exports/imports, and ship an explicit reversible schema migration. Avoid dropping historical tables merely because they are not read frequently.

Keep the remaining 30 tables for now:

- Identity: users, user_otps, user_auth_methods. The last has a real legacy password fallback. Backfill users.password_hash for accounts using only credential_hash, reconcile conflicts, remove dual password writes and fallback, then reconsider this table. Old plaintext OTP values need a separate cleanup; this change prevents new mirrors only.
- Tenant and profile: organizations, organization_members, organization_students, organization_settings. Student membership carries tenant-specific notes, teacher assignment, and status, independent of enrollment history.
- Platform billing: plans, plan_features, organization_subscriptions. These govern studio entitlements, distinct from student membership tiers.
- Class catalog: class_types, sessions, session_instructors, session_pricing, session_requirements. Pricing and requirements are possible one-to-one merges later, but both have real readers/writers and require data/API migration. Table count alone is not a reason to merge them.
- Scheduling: session_schedule_rules, class_occurrences, class_occurrence_changes. Rules describe recurrence; occurrences and changes preserve cancellations/rescheduling history.
- Commerce: orders, order_items, payments, payment_webhook_events, session_enrollments. Preserve transaction records and webhook deduplication. Do not merge enrollments into organization_students.
- Student passes: membership_tiers, membership_tier_classes. These describe offerings; current checkout still uses session_pricing. Decide how tiers are purchased before removing either pricing path.
- Attendance: attendance_records. This is the source record behind sessions_attended, not redundant history.
- Websites: website_templates, organization_websites. Templates are partly duplicated by the Python catalog, but current sites hold foreign keys to template rows. A static-code-only design needs a migration.
- Integrations and consent: organization_integrations, audit_logs. Zoom routes use the former; registration writes privacy consent to the latter.

## Remaining findings, in priority order

1. **Payment correctness precedes payment optimization.** commerce/router.py accepts a client-supplied provider order ID without binding it to a server-created provider order. Mock verification is allowed by configured secret prefix. Repeated verification creates another Payment/Enrollment and can hit unique constraints rather than returning the prior result. The webhook ignores its signature header and marks events processed without processing payment state. Implement provider-order binding, explicit environment gating, signature checks, atomic idempotent activation, and concurrency tests before production payments. This review does not change payment semantics.
2. **Read requests trigger writes.** classes/service.py is called by class lists, rosters, student lists and calendars. It automatically marks attendance, including for elapsed cancelled occurrences and non-active enrollments, and concurrent calls can race on attendance uniqueness. Move completion into an explicit transactional job/action; define attendance policy first. The filter optimization does not fix those existing semantics.
3. **Bound returned history.** list_sessions loads every occurrence for every class. Admin organizations, teacher lists, enrollments, and some catalogs have no pagination. Introduce date-windowed occurrence endpoints and page metadata with coordinated frontend changes. Add deterministic ID tie-breakers to paginated lists. Do not silently truncate existing array responses.
4. **Scheduling correctness.** The recurring engine treats rule times as UTC despite a timezone field. Schedule edits append new occurrences without reconciling old future ones. Define local timezone/DST and rescheduling policy, then add timezone and historical-attendance tests. Parent locking protects generators using this path, but there is no unique database constraint on (session_id, scheduled_start_at); audit existing duplicates before adding one.
5. **Enrollment access rules.** student/router.py checks ACTIVE status but not validity dates, exhausted credits, cancellation/completion, or the end of the meeting access window. Centralize eligibility and reuse it for calendar, meeting links, roster and admission. SQLite also returns naive timestamps; meeting-window arithmetic should use ensure_utc consistently.
6. **Avoid blocking the async server.** bcrypt hashing/checking occurs directly in async routes/services. Move CPU work to the thread pool; rate-limit login/OTP requests. Website rendering/upload/export also performs synchronous filesystem work in async handlers. Offload larger reads/writes and reuse a lifespan-managed HTTP client if traffic warrants it.
7. **Auth simplification.** Password/OTP login responses repeat organization/settings queries and settings creation. Share one context loader. OTP verification needs row locking to serialize attempt counting and consumption. Remove OTPs from email error logs. No plaintext OTP backfill or log cleanup was performed here.
8. **Smaller query improvements.** Batch instructor validation in class create/update; join subscription + feature lookups in entitlement checks; consolidate duplicated membership-tier serialization. Public site queries fetch all sessions/members and filter in Python: push public/active/deleted predicates into SQL after testing relationship-cache behavior. Preserve tenant predicates throughout.
9. **Schema constraints and drift.** Audit duplicates before adding unique constraints for plan features (plan_id, feature_key), instructor assignments (session_id, member_id), tier class links (tier_id, session_id), integrations (organization_id, provider), and active per-tenant slugs. docs/03-database/migrations/006_attendance_permissions_and_student_session_queries.sql describes tables absent from current ORM/Alembic; it is not the executable migration 006. Reconcile docs against a clean migrated PostgreSQL schema. Do not run reference SQL blindly.
10. **Operational simplicity.** Retain the current monolith. No demonstrated need for Redis caching, new services, repository abstraction layers, or more tables. Start with request latency/query metrics, SQL slow-query logging without parameters/secrets, and query plans. Set explicit retention for expired OTPs, preview exports and old webhook payloads after business/audit requirements are known.

## Validation and deployment

- Baseline: 55 tests passed, one existing query-budget test failed because a completion scan had been added without updating its expectation.
- Final suite: **61 passed**, with two existing Pydantic configuration deprecation warnings. PostgreSQL revision 008 SQL generation succeeded.
- Updated query budget now counts that scan; dedicated regression tests cover scheduling, conflict detection, attendance, OTP storage, and calendar enrollment duplication.
- Run `.venv/bin/python -m pytest -q` from progressrooms-api.
- Generate PostgreSQL migration SQL without connecting: `.venv/bin/alembic upgrade 007_student_profiles_pause:008_query_indexes --sql`.
- Migration 008 uses standard transactional index creation. For a large live installation, schedule a maintenance window or prepare a separate concurrent-index rollout. Do not apply without checking the target Alembic revision and index inventory.
- SQLite tests do not establish PostgreSQL locking behavior, foreign-key enforcement parity, or query planner speed. Validate those on a disposable PostgreSQL database before rollout.
