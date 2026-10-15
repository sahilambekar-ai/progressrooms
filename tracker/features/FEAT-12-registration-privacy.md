# Registration privacy notice and consent

Implemented 2026-09-27. Applies to new Studio and Student registrations, not login.

## Behavior

Both role-specific registration URLs use the shared form. The required checkbox is unchecked initially and resets when changing account type or filling test details. “Click here to read more” opens a native accessible dialog with a scrollable policy and a persistent Close button. Escape closes it and restores focus. Opening/closing does not accept consent. No acceptance button or other workflow is inside the modal. `/privacy` is also publicly readable, with both data categories, for a stable policy URL.

The policy identifies Sahil Ambekar as operator under the OpenRoots brand, and support@progressrooms.com as the privacy contact, as supplied by the project owner. It covers student, studio, multiple-teacher and payment data; permitted uses/sharing; public content; storage; requests and withdrawal; children; Google integrations; and studio-origin disclosures. Administrators must seek specific consent before changing personal details; registration acceptance is not blanket approval.

The studio-disclosure clause is limited to incidents caused solely outside platform control, to the extent allowed by law. It does not waive the operator’s own duties, acts/omissions or statutory rights.

## API and acceptance evidence

`POST /api/v1/auth/register` requires strict boolean `privacy_accepted: true` and `privacy_policy_version: "2026-09-27"`. Missing/false/string consent or an outdated version is rejected before account creation. The registration transaction adds `PRIVACY_POLICY_ACCEPTED` to the existing audit_logs table with the user, role, version and database acceptance timestamp. No migration is required. Deploy API and web together; older registration clients must send these fields.

This change records registration consent only. It does not add a new consent-approval workflow to existing administrator profile-edit endpoints, an age-verification system, automated deletion or an incident-response service. The admin-change clause is an operational obligation; staff must obtain and retain the person's specific permission before editing. Privacy requests need an actually monitored support mailbox and operational fulfilment.

## Source and review boundaries

Policy source: `progressrooms-web/src/lib/privacy/policy.ts`; shared modal component: `src/components/PrivacyPolicy.tsx`. Preserve this version's wording in version control. Bump the policy version in both API schema and frontend when materially changing notice/consent; do not silently reuse a version after altering the operator/contact through environment overrides.

Official sources checked on 2026-09-27:
- https://developers.google.com/terms/api-services-user-data-policy — accurate disclosures, minimum permissions and scope-specific Limited Use.
- https://support.google.com/googleplay/android-developer/answer/10144311 — Play-specific user data/privacy/account-deletion requirements if an Android distribution is introduced.
- https://www.meity.gov.in/static/uploads/2025/11/53450e6e5dc0bfa85ebd78686cadad39.pdf — published DPDP Rules; applicability and commencement require legal review for the actual service.

There is no universal “Google compliant through 2026” certificate conveyed by policy text. Google APIs/Play requirements apply to the integrations/distribution actually used. This is an application-specific draft for legal review, not a legal opinion or certification. Confirm retention schedules, provider contracts, processing locations, child safeguards and rights fulfilment before public launch. No live deployment was performed.

## Verification

48 API tests pass, including new route-level cases for both roles that check missing/false/string/outdated consent creates no account, and valid consent records role/version/time. Main web typecheck, lint and build pass with existing dashboard hook warnings. Browser checks verified student and studio text, initial unchecked state, modal opening, scrolling to the bottom, fixed Close control, Escape/Close focus restoration and a 390px-wide layout. No live account was submitted or email sent during browser checks.

## Registration completion follow-up

“Who this notice covers” is fourth from last in both role policies and the combined public policy. Register remains disabled until every visible field is nonblank, email has a valid address shape, the password is 8–128 characters, confirmation matches, and privacy consent is checked. Studio name is required for Studio only; phone and location are required for both. The submit handler repeats this guard. Type checking and lint passed with existing warnings.
