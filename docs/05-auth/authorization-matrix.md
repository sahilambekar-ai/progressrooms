> Updated implementation: see [Account roles and permissions](../03-database/account-roles.md). The original design below is superseded for account roles, registration, and teacher permissions.

# Roles and authorization matrix

Status: foundation role model; operations for later modules remain planned until their endpoints are implemented.

Authorization is a backend decision. All staff permissions require an active membership in the resource organization. `Assigned` means the instructor is assigned to that session/occurrence in this tenant; `Own` means the current user's student record, order or enrollment. Organization state and feature entitlements can further restrict a granted action.

| Operation | Super admin | Owner | Admin | Instructor | Student / public |
| --- | --- | --- | --- | --- | --- |
| View own identity / memberships | Own | Own | Own | Own | Own |
| Create organization | As user | Yes | As user | As user | Authenticated user |
| Read organization private overview | Audited admin route | Yes | Yes | Limited | No |
| Change organization settings | Audited support action | Yes | Yes, except ownership/billing | No | No |
| Transfer ownership / remove final owner | Dedicated audited flow | Transfer only | No | No | No |
| Invite / deactivate instructors | Audited support route | Yes | Yes, no owner changes | No | No |
| Grant administrator role | Audited support route | Yes | No | No | No |
| Create/edit/archive class types | Audited support route | Yes | Yes | No | No |
| Create/edit/publish sessions and pricing | Audited support route | Yes | Yes | No | No |
| Assign instructors | Audited support route | Yes | Yes | No | No |
| Create recurrence / schedule | Audited support route | Yes | Yes | No | No |
| View calendar | Explicit admin scope | All in org | All in org | Assigned | Own accessible occurrences |
| Cancel / reschedule occurrence | Audited support route | Yes | Yes | No initially | No |
| Read students / enrollments | Audited minimal support view | Organization | Organization | Assigned roster, minimal fields | Own |
| Edit private student notes | Audited support route | Yes | Yes | No initially | No |
| Edit teacher attendance | Audited support route | Yes | Yes | No, including own record | No |
| Edit student attendance | Audited support route | Yes | Yes | Assigned class and assigned student only | No |
| Submit session postpone / extension query | No | No | No | No | Own active enrollment, to assigned teacher |
| Resolve assigned student query | Audited support route | Read only | Read only | Assigned teacher only | Withdraw own pending query only |
| Read meeting join link | No implicit access | Organization class | Organization class | Assigned | Own valid access |
| Read host/start meeting URL | No implicit access | Host management policy | Host management policy | Assigned host | No |
| Browse published public pages | Public rules | Public rules | Public rules | Public rules | Yes |
| Create order | As purchaser | As purchaser | As purchaser | As purchaser | Own; valid published offering |
| Read orders / payment records | Audited finance view | Org summary | Org summary | No | Own redacted record |
| Request refund | Audited finance route | Yes | No initially | No | Support request only |
| Change plan / payment accounts | Audited admin route | Yes | Read entitlements only | No | No |
| Connect Zoom / manage integration | Audited support route | Yes | Yes for meetings | No | No |
| Edit / preview / publish website | Audited support route | Yes, entitled | Yes, entitled | No | Published projection only |
| Manage media | Audited support route | Yes | Yes | No | Public approved assets only |
| Read audit logs | Explicit platform/org scope | Own org | Own org | No | No |
| Manage platform plans/templates | Yes, audited | No | No | No | No |
| Suspend / restore organization | Yes, audited | No | No | No | No |
| Read notification / preferences | Own | Own | Own | Own | Own |

## Enforcement sequence

Authenticate → load active global user/session → resolve tenant → load active membership or owned organization-student relationship → evaluate role and assignment → confirm resource organization → evaluate organization state, subscription and feature/quota → execute. Use a common dependency/service so routers cannot forget one layer. Missing or foreign resources return 404; a known accessible resource with a denied operation returns 403.

Owner teaching is permitted without adding a second role row: session assignment establishes instructional scope. A person may have independent memberships in many organizations; selecting organization A in the UI cannot grant access to B. Students are not staff members and must never inherit a staff permission merely from enrollment.

Super admin status comes from `platform_admins`, not a predictable email or request header. Platform management uses distinct `/admin` routes, explicit scope and audit entries with actor, target organization, action and reason. Administrative access does not automatically reveal encrypted integration secrets or host meeting URLs.

## Mandatory authorization checks

Test each high-impact endpoint with owner A, admin A, assigned instructor A, unassigned instructor A, student A, user B and anonymous. Swap path IDs, nested IDs, query filters and JSON relationship IDs. Include suspended memberships, expired subscriptions, soft-deleted resources and a user who has different roles in two tenants. DB tests independently verify composite foreign keys reject a cross-tenant assignment.
