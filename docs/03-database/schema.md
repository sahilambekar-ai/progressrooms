# PostgreSQL schema blueprint

> Runtime update (2026-09-25): the implemented role model is documented in [Account roles](account-roles.md), with current ORM DDL in [runtime-schema.sql](runtime-schema.sql). The catalogue below is the earlier full-domain design, not the installed Alembic schema. In the running application, users.role is mandatory (SUPER_ADMIN, STUDIO, TEACHER, STUDENT); staff membership roles are STUDIO/TEACHER, and organization_students.teacher_member_id is constrained to the same studio.

Target: PostgreSQL 16. The initial migration creates the complete domain model; existence of a table does not imply that its business endpoints are implemented. `schema.sql` is the readable DDL and `schema-inventory.json` is the machine-readable catalogue. The immutable SQL copy in the API migration folder is what Alembic executes.

All identifiers are UUIDs and all instants are TIMESTAMPTZ. Schedule `DATE` and `TIME` fields deliberately describe local calendar rules, not instants. Money uses integer minor units and ISO currency codes. Fields named `updated_at` must be updated by application services on mutation. Every tenant resource has `organization_id` and composite foreign keys prevent mismatched tenant references. Foreign keys use RESTRICT to preserve business history; deletions are explicit retention/migration procedures.

Cross-row invariants require transactions: payment amount/currency versus order, aggregate refunds, capacity, consumption counters, current plan entitlements, accepted invitation email and instructor role. SQL prevents invalid references but never replaces authorization. Initial database access is application-scoped; PostgreSQL row-level security is not enabled by this migration. Use a restricted runtime role and tenant-filtered repositories; isolation tests are mandatory before release.

`organization_subscriptions` holds one current subscription per tenant; organization_subscription_history retains immutable transition snapshots. `plan_features.integer_value = -1` means unlimited, zero means disallowed, positive integers are limits. `Progress AI` remains COMING_SOON and non-purchasable. Staff and student memberships remain separate. Reserved route slugs are a database CHECK plus API validation; adding a top-level application route requires reserving its slug in a migration.

Public DTOs must omit student notes, meeting links, raw provider payloads, auth hashes, integration credentials and private media keys. Store only redacted webhook/audit payloads. Encrypted integration tokens carry a key ID for rotation; encryption keys live outside the database. Database history retention does not imply keeping personal data indefinitely; erasure pseudonymizes identities and removes operational metadata under an approved retention policy while preserving required financial evidence.

## Catalogue

