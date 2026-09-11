# Testing strategy

Run fast configuration tests and PostgreSQL integration tests for each foundation change. API integration tests use a dedicated `_test` database, apply migrations and seed, and verify real SQL behavior instead of replacing PostgreSQL with SQLite. Include OTP wrong-code persistence, expiry, replay, request limits, concurrent consumption, revoked sessions, role denials, tenant isolation, unique/reserved slugs, atomic trial creation and expired entitlements. Test migrations up/down/up on disposable data, and seed idempotency.

Frontend runs TypeScript, Biome, production build and dependency audit. A cross-service HTTP test runs the actual Next BFF with FastAPI and PostgreSQL: reject missing/foreign Origin, authenticate fixture, ensure token is absent from JSON and cookie is HttpOnly, create organization, render its workspace, logout and verify old credentials fail. Browser visual and interaction tests remain a separate release check; HTTP E2E is not represented as browser testing.

Future domain suites implement the script's pricing, recurrence/DST, payment/webhook retries, concurrent capacity/credits, notification retries, expiry, meeting-access and template cases. The full teacher → session → payment → enrollment → join → attendance → reminder flow is a release gate after those modules exist, not a foundation passing claim.

CI targets PostgreSQL 16/Python 3.13 and Node 22. Local validation uses installed PostgreSQL 18.4 and Node 24.16.0 with Python 3.13.13. Record actual results in feature trackers; CI configuration alone does not mean CI ran.
