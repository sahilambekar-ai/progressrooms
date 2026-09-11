# API specification

The foundation contract below is fixed for the initial implementation. Later module contracts are design targets and must be finalized with typed OpenAPI schemas and authorization tests before implementation. All routes are relative to `/api/v1` unless explicitly stated.

## Conventions

JSON field names use snake_case; entity IDs are UUID strings; instants are RFC 3339 with offsets; calendar date/time and IANA timezone fields remain separate on recurrence input. Monetary values are integer minor units with an ISO currency. Never accept a client-computed total as authority. JSON unknown-field policy, length limits and validation errors must be explicit in request schemas.

Private calls use `Authorization: Bearer <opaque-session-token>`. The Next.js BFF stores that token in an HttpOnly cookie and forwards it server-side. Responses containing identities, memberships, orders, rosters, entitlements or join links use `Cache-Control: no-store`. Public catalog responses contain only approved public fields.

Errors use:

```json
{
  "error": {"code": "FORBIDDEN", "message": "You do not have permission to perform this action.", "details": null},
  "request_id": "request-correlation-id"
}
```

Standard status meanings: 401 missing/expired/revoked credential; 403 denied role/feature; 404 absent or inaccessible tenant resource; 409 duplicate slug, stale state or idempotency conflict; 422 invalid input; 429 throttled; 503 unavailable dependency. Responses must not disclose internal stack traces. Collection limits must be bounded; future histories use an opaque keyset cursor with deterministic `(created_at,id)` ordering.

## Foundation models

`Membership` = `{organization_id, organization_name, organization_slug, role}` where role is OWNER, ADMIN or INSTRUCTOR. `Me` = `{id,email,full_name,is_platform_admin,memberships:Membership[]}`.

`SubscriptionSummary` = `{plan_slug,plan_name,status,trial_ends_at,ends_at}`; time fields may be null when not applicable. `OrganizationDetail` = `{id,name,slug,timezone,status,role,subscription:SubscriptionSummary,created_at}`. The owner role in a creation response refers to the current user's new membership. Organization summaries carry safe organization identifiers and display fields; exact runtime fields are defined by the generated OpenAPI model.

`Entitlements` = `{organization_id,subscription_status,active,features:{[feature_key]:boolean|integer|string}}`. `Plan` = `{id,name,slug,description,price_amount,currency,billing_interval,status,features:{[feature_key]:boolean|integer|string}}`. Coming-soon status does not grant purchase eligibility.

## Foundation endpoints

| Method / path | Authentication / authorization | Request | Success response | Specific errors |
| --- | --- | --- | --- | --- |
| POST `/auth/otp/request` | Public, rate limited | `{email}` | 202 `{message}`; generic whether account exists or not | 422 invalid email; 429 request budget |
| POST `/auth/otp/verify` | Public, attempt limited | `{email,code}` | 200 `{access_token,token_type:"bearer",expires_in}` | 401 invalid/expired/consumed code; 429 attempts exhausted; 422 shape |
| GET `/auth/me` | Active session | None | 200 `Me` | 401 |
| POST `/auth/logout` | Active session | None | 204; revoke session | 401 |
| GET `/plans` | Public | None | 200 `{items:Plan[]}` | 503 unavailable DB |
| GET `/organizations` | Active session | None | 200 `{items:[OrganizationSummary]}` from caller's memberships | 401 |
| POST `/organizations` | Active global user | `{name,slug,timezone}` | 201 `OrganizationDetail`; atomic owner + trial | 409 slug conflict; 422 reserved slug/invalid timezone |
| GET `/organizations/{id}` | Active staff member in path tenant | None | 200 `OrganizationDetail` | 404 foreign/absent org; 403 unavailable membership/state |
| GET `/organizations/{id}/entitlements` | Active staff member in path tenant | None | 200 `Entitlements` | 404 foreign/absent org |
| GET `/admin/organizations` | Explicit platform administrator | Query `q?`, `page=1`, `page_size=20` | 200 `{items:[OrganizationSummary],total,page,page_size}` | 403 non-admin; 422 invalid page/bounds |

