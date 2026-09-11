# Security design

Foundation uses opaque high-entropy bearer sessions, stored as keyed hashes, with expiry and revocation checked on every private request. Browser credentials stay in HttpOnly, SameSite=Lax cookies with Secure enabled in production. Cookie mutations require the configured Origin. Return paths must be local application paths, never protocol-relative/external redirects. Private responses use no-store.

OTP codes are random, short-lived, single-use and keyed-hashed with a deployment-specific pepper. Persist request budgets per normalized email and trusted client IP. Serialize challenge issuance/verification to prevent races; wrong-attempt counters must commit even when the HTTP response is an error. Resend invalidates older challenges. Development's fixed code is gated by environment and fixture allowlist; production rejects those settings. Real email is disabled in this workspace. No helper credentials are copied into source.

Inputs have explicit lengths, enums, UUID validation and IANA timezone checks. Errors use a stable public envelope and correlation ID without stack traces, tokens or request bodies in logs. ORM/Core queries bind parameters. Organization membership, role, assignment and entitlement are checked server-side. Reserved slugs are also constrained in PostgreSQL.

Later payment processing verifies the raw-body HMAC, order identity, currency, amount and captured state, then grants enrollment transactionally and idempotently. Integration secrets use authenticated encryption backed by a managed encryption key. Webhooks, audit history and money records have defined retention and redaction policies. Never expose meeting links through public projections.

Release gates: dependency audit, tenant/auth/CSRF regression tests, real email/provider sandbox validation, least-privilege DB roles, TLS at trusted ingress, secret manager, backups/restoration, rate-limit monitoring and incident procedures. Passing foundation tests does not constitute production certification.
