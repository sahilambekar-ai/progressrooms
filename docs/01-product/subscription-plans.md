# Subscription and entitlement system

Status: plan catalog, Starter trial and entitlement evaluation are foundation scope. Paid organization checkout, recurring renewal and upgrade/downgrade scheduling follow later.

| Plan | Initial status | Product intent |
| --- | --- | --- |
| Starter | Active catalog plan; 30-day trial | Evaluate core management and a default public page. No automatic charge at trial end. |
| Core | Active catalog plan | Paid core teaching operations and default public page. |
| Studio | Active catalog plan | Multiple instructors, advanced website templates and broader limits. |
| Progress AI | Coming Soon | Reserved future capabilities; no checkout or enabled AI features. |

Exact commercial prices and quota values are deployment data requiring product confirmation. Any locally seeded prices are development fixtures, not published commercial commitments. The API returns plan data; UI logic never compares display names to authorize a feature.

## Data and feature evaluation

`plans` holds catalog metadata, currency, billing interval, integer price amount and availability. `plan_features` holds typed boolean/integer/string values by unique plan and key. `organization_subscriptions` records plan, status, effective dates and trial dates. Future provider subscription identifiers belong here, separate from student orders.

Initial keys include `max_teachers`, `max_students`, `max_sessions`, `website_access`, `advanced_website`, `custom_domain`, `zoom_integration` and `ai_features`. Unsupported future capabilities remain false even if a future tier is visible. Validate known feature keys and types centrally. Missing capability keys deny access; missing limits must not silently become unlimited. Represent unlimited quotas explicitly when introduced.

The entitlement service evaluates organization active state, current subscription status, current server time, plan feature value and measured usage. Active trial is `status=TRIAL` with `now < trial_ends_at`; paid active access respects the effective period. Returned feature values drive UI visibility, while every write repeats server-side enforcement. Read access to essential billing/history may use an explicit recovery policy even after feature access expires.

## Trial creation and lifecycle

Organization creation atomically inserts owner membership and one Starter trial with a 30-day boundary. A user logging in again does not receive another trial for the existing organization. Trial start/end are auditable server timestamps. Creation retry and concurrent requests must not produce duplicate subscriptions for one organization.

Status transitions: TRIAL → ACTIVE or EXPIRED; ACTIVE → PAST_DUE, CANCELLED or SUSPENDED; PAST_DUE → ACTIVE or EXPIRED. Cancellation and scheduled period end are distinct concepts: a cancellation request may preserve access until the paid end. Initial design does not grant a hidden grace period for PAST_DUE; a future grace policy needs explicit effective dates. Platform suspension denies operational access irrespective of billing status.

## Usage limits and plan changes

Count active instructors, active student relationships, active sessions and valid stored bytes according to one documented policy. Owner teaching counts toward instructor usage when instructional capability is enabled. Archive/suspension effects on usage must be consistent in service and UI. Quota checks that create resources lock or reserve against concurrent writes; a read-count-then-insert race is insufficient.

Upgrades take effect only after verified billing or an audited administrator action. Downgrades should apply at the configured period boundary. Over-limit data is retained: deny new resource creation and show remediation rather than deleting existing business history. Advanced website downgrade preserves the draft and renders the entitled default version. Scheduled plan changes cannot mutate historical invoices or purchases.

## Tests and operating rules

Freeze time at trial start, one instant before end, exactly at end and after end. Test organization suspension, missing features, typed values, active versus expired periods, quota concurrency, coming-soon checkout denial, owner/admin billing authorization and prevention of client-supplied feature overrides. Update entitlements/cache version after plan changes. Seed plan fixtures through an idempotent script; production plan updates use an audited operation and a migration if the data model changes.
