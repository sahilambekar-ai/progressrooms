# Progress Rooms: Zoom steps 1–5 audit and implementation handoff

Date: 2026-10-21. Scope: current local working tree, including existing uncommitted changes. Static source review only; no live Zoom authorization, meeting, or production configuration was tested. All four repositories were on `dev`. No application code was changed by this audit.

## Product requirements

- A studio always has at least one active teaching-capable member; its owner is the initial teacher. Preserve owner permissions rather than changing the owner's role to TEACHER.
- Each teacher may connect one Zoom user identity for this studio. Ten teachers can have ten distinct identities. Their Zoom connection is optional when creating or editing a teacher.
- Zoom Settings holds studio-wide defaults applied to all teachers. Teacher identity and OAuth credentials are separate from these defaults.
- The owner manages defaults, sees connection status for every teacher, initiates connection requests, disconnects/replaces bindings, and selects the default host. Connecting an identity still requires that Zoom account holder's consent.
- Recommend the owner's verified connection as the initial default host. A studio can exist without Zoom; enabling automatic Zoom classes requires an active default host. Additional teachers may use the configured fallback for scheduling when eligible.
- “Use the owner's account” means create meetings owned by the selected default host through its authorization. Do not implement shared Zoom passwords or automatically grant every teacher permission to start its meetings.
- Scope for first release: one connection per teacher per studio; multiple teacher connections per studio. Multiple identities per individual teacher are outside this release.

## Audit of steps 1–5

| Step | Current evidence | Gap and required outcome |
|---|---|---|
| 1. Connection ownership | `app/models/organization.py` stores one `zoom_account_email`/connected flag. `organizations/router.py` selects an integration only by organization/provider. Teacher list filters membership role TEACHER. | Separate teaching eligibility from owner/staff role; include the owner once in the roster; associate each connection with a studio member. Add explicit studio default host. |
| 2. One General App | `zoom_service.py:verify_and_obtain_token` uses `grant_type=account_credentials`; connect requires each studio's Account ID, Client ID and Client Secret. | Implement one platform user-managed OAuth app. App credentials belong in backend secret configuration. Marketplace app/dashboard status is unverified. Remove manual S2S credentials from the normal customer flow. |
| 3. OAuth lifecycle | Connect validates S2S credentials, but records a supplied email. `credentials_enc` receives `json.dumps(cred_payload)`. Search of backend app found no user authorization-code callback, refresh-token, or deauthorization/revoke implementation. Generic profile update accepts Zoom identity/connected fields. | Implement verified provider identity, authorization-code exchange, single-use state, encryption, refresh rotation and reconnect handling. Derive connection state on the server; profile edits cannot forge it. |
| 4. Meetings | Real create/update/delete helpers exist. Occurrence provisioning chooses the studio integration and `zoom_account_email`. Cached meeting URLs are reused. Simulation paths also exist. | Resolve a teacher-specific host, persist the chosen connection on each occurrence, protect host responses, serialize provisioning and reconcile ambiguous timeouts. Review all scheduling callers. Live correctness remains unverified. |
| 5. Removal | Disconnect sets integration inactive and studio flag false. | Revoke provider access as appropriate, handle verified Zoom deauthorization notifications, purge credentials under policy, block new calls, and preserve class history. Define impact on future meetings. |

## Exact source entry points

Paths below are relative to `progressrooms/`.

- API: `progressrooms-api/app/models/organization.py`, `app/models/integration.py`, `app/models/schedule.py`, `app/models/session.py`.
- API: `app/modules/organizations/router.py` — profile update, Zoom connect/settings/host-key/disconnect/generate routes.
- API: `app/modules/organizations/zoom_service.py` — token acquisition and meeting provisioning.
- API: `app/modules/teachers/router.py` — serialization, roster role filters, teacher create/edit/deactivate.
- API: `app/modules/scheduling/router.py`, `app/modules/scheduling/engine.py`, `app/modules/classes/router.py`, `app/modules/student/router.py` — trace every meeting creation, update, cancellation and start/join caller.
- Web: `progressrooms-web/src/components/ZoomSettings.tsx` — current defaults, account display, host-key UI, and misleading password-sharing guidance.
- Web: `progressrooms-web/src/app/(dashboard)/dashboard/page.tsx` — teacher table around line 3995, view popup around 6200, teacher forms and legacy Zoom onboarding/connect flow.
- Web: `progressrooms-web/src/types/index.ts` — teacher and integration response types.
- Existing in-progress files include `alembic/versions/018_zoom_settings.py` and `tests/test_zoom_settings.py`; preserve them and choose migration revision after inspecting actual heads.

