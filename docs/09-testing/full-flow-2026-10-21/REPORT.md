# Full-flow acceptance test — 21 October 2026

**Result: partial pass. The complete requested journey is not ready to pass end to end.**

A fresh studio was registered and verified in the browser. Owner, teacher and student journeys were exercised through the running UI and HTTP API, with persisted records checked directly. No application fixes were made during this test. All four repositories stayed on `dev`; no commits, pushes or deployments.

## Environment and evidence boundaries

- Separate web/API: `http://localhost:3006` / `http://127.0.0.1:8006`. The existing demo on 3005/8005 and its database were left separate.
- PostgreSQL 18, local port 55433, database `progressrooms_full_flow_test`; separate fresh-migration reproduction database `progressrooms_migration_probe_test`.
- Alembic upgraded an empty database to `021_teacher_zoom_oauth`. Seven communication tables were missing. To continue testing, those tables were created from model metadata **only in the disposable flow database**. An untouched fresh migration probe independently reproduced `UndefinedTableError`. This workaround is not a migration fix or a clean-install pass.
- Zoom and payments were explicitly configured as mocks. Browser purchases of ₹500 and ₹450 persisted as `MOCK`, with no real charge. Real Zoom consent, video hosting, payment capture and delivery-provider acceptance were not tested.
- OTP dispatch was replaced by a local test outbox; these captured codes were used to verify real registration/login endpoints. Rendered notification bodies and database logs were captured separately. OTP codes are omitted from the exported outbox.
- Reminder workers were invoked directly with controlled “as of” times; this proves worker behavior, **not automatic background scheduling**. No scheduler was observed in the inspected app/deployment code; an admin engine-cycle endpoint exists.
- Existing backend regression suite: **139 passed**, including three PostgreSQL tests; two existing Pydantic warnings. Most existing tests use SQLite fixtures, so that result alone does not verify fresh migrations.

## Journey results

| Scenario | Outcome | Evidence |
|---|---|---|
| Fresh studio registration, mock verification email/OTP, dashboard | PASS in browser | Studio `Full Flow Test Studio`; owner subsequently logged in with password |
| Owner adds a teacher through “Send Invitation” | Account created; invitation FAIL | UI shows success and an eight-digit code, but no invitation is generated or sent; see finding F02 |
| Teacher logs in after invitation | BLOCKED in normal flow; recovery workaround passes | Random generated password is unknown; API OTP login works; test-only API password recovery enabled a browser teacher login |
| Teacher creates class/pass | UNSUPPORTED under current permissions | Teacher API attempts return 403; owner-only creation is enforced |
| Owner creates classes and passes | PASS via HTTP and browser | `Browser Created Yoga`, one-session ₹100 package; `Browser Created Practice Pass`, ₹90/one credit; screenshots 08–09 |
| Student registers and verifies with captured OTP | PASS in browser and HTTP | `Browser Flow Student`, then fresh password login |
| Student searches teacher by eight-digit code | PASS in browser and HTTP | `29126838` lists the assigned teacher’s class and pass; `37537166` lists browser-created offerings |
| Student buys class and pass | PASS with mock payment | Browser confirmations 05–06; dashboard 07; two paid orders and two MOCK payments verified |
| Repeat payment verification | PASS | Repeated verification does not create duplicate payment rows |
| Studio creates student before student registration | UNSUPPORTED / FAIL against requested journey | “Create Student” opens “Add a registered student”; unregistered email returns 422; no pending profile is created |
| The same rejected student email later registers | PASS as a normal new account | Browser registration succeeds; prior attempt did not reserve a profile |
| Owner admits the now-registered student | PASS via UI and HTTP | Screenshot 10; one user and one studio roster identity retained; active enrollment created without inventing a payment |
| New class appears for owner-admitted student | PASS | Persisted enrollment and student upcoming API verified |
| Teacher connects Zoom through owner’s request link | PASS with mock OAuth | Teacher redeems scoped request, verifies identity and confirms connection |
| Teacher obtains meeting; repeated request reuses link | PASS with mock Zoom | Stable persisted meeting link; explicitly marked simulation |
| Student meeting security and time window | PASS at API level | Anonymous 401; unenrolled 403; early access 403; enrolled student gets local simulated room during join window without host credential |
| Student discovers rescheduled class and joins from dashboard | FAIL | Rescheduled class missing from student upcoming list; next weekly class displayed instead |
| Two-hour and fifteen-minute reminders | PASS for rendering/logging only | Full rendered bodies and per-channel logs retained; teacher and active students included |
| Duplicate reminder cycle | PASS | Second cycle dispatches zero duplicate notices |
| WhatsApp opt-out | PASS for suppression; audit metadata gap | WhatsApp suppressed while email remains logged; opt-out logs omit occurrence/version metadata |
| Class cancellation notice | PASS for rendering/logging only | Synthetic final occurrence cancelled through normal API; seven occurrence-associated logs plus the opt-out suppression record |
| Reminder destination for teacher | FAIL | Teacher is sent `/student?...` and lands on Student Dashboard, not their teaching agenda |
| Payment receipt destination | FAIL | `/student/receipts/<order-id>` returns 404 |