No foundation route changes a paid subscription or accepts live payment. Foundation logout is a POST mutation and its cookie-backed BFF handler validates Origin. The API's OpenAPI document is the executable source of field types and constraints; regenerate any frontend contract when this table changes.

## Planned teacher and scheduling endpoints

`O` below means `/organizations/{organization_id}`. Authentication is required for every route in this table. Staff access follows the role matrix; path IDs and related JSON IDs are checked against the same organization.

| Method / path | Permission | Request | Response / errors |
| --- | --- | --- | --- |
| PATCH `O` | OWNER/ADMIN; ownership excluded | `{name?,description?,timezone?,contact?}` | Updated organization; 422 validation, 409 revision |
| GET/POST `O/members` | List staff; invite OWNER/ADMIN | POST `{email,role}` | List / 201 invitation; 403 role grant, 409 existing member/quota |
| PATCH `O/members/{member_id}` | OWNER; ADMIN cannot alter owner/admin grants | `{role?,status?,revision}` | Updated member; 409 final owner/revision |
| GET/POST `O/class-types` | Staff list; OWNER/ADMIN write | POST `{name,slug,description?}` | List / 201 ClassType; 409 duplicate slug |
| PATCH `O/class-types/{id}` | OWNER/ADMIN | `{name?,description?,status?,revision}` | ClassType; 404 tenant mismatch, 409 revision |
| GET/POST `O/sessions` | Staff list scoped by assignment; OWNER/ADMIN create | POST `{class_type_id,name,slug,session_type,description?,capacity?,duration_minutes?,visibility}` | List / 201 draft Session; 422 relation/field validation |
| GET/PATCH `O/sessions/{id}` | Staff scoped read; OWNER/ADMIN write | PATCH editable catalog fields and `revision` | Session with requirements/assignments; 409 stale revision |
| POST `O/sessions/{id}/publish` | OWNER/ADMIN, session entitlement | `{revision}` | Published Session; 422 incomplete public offering |
| PUT `O/sessions/{id}/instructors` | OWNER/ADMIN | `{assignments:[{member_id,role}]}` | Assignments; 422 inactive/foreign member |
| POST `O/sessions/{id}/pricing` | OWNER/ADMIN | `{name,pricing_type,amount,currency,access_type,access_duration_days?,included_class_count?}` | 201 Pricing; 422 incompatible access fields |
| PUT `O/sessions/{id}/requirements` | OWNER/ADMIN | `{items:[{requirement_type,title,description,is_required,display_order}]}` | Requirements; 422 invalid type/order |
| POST `O/sessions/{id}/schedule-rules/preview` | OWNER/ADMIN | `{weekdays,start_time,end_time,timezone,effective_from,effective_until?}` | `{occurrences,conflicts,warnings}`; 422 invalid/DST time |
| POST `O/sessions/{id}/schedule-rules` | OWNER/ADMIN | Validated preview input + conflict acknowledgment | 201 Rule + generation job reference; 409 changed conflict state |
| GET `O/calendar` | OWNER/ADMIN all; INSTRUCTOR assigned | `from,to,instructor_id?,session_id?,status?` | `{items:[Occurrence]}`; 422 interval exceeds bound |
| POST `O/occurrences/{id}/reschedule` | OWNER/ADMIN | `{actual_start_at,actual_end_at,reason,revision}` | Occurrence + conflicts; 409 completed/stale |
| POST `O/occurrences/{id}/cancel` | OWNER/ADMIN | `{reason,revision}` | Cancelled Occurrence; 409 completed/stale |
| PUT `O/occurrences/{id}/attendance/{student_id}` | OWNER/ADMIN or assigned instructor | `{status,enrollment_id,notes?,revision?}` | Attendance + current balance; 409 unavailable credit; 404 foreign student/enrollment |
| GET `O/students` | OWNER/ADMIN; assigned minimal roster for instructor | `cursor?,limit?,session_id?` | Redacted student list; no cross-student self-service access |

## Planned public, commerce and student endpoints