## Proposed data model

1. Add teaching capability/profile to the existing organization membership model. Backfill the owner without duplicate users or duplicate memberships. Existing owner and teacher authorization must continue working. Prevent removing/deactivating the last active teaching-capable member; owner transfer needs an explicit workflow.
2. Add `teacher_zoom_connections`: organization ID, member ID, verified Zoom user ID, Zoom account ID, verified email/display name, encrypted access/refresh token, expiry, granted scopes, lifecycle status, authorization timestamps, token version. Enforce tenant/member consistency and at most one active connection per member. For v1 disallow assigning the same Zoom user to several teachers within a studio; use the explicit default-host fallback instead.
3. Add short-lived OAuth attempts with hashed random state, studio/member, initiating actor, intended consenting user, expiry, consumed marker, safe return path, operation (connect/replace), and existing connection version. Never log codes, state, or tokens. Reject stale or replayed callbacks and changes in membership/access.
4. Store `default_zoom_host_member_id`, fallback enabled flag, and settings version alongside studio Zoom defaults. Keep membership eligibility separate from connection state.
5. Persist occurrence host member/connection ID, provider meeting ID, provisioning status, effective settings snapshot/version, timestamps and reconciliation operation key. Do not cascade-delete historical occurrences when a connection is removed.

Use authenticated application-level encryption backed by server-managed keys; a column name ending `_enc` is not encryption. Exclude token fields from all serializers, public profiles, logs, and browser responses.

## Zoom Settings UI

- Keep one studio settings block. Separate sections: **Default meeting settings**, **Default host and fallback**, **Teacher Zoom accounts**.
- Defaults include existing supported waiting-room, host-video, join-before-host, automatic provisioning and Zoom-login preferences. Preserve existing subscription/check-in policies but label them as Progress Rooms access rules, distinct from Zoom account authentication.
- Show all teaching-capable members with verified Zoom email, own connection status, default-host badge, and actions. Do not substitute the studio login email or a hard-coded email when Zoom identity is unknown.
- Owner can save defaults, select an active default host, request/connect an account, replace it through OAuth, and disconnect. Changing an email input must never change the authenticated Zoom identity.
- Initial scope uses studio defaults for everyone, without per-teacher overrides. Apply changed defaults to newly provisioned meetings. Existing scheduled meetings require an explicit “apply to future meetings” operation with impact preview, provider updates, per-meeting failures and retries; never silently imply they were updated.
- Remove advice to share Zoom passwords. Do not expose a studio host key across the teacher roster. If host-key support remains, scope it to the owning connection with restricted access; it is not a substitute for OAuth or host eligibility.
- Keep recording access out of the initial Marketplace scope unless explicitly implemented and tested; preserve existing data but do not promise unsupported recording behavior.

## Manage Teachers UI

Add a **Zoom** column after teacher status. Display two separate facts: personal authorization and effective meeting host.

| Personal state | Column text and click action |
|---|---|
| Not connected, fallback available | `Not connected · Uses studio host` → open Zoom dialog |
| Not connected, no fallback | `Not connected · Setup needed for Zoom classes` → open Zoom dialog |
| Connected | `Connected` plus verified email → manage dialog |
| Reauthorization required | `Reconnect required` → reconnect/request authorization |
| Pending authorization | `Awaiting authorization` → view/copy fresh request link |
| Simulated development connection | `Development simulation` — never count as production ready |

Dialog actions: Connect my Zoom, Copy authorization request link for this teacher, Reconnect, Replace account, Disconnect, and owner-only default-host selection. A connection request link is expiring, single-use, and requires the intended teacher to sign into Progress Rooms before a fresh OAuth attempt is created. Do not let an owner accidentally bind the owner's active Zoom browser session to another teacher. Show and confirm verified account identity before activating a replacement.

Teacher create/edit: OAuth is optional, preferably in a separate Zoom section after the teacher record exists. Show current verified identity read-only, status and effective fallback; offer authorization actions. Profile save must neither require OAuth nor silently disconnect it.

Expand the existing **View Teacher** popup to contain every table field: name, email, phone, title/specialization, full bio, teacher code, active status and joined date. Also show username, address, location and studio context when available, owner/teaching role, Zoom identity/status, default/fallback host and next action. Use the same date formatting as the table and clear empty states. Never display passwords, client secrets, refresh tokens, or host keys. Keep edit/attendance actions. Zoom action clicks must not trigger the row-click handler; ensure keyboard and mobile access.

## Host selection and class behavior

