# FEAT-20 — Super admin management and server health

Implemented locally on dev, 24 October 2026. Not deployed or pushed.

## Behavior

- Manage Studios provides suspend/restore login and confirmed deletion directly in each row. Suspension and deletion reject existing staff tokens and fresh password/OTP login when no other active studio membership exists. Shared staff accounts can continue using other active studios.
- Studio deletion is a soft delete: hides the studio and disables operations/public website through existing tenant guards. Historical financial records remain intact; shared teacher/student identities are not deleted.
- Manage Teachers and Manage Students provide backend search, pagination, contact/profile information and confirmed platform-wide account soft deletion. No attendance data is returned. People without studio associations are included. Teacher deletion disconnects Zoom and applies the existing last-active-teacher protection; add another active teacher before deleting the last one.
- New mutations are super-admin-only and use existing AuditLog records. User deletion protects studio-owner and super-admin roles and revokes authentication.
- Platform Overview no longer includes registered tenant studios or fabricated fallback counts/health claims. Server Health is an additional sidebar entry to the same telemetry dashboard.
- Telemetry includes CPU busy percentage, available-memory-based RAM usage, filesystem disk usage, 1-minute load, request count, server error count and average response time. Calendar day/week/month views use Asia/Kolkata. Charts preserve bucket peaks. Stress is explicitly the higher of sampled CPU and RAM usage, not a standard kernel metric.
- Maximum idle is a consecutive run of sampled CPU <=10%, in minutes. Missing samples interrupt the run. No login/logout tracking is added.

## Implementation

Web: `src/components/AdminStudios.tsx`, `AdminPeople.tsx`, `AdminHealth.tsx`, and `src/app/(dashboard)/dashboard/page.tsx`.
API: `app/modules/admin/router.py`, new `health.py`, `app/main.py`, auth dependencies/service, `.gitignore`, `tests/test_admin_management.py`.
No database migration or additional package dependency.

## Deployment and resource scope

- API lifespan starts one sampling coroutine per API worker; blocking filesystem/SQLite work runs in a thread. Request counters hold three aggregate numbers, without URLs, identities, request bodies or tokens. Samples are flushed once per minute and retained for 32 days in `data/platform-health.sqlite3`. Multiple workers share the file; request totals are summed, host values combined per minute. All workers for an environment must share this path; production and QAT must use separate data volumes.
- Existing deploy/compose.api.yaml already persists `/app/data`; ensure it remains writable by uid 10001. The root development docker-compose setup must likewise persist this directory if history across recreation is desired.
- Optional environment variables: `PLATFORM_METRICS_PATH` (persistent SQLite file), `PLATFORM_HOST_PROC` (Linux proc path), `PLATFORM_DISK_PATH` (filesystem to measure). APP_ENV identifies the environment. These variables are read directly by the collector.
- CPU/RAM/load describe the OS visible to the API. Standard Docker proc CPU/memory values include host activity, including production and QAT; virtualized proc mounts can instead describe a restricted scope. Disk describes the selected mounted filesystem, not automatically all VPS disks. For a specific host filesystem, use an appropriately mounted path. No Docker socket or privileged container is required.
- macOS/non-Linux development reports unavailable CPU/RAM rather than synthesizing data. CPU needs two samples after startup. History begins at deployment; it is not backfilled. Graph resolution is 5 minutes/day, 30 minutes/week, 2 hours/month, retaining peaks in each bucket.
- This is intended to have low overhead: 1 sample/minute/worker, 512 KiB SQLite cache per connection, no additional monitoring server. Actual incremental RSS/CPU and disk size have not been measured on the VPS. A month report temporarily reads up to about 46,080 minute aggregates and returns at most about 372 chart buckets; it does not load production customer data. Worker crashes may lose the unflushed minute of request counters. Samples do not capture sub-minute spikes.
- Resource thresholds (75% watch, 90% high) are guidance, not application/database health tests. Data older than 3 minutes is stale. The panel cannot monitor itself during an API/VPS outage. Configure an independent uptime check for outage alerts. Alert delivery, per-container CPU/RAM, network throughput, database connection metrics and backups are not implemented here.
- CPU idle and MemAvailable follow Linux proc definitions: https://www.kernel.org/doc/html/latest/filesystems/proc.html . I/O wait counts as busy for this panel and CPU guest time is not double-counted.

## Verification

Automated: `npm run typecheck`, `npm run build` (passes with network access for existing Google Fonts), and `.venv/bin/pytest tests/test_admin_management.py tests/test_account_roles.py tests/test_auth.py -q` (14 passed). Existing React hook/image and Pydantic deprecation warnings remain. No live VPS deployment or browser interaction was performed.

Manual review on a local or disposable test environment:

1. Sign in as super admin. Verify Manage Studios, Manage Teachers, Manage Students, Server Health and Platform Overview navigation, including refresh/deep links.
2. Suspend a test studio. With an existing owner token, GET auth/me and studio operations must fail; fresh login must fail. Restore the studio; login should work again. Delete it after confirmation; directory and public operations should exclude it, but database historical records should remain.
3. Search both people directories by email/name, page through results, inspect contact/profile data, and confirm attendance is absent. Include a registered student with no studio.
4. Cancel a deletion and confirm nothing changes. Delete a test student and confirm existing authentication fails. Delete a teacher with another active teacher in the studio; confirm Zoom disconnected and access revoked. Last-active-teacher deletion must return an actionable conflict. Repeat API calls as a student/owner; access must be denied.
5. Run API on Linux for at least two minutes. Verify measured CPU/RAM against OS values and chosen disk against df. Check APP_ENV is correct for each environment and volumes are separate.
6. Switch day/week/month; verify peaks, labels and idle definition. Stop sampling/restart and confirm missing periods are not treated as zero/idle. Recreate API container retaining the data volume and confirm history persists.
7. Validate responsive table/modal/chart layout in browser before promotion. Measure actual VPS resource impact under representative traffic before treating estimates as a capacity guarantee.


## Follow-up — compact analytics dashboard and local API recovery

- Diagnosed the actual running local service: admin health and people endpoints returned 404 because the uvicorn process predated these routes and ran without reload. Restarted it from this API checkout with `--reload`; browser-backed requests for studios, teachers, students and health now return 200. No remote environment changed.
- Redesigned AdminHealth into one desktop KPI strip and one chart row, with CPU/RAM/stress trends beside API traffic, 5xx rate, disk utilization and host load. Definitions are collapsed by default. Narrow screens wrap cards and charts responsively.
- Added server-provided period boundaries and bucket size to `/admin/health` so charts use the same timezone/calendar range as the aggregates. Added request cancellation and a manual refresh/retry control. CPU-derived idle is unavailable when CPU samples are missing.
- Verified the live Chrome page at 1230px width: all eight KPIs occupy one row; charts occupy the second row. Verified day/week/month filters, and the real local database directories loaded (16 teacher accounts, 1003 student accounts, 13 studios). Did not perform destructive changes to these records.
- CPU/RAM charts on this macOS machine explicitly show partial telemetry; host CPU/RAM are implemented for Linux VPS, as documented above.
