# Regression retest — 15 October 2026

## Result

Partial pass. Improvements are visible in the running app, but Zoom, analytics, readiness claims and purchasing clarity remain incomplete. This is a test report; no application fixes were made during this retest.

## Verification performed

- Reloaded the running app in Chrome; used developer owner, student and teacher logins; restored owner login.
- API full suite: **82 passed**, 2 Pydantic deprecation warnings.
- Targeted audit/Zoom test files: **6 passed** (also included in full suite).
- Frontend TypeScript check: passed.
- Frontend lint: passed with 7 hook dependency warnings and 2 image optimization warnings.
- Fresh teacher/owner test tab: no captured console warnings/errors during inspected journeys.
- Did not run a production build against the active development output directory.

## Confirmed improvements

| Area | Evidence | Scope |
|---|---|---|
| Class edit initialization | Startup Pitch opens with Alistair Vance selected and first session date 2026-10-01. | Form initialization verified; did not save edits to existing classes. |
| Owner class discovery | New teacher/day/status/type controls; searching Startup Pitch reduces 85 classes to one. | Search exercised; not every filter combination tested. |
| Roster pagination | 10 rows selected, showing 1–10 of 507, 51 pages. | Original mismatch resolved in observed initial page. |
| Student pass history | Active Passes and Past & Expired; latter displays three expired records. Search and studio selector present. | History toggle exercised. |
| Attendance lifecycle | Oct 10, Oct 12 and elapsed Oct 15 entries now show Completed, Not Marked. | Corrected labels observed. |
| Attendance identity | Selected-day entries identify Studio, Teacher and Student; studio selector added. | Cross-studio records are distinguishable in details. |
| Support | Owner View Thread & Reply opens persisted message history and reply composer; student support shows the same tickets. | Existing records verified across accounts; new create/reply/resolve flow passes API tests but was not submitted in browser. |
| Recurring time | Aerial Yoga now appears 18:00–19:00 in teacher agenda and recurring rule. | Current example fixed; timezone/midnight regression test passes. |
| Public discovery | Day/level/format filters added; searching Aerial Yoga Conditioning narrows results correctly. | Search exercised. Teacher/time-of-day/delivery-mode/availability controls remain absent. |
| Public detail | Prerequisites and equipment are visible for Aerial Yoga Conditioning. | Other purchase information remains incomplete. |
| Password recovery | Forgot password opens email/reset-code form. | Request/reset/login passes isolated API test; actual email delivery and browser reset not performed. |
| Demo memberships | Aerial Silks pass now lists aerial/conditioning-related classes instead of Figma and financial modelling. | Sample content checked, not entire catalog. |

## Remaining findings, prioritized

### P0 — Zoom frontend still fabricates success on API failure

Reproduction: owner Settings → Zoom says Not Connected → Test Generate Zoom Meeting → banner says Live Zoom Room Provisioned Successfully and provides a random us05web.zoom.us URL. Toast says Zoom preview room generated, which contradicts the banner.

The API now rejects disconnected generation, but `handleGenerateTestZoomMeeting` catches failures and constructs a random URL client-side. It is not gated to developer mode. Remove the fallback, surface the actual API error, and label deliberate simulations consistently without a live meeting link. Real Zoom host/student end-to-end access is **not verified**.

### P1 — Analytics remains dependent on navigation state

Reproduction after reload: open Analytics before roster/support → Active Enrolled Students = 0, Support Queries = 0. Visit roster and support, then Analytics → 507 and 2. Metrics still read component state populated by other screens.

The 507 count is the full roster total, not a verified count of active enrolled students. Active Recurring Batches shows 3 despite the class catalog reporting 85 configured batches; source uses a separate `batches` array. Projected Subscription Value sums list prices without enrollment quantities. These are not reliable business aggregates.

Use dedicated server aggregates and precise definitions. The billing referral text promises collected/outstanding/transaction reporting, while the earlier billing view explicitly excluded payment transactions; verify the actual capability before promising it.

### P1 — Readiness claims remain false

Settings still claims all studio details verified, integrations active, automatic authenticated meetings and verified bank routing while Zoom says Not Connected and account completion says 80%. Derive claims from actual state; do not use a blanket verification banner.

### P1/P2 — Scheduling history still needs reconciliation

Aerial Yoga's current occurrence is corrected, but today's teacher agenda still includes Yin Yoga at 00:30 on Thursday while its recurring rules show Wednesday/Saturday 19:00. This is consistent with an old shifted occurrence. Confirm historical-data handling separately from corrected future generation; do not blindly modify attendance history.

### P2 — Public purchase information remains incomplete

Aerial Yoga detail still displays raw GROUP / INTERMEDIATE values and promises Protected Zoom Video Access Link while meeting readiness is unresolved. It lacks an explicit next actual date, venue/delivery mode, seat availability and renewal/cancellation explanation. Day/level/format filters help, but all catalog/pass content still renders as a very long page; large all-access passes expand extensive class lists.

Demo address cleanup is partial: Bangalore/Karnataka appears alongside Opposite Osho Garden, Koregaon Park; the legal business name and payout beneficiary still differ. Review demo content coherently rather than replacing isolated fields.

## Untested external or consequential steps

No real Zoom connection, host start or attendee join; no payments/refunds; no email/reset-code delivery; no website publishing; no deletion; no class save/reschedule/cancellation against existing live records. Small-screen/accessibility and production-build checks were not part of this retest. Passing isolated tests does not prove those external journeys.

No commits or pushes. All four repositories remained on dev.