Resolve host server-side: explicit eligible class host, otherwise primary assigned teacher's active personal connection, otherwise studio default host if fallback is enabled. For multi-teacher classes require one primary host. Reject cross-studio/inactive selections. If a teacher's existing connection is revoked, show an action-required state rather than silently rerouting existing meetings.

Persist the host at provisioning. A later default-host change must not relabel old meetings. Changing teacher/host after creation requires an explicit reconciliation workflow; if replacement is needed, warn that links change and retain audit history. Repeated requests must not duplicate meetings, including concurrent requests and a provider success followed by a lost response.

Fallback scheduling does not ensure independent hosting. Show `Hosted by [verified account]`, who must start the meeting, and any setup needed. A teacher with no own Zoom authorization can still teach when the owner starts the meeting and manages in-meeting permissions; do not advertise unattended independent start unless an eligible Zoom-supported mechanism has been verified. Alternative hosts normally require licensed users on the same Zoom account. Check overlap against the resolved Zoom host, even when class teachers differ; default conservatively to one simultaneous meeting unless supported capacity is verified. Joining before the host does not confer host permissions.

Participant responses contain only permitted join information. Host/start URLs require explicit host authorization and should be obtained/refreshed when needed rather than treated as permanent public links. Trace current service return values, which include both host and join URLs, and enforce filtering at every response boundary.

## Proposed API contract (adapt to existing route prefixes)

- `GET /organizations/{org}/zoom/settings`: defaults, version, default-host summary; no secrets.
- `PUT /organizations/{org}/zoom/settings`: owner changes defaults/fallback/default host; validate active connection and version.
- `GET /organizations/{org}/teachers/{member}/zoom`: own state and effective host summary.
- `POST .../teachers/{member}/zoom/authorization-request`: owner creates a scoped request link; do not send email automatically.
- `POST .../teachers/{member}/zoom/connect`: intended teacher starts OAuth; owner may connect their own identity.
- `GET /integrations/zoom/callback`: validate/consume state, exchange code, fetch verified identity, encrypt tokens, activate binding.
- `DELETE .../teachers/{member}/zoom`: owner or that teacher removes studio binding with impact preview and appropriate provider revocation.
- `POST /integrations/zoom/deauthorization`: validate notification authenticity/replay protection and process idempotently.
- Teacher list/detail: add owner/teaching flags, `zoom_connection_status`, verified email, `is_default_zoom_host`, effective host and readiness. Keep these out of public teacher serializers.

Use real cryptographic webhook verification and Zoom endpoint validation per current documentation. Teacher self-service permits only their own binding; studio management permits only its members. Owners cannot supply arbitrary Zoom identities and mark them verified.

## Disconnect, replacement and migration

- Before changing/removing the default or last usable host, show affected future classes and require replacement or explicitly pause new Zoom provisioning. Do not block teacher creation because OAuth is absent.
- Stop queued/new API operations after disconnect, remove tokens according to retention policy, process revocation idempotently, and expose reconnect status. Disconnecting Progress Rooms must not be presented as automatically deleting existing Zoom meetings.
- Revoke with awareness of provider grant scope: if future support shares one grant across studios, removing one local binding must not silently revoke other studios. V1 must document/enforce its binding policy and handle provider-wide deauthorization across all affected records.
- Existing S2S credentials cannot become user OAuth refresh tokens. Preserve historical meetings; mark the legacy connection as requiring owner reauthorization. Map it to the owner only after verified OAuth. Remove old plaintext secrets after cutover under an explicit migration procedure; never copy them into a falsely encrypted field.
- Backfill owner teaching eligibility and default selection idempotently. Preserve teacher codes, assignments, attendance, roles, subscriptions and existing class history. Reassess onboarding completion independently from optional Zoom readiness.
- Keep development simulation behind server-side environment/permission gates; client flags alone cannot enable it in production.

## Implementation order and acceptance gates

1. Add migration/model support, owner roster inclusion, data backfill and last-teacher protection.
2. Implement user OAuth, encrypted token lifecycle, verified identity and role/tenant enforcement.
3. Extend teacher API and UI: Zoom column/dialog, optional connect, complete view popup.
4. Refactor Zoom Settings into shared defaults and per-teacher account management; retire conflicting legacy connection controls.
5. Route every meeting operation through persisted host selection, defaults snapshot, conflict checks and safe response serializers.
6. Implement revocation, deauthorization, replacement and legacy cutover; document class impact and recovery.
7. Verify with automated tests and live Zoom before declaring steps 1–5 complete.

Required verification:

