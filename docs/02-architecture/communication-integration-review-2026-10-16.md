# Communication integration verification — 16 October 2026

## Result

Not production ready. The implementation contains scheduling rules, English message renderers, communication models, super-admin controls, budget helpers, and activity records. It does not yet implement real operational WhatsApp/email delivery. Existing SENT records must not be treated as evidence of delivery.

Reviewed the current uncommitted changes against the two-sender Progress Rooms plan. No real messages were sent during verification. Existing changes were preserved; this review adds explanatory WhatsApp UI indicators and this report. No deployment, commit, or push was performed.

## Verification performed

- Communication suites: `tests/test_communication.py`, `tests/test_reminder_engine_acceptance.py`, `tests/test_billing_and_budgets.py`: 14 passed, two existing Pydantic deprecation warnings.
- Frontend TypeScript check passed. Next lint passed with existing hook-dependency and image warnings.
- Tests create all ORM tables directly in an in-memory SQLite database; passing these tests does not verify Alembic deployment, a background worker, provider delivery, or PostgreSQL concurrency.
- Isolated in-memory probes reproduced three uncovered defects: a delayed worker recorded four student messages after a class had ended; those records required no consent record; rescheduling after a sent preparation reminder queued another preparation reminder.
- Browser verification: WhatsApp icon and notification tooltip render in the communication panel. The signed-out browser receives 401 for admin settings, as expected; no test-send action was submitted.

## Required engineering work, in priority order

### P1 — Real delivery and truthful status

Evidence: `progressrooms-api/app/modules/communication/reminder_engine.py` and `billing_engine.py` render text and insert `CommunicationLog(status="SENT")` without calling a transport. WhatsApp test sends in `service.py` generate a local identifier and explicitly store `simulated: true`. Email tests have a Brevo HTTP path, but class and billing emails do not use it.

Implement shared transports: Meta template sends using the correct Admin or Classes phone-number ID, and Brevo operational emails using complete rendered content. Store provider message IDs; distinguish SIMULATED, QUEUED, provider-accepted, DELIVERED, FAILED, and SUPPRESSED. Never report SENT solely because a log row was inserted. Fail clearly when configuration is missing. Add mocked transport-contract tests, then authorized real-device tests.

### P1 — Deployable database and configuration

Evidence: seven communication tables are introduced by the ORM without a corresponding migration after `015_meetings_and_support.py`. `app/core/config.py` declares no WhatsApp settings, although `service.py` reads them using `getattr`. The settings model ignores extra environment values, so merely adding WhatsApp keys to `.env` will not load those undeclared fields. Health currently checks token length and can display placeholder numbers as sender identities.

Add an Alembic migration with constraints/indexes and a controlled reminder backfill for existing future occurrences. Declare both sender IDs/numbers, business account details as needed, credentials, webhook verification/signature configuration, template mappings, and provider API version. Document required variables without values. Default unconfigured delivery safely off. Report CONFIGURED separately from provider-verified health. Enforce a unique platform-settings singleton and unique monthly budget rows.

### P1 — Automatic worker and reliable dispatch

Evidence: `router.py` exposes a manual `run-engine-cycle` endpoint, but no periodic worker invokes it. Dispatch queries do not claim jobs with row locks/leases, have no delivery idempotency keys, and have no retry lifecycle. Some helper functions commit while the caller's business transaction is still in progress; payment notifications are invoked after payment commit without a durable outbox.

Add a deployed periodic worker, transactional outbox, job claiming, per-recipient/channel/event uniqueness, bounded retries, stale-job expiry, dead-letter handling, and reconciliation. Channel disable/enable must not replay stale work. Use service-owned transaction boundaries; save business changes and notification intents atomically, then deliver after commit.

### P1 — Reminder correctness and enrollment eligibility

Evidence: `dispatch_pending_reminders` selects any overdue PENDING job and only skips missing/cancelled occurrences. It does not reject ended/completed classes, deleted/inactive offerings, or outdated schedule versions. Student selection checks ACTIVE status without validity windows, remaining credits, per-occurrence access, or cancellation/reschedule eligibility. Schedule version defaults to 1 and is not compared with occurrence state. Rescheduling can recreate an already-sent two-hour reminder alongside a correction.

Use the existing access rules to calculate eligible recipients at send time. Drop expired reminders, suppress obsolete revisions, and preserve per-recipient reminder history when rescheduling. After a sent preparation reminder, send the consolidated correction and the remaining useful reminder, not another preparation notice. Test delayed workers, concurrent workers, exhausted/expired passes, withdrawn enrollments, edits around dispatch, and channel toggles.

### P1 — Connect every actual class mutation

Evidence: scheduling generation and dedicated occurrence reschedule/cancel routes have hooks. `app/modules/classes/router.py` creates one-on-one occurrences directly without scheduling reminders, bulk-updates teacher assignments without calling `record_class_edit`, and bulk-cancels deleted batches without cancellation notices. Venue/mode changes are not represented in `MATERIAL_FIELDS`. Student cancellation/reschedule routes also do not invoke communication hooks.

