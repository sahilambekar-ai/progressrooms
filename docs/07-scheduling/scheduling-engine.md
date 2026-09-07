# ProgressRooms Scheduling Engine

## 1. Core Principles
- **Rules vs Occurrences**: Teachers define recurrence rules (`session_schedule_rules`) specifying days of week, start time, end time, and timezone. The scheduling engine generates concrete instances into `class_occurrences`.
- **Rolling Generation Window**: The engine proactively generates occurrences for a rolling horizon (default: 30 days ahead).
- **Timezone Awareness**: All schedule calculations account for the Organization's configured timezone and store timestamps in UTC (`TIMESTAMPTZ`).

## 2. Occurrence States
- `SCHEDULED`: Normal upcoming occurrence.
- `IN_PROGRESS`: Class currently underway.
- `COMPLETED`: Class finished; attendance recorded.
- `CANCELLED`: Class cancelled by instructor; cancellation reason logged; students notified.
- `RESCHEDULED`: Date/time modified; historical start stored in `class_occurrence_changes`.

## 3. Conflict Detection
Before creating or updating an occurrence or schedule rule:
- Checks instructor assignments across all organizations/sessions for overlapping intervals `[start_at, end_at]`.
- Returns HTTP 409 Conflict if the instructor has another active scheduled class at that time.