| Method / path | Authentication / authorization | Request | Response / errors |
| --- | --- | --- | --- |
| GET `/public/organizations/{slug}` | Public, active entitled organization | None | Approved profile, published website config, public catalog; 404 hidden/unpublished |
| GET `/public/organizations/{slug}/sessions/{session_slug}` | Public active visible session | None | Session, public instructor bio, schedules, current pricing, requirements; no meeting URL; 404 |
| POST `/orders` | Verified user as purchaser | `{organization_id,pricing_id}` + `Idempotency-Key` | 201 Order snapshot; 409 changed/unavailable offering or conflicting key |
| POST `/orders/{id}/checkout` | Own unpaid order | `{provider:"RAZORPAY"}` + `Idempotency-Key` | Checkout-safe provider order/key/amount/currency; 409 paid/expired order, 503 provider |
| GET `/orders/{id}` | Purchaser or authorized tenant finance staff | None | Order/payment/fulfillment state; 404 foreign order |
| POST `/orders/{id}/checkout-result` | Purchaser | Provider payment/order/signature fields | 202 verification queued / pending; never grants access directly; 422 mismatch |
| POST `/webhooks/razorpay` | Raw-body signature verification, no user token | Provider raw JSON, signature, event ID headers | 200 after durable receipt; 400 invalid signature; 503 cannot persist |
| POST `/payments/{id}/refunds` | OWNER / platform finance admin, audited | `{amount,reason}` + `Idempotency-Key` | 202 Refund pending; 409 exceeds refundable balance |
| GET `/me/enrollments` | Verified user | `status?,cursor?,limit?` | Own enrollment/access summaries |
| GET `/me/calendar` | Verified user | `from,to` | Own eligible occurrences without reusable meeting secrets |
| GET `/me/orders` | Verified user | `cursor?,limit?` | Own order history |
| POST `/occurrences/{id}/join` | Current authorized student or assigned staff | None | `{join_url,expires_at?}`; 403 no access/outside join window; 404 foreign/private |
| POST `/enrollments/{id}/renew` | Own enrollment | `{pricing_id}` + `Idempotency-Key` | New order with renewal lineage; 409 offering unavailable |
| GET/PATCH `/me/notification-preferences` | Own user | PATCH allowed event/channel preferences | Preferences; 422 invalid channel |
| GET `/me/notifications` | Own user | `cursor?,limit?` | Own notifications |

## Planned websites, billing and integrations

| Method / path | Permission | Request | Response / errors |
| --- | --- | --- | --- |
| GET `/website-templates` | Public preview metadata / entitled selection | None | Available code template IDs, versions, preview images |
| GET/PATCH `O/website` | OWNER/ADMIN; advanced entitlement for advanced config | PATCH `{template_id,template_version,configuration,revision}` | Draft config; 422 schema invalid, 403 entitlement |
| POST `O/website/preview` | OWNER/ADMIN | Draft revision | Authenticated preview descriptor; no public cache |
| POST `O/website/publish` | OWNER/ADMIN and entitlement | `{revision}` | Published revision/time; 409 stale config |
| POST `O/media/upload-intents` | OWNER/ADMIN, storage quota | `{file_name,mime_type,size}` | Short-lived upload intent; 422 type/size |
| POST `O/media/{id}/complete` | OWNER/ADMIN | Upload proof/metadata | Validated asset or processing state; 422 invalid image |
| GET `O/subscription` | OWNER/ADMIN | None | Current subscription, effective features, usage |
| POST `O/subscription/checkout` | OWNER | `{plan_id,billing_interval}` | Separate SaaS checkout; 403 coming-soon plan |
| POST `O/integrations/zoom/connect` | OWNER/ADMIN | Safe local return path | OAuth authorization URL/state; 403 plan |
| GET `/integrations/zoom/callback` | Valid OAuth state bound to org/member | Provider code/state | Redirect after encrypted credential storage; 400 state mismatch |
| DELETE `O/integrations/{provider}` | OWNER/ADMIN | None | 204 disconnect, revoke when supported |

Platform plan/template mutations and organization suspension require explicit audited `/admin` contracts when that phase starts. No endpoint returns an integration access token or private webhook secret.