- [users](#users) — One global identity reused across all organizations; credentials and roles live separately.
- [user_auth_methods](#user-auth-methods) — Future-compatible authentication method bindings; no plaintext credentials.
- [user_sessions](#user-sessions) — Revocable opaque login sessions. Store only a keyed digest of the bearer token.
- [otp_challenges](#otp-challenges) — Short-lived, single-use OTP challenges. Keyed hashes prevent offline guessing of small code spaces.
- [platform_admins](#platform-admins) — Explicit global administrator grants; granting organization ownership never grants platform access.
- [organizations](#organizations) — Shared business root for both individual teachers and multi-instructor studios.
- [organization_members](#organization-members) — Staff membership only. A person may hold different roles in different tenants.
- [organization_invitations](#organization-invitations) — Expiring invitations grant a specific staff role only after verified-email acceptance.
- [organization_students](#organization-students) — Private student relationship and notes for a tenant, backed by a global user.
- [organization_settings](#organization-settings) — Typed operational preferences; flexible contact/social content remains validated JSON.
- [plans](#plans) — Database-driven platform subscription catalogue; amounts are integer minor currency units.
- [plan_features](#plan-features) — Typed entitlements read by one centralized authorization/usage service.
- [organization_subscriptions](#organization-subscriptions) — Current platform subscription per tenant; historical transitions remain in organization_subscription_history and audit logs. Student purchases never use this table.
- [organization_subscription_history](#organization-subscription-history) — Append-only subscription transition snapshots; preserve past plan periods, amounts and effective access.
- [media_assets](#media-assets) — External-object metadata; PostgreSQL stores neither image binaries nor signed URLs.
- [class_types](#class-types) — Tenant-specific classification; no industry-specific application rules.
- [sessions](#sessions) — Sellable session or program; actual dated classes are class_occurrences.
- [session_instructors](#session-instructors) — Staff assignment with primary, secondary or substitute responsibilities.
- [session_pricing](#session-pricing) — Versionable access/pricing options; purchased values are copied into order items and enrollments.
- [session_requirements](#session-requirements) — Structured public prerequisites, equipment, preparation and notes.
- [session_schedule_rules](#session-schedule-rules) — Finite or open-ended weekly/local rules expanded only over a bounded rolling horizon. Local wall times intentionally use TIME and DATE.
- [organization_integrations](#organization-integrations) — Provider-neutral connected accounts; encrypted tokens remain inaccessible to browser/public response models.
- [class_occurrences](#class-occurrences) — Dated execution of a session. Original time is immutable; actual time changes during rescheduling.
- [class_occurrence_changes](#class-occurrence-changes) — Immutable cancellation/rescheduling history; redacted snapshots never include meeting secrets.
- [organization_payment_accounts](#organization-payment-accounts) — Organization-owned settlement destination, independent of platform subscription billing.
- [orders](#orders) — Student commerce order with server-computed totals and a tenant-local student relationship.
- [order_items](#order-items) — Immutable purchased session/pricing snapshot. Initial SESSION target has a real FK; other product types require an explicit migration.
- [payments](#payments) — Provider-confirmed movement for a student order; provider IDs are globally idempotent per provider.
- [payment_attempts](#payment-attempts) — One traceable provider checkout initiation attempt with redacted failure diagnostics.
- [refunds](#refunds) — Idempotent refund request and provider outcome. Aggregate refund amount is checked transactionally under payment lock.
- [payment_webhook_events](#payment-webhook-events) — Verified provider webhook inbox. Organization/order are resolved from trusted provider order references, never caller tenant claims.
- [session_enrollments](#session-enrollments) — Purchased access grant; each order item activates at most once. Renewal creates another grant and preserves prior payment history.
- [attendance_records](#attendance-records) — One attendance decision per student and occurrence; links the precise enrollment used for access.
- [attendance_consumptions](#attendance-consumptions) — Idempotent package usage ledger. Lock enrollment and ledger before toggling consumed state or restoring a class.
- [website_templates](#website-templates) — Versioned fixed-layout catalogue. Application renders templates; arbitrary HTML is forbidden.
- [organization_websites](#organization-websites) — Separate draft and published content snapshots prevent unreviewed edits leaking onto the public site.
- [organization_domains](#organization-domains) — Reserved support for verified custom domains; DNS automation is deferred.
- [notifications](#notifications) — Per-user delivery record, channel-independent. Public APIs never read this table.
- [notification_preferences](#notification-preferences) — User-controlled event/channel preferences, optionally overridden for an organization.
- [outbox_events](#outbox-events) — Transactional, at-least-once work queue for reliable notifications, scheduling and integrations. Workers must be idempotent.
- [audit_logs](#audit-logs) — Append-only business/admin audit history; snapshots are explicitly redacted and exclude credentials, OTPs and payment secrets.

## users

One global identity reused across all organizations; credentials and roles live separately.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| email | TEXT | No | — | UQ1 | Canonical lower-case email; application validates format. |
| full_name | TEXT | Yes | — | — | Full name |
| email_verified_at | TIMESTAMPTZ | Yes | — | — | Email verified at |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, SUSPENDED. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |
| deleted_at | TIMESTAMPTZ | Yes | — | — | Soft deletion instant; history and foreign keys remain intact. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(email)` (unique B-tree; NULL follows PostgreSQL default semantics).
- CHECK 1: `email = lower(btrim(email)) AND position('@' IN email) > 1`.
- CHECK 2: `status IN ('ACTIVE', 'SUSPENDED')`.

## user_auth_methods

Future-compatible authentication method bindings; no plaintext credentials.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| user_id | UUID | No | — | FK1, UQ2 | User id |
| provider | TEXT | No | `'EMAIL_OTP'` | UQ1, UQ2 | Allowed values: EMAIL_OTP, PASSWORD, GOOGLE, APPLE, PHONE_OTP. |
| provider_subject | TEXT | No | — | UQ1 | Provider subject |
| password_hash | TEXT | Yes | — | — | Password hash |
| verified_at | TIMESTAMPTZ | Yes | — | — | Verified at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(provider, provider_subject)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(user_id, provider)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(user_id) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `(provider = 'PASSWORD' AND password_hash IS NOT NULL) OR (provider <> 'PASSWORD' AND password_hash IS NULL)`.
- CHECK 2: `provider IN ('EMAIL_OTP', 'PASSWORD', 'GOOGLE', 'APPLE', 'PHONE_OTP')`.
- `ix_user_auth_methods_1`: `user_id`.

## user_sessions

Revocable opaque login sessions. Store only a keyed digest of the bearer token.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| user_id | UUID | No | — | FK1 | User id |
| token_hash | TEXT | No | — | UQ1 | Token hash |
| expires_at | TIMESTAMPTZ | No | — | — | Expires at |
| revoked_at | TIMESTAMPTZ | Yes | — | — | Revoked at |
| ip_address | INET | Yes | — | — | Ip address |
| user_agent | TEXT | Yes | — | — | User agent |
| last_seen_at | TIMESTAMPTZ | No | `now()` | — | Last seen at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(token_hash)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(user_id) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `expires_at > created_at`.
- `ix_user_sessions_1`: `user_id, expires_at` WHERE `revoked_at IS NULL`.
- `ix_user_sessions_2`: `expires_at`.

## otp_challenges

Short-lived, single-use OTP challenges. Keyed hashes prevent offline guessing of small code spaces.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| email | TEXT | No | — | — | Email |
| code_hash | TEXT | No | — | — | Code hash |
| purpose | TEXT | No | `'LOGIN'` | — | Allowed values: LOGIN. |
| expires_at | TIMESTAMPTZ | No | — | — | Expires at |
| attempts | INTEGER | No | `0` | — | Attempts |
| max_attempts | INTEGER | No | `5` | — | Max attempts |
| consumed_at | TIMESTAMPTZ | Yes | — | — | Consumed at |
| request_ip | INET | Yes | — | — | Request ip |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- CHECK 1: `email = lower(btrim(email))`.
- CHECK 2: `attempts >= 0 AND max_attempts BETWEEN 1 AND 10 AND attempts <= max_attempts`.
- CHECK 3: `expires_at > created_at`.
- CHECK 4: `purpose IN ('LOGIN')`.
- `ix_otp_challenges_1`: `email, created_at DESC`.
- `ix_otp_challenges_2`: `request_ip, created_at DESC`.
- `ix_otp_challenges_3`: `expires_at`.

## platform_admins

Explicit global administrator grants; granting organization ownership never grants platform access.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| user_id | UUID | No | — | FK1, UQ1 | User id |
| role | TEXT | No | `'SUPER_ADMIN'` | — | Allowed values: SUPER_ADMIN. |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, SUSPENDED. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(user_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(user_id) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `role IN ('SUPER_ADMIN')`.
- CHECK 2: `status IN ('ACTIVE', 'SUSPENDED')`.

## organizations

Shared business root for both individual teachers and multi-instructor studios.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| name | TEXT | No | — | — | Name |
| slug | TEXT | No | — | UQ1 | Slug |
| description | TEXT | Yes | — | — | Description |
| timezone | TEXT | No | `'Asia/Kolkata'` | — | IANA timezone name; validated against installed zoneinfo at the API boundary. |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, SUSPENDED. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |
| deleted_at | TIMESTAMPTZ | Yes | — | — | Soft deletion instant; history and foreign keys remain intact. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(slug)` (unique B-tree; NULL follows PostgreSQL default semantics).
- CHECK 1: `length(btrim(name)) BETWEEN 1 AND 160`.
- CHECK 2: `slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$' AND length(slug) BETWEEN 3 AND 80`.
- CHECK 3: `slug NOT IN ('admin', 'api', 'app', 'auth', 'login', 'logout', 'signup', 'dashboard', 'pricing', 'sessions', 'about', 'contact', 'settings', 'health', 'docs', 'openapi', 'static', 'assets', 'robots', 'sitemap', 'student', 'students', 'teacher', 'teachers', 'organizations', 'plans', 'support', 'terms', 'privacy', 'favicon', 'www', 'account', 'calendar', 'enrollments', 'payments', 'website', 'integrations')`.
- CHECK 4: `status IN ('ACTIVE', 'SUSPENDED')`.

## organization_members

Staff membership only. A person may hold different roles in different tenants.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| user_id | UUID | No | — | FK2, UQ2 | User id |
| role | TEXT | No | `'INSTRUCTOR'` | — | Allowed values: OWNER, ADMIN, INSTRUCTOR. |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, INVITED, SUSPENDED, REMOVED. |
| joined_at | TIMESTAMPTZ | No | `now()` | — | Joined at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, user_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(user_id) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `role IN ('OWNER', 'ADMIN', 'INSTRUCTOR')`.
- CHECK 2: `status IN ('ACTIVE', 'INVITED', 'SUSPENDED', 'REMOVED')`.
- `ix_organization_members_1`: `organization_id`.
- `ix_organization_members_2`: `user_id, status`.
- `ix_organization_members_3`: `organization_id, role, status`.

## organization_invitations

Expiring invitations grant a specific staff role only after verified-email acceptance.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1 | Owning tenant; always filter tenant reads by this column. |
| email | TEXT | No | — | — | Email |
| role | TEXT | No | `'INSTRUCTOR'` | — | Allowed values: ADMIN, INSTRUCTOR. |
| token_hash | TEXT | No | — | UQ2 | Token hash |
| invited_by | UUID | No | — | FK2 | Invited by |
| accepted_by | UUID | Yes | — | FK3 | Accepted by |
| expires_at | TIMESTAMPTZ | No | — | — | Expires at |
| accepted_at | TIMESTAMPTZ | Yes | — | — | Accepted at |
| revoked_at | TIMESTAMPTZ | Yes | — | — | Revoked at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(token_hash)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, invited_by) → organization_members (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(accepted_by) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `email = lower(btrim(email))`.
- CHECK 2: `expires_at > created_at`.
- CHECK 3: `(accepted_at IS NULL) = (accepted_by IS NULL)`.
- CHECK 4: `role IN ('ADMIN', 'INSTRUCTOR')`.
- `ix_organization_invitations_1`: `organization_id`.
- `ix_organization_invitations_2`: `organization_id, email`.

## organization_students

Private student relationship and notes for a tenant, backed by a global user.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| user_id | UUID | No | — | FK2, UQ2 | User id |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, INACTIVE, BLOCKED. |
| notes | TEXT | Yes | — | — | Private staff notes, never serialized to public/student APIs. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, user_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(user_id) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `status IN ('ACTIVE', 'INACTIVE', 'BLOCKED')`.
- `ix_organization_students_1`: `organization_id`.
- `ix_organization_students_2`: `user_id, status`.

## organization_settings

Typed operational preferences; flexible contact/social content remains validated JSON.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| default_currency | CHAR(3) | No | `'INR'` | — | Default currency |
| contact_email | TEXT | Yes | — | — | Contact email |
| contact_phone | TEXT | Yes | — | — | Contact phone |
| location | TEXT | Yes | — | — | Location |
| social_links | JSONB | No | `'{}'::jsonb` | — | Social links |
| class_reminder_minutes | INTEGER | No | `60` | — | Class reminder minutes |
| meeting_join_window_minutes | INTEGER | No | `15` | — | Meeting join window minutes |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `default_currency ~ '^[A-Z]{3}$'`.
- CHECK 2: `jsonb_typeof(social_links) = 'object'`.
- CHECK 3: `class_reminder_minutes BETWEEN 0 AND 10080`.
- CHECK 4: `meeting_join_window_minutes BETWEEN 0 AND 120`.
- `ix_organization_settings_1`: `organization_id`.

## plans

Database-driven platform subscription catalogue; amounts are integer minor currency units.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| name | TEXT | No | — | — | Name |
| slug | TEXT | No | — | UQ1 | Slug |
| description | TEXT | Yes | — | — | Description |
| price_amount | BIGINT | No | `0` | — | Price amount |
| currency | CHAR(3) | No | `'INR'` | — | Currency |
| billing_interval | TEXT | No | `'MONTH'` | — | Allowed values: TRIAL, MONTH, YEAR. |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, COMING_SOON, ARCHIVED. |
| is_public | BOOLEAN | No | `true` | — | Is public |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(slug)` (unique B-tree; NULL follows PostgreSQL default semantics).
- CHECK 1: `price_amount >= 0`.
- CHECK 2: `currency ~ '^[A-Z]{3}$'`.
- CHECK 3: `slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'`.
- CHECK 4: `billing_interval IN ('TRIAL', 'MONTH', 'YEAR')`.
- CHECK 5: `status IN ('ACTIVE', 'COMING_SOON', 'ARCHIVED')`.

## plan_features

Typed entitlements read by one centralized authorization/usage service.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| plan_id | UUID | No | — | FK1, UQ1 | Plan id |
| feature_key | TEXT | No | — | UQ1 | Feature key |
| value_type | TEXT | No | `'BOOLEAN'` | — | Allowed values: BOOLEAN, INTEGER, TEXT. |
| boolean_value | BOOLEAN | Yes | — | — | Boolean value |
| integer_value | BIGINT | Yes | — | — | Integer value |
| text_value | TEXT | Yes | — | — | Text value |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(plan_id, feature_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(plan_id) → plans (id)`; ON DELETE RESTRICT.
- CHECK 1: `feature_key ~ '^[a-z][a-z0-9_]*$'`.
- CHECK 2: `(value_type = 'BOOLEAN' AND boolean_value IS NOT NULL AND integer_value IS NULL AND text_value IS NULL) OR (value_type = 'INTEGER' AND boolean_value IS NULL AND integer_value IS NOT NULL AND text_value IS NULL) OR (value_type = 'TEXT' AND boolean_value IS NULL AND integer_value IS NULL AND text_value IS NOT NULL)`.
- CHECK 3: `integer_value IS NULL OR integer_value >= -1`.
- CHECK 4: `value_type IN ('BOOLEAN', 'INTEGER', 'TEXT')`.

## organization_subscriptions

Current platform subscription per tenant; historical transitions remain in organization_subscription_history and audit logs. Student purchases never use this table.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| plan_id | UUID | No | — | FK2 | Plan id |
| status | TEXT | No | `'TRIAL'` | — | Allowed values: TRIAL, ACTIVE, PAST_DUE, EXPIRED, CANCELLED, SUSPENDED. |
| starts_at | TIMESTAMPTZ | No | `now()` | — | Starts at |
| ends_at | TIMESTAMPTZ | Yes | — | — | Ends at |
| trial_starts_at | TIMESTAMPTZ | Yes | `now()` | — | Trial starts at |
| trial_ends_at | TIMESTAMPTZ | Yes | `now() + interval '30 days'` | — | Trial ends at |
| cancelled_at | TIMESTAMPTZ | Yes | — | — | Cancelled at |
| payment_provider | TEXT | Yes | — | UQ3 | Payment provider |
| provider_subscription_id | TEXT | Yes | — | UQ3 | Provider subscription id |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(payment_provider, provider_subscription_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(plan_id) → plans (id)`; ON DELETE RESTRICT.
- CHECK 1: `ends_at IS NULL OR ends_at > starts_at`.
- CHECK 2: `(trial_starts_at IS NULL AND trial_ends_at IS NULL) OR (trial_starts_at IS NOT NULL AND trial_ends_at IS NOT NULL AND trial_ends_at > trial_starts_at)`.
- CHECK 3: `status <> 'TRIAL' OR (trial_starts_at IS NOT NULL AND trial_ends_at IS NOT NULL)`.
- CHECK 4: `(provider_subscription_id IS NULL) OR (payment_provider IS NOT NULL)`.
- CHECK 5: `status IN ('TRIAL', 'ACTIVE', 'PAST_DUE', 'EXPIRED', 'CANCELLED', 'SUSPENDED')`.
- `ix_organization_subscriptions_1`: `organization_id`.
- `ix_organization_subscriptions_2`: `status, trial_ends_at`.

## organization_subscription_history

Append-only subscription transition snapshots; preserve past plan periods, amounts and effective access.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1 | Owning tenant; always filter tenant reads by this column. |
| subscription_id | UUID | No | — | FK2 | Subscription id |
| plan_id | UUID | No | — | FK3 | Plan id |
| event_type | TEXT | No | — | — | Event type |
| status | TEXT | No | — | — | Status |
| starts_at | TIMESTAMPTZ | No | — | — | Starts at |
| ends_at | TIMESTAMPTZ | Yes | — | — | Ends at |
| trial_starts_at | TIMESTAMPTZ | Yes | — | — | Trial starts at |
| trial_ends_at | TIMESTAMPTZ | Yes | — | — | Trial ends at |
| price_amount | BIGINT | No | — | — | Price amount |
| currency | CHAR(3) | No | — | — | Currency |
| billing_interval | TEXT | No | — | — | Billing interval |
| feature_snapshot | JSONB | No | — | — | Feature snapshot |
| changed_by | UUID | Yes | — | FK4 | Changed by |
| reason | TEXT | Yes | — | — | Reason |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, subscription_id) → organization_subscriptions (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(plan_id) → plans (id)`; ON DELETE RESTRICT.
- FK4: `(changed_by) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `price_amount >= 0`.
- CHECK 2: `currency ~ '^[A-Z]{3}$'`.
- CHECK 3: `jsonb_typeof(feature_snapshot) = 'object'`.
- CHECK 4: `status IN ('TRIAL','ACTIVE','PAST_DUE','EXPIRED','CANCELLED','SUSPENDED')`.
- CHECK 5: `billing_interval IN ('TRIAL','MONTH','YEAR')`.
- CHECK 6: `ends_at IS NULL OR ends_at > starts_at`.
- `ix_organization_subscription_history_1`: `organization_id`.
- `ix_organization_subscription_history_2`: `organization_id, created_at DESC`.

## media_assets

External-object metadata; PostgreSQL stores neither image binaries nor signed URLs.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1 | Owning tenant; always filter tenant reads by this column. |
| uploaded_by | UUID | No | — | FK2 | Uploaded by |
| storage_provider | TEXT | No | — | UQ2 | Storage provider |
| object_key | TEXT | No | — | UQ2 | Object key |
| file_name | TEXT | No | — | — | File name |
| file_type | TEXT | No | — | — | File type |
| file_size | BIGINT | No | — | — | File size |
| url | TEXT | Yes | — | — | Public CDN URL when explicitly public; private delivery uses short-lived signed URLs. |
| visibility | TEXT | No | `'PRIVATE'` | — | Allowed values: PRIVATE, PUBLIC. |
| metadata | JSONB | No | `'{}'::jsonb` | — | Metadata |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |
| deleted_at | TIMESTAMPTZ | Yes | — | — | Soft deletion instant; history and foreign keys remain intact. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(storage_provider, object_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(uploaded_by) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `file_size > 0`.
- CHECK 2: `jsonb_typeof(metadata) = 'object'`.
- CHECK 3: `visibility IN ('PRIVATE', 'PUBLIC')`.
- `ix_media_assets_1`: `organization_id`.

## class_types

Tenant-specific classification; no industry-specific application rules.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| name | TEXT | No | — | — | Name |
| slug | TEXT | No | — | UQ2 | Slug |
| description | TEXT | Yes | — | — | Description |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, INACTIVE. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |
| deleted_at | TIMESTAMPTZ | Yes | — | — | Soft deletion instant; history and foreign keys remain intact. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, slug)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'`.
- CHECK 2: `status IN ('ACTIVE', 'INACTIVE')`.
- `ix_class_types_1`: `organization_id`.

## sessions

Sellable session or program; actual dated classes are class_occurrences.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| class_type_id | UUID | No | — | FK2 | Class type id |
| name | TEXT | No | — | — | Name |
| slug | TEXT | No | — | UQ2 | Slug |
| short_description | TEXT | Yes | — | — | Short description |
| description | TEXT | Yes | — | — | Description |
| session_type | TEXT | No | `'GROUP'` | — | Allowed values: GROUP, ONE_TO_ONE, WORKSHOP, PROGRAM. |
| visibility | TEXT | No | `'PRIVATE'` | — | Allowed values: PUBLIC, PRIVATE, UNLISTED. |
| status | TEXT | No | `'DRAFT'` | — | Allowed values: DRAFT, ACTIVE, PAUSED, ARCHIVED. |
| capacity | INTEGER | Yes | — | — | Capacity |
| minimum_age | SMALLINT | Yes | — | — | Minimum age |
| maximum_age | SMALLINT | Yes | — | — | Maximum age |
| skill_level | TEXT | Yes | — | — | Skill level |
| language | TEXT | Yes | — | — | Language |
| duration_minutes | INTEGER | No | — | — | Duration minutes |
| cover_image_id | UUID | Yes | — | FK3 | Cover image id |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |
| deleted_at | TIMESTAMPTZ | Yes | — | — | Soft deletion instant; history and foreign keys remain intact. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, slug)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, class_type_id) → class_types (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, cover_image_id) → media_assets (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'`.
- CHECK 2: `capacity IS NULL OR capacity > 0`.
- CHECK 3: `duration_minutes BETWEEN 1 AND 1440`.
- CHECK 4: `minimum_age IS NULL OR minimum_age BETWEEN 0 AND 150`.
- CHECK 5: `maximum_age IS NULL OR maximum_age BETWEEN 0 AND 150`.
- CHECK 6: `minimum_age IS NULL OR maximum_age IS NULL OR maximum_age >= minimum_age`.
- CHECK 7: `session_type IN ('GROUP', 'ONE_TO_ONE', 'WORKSHOP', 'PROGRAM')`.
- CHECK 8: `visibility IN ('PUBLIC', 'PRIVATE', 'UNLISTED')`.
- CHECK 9: `status IN ('DRAFT', 'ACTIVE', 'PAUSED', 'ARCHIVED')`.
- `ix_sessions_1`: `organization_id`.
- `ix_sessions_2`: `organization_id, status, visibility` WHERE `deleted_at IS NULL`.
- `ix_sessions_3`: `organization_id, class_type_id`.

## session_instructors

Staff assignment with primary, secondary or substitute responsibilities.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| session_id | UUID | No | — | FK2, UQ2 | Session id |
| organization_member_id | UUID | No | — | FK3, UQ2 | Organization member id |
| role | TEXT | No | `'PRIMARY'` | — | Allowed values: PRIMARY, SECONDARY, SUBSTITUTE. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, session_id, organization_member_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, organization_member_id) → organization_members (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `role IN ('PRIMARY', 'SECONDARY', 'SUBSTITUTE')`.
- `ix_session_instructors_1`: `organization_id`.
- `ix_session_instructors_2`: `organization_id, organization_member_id`.
- `ix_session_instructors_3`: `organization_id, session_id`.
- `ix_session_instructors_4`: `UNIQUE organization_id, session_id` WHERE `role = 'PRIMARY'`.

## session_pricing

Versionable access/pricing options; purchased values are copied into order items and enrollments.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ2 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| session_id | UUID | No | — | FK2, UQ2 | Session id |
| name | TEXT | No | — | — | Name |
| description | TEXT | Yes | — | — | Description |
| pricing_type | TEXT | No | `'ONE_TIME'` | — | Allowed values: ONE_TIME, MONTHLY, PACKAGE, PER_SESSION, CUSTOM. |
| amount | BIGINT | No | — | — | Amount |
| currency | CHAR(3) | No | `'INR'` | — | Currency |
| access_type | TEXT | No | `'DATE_RANGE'` | — | Allowed values: DATE_RANGE, NUMBER_OF_CLASSES, PROGRAM_DURATION, UNLIMITED. |
| access_duration_days | INTEGER | Yes | — | — | Access duration days |
| included_class_count | INTEGER | Yes | — | — | Included class count |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, INACTIVE. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, session_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `amount >= 0`.
- CHECK 2: `currency ~ '^[A-Z]{3}$'`.
- CHECK 3: `access_duration_days IS NULL OR access_duration_days > 0`.
- CHECK 4: `included_class_count IS NULL OR included_class_count > 0`.
- CHECK 5: `(access_type = 'DATE_RANGE' AND access_duration_days IS NOT NULL AND included_class_count IS NULL) OR (access_type = 'NUMBER_OF_CLASSES' AND included_class_count IS NOT NULL AND access_duration_days IS NULL) OR (access_type IN ('PROGRAM_DURATION','UNLIMITED') AND access_duration_days IS NULL AND included_class_count IS NULL)`.
- CHECK 6: `pricing_type IN ('ONE_TIME', 'MONTHLY', 'PACKAGE', 'PER_SESSION', 'CUSTOM')`.
- CHECK 7: `access_type IN ('DATE_RANGE', 'NUMBER_OF_CLASSES', 'PROGRAM_DURATION', 'UNLIMITED')`.
- CHECK 8: `status IN ('ACTIVE', 'INACTIVE')`.
- `ix_session_pricing_1`: `organization_id`.
- `ix_session_pricing_2`: `organization_id, session_id, status`.

## session_requirements

Structured public prerequisites, equipment, preparation and notes.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1 | Owning tenant; always filter tenant reads by this column. |
| session_id | UUID | No | — | FK2 | Session id |
| requirement_type | TEXT | No | `'PREREQUISITE'` | — | Allowed values: PREREQUISITE, EQUIPMENT, PREPARATION, NOTE. |
| title | TEXT | No | — | — | Title |
| description | TEXT | No | — | — | Description |
| is_required | BOOLEAN | No | `false` | — | Is required |
| display_order | INTEGER | No | `0` | — | Display order |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `display_order >= 0`.
- CHECK 2: `requirement_type IN ('PREREQUISITE', 'EQUIPMENT', 'PREPARATION', 'NOTE')`.
- `ix_session_requirements_1`: `organization_id`.
- `ix_session_requirements_2`: `organization_id, session_id, display_order`.

## session_schedule_rules

Finite or open-ended weekly/local rules expanded only over a bounded rolling horizon. Local wall times intentionally use TIME and DATE.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ2 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| session_id | UUID | No | — | FK2, UQ2 | Session id |
| recurrence_type | TEXT | No | `'WEEKLY'` | — | Allowed values: WEEKLY, ONE_TIME. |
| day_of_week | SMALLINT | Yes | — | — | ISO weekday 1=Monday to 7=Sunday for WEEKLY rules. |
| start_time | TIME | No | — | — | Start time |
| end_time | TIME | No | — | — | End time |
| end_day_offset | SMALLINT | No | `0` | — | Day offset for overnight classes (0 = same day, 1 = overnight). |
| timezone | TEXT | No | — | — | Timezone |
| effective_from | DATE | No | — | — | Effective from |
| effective_until | DATE | Yes | — | — | Effective until |
| is_active | BOOLEAN | No | `true` | — | Is active |
| dst_fold_policy | TEXT | No | `'EARLIER'` | — | Dst fold policy |
| dst_gap_policy | TEXT | No | `'SKIP'` | — | Dst gap policy |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, session_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `(recurrence_type = 'WEEKLY' AND day_of_week IS NOT NULL AND day_of_week BETWEEN 1 AND 7) OR (recurrence_type = 'ONE_TIME' AND day_of_week IS NULL)`.
- CHECK 2: `(end_day_offset = 0 AND end_time > start_time) OR (end_day_offset = 1 AND end_time <= start_time)`.
- CHECK 3: `effective_until IS NULL OR effective_until >= effective_from`.
- CHECK 4: `dst_fold_policy IN ('EARLIER','LATER')`.
- CHECK 5: `dst_gap_policy = 'SKIP'`.
- CHECK 6: `recurrence_type IN ('WEEKLY', 'ONE_TIME')`.
- CHECK 7: `end_day_offset IN (0, 1)`.
- CHECK 6: `recurrence_type IN ('WEEKLY', 'ONE_TIME')`.
- `ix_session_schedule_rules_1`: `organization_id`.
- `ix_session_schedule_rules_2`: `organization_id, session_id, is_active`.

## organization_integrations

Provider-neutral connected accounts; encrypted tokens remain inaccessible to browser/public response models.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| provider | TEXT | No | — | UQ2 | Provider |
| account_identifier | TEXT | No | — | UQ2 | Account identifier |
| encrypted_credentials | BYTEA | Yes | — | — | Encrypted credentials |
| encryption_key_id | TEXT | Yes | — | — | Encryption key id |
| configuration | JSONB | No | `'{}'::jsonb` | — | Configuration |
| status | TEXT | No | `'DISCONNECTED'` | — | Allowed values: CONNECTED, DISCONNECTED, ERROR. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, provider, account_identifier)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(configuration) = 'object'`.
- CHECK 2: `(encrypted_credentials IS NULL) = (encryption_key_id IS NULL)`.
- CHECK 3: `status IN ('CONNECTED', 'DISCONNECTED', 'ERROR')`.
- `ix_organization_integrations_1`: `organization_id`.

## class_occurrences

Dated execution of a session. Original time is immutable; actual time changes during rescheduling.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ2 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, FK4, UQ1, UQ2, UQ3 | Owning tenant; always filter tenant reads by this column. |
| session_id | UUID | No | — | FK2, FK3, UQ2, UQ3 | Session id |
| schedule_rule_id | UUID | Yes | — | FK3, UQ3 | Schedule rule id |
| original_start_at | TIMESTAMPTZ | No | — | UQ3 | Original start at |
| original_end_at | TIMESTAMPTZ | No | — | — | Original end at |
| actual_start_at | TIMESTAMPTZ | No | — | — | Actual start at |
| actual_end_at | TIMESTAMPTZ | No | — | — | Actual end at |
| status | TEXT | No | `'SCHEDULED'` | — | Allowed values: SCHEDULED, IN_PROGRESS, COMPLETED, CANCELLED, POSTPONED, RESCHEDULED. |
| meeting_provider | TEXT | Yes | — | — | Meeting provider |
| meeting_id | TEXT | Yes | — | — | Meeting id |
| meeting_join_url | TEXT | Yes | — | — | Private attendee link; return only via authorization-checked join endpoint. |
| meeting_host_url_ciphertext | BYTEA | Yes | — | — | Meeting host url ciphertext |
| integration_id | UUID | Yes | — | FK4 | Integration id |
| notes | TEXT | Yes | — | — | Notes |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, session_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, session_id, schedule_rule_id, original_start_at)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, session_id, schedule_rule_id) → session_schedule_rules (organization_id, session_id, id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, integration_id) → organization_integrations (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `original_end_at > original_start_at`.
- CHECK 2: `actual_end_at > actual_start_at`.
- CHECK 3: `meeting_join_url IS NULL OR meeting_provider IS NOT NULL`.
- CHECK 4: `status IN ('SCHEDULED', 'IN_PROGRESS', 'COMPLETED', 'CANCELLED', 'POSTPONED', 'RESCHEDULED')`.
- `ix_class_occurrences_1`: `organization_id`.
- `ix_class_occurrences_2`: `organization_id, actual_start_at, id`.
- `ix_class_occurrences_3`: `organization_id, session_id, actual_start_at`.
- `ix_class_occurrences_4`: `status, actual_start_at`.

## class_occurrence_changes

Immutable cancellation/rescheduling history; redacted snapshots never include meeting secrets.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1 | Owning tenant; always filter tenant reads by this column. |
| class_occurrence_id | UUID | No | — | FK2 | Class occurrence id |
| change_type | TEXT | No | `'UPDATED'` | — | Allowed values: CREATED, CANCELLED, RESCHEDULED, POSTPONED, UPDATED. |
| previous_data | JSONB | Yes | — | — | Previous data |
| new_data | JSONB | No | — | — | New data |
| reason | TEXT | Yes | — | — | Reason |
| changed_by | UUID | No | — | FK3 | Changed by |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, class_occurrence_id) → class_occurrences (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(changed_by) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(new_data) = 'object'`.
- CHECK 2: `change_type IN ('CREATED', 'CANCELLED', 'RESCHEDULED', 'POSTPONED', 'UPDATED')`.
- `ix_class_occurrence_changes_1`: `organization_id`.
- `ix_class_occurrence_changes_2`: `organization_id, class_occurrence_id, created_at`.

## organization_payment_accounts

Organization-owned settlement destination, independent of platform subscription billing.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1 | Owning tenant; always filter tenant reads by this column. |
| provider | TEXT | No | — | UQ2 | Provider |
| provider_account_id | TEXT | No | — | UQ2 | Provider account id |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, ACTIVE, RESTRICTED, DISABLED. |
| configuration | JSONB | No | `'{}'::jsonb` | — | Configuration |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(provider, provider_account_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(configuration) = 'object'`.
- CHECK 2: `status IN ('PENDING', 'ACTIVE', 'RESTRICTED', 'DISABLED')`.
- `ix_organization_payment_accounts_1`: `organization_id`.

## orders

Student commerce order with server-computed totals and a tenant-local student relationship.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ3 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, UQ1, UQ2, UQ3 | Owning tenant; always filter tenant reads by this column. |
| organization_student_id | UUID | No | — | FK2, UQ3 | Organization student id |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, PAYMENT_PENDING, PAID, FAILED, CANCELLED, REFUNDED, PARTIALLY_REFUNDED. |
| subtotal_amount | BIGINT | No | — | — | Subtotal amount |
| discount_amount | BIGINT | No | `0` | — | Discount amount |
| tax_amount | BIGINT | No | `0` | — | Tax amount |
| total_amount | BIGINT | No | — | — | Total amount |
| currency | CHAR(3) | No | `'INR'` | — | Currency |
| payment_status | TEXT | No | `'UNPAID'` | — | Allowed values: UNPAID, PENDING, PAID, FAILED, REFUNDED, PARTIALLY_REFUNDED. |
| idempotency_key | TEXT | No | — | UQ2 | Idempotency key |
| expires_at | TIMESTAMPTZ | Yes | — | — | Expires at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, idempotency_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, id, organization_student_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, organization_student_id) → organization_students (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `subtotal_amount >= 0 AND discount_amount >= 0 AND tax_amount >= 0 AND total_amount >= 0`.
- CHECK 2: `discount_amount <= subtotal_amount`.
- CHECK 3: `total_amount = subtotal_amount - discount_amount + tax_amount`.
- CHECK 4: `currency ~ '^[A-Z]{3}$'`.
- CHECK 5: `status IN ('PENDING', 'PAYMENT_PENDING', 'PAID', 'FAILED', 'CANCELLED', 'REFUNDED', 'PARTIALLY_REFUNDED')`.
- CHECK 6: `payment_status IN ('UNPAID', 'PENDING', 'PAID', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED')`.
- `ix_orders_1`: `organization_id`.
- `ix_orders_2`: `organization_id, organization_student_id, created_at DESC`.
- `ix_orders_3`: `organization_id, status, created_at`.

## order_items

Immutable purchased session/pricing snapshot. Initial SESSION target has a real FK; other product types require an explicit migration.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ2 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, FK4, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| order_id | UUID | No | — | FK2, UQ2 | Order id |
| purchasable_type | TEXT | No | `'SESSION'` | — | Allowed values: SESSION. |
| purchasable_id | UUID | No | — | FK3, FK4, UQ2 | Session identifier for the initial supported purchase type. |
| pricing_id | UUID | No | — | FK4, UQ2 | Pricing id |
| name_snapshot | TEXT | No | — | — | Name snapshot |
| quantity | INTEGER | No | `1` | — | Quantity |
| unit_price | BIGINT | No | — | — | Unit price |
| total_price | BIGINT | No | — | — | Total price |
| metadata | JSONB | No | `'{}'::jsonb` | — | Validated snapshot of access terms and tax/discount allocation; no payment credentials. |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, id, order_id, purchasable_id, pricing_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, order_id) → orders (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, purchasable_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, purchasable_id, pricing_id) → session_pricing (organization_id, session_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `quantity = 1`.
- CHECK 2: `unit_price >= 0 AND total_price >= 0`.
- CHECK 3: `total_price = quantity * unit_price`.
- CHECK 4: `jsonb_typeof(metadata) = 'object'`.
- CHECK 5: `purchasable_type IN ('SESSION')`.
- `ix_order_items_1`: `organization_id`.
- `ix_order_items_2`: `organization_id, order_id`.

## payments

Provider-confirmed movement for a student order; provider IDs are globally idempotent per provider.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ3 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, FK4, UQ1, UQ3 | Owning tenant; always filter tenant reads by this column. |
| organization_student_id | UUID | No | — | FK2, FK3 | Organization student id |
| order_id | UUID | No | — | FK3, UQ3 | Order id |
| payment_account_id | UUID | Yes | — | FK4 | Payment account id |
| provider | TEXT | No | — | UQ2 | Provider |
| provider_payment_id | TEXT | Yes | — | UQ2 | Provider payment id |
| provider_order_id | TEXT | No | — | — | Provider order id |
| amount | BIGINT | No | — | — | Amount |
| currency | CHAR(3) | No | `'INR'` | — | Currency |
| status | TEXT | No | `'CREATED'` | — | Allowed values: CREATED, AUTHORIZED, CAPTURED, FAILED, REFUNDED, PARTIALLY_REFUNDED. |
| payment_method | TEXT | Yes | — | — | Payment method |
| provider_response | JSONB | No | `'{}'::jsonb` | — | Redacted provider summary; never retain PAN/CVV or full unfiltered secrets. |
| paid_at | TIMESTAMPTZ | Yes | — | — | Paid at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(provider, provider_payment_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, id, order_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, organization_student_id) → organization_students (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, order_id, organization_student_id) → orders (organization_id, id, organization_student_id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, payment_account_id) → organization_payment_accounts (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `amount >= 0`.
- CHECK 2: `currency ~ '^[A-Z]{3}$'`.
- CHECK 3: `jsonb_typeof(provider_response) = 'object'`.
- CHECK 4: `status IN ('CREATED', 'AUTHORIZED', 'CAPTURED', 'FAILED', 'REFUNDED', 'PARTIALLY_REFUNDED')`.
- `ix_payments_1`: `organization_id`.
- `ix_payments_2`: `organization_id, order_id`.
- `ix_payments_3`: `provider, provider_order_id`.
- `ix_payments_4`: `organization_id, paid_at`.

## payment_attempts

One traceable provider checkout initiation attempt with redacted failure diagnostics.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| order_id | UUID | No | — | FK2, FK3 | Order id |
| payment_id | UUID | Yes | — | FK3 | Payment id |
| provider | TEXT | No | — | UQ3 | Provider |
| provider_order_id | TEXT | Yes | — | UQ3 | Provider order id |
| idempotency_key | TEXT | No | — | UQ2 | Idempotency key |
| status | TEXT | No | `'CREATED'` | — | Allowed values: CREATED, PENDING, SUCCEEDED, FAILED. |
| error_code | TEXT | Yes | — | — | Error code |
| error_message | TEXT | Yes | — | — | Error message |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, idempotency_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(provider, provider_order_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, order_id) → orders (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, payment_id, order_id) → payments (organization_id, id, order_id)`; ON DELETE RESTRICT.
- CHECK 1: `status IN ('CREATED', 'PENDING', 'SUCCEEDED', 'FAILED')`.
- `ix_payment_attempts_1`: `organization_id`.
- `ix_payment_attempts_2`: `organization_id, order_id, created_at`.

## refunds

Idempotent refund request and provider outcome. Aggregate refund amount is checked transactionally under payment lock.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, UQ1, UQ3 | Owning tenant; always filter tenant reads by this column. |
| payment_id | UUID | No | — | FK2 | Payment id |
| order_id | UUID | No | — | FK2, FK3 | Order id |
| provider | TEXT | No | — | UQ2 | Provider |
| provider_refund_id | TEXT | Yes | — | UQ2 | Provider refund id |
| idempotency_key | TEXT | No | — | UQ3 | Idempotency key |
| amount | BIGINT | No | — | — | Amount |
| currency | CHAR(3) | No | — | — | Currency |
| status | TEXT | No | `'REQUESTED'` | — | Allowed values: REQUESTED, PROCESSING, SUCCEEDED, FAILED. |
| reason | TEXT | Yes | — | — | Reason |
| requested_by | UUID | No | — | FK4 | Requested by |
| processed_at | TIMESTAMPTZ | Yes | — | — | Processed at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(provider, provider_refund_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, idempotency_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, payment_id, order_id) → payments (organization_id, id, order_id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, order_id) → orders (organization_id, id)`; ON DELETE RESTRICT.
- FK4: `(requested_by) → users (id)`; ON DELETE RESTRICT.
- CHECK 1: `amount > 0`.
- CHECK 2: `currency ~ '^[A-Z]{3}$'`.
- CHECK 3: `status IN ('REQUESTED', 'PROCESSING', 'SUCCEEDED', 'FAILED')`.
- `ix_refunds_1`: `organization_id`.
- `ix_refunds_2`: `organization_id, payment_id`.

## payment_webhook_events

Verified provider webhook inbox. Organization/order are resolved from trusted provider order references, never caller tenant claims.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| organization_id | UUID | Yes | — | FK1, FK2 | Organization id |
| order_id | UUID | Yes | — | FK2 | Order id |
| provider | TEXT | No | — | UQ1 | Provider |
| event_id | TEXT | No | — | UQ1 | Event id |
| event_type | TEXT | No | — | — | Event type |
| payload | JSONB | No | — | — | Redacted verified event data; apply documented retention period. |
| payload_sha256 | TEXT | No | — | — | Payload sha256 |
| status | TEXT | No | `'RECEIVED'` | — | Allowed values: RECEIVED, PROCESSING, PROCESSED, FAILED, IGNORED. |
| attempts | INTEGER | No | `0` | — | Attempts |
| processed_at | TIMESTAMPTZ | Yes | — | — | Processed at |
| error_message | TEXT | Yes | — | — | Error message |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(provider, event_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, order_id) → orders (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `attempts >= 0`.
- CHECK 2: `jsonb_typeof(payload) = 'object'`.
- CHECK 3: `order_id IS NULL OR organization_id IS NOT NULL`.
- CHECK 4: `status IN ('RECEIVED', 'PROCESSING', 'PROCESSED', 'FAILED', 'IGNORED')`.
- `ix_payment_webhook_events_1`: `status, created_at`.
- `ix_payment_webhook_events_2`: `organization_id, order_id`.

## session_enrollments

Purchased access grant; each order item activates at most once. Renewal creates another grant and preserves prior payment history.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ3 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, FK4, FK5, FK6, UQ1, UQ3 | Owning tenant; always filter tenant reads by this column. |
| organization_student_id | UUID | No | — | FK2, FK5, UQ3 | Organization student id |
| session_id | UUID | No | — | FK3, FK4, FK6, UQ3 | Session id |
| pricing_id | UUID | No | — | FK4, FK6 | Pricing id |
| order_id | UUID | No | — | FK5, FK6 | Order id |
| order_item_id | UUID | No | — | FK6, UQ2 | Order item id |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, ACTIVE, PAUSED, EXPIRED, CANCELLED, COMPLETED. |
| access_type | TEXT | No | `'DATE_RANGE'` | — | Allowed values: DATE_RANGE, NUMBER_OF_CLASSES, PROGRAM_DURATION, UNLIMITED. |
| access_starts_at | TIMESTAMPTZ | No | — | — | Access starts at |
| access_ends_at | TIMESTAMPTZ | Yes | — | — | Access ends at |
| included_class_count | INTEGER | Yes | — | — | Included class count |
| remaining_class_count | INTEGER | Yes | — | — | Remaining class count |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(order_item_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, id, session_id, organization_student_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, organization_student_id) → organization_students (organization_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, session_id) → sessions (organization_id, id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, session_id, pricing_id) → session_pricing (organization_id, session_id, id)`; ON DELETE RESTRICT.
- FK5: `(organization_id, order_id, organization_student_id) → orders (organization_id, id, organization_student_id)`; ON DELETE RESTRICT.
- FK6: `(organization_id, order_item_id, order_id, session_id, pricing_id) → order_items (organization_id, id, order_id, purchasable_id, pricing_id)`; ON DELETE RESTRICT.
- CHECK 1: `access_ends_at IS NULL OR access_ends_at > access_starts_at`.
- CHECK 2: `(access_type = 'NUMBER_OF_CLASSES' AND included_class_count IS NOT NULL AND remaining_class_count IS NOT NULL AND included_class_count > 0 AND remaining_class_count BETWEEN 0 AND included_class_count) OR (access_type <> 'NUMBER_OF_CLASSES' AND included_class_count IS NULL AND remaining_class_count IS NULL)`.
- CHECK 3: `access_type NOT IN ('DATE_RANGE','PROGRAM_DURATION') OR access_ends_at IS NOT NULL`.
- CHECK 4: `status IN ('PENDING', 'ACTIVE', 'PAUSED', 'EXPIRED', 'CANCELLED', 'COMPLETED')`.
- CHECK 5: `access_type IN ('DATE_RANGE', 'NUMBER_OF_CLASSES', 'PROGRAM_DURATION', 'UNLIMITED')`.
- `ix_session_enrollments_1`: `organization_id`.
- `ix_session_enrollments_2`: `organization_id, organization_student_id, status`.
- `ix_session_enrollments_3`: `organization_id, session_id, status`.
- `ix_session_enrollments_4`: `status, access_ends_at`.

## attendance_records

One attendance decision per student and occurrence; links the precise enrollment used for access.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1, UQ3 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, FK4, FK5, UQ1, UQ2, UQ3 | Owning tenant; always filter tenant reads by this column. |
| class_occurrence_id | UUID | No | — | FK2, UQ2 | Class occurrence id |
| session_id | UUID | No | — | FK2, FK4 | Session id |
| organization_student_id | UUID | No | — | FK3, FK4, UQ2 | Organization student id |
| enrollment_id | UUID | No | — | FK4, UQ3 | Enrollment id |
| status | TEXT | No | `'PRESENT'` | — | Allowed values: PRESENT, ABSENT, LATE, EXCUSED. |
| marked_by | UUID | No | — | FK5 | Marked by |
| marked_at | TIMESTAMPTZ | No | `now()` | — | Marked at |
| notes | TEXT | Yes | — | — | Notes |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id, class_occurrence_id, organization_student_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ3: `(organization_id, id, enrollment_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, session_id, class_occurrence_id) → class_occurrences (organization_id, session_id, id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, organization_student_id) → organization_students (organization_id, id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, enrollment_id, session_id, organization_student_id) → session_enrollments (organization_id, id, session_id, organization_student_id)`; ON DELETE RESTRICT.
- FK5: `(organization_id, marked_by) → organization_members (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `status IN ('PRESENT', 'ABSENT', 'LATE', 'EXCUSED')`.
- `ix_attendance_records_1`: `organization_id`.
- `ix_attendance_records_2`: `organization_id, enrollment_id`.
- `ix_attendance_records_3`: `organization_id, organization_student_id, marked_at`.

## attendance_consumptions

Idempotent package usage ledger. Lock enrollment and ledger before toggling consumed state or restoring a class.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK2, FK3, UQ1 | Owning tenant; always filter tenant reads by this column. |
| attendance_record_id | UUID | No | — | FK2, UQ2 | Attendance record id |
| enrollment_id | UUID | No | — | FK2, FK3 | Enrollment id |
| consumed_at | TIMESTAMPTZ | No | `now()` | — | Consumed at |
| reversed_at | TIMESTAMPTZ | Yes | — | — | Reversed at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(attendance_record_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id, attendance_record_id, enrollment_id) → attendance_records (organization_id, id, enrollment_id)`; ON DELETE RESTRICT.
- FK3: `(organization_id, enrollment_id) → session_enrollments (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `reversed_at IS NULL OR reversed_at >= consumed_at`.
- `ix_attendance_consumptions_1`: `organization_id`.
- `ix_attendance_consumptions_2`: `organization_id, enrollment_id`.

## website_templates

Versioned fixed-layout catalogue. Application renders templates; arbitrary HTML is forbidden.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| name | TEXT | No | — | — | Name |
| slug | TEXT | No | — | UQ1 | Slug |
| description | TEXT | Yes | — | — | Description |
| status | TEXT | No | `'ACTIVE'` | — | Allowed values: ACTIVE, ARCHIVED. |
| preview_image_url | TEXT | Yes | — | — | Preview image url |
| template_version | INTEGER | No | `1` | UQ1 | Template version |
| is_available | BOOLEAN | No | `true` | — | Is available |
| configuration_schema | JSONB | No | `'{}'::jsonb` | — | Configuration schema |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(slug, template_version)` (unique B-tree; NULL follows PostgreSQL default semantics).
- CHECK 1: `template_version > 0`.
- CHECK 2: `jsonb_typeof(configuration_schema) = 'object'`.
- CHECK 3: `status IN ('ACTIVE', 'ARCHIVED')`.

## organization_websites

Separate draft and published content snapshots prevent unreviewed edits leaking onto the public site.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, FK4, UQ1, UQ2 | Owning tenant; always filter tenant reads by this column. |
| template_id | UUID | Yes | — | FK2 | Template id |
| website_type | TEXT | No | `'DEFAULT'` | — | Allowed values: DEFAULT, ADVANCED. |
| status | TEXT | No | `'DRAFT'` | — | Allowed values: DRAFT, PUBLISHED, UNPUBLISHED. |
| configuration | JSONB | No | `'{}'::jsonb` | — | Draft content validated against the selected template version. |
| published_configuration | JSONB | Yes | — | — | Published configuration |
| published_template_id | UUID | Yes | — | FK3 | Published template id |
| published_website_type | TEXT | Yes | — | — | Published website type |
| published_at | TIMESTAMPTZ | Yes | — | — | Published at |
| seo_title | TEXT | Yes | — | — | Seo title |
| seo_description | TEXT | Yes | — | — | Seo description |
| og_image_id | UUID | Yes | — | FK4 | Og image id |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(organization_id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(template_id) → website_templates (id)`; ON DELETE RESTRICT.
- FK3: `(published_template_id) → website_templates (id)`; ON DELETE RESTRICT.
- FK4: `(organization_id, og_image_id) → media_assets (organization_id, id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(configuration) = 'object'`.
- CHECK 2: `published_configuration IS NULL OR jsonb_typeof(published_configuration) = 'object'`.
- CHECK 3: `(website_type = 'DEFAULT' AND template_id IS NULL) OR (website_type = 'ADVANCED' AND template_id IS NOT NULL)`.
- CHECK 4: `published_website_type IS NULL OR published_website_type IN ('DEFAULT','ADVANCED')`.
- CHECK 5: `status <> 'PUBLISHED' OR (published_at IS NOT NULL AND published_configuration IS NOT NULL AND published_website_type IS NOT NULL)`.
- CHECK 6: `published_website_type <> 'ADVANCED' OR published_template_id IS NOT NULL`.
- CHECK 7: `website_type IN ('DEFAULT', 'ADVANCED')`.
- CHECK 8: `status IN ('DRAFT', 'PUBLISHED', 'UNPUBLISHED')`.
- `ix_organization_websites_1`: `organization_id`.

## organization_domains

Reserved support for verified custom domains; DNS automation is deferred.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK, UQ1 | Stable record identifier. |
| organization_id | UUID | No | — | FK1, UQ1 | Owning tenant; always filter tenant reads by this column. |
| hostname | TEXT | No | — | UQ2 | Hostname |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, VERIFIED, ACTIVE, FAILED, DISABLED. |
| verification_token_hash | TEXT | No | — | — | Verification token hash |
| verified_at | TIMESTAMPTZ | Yes | — | — | Verified at |
| is_primary | BOOLEAN | No | `false` | — | Is primary |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(organization_id, id)` (unique B-tree; NULL follows PostgreSQL default semantics).
- UQ2: `(hostname)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `hostname = lower(btrim(hostname)) AND position('.' IN hostname) > 1`.
- CHECK 2: `status IN ('PENDING', 'VERIFIED', 'ACTIVE', 'FAILED', 'DISABLED')`.
- `ix_organization_domains_1`: `organization_id`.
- `ix_organization_domains_2`: `UNIQUE organization_id` WHERE `is_primary = true`.

## notifications

Per-user delivery record, channel-independent. Public APIs never read this table.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| user_id | UUID | No | — | FK1, UQ1 | User id |
| organization_id | UUID | Yes | — | FK2 | Organization id |
| event_type | TEXT | No | — | — | Event type |
| channel | TEXT | No | `'IN_APP'` | UQ1 | Allowed values: IN_APP, EMAIL, WHATSAPP, SMS, PUSH. |
| title | TEXT | No | — | — | Title |
| message | TEXT | No | — | — | Message |
| metadata | JSONB | No | `'{}'::jsonb` | — | Metadata |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, SENT, FAILED, READ. |
| idempotency_key | TEXT | No | — | UQ1 | Idempotency key |
| read_at | TIMESTAMPTZ | Yes | — | — | Read at |
| sent_at | TIMESTAMPTZ | Yes | — | — | Sent at |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(user_id, channel, idempotency_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(user_id) → users (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(metadata) = 'object'`.
- CHECK 2: `channel IN ('IN_APP', 'EMAIL', 'WHATSAPP', 'SMS', 'PUSH')`.
- CHECK 3: `status IN ('PENDING', 'SENT', 'FAILED', 'READ')`.
- `ix_notifications_1`: `user_id, created_at DESC`.
- `ix_notifications_2`: `organization_id, status`.

## notification_preferences

User-controlled event/channel preferences, optionally overridden for an organization.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| user_id | UUID | No | — | FK1 | User id |
| organization_id | UUID | Yes | — | FK2 | Organization id |
| event_type | TEXT | No | — | — | Event type |
| channel | TEXT | No | `'EMAIL'` | — | Allowed values: IN_APP, EMAIL, WHATSAPP, SMS, PUSH. |
| enabled | BOOLEAN | No | `true` | — | Enabled |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- FK1: `(user_id) → users (id)`; ON DELETE RESTRICT.
- FK2: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `channel IN ('IN_APP', 'EMAIL', 'WHATSAPP', 'SMS', 'PUSH')`.
- `ix_notification_preferences_1`: `UNIQUE user_id, event_type, channel` WHERE `organization_id IS NULL`.
- `ix_notification_preferences_2`: `UNIQUE user_id, organization_id, event_type, channel` WHERE `organization_id IS NOT NULL`.

## outbox_events

Transactional, at-least-once work queue for reliable notifications, scheduling and integrations. Workers must be idempotent.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| organization_id | UUID | Yes | — | FK1 | Organization id |
| topic | TEXT | No | — | UQ1 | Topic |
| aggregate_type | TEXT | No | — | — | Aggregate type |
| aggregate_id | UUID | Yes | — | — | Aggregate id |
| idempotency_key | TEXT | No | — | UQ1 | Idempotency key |
| payload | JSONB | No | — | — | Payload |
| status | TEXT | No | `'PENDING'` | — | Allowed values: PENDING, PROCESSING, COMPLETED, DEAD. |
| attempts | INTEGER | No | `0` | — | Attempts |
| max_attempts | INTEGER | No | `8` | — | Max attempts |
| available_at | TIMESTAMPTZ | No | `now()` | — | Available at |
| locked_at | TIMESTAMPTZ | Yes | — | — | Locked at |
| locked_by | TEXT | Yes | — | — | Locked by |
| completed_at | TIMESTAMPTZ | Yes | — | — | Completed at |
| last_error | TEXT | Yes | — | — | Last error |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |
| updated_at | TIMESTAMPTZ | No | `now()` | — | Last mutation instant; application updates this field. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- UQ1: `(topic, idempotency_key)` (unique B-tree; NULL follows PostgreSQL default semantics).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- CHECK 1: `jsonb_typeof(payload) = 'object'`.
- CHECK 2: `attempts >= 0 AND max_attempts > 0 AND attempts <= max_attempts`.
- CHECK 3: `status <> 'PROCESSING' OR (locked_at IS NOT NULL AND locked_by IS NOT NULL)`.
- CHECK 4: `status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'DEAD')`.
- `ix_outbox_events_1`: `available_at, created_at` WHERE `status = 'PENDING'`.
- `ix_outbox_events_2`: `locked_at` WHERE `status = 'PROCESSING'`.
- `ix_outbox_events_3`: `organization_id, created_at`.

## audit_logs

Append-only business/admin audit history; snapshots are explicitly redacted and exclude credentials, OTPs and payment secrets.

| Column | Type | Nullable | Default | Key | Purpose |
| --- | --- | --- | --- | --- | --- |
| id | UUID | No | `gen_random_uuid()` | PK | Stable record identifier. |
| organization_id | UUID | Yes | — | FK1 | Organization id |
| user_id | UUID | Yes | — | FK2 | User id |
| entity_type | TEXT | No | — | — | Entity type |
| entity_id | UUID | Yes | — | — | Entity id |
| action | TEXT | No | — | — | Action |
| old_data | JSONB | Yes | — | — | Old data |
| new_data | JSONB | Yes | — | — | New data |
| ip_address | INET | Yes | — | — | Ip address |
| created_at | TIMESTAMPTZ | No | `now()` | — | Creation instant in UTC. |

Constraints and indexes:

- PK: `(id)` (unique B-tree).
- FK1: `(organization_id) → organizations (id)`; ON DELETE RESTRICT.
- FK2: `(user_id) → users (id)`; ON DELETE RESTRICT.
- `ix_audit_logs_1`: `organization_id, created_at DESC`.
- `ix_audit_logs_2`: `user_id, created_at DESC`.
- `ix_audit_logs_3`: `entity_type, entity_id, created_at`.
