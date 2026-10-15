# Product audit — 15 October 2026

## Scope and confidence

Reviewed the running localhost app in Chrome with its developer mode enabled, using studio owner, seeded student, and seeded teacher accounts. Inspected owner classes, class edit modal, roster, attendance, support, analytics, billing, website builder, public storefront, class detail, purchase review, student enrollments and attendance, and teacher agenda. Corroborated Zoom and scheduling behavior against source. Restored the owner login afterward.

No application code changed. No purchases, external messages, publishing, deletions, or pushes. Opening forms is not proof that saving them works. Live Zoom hosting, payment capture/refunds/webhooks, registration email delivery, tenant isolation, mobile viewport behavior, and website publishing remain unverified. Student join buttons were outside their permitted time window, so a live student join was not executed. Existing browser logs contained hot-reload errors; those are not counted as reproduced current defects.

## Prioritized findings

| Priority | Finding and evidence | User impact / recommended outcome |
|---|---|---|
| P0 | Settings says Zoom is Not Connected, but Test Generate Zoom Meeting reports Live Zoom Room Provisioned Successfully. `organizations/router.py` generates random IDs/passcodes and a mock host token, without calling Zoom. Connect also records connected status without a provider authentication exchange. | False success blocks the core live-class promise. Implement actual provider authentication and meeting creation; show connected only after verification. Clearly label any retained development simulation. |
| P0 | Join URLs have incompatible sources: Zoom test returns a fabricated Zoom URL; scheduling join-link defaults to Jitsi; student meeting endpoint falls back to meet.progressrooms.com; teacher agenda visibly links to meet.progressrooms.com. | Create and persist one provider-backed meeting per occurrence; separate host and attendee access; return a useful unavailable/retry state when provisioning fails. Never invent a successful room URL. |
| P0 | Teacher agenda shows Aerial Yoga Silks at 23:30 while the recurring schedule shows 18:00 Asia/Kolkata. Scheduling engine combines rule times directly with UTC. | Classes occur 5.5 hours late and can move to the next day. Interpret rules in studio timezone, convert to UTC for storage, and display explicitly in the intended timezone. Repair already generated future occurrences carefully. |
| P1 | Startup Pitch class card identifies Alistair Vance; opening Edit Class Batch shows Assigned Teacher = Select teacher. | Editing an unrelated field requires reselecting a teacher or risks incorrect assignment. Preserve assignment and effective dates when opening and saving an existing batch. Save behavior was not exercised. |
| P1 | Student attendance shows Oct 10 and Oct 12 as Scheduled / Upcoming on Oct 15; elapsed classes today also retain that label. | Students cannot tell whether attendance is pending or the class is in the future. Distinguish upcoming, completed/unmarked, cancelled, excused, absent and present. |
| P1 | Settings claims all details verified, authenticated meeting provisioning, bank routing and GST invoice generation while Zoom is disconnected and account completion is 80%. | Trust claims exceed the visible state. Derive each status from real verification and show individual missing steps. Bank settlement and tax invoice functionality were not independently verified. |
| P1 | Analytics shows preview revenue ₹62,000 and 91.4% attendance; verified active students displays 0 before roster load. Billing separately reports ₹2,98,300 in subscription value. | These are different measures but look like competing business facts. Use server aggregates, defined reporting periods and clear billed/collected/outstanding distinctions. Remove fabricated production metrics. |
| P1 | Student roster showed 5 rows out of 507 with Rows = 10 and 102 pages. | Pagination state and displayed page size disagree. Keep request size, server response, select options, and page counts consistent. |
| P1 | Support UI offers Mark Resolved but no reply composer or conversation. | Owners can close a request without helping the student. Add a persisted thread, reply, status history and student-visible responses; verify receipt and delivery. |
| P1 | Student attendance repeats identical class names/times across two studios, without identifying the studio in the selected-day entries. | Multi-studio students cannot identify which attendance record belongs to which booking. Show studio and teacher, with a studio filter. This observation does not prove a data leak. |
| P2 | Student enrollments form a very long list mixing active, expired and paused items; no visible search/status/studio filter in My classes & passes. | Default to active items grouped by studio; put past purchases in history; add search and useful expiry/credit sorting. |
| P2 | Owner class catalog has 85 entries with pagination but no visible class search or teacher/day filter. | Finding a class requires paging. Add search, teacher, weekday, delivery mode and status filters; preserve them when returning from a detail. |
| P2 | Public Explore renders a large catalog and all passes together with only text search and class/pass toggles. | Add weekday/time, level, teacher, online/in-person and availability filters, plus pagination or incremental loading. Measure actual response/render cost before claiming a speed improvement. |
| P2 | Public class detail does not clearly explain venue/delivery mode, next actual date, remaining availability, equipment, cancellation rules, or whether monthly access renews. | Explain exactly what a buyer receives before checkout. Include pass activation, validity, session limits, renewal and cancellation behavior. |
| P2 | Public home mentions Bangalore, owner settings list Pune, story uses Sahil Yoga Studio, header uses Demo Yoga Studio. Some pass descriptions contradict their included classes: Aerial Silks pass includes Figma and financial modelling. | Likely demo/content issues, not proven application logic defects. Use coherent fixtures and a prepublish content checklist so clients can trust the demo. |
| P2 | Operational language varies among students, yogis, practitioners, guides and sanctuary. Class details expose ALL_LEVELS. Sign-in lacks a visible password recovery action. | Use Student, Teacher, Studio, Class and Pass consistently; humanize enums; provide recovery and a clear route back to the correct portal. |