## Findings and reproduction steps

### F01 — P1: fresh migrations omit communication tables

Run `alembic upgrade head` on an empty PostgreSQL database, then call `get_or_create_settings`. It raises `UndefinedTableError: relation "platform_communication_settings" does not exist`.

Missing tables: `class_reminder_schedules`, `communication_channel_audit_logs`, `communication_logs`, `pending_material_changes`, `platform_communication_settings`, `studio_communication_budgets`, `user_communication_preferences`.

Evidence: `migration-baseline.json`, `migration-runtime-result.json`, `check_migration_baseline.py`. Existing model-created test fixtures hide this gap. Add a migration for the full communication schema and run fresh-migration acceptance tests before a release.

### F02 — P1: “Send Invitation” does not produce a teacher invitation

Owner → Manage Teachers → Add New Teacher → fill details → Send Invitation. The UI says the teacher was invited. `POST /teachers` instead immediately creates an active, verified teacher with a random password, returns no invitation link, and calls no invitation dispatcher. The password is neither known to the teacher nor delivered. No invitation exists in the captured outbox or communication logs.

A password-login attempt fails. API OTP login and password recovery work, but the normal sign-in screen offers password sign-in/recovery, not the direct OTP-login flow. A synthetic teacher was recovered through the API solely to continue the browser journey. That workaround does not count as successful invitation onboarding.

Evidence: screenshot 01; `app/modules/teachers/router.py:create_studio_teacher`; `dashboard/page.tsx:handleCreateTeacher`; outbox and logs. Implement a scoped, expiring invitation/activation flow with a mockable delivery record and truthful UI status.

### F03 — Product gap: studio-first student profile creation is unavailable

Owner → Manage Students → Create Student opens “Add a registered student.” An unregistered address returns 422: “The student must register and verify their account first.” No name/contact draft or invitation exists to claim later.

The same address can subsequently register normally. Once verified, the owner can admit it, without duplicating its user or studio roster record. That supported alternative was tested, but **the requested pre-create → register → claim profile sequence cannot currently be completed**.

Evidence: screenshots 02 and 10; `/students` POST; `browser-record-results.json`. Decide whether to add a pending student invitation/profile-claim model or rename the current button to “Add registered student.”

### F04 — Product limitation: teachers cannot create classes or passes

The teacher agenda has no Create Class action. Class creation and pass creation endpoints both return 403 for the teacher role. Owner creation works. This is the current explicit role policy, so it was not weakened for testing. If teacher creation is intended, define its studio/assignment scope before changing permissions.

Evidence: API results and screenshot 03. The teacher catalog also exposes “Edit packages” despite owner-only save permissions; review that action’s visibility.

### F05 — P1: rescheduled classes disappear from student upcoming classes

