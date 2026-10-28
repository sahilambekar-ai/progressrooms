# One-on-one class flow and email investigation — 28 October 2026

## Delivery status

The user authorized pushing all work and creating PRs on 28 October 2026. API commit `5c54237` and Web commit `ec720d2` were pushed to `dev`. All four repositories remain on `dev`. API PR https://github.com/sahilambekar-ai/progressrooms-api/pull/7 and Web PR https://github.com/sahilambekar-ai/progressrooms-web/pull/6 target `uat`; neither was merged. No UAT or production deployment was performed. Pre-existing Zoom authorization work was included in the authorized push; audit/tracker documentation is published with the parent repositories.

## UAT email findings

Authenticated read-only checks of UAT returned operational email enabled and 15 Zoom Mail history records, all `SUPPRESSED`. The recorded reason was the old combined message, “Email disabled or recipient opted out.” The events were reminders and corrections; there were no recorded creation invitations in that history.

Validation Solo Teacher One has an active live Zoom connection, automatic meetings enabled, a connected studio default host, and Zoom Mail send permission. This verifies authorization state; it does not prove that the Zoom mailbox is provisioned or that Zoom accepts mail submission.

The validation seed creates synthetic `validation.uat.*@example.com` accounts with `email_opted_out=True` (`app/validation_seed.py`). These preferences explain the suppressed validation notifications. Connecting a Zoom account does not opt recipients into app notifications. Synthetic validation recipients were kept opted out.

The user supplied `sahilambekar777@gmail.com` for the student and `sahilambekar.dev@gmail.com` for the studio/teacher delivery check, then explicitly requested verified real-account fixtures on both local and UAT. No live messages have been submitted. UAT already has an owner studio associated with the teacher email; the student email was absent from the admin student search. The earlier deployment chat confirms SSH user `deploy`. Both available deployment keys are encrypted, the SSH agent has no identities, and batch authentication was rejected. The user was asked to unlock the existing key locally with `ssh-add --apple-use-keychain ~/.ssh/id_ed25519`. UAT fixture creation remains pending this access; no synthetic account emails or preferences were changed.

## Local email findings

The local API health endpoint responds. The configured local PostgreSQL database has operational email enabled, no current teacher Zoom connections, no queued meeting deliveries, and older Zoom Mail failures including mailbox authorization/setup failures. Those older failures do not establish the current UAT mailbox state.

The local configuration points its public origin and Zoom callback at UAT. A live local OAuth/mail test requires a valid local callback setup and a current local Zoom grant. The local API does not start the email worker automatically. No existing queue was drained and no Zoom connection, recipient preference or environment secret was changed during diagnosis.

## Fixes

- Dedicated scheduled one-on-one editor and API endpoint: teacher, student, local date/time, duration, description and pricing update together. The generic batch editor rejects scheduled appointments. Regular and offer prices survive reopening the form.
- Today’s classes use a compact scrollable table with email status counts and Send invite. The class page no longer displays an unloaded Zoom setup control; other teacher controls fetch saved status.
- Creation, new timetable occurrences, and purchases covering upcoming occurrences queue initial invitations. Recurring generation resolves recipients in one batch query.
- Initial invitations, the 30-minute reminder, corrections, reassignment cancellations and deletion cancellations use the Zoom Mail queue. Manual invitations fail clearly if all recipients have email disabled. Worker logs distinguish recipient opt-out from a platform-wide pause.
- Deletion cancels unfinished occurrences, including classes already in progress, and refreshes the agenda immediately. Deleted unfinished classes are excluded from calendar, teacher/student attendance and student upcoming queries. Completed attendance history is retained.
- Assigned one-on-one access works before the appointment starts and independently of catalog Live status. Direct appointments do not fail a purchased-session allowance check or appear as pass renewals. Paid passes/courses retain their purchased session allowances.
- Private appointments remain absent from public catalogs and public checkout, including legacy appointments accidentally marked public. Reassignment removes the previous student’s upcoming access.
- Students receive studio-host guidance rather than instructions to authorize their own Zoom account when the host needs attention.
- The appointment student picker supports server search and retains an assigned student outside the first directory page. Studio-local appointment times are preserved.

## Verification

- API: `690 passed, 20 skipped` across the full suite. The skips require optional external test environments. Existing Pydantic deprecation warnings remain.
- Web: TypeScript check passes; 15 component tests and 15 Node tests pass.
- Production Web build and TypeScript check pass, with existing lint warnings. All 56 desktop/mobile Chrome browser tests pass, including appointment table, correct prefilled editor, update request, invitation action, and immediate removal after deletion. The test gallery now includes viewport metadata so mobile checks use the actual device width.
- API regression exercises free appointment creation, simulated worker outcomes, private/public access boundaries, joining before enrollment start, marked-attendance access, rescheduling/reassignment, cancellation delivery, deletion from attendance and agendas, opt-out feedback, and student-safe host errors.
- Simulated/provider-mocked tests send no real emails. Live Zoom mailbox acceptance and inbox receipt remain unverified.

## Review/deployment notes

No database migration is required for these changes. Deploy the compatible API, worker and web changes together through the user-controlled promotion flow. UAT diagnosis does not imply that these local fixes are deployed. Live Zoom Mail additionally requires a provisioned/onboarded mailbox and the license/settings documented at https://developers.zoom.us/docs/api/mail/.

## Requested real-account fixtures

Local setup completed using `app.real_account_fixture`: both requested accounts are verified and active, the studio owner can teach, and both have class email enabled. Existing passwords and Zoom settings were preserved. The fixture contains one complimentary course and three private appointments, with seven total occurrences: three past, two today (28 October 2026), and two tomorrow (29 October 2026), in Asia/Kolkata, plus three past attendance marks.

The running local API accepted authenticated requests for both users. The teacher agenda returned two classes, the student upcoming endpoint returned four, and the student attendance endpoint returned seven records for October. These are class schedule records; no real Zoom rooms or email sends were fabricated. The local accounts were reused in their existing studio. The teacher's existing password was preserved; only known/new credentials are available in the ignored mode-0600 `private-validation/solo-fixture-local.json` file.

The fixture CLI is limited to local development and UAT, rejects production, preserves existing passwords/subscriptions/Zoom grants, is repeatable without duplicate records, and makes no provider calls. Its six regression tests cover environment guards, role conflicts, verified users, dated attendance, idempotence and preservation. UAT execution is pending the unlocked deployment key.