## Zoom completion criteria

1. Verified studio connection, revoked/expired-token recovery, disconnect behavior, and visible test/live distinction.
2. Creating a class occurrence creates a real provider meeting once, persists its identifiers, and survives retries without duplicate rooms.
3. Schedule updates and cancellations update the provider meeting and local occurrence consistently.
4. Authorized teacher receives the correct host access; enrolled student receives attendee access only during the permitted window.
5. Expired/paused/exhausted enrollment, cancelled class, wrong studio and unauthorized teacher are denied by the API.
6. Student button respects server eligibility. The current client computes eligibility from time even though its class type includes `can_join`.
7. Exercise real host start and student join, popup/app handoff, missing room, provider outage and retry; reconcile attendance using an explicit verified mechanism.

## Product improvements in delivery order

1. **Reliable daily operation:** fix meeting provisioning, timezone consistency, edit preservation and attendance lifecycle first. Add a Today view with next classes, host readiness, unmarked attendance, expiring memberships and unpaid balances.
2. **Simpler onboarding:** a short checklist for studio profile → teacher → class → price/pass → verified meeting connection → student invitation → preview/publish. Link each missing item to its action; do not call incomplete setup verified.
3. **Clear buying and learning:** a schedule-first discovery view; clear class/pass comparison; booking confirmation; next-class access; credit ledger; renewal, pause and cancellation explanations.
4. **Client retention:** reminders, renewal prompts, waitlist with seat release, trial booking, easy rescheduling and missed-class recovery. Validate demand with studios before building all of these.
5. **Owner decisions:** reporting by period, teacher and class; collected versus billed revenue; occupancy, attendance trends, renewals and at-risk students. Every metric should link to its underlying records.
6. **Growth after reliability:** referral links, trial-to-membership funnel, client testimonials with consent, branded confirmations and reusable studio templates. Measure conversion and repeat attendance rather than adding feature count.

## Engineering optimization candidates

- Replace the large dashboard component with feature modules and shared request/error/pagination handling; avoid unrelated section data affecting metrics.
- Use explicit response contracts for page size, counts, teacher identity, occurrence timezone and join eligibility.
- Ensure request cancellation actually reaches fetch; student attendance creates an AbortController but its request helper does not accept the signal.
- Student initial load uses one Promise.all for profile, enrollments, classes and studios; one failure prevents all sections updating. Prefer section-level failures and retries.
- Add targeted regression coverage for timezone/date rollover, instructor preservation, pagination consistency, occurrence status and provider provisioning. Do not treat hot-reload console history as a current regression without reproduction.

## Remaining verification

- Full register → email verification → login → reset/recovery journey.
- Sandbox purchase → gateway confirmation/webhook → enrollment → credit consumption → invoice → refund/cancellation.
- Live meeting creation, teacher hosting and student joining during an actual permitted window.
- Create/edit/reschedule/cancel flows with existing enrollments and teacher conflicts.
- Authorization and tenant-boundary tests across owner, teacher, student and platform admin.
- Explicit small-screen, keyboard-only, modal focus and screen-reader checks.
- Production build, request timings and realistic load measurements; no performance numbers are asserted by this review.