Centralize class-change events and connect recurring schedule replacement, one-on-one creation, teacher substitution, venue/mode changes, batch deletion and relevant student booking changes. Include the original teacher where assignment removal matters. Confirm which student booking actions warrant notifications versus only recipient/reminder eligibility changes. Test real API routes rather than invoking reminder helpers alone.

### P1 — Consent, India-only recipients, opt-outs

Evidence: preferences only store opt-out booleans. Missing preferences permit sending; there is no affirmative consent evidence or opt-out webhook. Fallback to `user.phone` is automatic.

Collect and record explicit consent covering the two Progress Rooms senders and operational purposes, with timestamp/source/text version. Normalize and validate Indian recipient numbers. Do not treat an arbitrary account phone as a consented WhatsApp destination. Implement verified inbound webhooks for opt-outs and delivery statuses even though conversational support is out of scope. Add recipient preference controls and unsubscribe handling. Keep authentication email independent from operational switches.

### P1 — Actual billing lifecycle

Evidence: `process_billing_reminders` returns fixed zero counters. Studio invoice/due/overdue/payment helpers are not connected to a billing ledger lifecycle. The verified-studio-contact helper only filters STUDIO membership and does not establish a designated verified billing contact.

Connect invoice generation, due dates, due-day notices, overdue notices, and confirmed payments to persistent invoices/subscriptions. Recheck outstanding balances immediately before delivery. Deduplicate by invoice, event, recipient and channel. Select verified designated billing contacts using current organization roles. Keep platform subscription invoices separate from student studio purchases.

### P2 — Links, content, budgets and operations

- Reminder links use the student portal for teachers too. Student portal code does not consume the generated studio/class/occurrence parameters to focus the intended class. Generate role-appropriate authenticated destinations and verify the redirect after login.
- Resolve actual invoice/receipt destinations: billing templates currently construct routes that must be implemented/verified before messages use them. Set the real HTTPS public origin instead of localhost.
- Budget helpers use fixed estimated rates, floating-point amounts and unlocked counters. Reconcile provider costs, reserve/increment atomically, define bounded critical-message overage, use month-specific accounting, and ensure all operational sends follow the correct policy. Thresholds currently write server logs rather than user-visible alerts.
- Restrict test recipients, validate channel/number/email inputs, rate-limit tests and sends, verify webhook signatures, and sanitize template parameters.
- Provide studio-scoped communication visibility and actionable failure handling without exposing other studios' recipients. Developer mode is a browser preference and must never grant platform admin authorization.

## UI changes in this review

A reusable WhatsApp brand icon and tooltip now appear on studio/teacher class schedules and cards, class creation/editing forms, one-on-one creation, scheduled attendance entries, student next/upcoming classes, checkout/payment notices, student/teacher/studio recipient details, WhatsApp channel controls, sender explanations, test selection, and WhatsApp activity rows.

Tooltips explain recipient, sender, purpose, reminder timing, join-five-minutes-early behavior, and changes/cancellation policy where relevant. They open on hover, keyboard focus and tap, dismiss with Escape, and render outside clipping containers. They explicitly identify planned behavior and pending delivery setup. They are explanatory, not per-recipient delivery-status indicators. Once live delivery exists, replace the temporary pending-copy with API-backed availability/suppression/delivery state.

The communication panel also warns that current SENT entries do not verify delivery. Studio contact copy now identifies it as a recipient number, not the studio's sending account. Switching test channel clears the previous recipient and result.

## Owner-provided setup inputs

1. Two Progress Rooms-owned WhatsApp numbers: Admin and Classes; current WhatsApp registration/use of each.
2. Meta business administrator access, business identity/profile and requested verification materials.
3. Final integration route: direct Meta Cloud API or selected official provider; billing method paid by Progress Rooms.
4. Account and phone-number IDs, production credentials stored in secrets management, and webhook setup.
5. Approved English operational template names, versions and parameter layouts for both senders.
6. Brevo effective production sender verification and credential availability. Code defaults to `sahilambekar.dev@gmail.com`; runtime verification remains necessary.
7. Public HTTPS frontend/API origins and working authenticated class/invoice/receipt pages.
8. Per-studio monthly allowance, overage rules, designated billing contacts and consent collection wording.
9. Authorized pilot recipients with explicit permission for real WhatsApp/email test notifications.

## Go-live gate

Deploy migration and worker in staging; prove two real recipient deliveries through the distinct WhatsApp senders and real class/billing Brevo emails. Confirm provider webhook statuses. Then test ten pre-reminder edits, post-reminder correction consolidation, cancellation, rescheduling, one-on-one creation, paid-invoice suppression, expired access, opt-out, channel disable/re-enable, provider outage, retries, and two workers racing for one job. Launch only when no simulation is presented as delivery and no stale or duplicate notifications are emitted.
