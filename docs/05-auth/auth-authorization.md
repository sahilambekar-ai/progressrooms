> Updated implementation: see [Account roles and permissions](../03-database/account-roles.md). The original design below is superseded for account roles, registration, and teacher permissions.

# Authentication and session security

Status: email OTP and server authorization are foundation scope. Social login, password login, invitations and privileged MFA are later work.

## OTP flow

1. Normalize and validate email at the API boundary. `POST /api/v1/auth/otp/request` always provides a generic accepted response, irrespective of account existence.
2. Generate a cryptographically random six-digit code. Persist an HMAC digest bound to the challenge/email with a server-held secret, expiration and attempt counters. Do not store the code itself. Delivery is through an environment-specific email adapter.
3. Enforce resend delay, per-email and per-IP request budgets, per-challenge attempt limits and a bounded challenge lifetime. A new request invalidates prior live codes. Checks must remain effective across multiple API processes.
4. `POST /api/v1/auth/otp/verify` atomically checks expiration, attempts and digest, consumes a valid challenge once, creates or loads the global verified user, and issues a revocable session credential. Concurrent use of one code must yield only one successful consumption.
5. Return to a validated local `next` path captured before login. Allow only application-relative paths; reject schemes, protocol-relative URLs, encoded bypasses and external origins. The selected offering is revalidated after login.

## Browser/API contract

FastAPI accepts the session credential using `Authorization: Bearer <token>`. Next.js is the browser's BFF: verification takes place server-side, then stores the credential in a cookie with HttpOnly, SameSite=Lax, Path=/ and Secure in production. Do not store the bearer token in localStorage or include it in serialized page props. Authenticated fetches use `cache: no-store`. The cookie lifetime cannot outlive the API session.

Logout must revoke the server session and clear the browser cookie. Expired/revoked tokens return 401 and the UI redirects to login while preserving a safe intent. Hash opaque session tokens before persisting them. If signed credentials are used, enforce expiration, issuer/audience and revocable session lookup; never trust claims containing unverified roles as the live source of authorization.

Cookie-backed mutations validate Origin against the canonical application origin. CORS accepts explicit trusted origins, not wildcard credentials. Add anti-CSRF tokens where same-origin validation is insufficient. Rate limit login and sensitive operations independent of UI countdowns.

## Identity versus tenancy

`GET /api/v1/auth/me` returns the global user and active memberships. Creating an organization atomically adds OWNER membership and a Starter trial. Joining another business as a student does not create another global account. Backend membership and assignment checks follow the [authorization matrix](authorization-matrix.md).

## Environment and delivery

Local/test delivery may expose the generated OTP only through an explicitly selected development adapter or isolated test fixture. Production must reject development OTP bypass configuration and require a real delivery provider plus non-default secrets. Never use test email patterns to infer a role or accept a fixed universal OTP in production. Operator accounts require explicit seeding in development; production provisioning is a controlled audited action.

## Acceptance and later hardening

Foundation tests cover expired/wrong/reused code, exhausted attempts, resend throttling, blocked users, expired/revoked sessions, role denial, missing/foreign tenants and generic error responses. Before live operation validate delivery, distributed throttling, cookie/Origin behavior over HTTPS and privileged-account MFA. Future auth providers attach to `user_auth_methods` only after verifying account-linking ownership; matching an unverified email is insufficient.
