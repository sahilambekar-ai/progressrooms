# User flows

Status: teacher identity, organization setup and trial readout are the foundation milestone. All later flows below define acceptance criteria for subsequent implementation; they are not currently complete.

## Teacher signup and trial

1. Teacher chooses to start ProgressRooms, enters email, receives a generic OTP delivery response and verifies the code.
2. Backend creates or retrieves one verified global user. A failed or expired code leaves the user on verification with a safe retry/resend state.
3. An existing member chooses an organization; a new teacher enters name, slug and IANA timezone. The server validates reserved/duplicate slugs.
4. One transaction creates organization, OWNER membership, settings and a 30-day Starter subscription. Failure rolls back all rows; a race on the slug returns a recoverable conflict.
5. Dashboard displays organization, role, trial end and returned feature entitlements. An independent owner can later assign themself as instructor without another account.

Trial starts on organization creation, not OTP request. Re-authentication never resets trial. A retry must not create a duplicate organization. Foundation does not collect a card or imply automatic paid conversion.

## Plan upgrade and expiry

Owner views the plan catalog and current entitlements. Core/Studio selection later creates a distinct SaaS billing checkout. Provider-confirmed payment activates the new subscription and audits the change. A browser cancellation retains the current plan. Progress AI always displays Coming Soon with no purchase action.

On trial expiry, server time immediately denies capabilities requiring an active subscription. Keep access to billing, account data and support so the owner can recover. Retain historical students, payments and website drafts. A downgrade applies documented effective dates and limits; it does not delete excess resources. Full paid subscription checkout is later scope.

## Teacher session creation

Owner/admin creates an organization-specific class type, then a draft session with name, slug, descriptions, type, optional age/skill/language fields, duration and capacity. They assign active same-tenant instructors and add requirements, equipment, pricing and access policy. Save validates the whole relationship graph. Publishing requires sufficient public details, an active price and schedule where relevant. The public catalog updates through cache invalidation. An instructor without administrative rights cannot publish by calling the API directly.

## Teacher scheduling

Owner/admin selects weekdays, wall-clock start/end, timezone and effective dates. A preview shows the first generated occurrences and instructor conflicts. Confirm creates a versioned rule and queues bounded generation. A worker inserts occurrences idempotently. The calendar displays actual timestamps in an explicit timezone.

For a single change, select occurrence → choose cancel/reschedule → enter reason → preview affected students → submit revision. Append history, preserve original times and queue notifications. A stale revision asks the editor to reload. A series change affects future unmodified events from an explicit effective date; completed/history rows remain intact.

## Website setup

Default pages use profile, contact details and live public sessions. An entitled Studio owner/admin selects one of three fixed templates, edits approved fields, uploads validated media and previews privately. Publish validates configuration and references, advances the published revision and invalidates public caches. Missing required content blocks publication with field errors. A template switch preserves the old draft for recovery and maps compatible content explicitly.

## Student discovery and login

Visitor opens `/{organization_slug}`, browses active public sessions and views a server-rendered detail page including schedule, requirements, price and access period. Enroll captures a safe local intent identifying organization/session/pricing. Email OTP verifies the global identity. The student returns to that exact offering; price, availability and access conditions are checked again. A private or removed offering now shows unavailable and never initiates payment.

## Student payment and enrollment

1. Authenticated student confirms a server-calculated price and access policy. Backend creates/reuses an idempotent order and immutable item snapshot.
2. Backend creates a provider order; browser receives only checkout-safe data and opens Razorpay Checkout.
3. Checkout completion changes the UI to Confirming payment. Poll the student's own order while webhook processing is pending. Closing the tab cannot lose a captured payment.
4. Verified captured payment locks the order, checks amount/currency/account/order identity and records payment, activates one access grant and queues confirmation in one transaction.
5. Dashboard shows enrollment and eligible upcoming occurrences. Repeated or out-of-order webhooks cannot duplicate access or regress PAID to FAILED.
6. Failed attempts leave a clear retry path. A paid-but-unfulfilled anomaly enters reconciliation/support with an order reference; do not ask the student to pay again automatically.

## Join and attendance

Student opens an upcoming occurrence. Server checks ownership, active enrollment, applicable access interval/credits, occurrence state and join window before returning a private join URL. Teacher host URLs require separate authorization. A cancelled occurrence has no join action.

Owner/admin or assigned instructor marks attendance. For a package, PRESENT/LATE consumes one credit under a transaction and unique attendance/consumption key. Repeated submission is harmless. Correcting attendance reverses only a prior consumption, appends audit history and recalculates reminders. ABSENT/EXCUSED initially do not consume; any later cancellation/no-show policy must be explicit in purchased terms.

## Renewal and notifications

Date-based access generates deduplicated reminders at 7, 3 and 1 day and expiration; packages at 3, 1 and 0 credits. Student opens Renew → sees current offering/terms → buys a new order. Verified payment creates a new access period or grant with lineage. For duration access, start at `max(now, current_end)` under a row lock. Preserve historical payment and period records. Preferences govern optional communication; necessary transactional notices follow the stated product policy.

## Complete release acceptance path

Teacher OTP → organization/trial → class type → session → pricing → schedule → generated occurrences → public SSR listing/detail → student OTP with restored intent → order → Razorpay test checkout → captured webhook → enrollment → student dashboard → permitted Zoom join → attendance → credit decrement → expiry reminder. This full flow is a release gate for the complete MVP; foundation delivery verifies only its completed first segment.