- New studio includes owner as a teacher exactly once, with full owner permissions. Cannot remove last teacher; adding others needs no Zoom connection.
- Ten teachers can have ten independent connections; teacher A's class never uses B's token. Tenant and member substitution are rejected.
- Owner can administer all bindings but cannot forge consent. Expired/replayed/request-link callbacks, wrong signed-in users and unsafe return URLs fail safely.
- Refresh rotation handles concurrent workers without losing the current token; invalid/revoked grants produce reconnect state.
- Studio defaults apply consistently; a provider/account-locked setting is shown as restricted rather than falsely saved as effective.
- Optional personal Zoom with default fallback works for scheduling; host identity, start responsibility and overlaps remain explicit.
- Meeting creation, edit, cancellation, substitution, retry/timeout and simultaneous provisioning behave correctly. Host URLs/secrets never appear in student or public responses.
- Removing a teacher/default connection yields correct impact and readiness; deauthorization replay is harmless; token material is removed according to policy.
- Table, detail popup and edit dialog remain consistent after connect/reconnect/disconnect and profile edits; all existing table fields are visible in detail.
- Run existing relevant backend suites and frontend checks. Live acceptance requires two distinct Zoom users, owner fallback, a real host start/student join, reschedule/cancel, refresh/reconnect and Marketplace removal. Record tested account/license constraints without logging credentials.

## Instructions for the implementing engine

Implement the above in the existing application, preserving all current uncommitted work. Read applicable AGENTS.md files and check every affected repository is on `dev` before editing. Do not push, create promotion PRs or modify `uat`/`main`. Inspect current migration heads before selecting a revision. Use existing authorization/tenant helpers but update role assumptions deliberately for teaching-capable owners. Do not merely add UI badges to the current organization-wide S2S implementation. Complete backend/UI/migration/test changes together and report any live Zoom tests that could not be executed. Marketplace submission itself is a later phase.

## Official references checked

- User OAuth and refresh/deauthorization: https://developers.zoom.us/docs/integrations/oauth/
- OAuth app setup: https://developers.zoom.us/docs/integrations/create/
- Security requirements: https://developers.zoom.us/docs/distribute/security-requirements/
- Removal and submission pitfalls: https://developers.zoom.us/docs/distribute/app-submission/common-rejection-issues/
- Concurrent meetings: https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0068522
- Alternative host requirements: https://support.zoom.com/hc/en/article?id=zm_kb&sysparm_article=KB0082130

Zoom hosting behavior depends on account/license and account policies; verify exact supported behavior with the intended deployment accounts.


## Implementation progress — 2026-10-21

### Teaching membership foundation completed

- Added `OrganizationMember.can_teach`, independent of the permission role. New studio owners receive a teaching profile and unique teacher code on their existing membership while retaining `STUDIO` permissions. Teacher creation still requires no Zoom connection.
- Added migration `020_teaching_capability` after `019_class_packages`. It backfills existing owners and teachers without inserting users/memberships, preserves existing codes, allocates missing codes, and updates the code constraint to use teaching capability. Corrected the pre-existing local `018_zoom_settings` migration's nonexistent parent `017_whatsapp_completely_disabled` to the actual previous revision, `016_consolidate_passwords`.
- Teacher roster, public teacher lookup, class teacher validation, student teacher assignment and teacher attendance selection now use teaching eligibility. Private roster responses include `is_owner` and `can_teach`.
- Teacher removal/deactivation and the administrator status toggle share a studio-row lock and last-active-teacher check. Owner access cannot be removed through teacher controls; owner transfer remains a separate, unimplemented workflow. Dashboard marks the owner and disables its teacher deactivation/removal controls, including edit-form status changes.
- Verification: all 122 backend tests and frontend `npm run check` passed. Added regression coverage in `tests/test_teaching_capability.py`. An isolated PostgreSQL 18 instance verified the full migration chain, populated downgrade/upgrade backfill, stable pre-existing teacher codes, repeat upgrade at head, and concurrent removal of the last two teachers (one succeeds, one receives 409).

### Remaining handoff implemented using mock/live adapters

The remaining backend, migration and frontend work is implemented, with mock provider responses for development and an isolated synthetic demo. See [implementation and verification](zoom-implementation-verification-2026-10-21.md) for the behavior, data cutover and reproducible checks. See [Zoom Marketplace setup](zoom-marketplace-setup-2026-10-21.md) for the only external setup values still required.

Live Zoom acceptance and Marketplace publication are not marked complete: no real authorization, account/license hosting, provider settings restriction or public-app removal notification was tested. Real values are installed as backend configuration, after which each intended teacher authorizes a real identity; mock tokens/identities are never relabeled as verified live data. All work remains on `dev`; no push, promotion or deployment was performed.