Create/enroll a class, then use the normal occurrence reschedule endpoint. The teacher agenda shows the rescheduled occurrence. `/student/upcoming-classes` filters strictly to `status == "SCHEDULED"`, excluding `RESCHEDULED` (and in-progress entries). Student UI therefore shows the next weekly date even while the rescheduled class is joinable through `/student/classes/<occurrence-id>/meeting-url`.

Teacher public discovery similarly chooses only `SCHEDULED` for its next-session date. The test rescheduled the first occurrence into the 15-minute join window: meeting API returned a mock room, but the student dashboard skipped it.

Evidence: `notification-followup-results.json`, screenshots 03 and 07; `app/modules/student/router.py:get_my_upcoming_classes`, `app/modules/teachers/router.py` next-occurrence query. Include appropriate live/rescheduled statuses consistently and regression-test the UI route as well as direct meeting access.

### F06 — P1: teacher reminders open the wrong portal; occurrence deep links are not honored

Reminder engine creates the same `/student?studio=<uuid>&class=<uuid>&occ=<uuid>` URL for teachers and students. Follow it while signed in as the teacher: the page labels itself “Student Dashboard Flow Test Teacher,” shows student discovery, and cannot open the teaching session.

The student page does not consume `class`/`occ` to focus the intended class. The rescheduled-class issue makes this particularly disruptive. Use role-specific authenticated destinations and preserve the intended occurrence through sign-in.

Evidence: screenshot 04, complete URLs in `rendered-reminders.json` / `rendered-followup-reminders.json`, `reminder_engine.py` join URL generation.

### F07 — P1: notification “SENT” is not proof of dispatch; automatic scheduling unverified

Reminder and payment-notification paths render templates and insert `CommunicationLog(status="SENT")` without invoking a provider transport. A captured template plus a SENT row therefore proves only application rendering/logging. This test deliberately sent no real email or WhatsApp.

The inspected app/deployment code exposes an admin engine-cycle endpoint; automatic periodic worker execution was not established. Tests explicitly invoked the worker, so automatic notification timing is **not verified**.

Evidence: renderer captures, logs, `reminder_engine.py`, `billing_engine.py`, `communication/router.py:run-engine-cycle`. Introduce explicit simulated/queued/accepted/delivered states, a mock transport outbox, and a durable scheduled worker with idempotency before claiming delivery.

### F08 — P2: payment-confirmation receipt link is a 404

Payment templates link to `/student/receipts/<order-id>`. Actual HTTP request to that destination returns 404; no matching web route exists. The billing-payment receipt destination is also referenced in source but was not separately exercised.

Evidence: `notification-results.json`, `mock-outbox.json`, server response; `billing_engine.py:notify_student_payment_received`. Add the authenticated receipt page or link to an existing purchase detail view.

### F09 — P2: smaller clarity and auditability defects

- “Create a student account” on the login screen links to `/register` without `role=STUDENT`, opening Studio Registration by default. The tester had to select Student explicitly.
- Class catalog labels a session package as “/ month,” including a browser-created single-session option, despite checkout correctly saying one-time purchase.
- Teacher agenda initially shows “Not connected” for a teacher whose mock connection is already active; the badge initially has no loaded state, while the API had already confirmed its active connection. Load state before showing a disconnected status.
- Opt-out suppression logs omit occurrence ID and schedule version. Suppression works, but the affected class cannot be reliably traced from that row alone.

## Coverage limits and continuation

The evidence covers the listed journeys on a desktop browser, HTTP endpoints and PostgreSQL persistence. It is not a mobile/browser compatibility audit, penetration test, real-money test, live Zoom call or proof of external delivery. GST/bank onboarding, studio billing collection, refunds and website publishing were not exercised. The original 3005 demo remains separate.

Start fixes with F01/F02/F05/F06/F07, then settle the F03/F04 product permissions decisions and repair receipt/navigation details. Retest the same scenarios after fixes; do not treat the current 139 passing backend tests as end-to-end approval.
