# Deployment and operations

Status: local development foundation; no cloud deployment or Git remotes created.

Two repositories deploy independently: Next.js standalone Node service and FastAPI ASGI service. PostgreSQL 16 is the target database. Containers and lockfiles pin application/runtime release lines; deployment should record image digests and run dependency scanning. The current local verification database uses PostgreSQL 18.4 because16/Docker were not installed.

Use the root `infrastructure/compose.yaml` for a PostgreSQL 16 development server when Docker is available. Copy each repository's `.env.example` to its ignored local env file and configure API/database origins. Run API migration, development seed, API server on 8000 and web on 3000. Exact executable commands are in repository READMEs. Never commit `.env`, provider keys, database data or `.venv`.

Production uses `APP_ENV=production`, real email delivery, a unique strong OTP pepper, unique `INTERNAL_API_SECRET` (minimum 32 characters), HTTPS application origin and no development OTP/UI. Terminate TLS at a trusted reverse proxy; trusted ingress forwards client IP to the Next BFF. The BFF passes verified client IP to the API via `X-Client-IP` accompanied by `X-Internal-Secret` matching `INTERNAL_API_SECRET`. The API verifies this secret before trusting client-IP headers, preventing IP rate limit collisions across BFF users while strictly rejecting spoofed headers.

Apply Alembic migration (`alembic upgrade head`) as a single release job before application rollout. Migration `20260909_0002_catalog_bootstrap` automatically seeds the required plan catalog (Starter, Core, Studio, Progress AI) idempotently without test fixtures. For platform administration, run the controlled first-admin bootstrap command:
`python -m scripts.bootstrap.create_admin --email admin@yourdomain.com --name "Platform Admin"`
Rehearse on a staging backup, use additive expand/contract changes, then promote. Initial downgrade destroys schema and is only for disposable development data. Back up before destructive changes. Test restoration and define RPO/RTO before production. No automated destructive production migration is configured.

Health: `/health/live` checks process, `/health/ready` validates database connectivity and verified migration revision head (`20260909_0002`). Unmigrated or incompatible revisions fail readiness with HTTP 503. Observe request IDs, latency, failures, authentication throttling and later outbox/provider retries without logging secrets or student PII. Roll back application code only when schema remains compatible. Workers, real payment settlement, encrypted Zoom credentials and media storage are later milestones.
