# Scheduling engine

Status: design for the scheduling milestone; the foundation does not yet generate operational calendars.

## Offering, recurrence and event

The session is an offering. A schedule rule expresses a local recurring appointment. A class occurrence is a concrete dated event that can be attended, cancelled or moved. Attendance, meeting metadata and reminders reference occurrences, never the abstract rule.

Initial recurrence supports one-off and weekly rules. A weekly rule specifies ISO weekday 1–7, local start/end time, explicit `end_day_offset` (0 for same-day, 1 for overnight), IANA timezone, effective start date and optional end date. Multiple weekdays may be represented by multiple rules created in one operation. Overnight events must carry an explicit `end_day_offset = 1` and satisfy bounded duration constraints (`end_time <= start_time`, maximum 24 hours); reject ambiguous implicit overnight input. Same-day events (`end_day_offset = 0`) must satisfy `end_time > start_time`. Reject zero/negative duration and invalid timezones. General RRULE support is a later enhancement.

## Generation algorithm

1. A periodic job selects active rules for active sessions and organizations, bounded to `[today, today + 90 days]` and the rule's effective range.
2. Enumerate matching dates in the rule's timezone. Combine date and wall-clock fields and resolve both start and end to timezone-aware instants.
3. Detect daylight-saving gaps by round-tripping local time to UTC and back. Do not silently move a nonexistent time. Mark generation as requiring a teacher decision or apply an explicitly selected skip policy.
4. Ambiguous local times require a documented fold/offset choice. Default design chooses the earlier occurrence only after displaying that policy in schedule preview. Never generate both unintentionally.
5. Insert `original_start_at`, `original_end_at`, `actual_start_at`, `actual_end_at` and SCHEDULED state. Use uniqueness on tenant + rule + original start; duplicate work becomes a no-op.
6. Commit occurrence records and meeting/notification work requests atomically. Advance a generation checkpoint only after successful commit. Use bounded batches so one organization cannot monopolize a worker.

Rerunning the job does not reset a cancelled event or move a rescheduled one. A rule's identity and original occurrence start form stable generation identity. New schedule versions use a new rule or an effective-date revision rather than rewriting historical rule semantics.

## Editing, cancellation and rescheduling

Single occurrence rescheduling requires new offset-qualified start/end timestamps, reason and current revision. Preserve original times, update actual times, append `class_occurrence_changes` with actor and old/new values, and queue meeting updates/reminders in the same transaction. Optimistic revision checks reject concurrent stale edits. A second reschedule updates actual times again while retaining full history.

Cancellation sets CANCELLED and adds history; it does not delete the event. Invalidate join access, suppress pending reminders and queue cancellation notices. Completed events cannot be casually cancelled; corrections require a dedicated audited operation and attendance reconciliation.

For “this and following”, choose an explicit effective date, end the old rule and create its replacement. Cancel future unmodified occurrences from the old rule with a series-change reason. Preserve individually moved/cancelled occurrences and show their treatment in the preview. Completed occurrences remain immutable. Do not silently move a student's historical attendance.

## Calendar and conflict queries

Calendar queries use actual times and overlap logic: `actual_start_at < range_end AND actual_end_at > range_start`. Bound requested ranges (initial target 93 days). Use tenant/start indexes with status and instructor/session filtering where justified. Owners/admins see the tenant calendar; instructors see assigned events; students see events allowed by their own enrollments.

Instructor conflicts use half-open interval overlap, so 10:00–11:00 and 11:00–12:00 do not conflict. Check all assigned instructors, including substitutes, within the tenant and against known assignments in other tenants only if a privacy-safe global availability policy is later introduced. Initially issue a warning and require explicit acknowledgment; do not reveal another organization's class details. Re-evaluate conflicts at write time, because preview is not a lock.

## Access, meetings and reminders

Access is evaluated at the occurrence's actual start, using the enrollment interval and package balance. A reschedule can move outside an access period; expose the affected students in preview and require an explicit access-policy decision instead of silently charging another credit. Join endpoints also enforce occurrence state and a configurable join window.

The meeting adapter creates one meeting per occurrence using a stable operation key. On timeout, reconcile before creating another meeting. Keep host URLs separate from participant URLs. A disconnected Zoom account shows a recoverable integration state and does not cancel class records automatically.

Reminder keys include event type, occurrence or enrollment ID, relevant schedule/access revision, user and channel. A moved class invalidates its old reminder and creates a new one. Delivery workers re-check current event state immediately before sending.

## Required tests

Cover weekly/day bounds, one-off rules, 90-day horizon, leap day, UTC/Kolkata, DST spring gap/fall fold, overnight duration, duplicate concurrent generation, job restart, series revision, cancellation persistence, multiple reschedules, touching/non-touching conflict intervals, inaccessible tenant calendars and reminder dedupe. Freeze the clock. Run integration cases against PostgreSQL constraints; SQLite cannot prove the required timezone/constraint behavior.
