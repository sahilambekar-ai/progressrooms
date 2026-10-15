# Account roles and studio relationships

Implemented September 25, 2026. This document and `runtime-schema.sql` describe the running API; the older `schema.sql` / `schema-inventory.json` are a broader design blueprint and are not the Alembic migration source.

## Identity and constraints

`users.role` is required and contains exactly one of `SUPER_ADMIN`, `STUDIO`, `TEACHER`, or `STUDENT`. One role per person avoids ambiguous authority. `is_superadmin` is retained for compatibility and constrained to agree with `role`. A partial unique index allows at most one super admin, including soft-deleted accounts. Registration cannot select that role. Migration preserves the existing administrator rather than guessing a new identity.

| Table | Relationship / fields | Invariants |
| --- | --- | --- |
| users | role, username, password_hash, full_name, email, phone, address, location | Valid role; unique email and optional username; singleton super admin; only password hashes are stored |
| organization_members | organization_id, user_id, role, is_active | Unique studio/user membership; owner role STUDIO, staff role TEACHER; application requires membership role to match account role |
| organization_students | organization_id, user_id, teacher_member_id, student_notes | Unique studio/student relationship; composite foreign key ensures assigned teacher belongs to the same studio |
| sessions (internal name) | Studio-owned recurring class definition | Owners create; teacher IDs and class type validated against the studio |
| class_occurrences | Class date/time, instructor_id, meeting_url | Explicit occurrence teacher overrides recurring assignment; teacher access checks this assignment |
| session_enrollments (internal name) | Student enrolled in a class | Attendance requires an active enrollment in the selected studio and class |
| teacher_attendance_records | Attendance status for the teacher assigned to an occurrence | Exactly one status per occurrence/teacher; only the studio owner may create or correct it |
| student_session_queries | A student's postpone or extension request | Tied to the student's enrollment and immutable assigned-teacher recipient; students never change attendance through a request |

Teacher deactivation preserves membership and attendance history while denying access immediately, including with an existing token. Existing unassigned students remain unassigned until the owner chooses a teacher; the migration does not guess assignments.

## Permissions

| Capability | Super admin | Studio | Teacher | Student |
| --- | --- | --- | --- | --- |
| Platform administration | Yes | No | No | No |
| Create teacher credentials | No (owner workflow) | Own studio | No | No |
| Create, cancel, reschedule classes | Yes | Own studio | No | No |
| Website and studio settings | Yes | Own studio | No | No |
| Class calendar and join links | Yes | Own studio | Assigned classes | Enrolled class links |
| Student directory and notes | Platform endpoints | Own studio | Assigned students | Own portal |
| Student-to-teacher assignment | No (owner workflow) | Own studio | No | No |
| Edit teacher attendance | Yes | Own studio | No — including own attendance | No |
| Edit student attendance | Yes | Own studio | Assigned class and assigned student | No |
| Create postpone/extension query | No | No | No | Own enrollment, to assigned teacher only |
| Read/respond to a student query | Audited support route | Read own studio | Assigned recipient only | Own queries; withdraw pending only |
| Own profile | Yes | Yes | Yes | Yes |

## Registration and login

- `/register/studio`: creates one STUDIO identity, one studio, and its owner membership. A solo teacher registers a studio too.
- `/register/student`: name, email, password, phone, location; verification activates the account. No arbitrary studio is attached at registration.
- Studio owner creates a teacher with name, username, email, password, phone, address, and location. The teacher can immediately sign in with email and password; the studio distributes credentials separately. No email or password is sent automatically by the teacher-creation endpoint.
- A studio can admit an already verified student to a class and assign its teacher. This creates an enrollment, not a payment. Paid enrollment also creates the studio/student relationship; the owner chooses the teacher separately.
- `/auth/me` and `/auth/context` provide authenticated identity and studio context. Menus are backed by API authorization, not local-storage trust.
- Unknown-email OTP requests no longer create accounts. Public registration rejects teacher and administrator roles. Legacy synthetic development tokens and password bootstrap shortcuts are removed. OTP previews are disabled by default (`AUTH_SHOW_OTP_PREVIEW=false`).

## Attendance and student session queries

Attendance is split by the person being recorded, not by the editor's portal:

- A studio owner can create and correct both teacher and student attendance for the owner's studio.
- A teacher can create and correct attendance only for a student assigned to that teacher in an assigned class. A teacher cannot create or alter a teacher-attendance record, including their own.
- A student has no attendance write endpoint. Instead, from a session they can submit a `POSTPONE` request for a specific future occurrence or an `EXTEND` request for their enrollment through **Student Queries**. The request is delivered only to the teacher currently assigned to that student.
- The assigned teacher may approve or reject the request with an optional response. Approval is a decision record, not an implicit calendar or entitlement change: the existing reschedule or extension workflow performs the actual change and records its audit trail.

The API must validate in one transaction that the requester's organization-student relationship, enrollment, occurrence (when supplied), and assigned teacher all belong to the same studio and session. A request keeps the assigned-teacher recipient that existed at creation so a later reassignment does not expose the old request to the new teacher. Deactivated teachers retain historical records but cannot respond.

## Teacher portal

Menu order: **Classes → Manage Students → Student Attendance → My Profile**. Teachers land on `/teacher`. The class agenda uses the studio timezone, shows all today's assigned classes and highlights the current one; it shows tomorrow only when today is empty. Empty states are explicit. Attendance includes a date selector and persists records and counters.

“Create a join link” persists a random room URL on that existing class occurrence. Repeated requests return the same URL; a database row lock serializes concurrent creation. “Join class” opens the stored URL. The default provider is Jitsi (`CLASS_MEETING_BASE_URL=https://meet.jit.si`); generating a URL does not provision a Zoom meeting. Existing stored meeting URLs are preserved. Actual conferencing/provider-host authentication is outside the automated checks.

User-facing text and public links use **classes**. Legacy `/sessions` URLs redirect or remain hidden API aliases to preserve existing links. Internal database table names remain unchanged to preserve existing foreign keys and integrations.

## Migration and verification

1. `004_account_roles`: backfills all user roles and normalizes membership roles, adds singleton-admin and valid-role checks, username/location/address, membership uniqueness, and the student-teacher composite foreign key. Ambiguous duplicates fail the transaction rather than silently dropping data.
2. `005_auth_schema_parity`: supplies authentication columns and OTP table previously present locally but absent from versioned migrations. Its downgrade preserves pre-existing authentication data.
3. Apply using `alembic upgrade head`. This has been applied to the local PostgreSQL database. Existing schema blueprint files are not executable migration inputs.
4. Run `BREVO_ENABLED=false .venv/bin/pytest -q` in the API and `npm run build` in the web app. Role tests call the actual ASGI routes and cover credential login, restricted registration, denied cross-studio operations, teacher restrictions, attendance idempotence, tomorrow fallback, class creation, and singleton constraints.
5. Add migration `006_attendance_permissions_and_student_session_queries` before deploying this feature. Test that an owner can correct teacher and student attendance; a teacher can correct only an assigned student's record; teachers cannot edit their own attendance; and students can only create/withdraw their own pending postpone or extension queries.
