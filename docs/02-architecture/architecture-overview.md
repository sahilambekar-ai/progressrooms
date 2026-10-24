# Progress Rooms System Architecture

## 1. System Topology

Progress Rooms is engineered as a decoupled, multi-tenant system with two core repositories:

```text
┌─────────────────────────────────────────────────────────────┐
│                      Client Browsers                        │
│   (Students, Teachers, Studio Owners, Platform Admins)      │
└───────────────┬─────────────────────────────┬───────────────┘
                │                             │
                │ HTTP (SSR / Client)         │ REST API / Webhooks
                ▼                             ▼
   ┌──────────────────────────┐  Proxy /    ┌──────────────────────────┐
   │    progressrooms-web     │ ──────────> │    progressrooms-api     │
   │  (Next.js 14 App Router) │  Internal   │    (FastAPI + Python)    │
   └──────────────────────────┘             └─────────────┬────────────┘
                                                          │
                                         ┌────────────────┴────────────────┐
                                         ▼                                 ▼
                             ┌───────────────────────┐         ┌───────────────────────┐
                             │  PostgreSQL Database  │         │   Redis Cache / Q     │
                             │  (Multi-Tenant UUIDs) │         │ (Sessions, Jobs, Rate)│
                             └───────────────────────┘         └───────────────────────┘
```

## 2. Multi-Tenant Security & Tenant Resolution

1. **Organization as Tenant**: Every tenant entity references `organization_id`.
2. **Context Resolution**:
   - In the API, middleware and dependencies (`get_current_tenant`) resolve the tenant from JWT claims or headers.
   - Database queries strictly filter by `organization_id` to prevent cross-tenant data leakage.
3. **Public SSR Resolution**:
   - Public pages (`/[orgSlug]`) resolve the organization by unique slug, loading public sessions, public bio, and active website templates.
4. **Soft Delete Policy**:
   - Business entities use `deleted_at`. Historical payment and audit records are never permanently erased.
