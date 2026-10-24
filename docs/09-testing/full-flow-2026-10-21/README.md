# Full studio → teacher → student test pack

Read **[REPORT.md](REPORT.md)** first. It records a partial pass and the blockers; a successful HTTP status or a `SENT` log is not a successful product journey or a delivered message.

## Contents

- `REPORT.md`: scenario matrix, reproduction steps and prioritized findings.
- `evidence/`: ten browser screenshots, from teacher invitation through purchases and owner admission.
- `api-results.json`: HTTP probe results and synthetic studio/teacher/class/pass identifiers. An expected 403/422 is a passing denial check, but the corresponding requested product scenario remains unsupported.
- `migration-baseline.json`, `migration-runtime-result.json`: missing model tables and failure reproduced after fresh migrations on a separate database.
- `browser-record-results.json`: persisted identities, enrollments, mock payments and discovery checks for browser-created data.
- `notification-results.json`, `notification-followup-results.json`: timing, deduplication, opt-out, cancellation, meeting authorization and broken-destination checks.
- `notification-logs*.json`: application log rows. `SENT` means the current app recorded that status; external delivery was not performed.
- `rendered-*.json`, `mock-outbox.json`: complete rendered notification content and local OTP capture metadata; exported OTP values omitted.
- `regression-results.txt`: existing backend suite result and its database/test scope.
- Python files: local test instrumentation and runnable probes. These are test artifacts, not production API code.

## Current local test setup

Web: [test studio](http://localhost:3006/dashboard?tab=students). API: `http://127.0.0.1:8006`. PostgreSQL: local port 55433, `progressrooms_full_flow_test`. The separate fresh-migration probe is `progressrooms_migration_probe_test`.

All contacts and accounts are synthetic. Owner email: `flow.owner.20261021@example.com`; browser student: `flow.browser.precreated@example.com`. Both use the local-test-only password `FlowTestOnly2026!`. API probe identities and teacher codes are in `api-results.json`. Teacher `flow.teacher.072804@example.com` required test-only recovery because no invitation was generated. `Browser Flow Teacher` has code `37537166`; the API-flow teacher has code `29126838`.

Environment secrets and full OTP capture stay outside the repository in `/private/tmp/progressrooms-full-flow.env` (mode 0600) and `/private/tmp/progressrooms-full-flow-outbox.jsonl` (mode 0600). Do not deploy these test settings. Payment and Zoom integrations are mocks; Brevo is disabled. The existing 3005/8005 demo uses different storage.

## Repeating the run

Run API commands from `progressrooms/progressrooms-api` using its `.venv`. The scripts intentionally accept only this local isolated test setup.

1. Initialize/start a disposable PostgreSQL instance on 55433. Create `progressrooms_full_flow_test` and `progressrooms_migration_probe_test`. The current cluster lives at `/private/tmp/progressrooms-full-flow-20261021-pg`.
2. Run `setup_test_environment.py` to generate a **new** local mock environment if none exists. It preserves an existing environment rather than changing its token-encryption key.
3. Load that environment and apply Alembic migrations. Run `check_migration_baseline.py` against the empty probe database. It reproduces the missing communication schema until F01 is fixed.
4. Start `serve_test_api.py`. It captures OTPs locally, instruments notification renderers, disables real email and enforces mock payment/Zoom configuration.
5. From `progressrooms-web`, start the separate web app:

   ```sh
   NEXT_DIST_DIR=.next-audit-full-flow NEXT_PUBLIC_API_URL=http://localhost:8006/api/v1 npm run dev -- --hostname 127.0.0.1 --port 3006
   ```

6. In the browser register `Full Flow Test Studio` with the synthetic owner email above. Read its OTP from the local test outbox and verify it. This is an actual registration flow, not a seeded owner fixture.
7. Run `run_api_flow.py`. It creates unique synthetic teacher/student emails per run. If fresh communication tables are absent and class scheduling fails, it explicitly records a test-only metadata continuation workaround. This must never be presented as migration success. Existing run artifacts record the workaround that was needed during this session.
8. Follow the browser scenarios in `REPORT.md`: send teacher invitation, inspect its missing delivery, recover the synthetic teacher only to continue, log in as teacher, attempt creation, register student, search teacher code, buy class/pass with mock payments, attempt pre-registration admission, then admit after registration. Create `Browser Created Yoga` / `Browser Created Practice Pass` and use the browser test identities if running the record verification unchanged.
9. Run `check_notifications.py`, then `check_notification_followups.py`, then `check_browser_records.py` after the corresponding UI records exist. Followups intentionally reschedule/cancel synthetic occurrences and create an opt-out preference. These stateful probes are designed for a fresh test run; reset/recreate only the disposable databases before repeating the whole sequence. They are not a general idempotent production maintenance command.
10. Run the backend suite with `ZOOM_TEST_POSTGRES_URL` pointing at the isolated PostgreSQL instance. Record failures alongside the browser report; do not overwrite them with a blanket pass.

The JSON results are the assertions to inspect. Scripts preserve findings even when they cannot continue. Browser interactions were performed using the app’s browser controls; the Python HTTP probes do not represent browser automation.

## Expected retest gate

A future complete pass requires: working fresh migrations; actual mock invitation artifact plus teacher activation; an agreed student pre-creation/claim policy; agreed teacher creation permissions; rescheduled classes visible and joinable through their real UI; role-correct reminder destinations; an implemented receipt destination; truthful notification transport/scheduling states. Live provider tests remain a separate gate after real credentials are configured.
