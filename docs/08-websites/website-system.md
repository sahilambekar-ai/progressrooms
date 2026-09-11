# Website system

Status: design; public catalog and template implementation follow foundation.

Every active, entitled organization has an SSR route `/{organization_slug}`. Sessions use `/{organization_slug}/sessions/{session_slug}`. Next.js Server Components fetch a deliberately public FastAPI projection. It excludes student records, internal notes, unpublished content, payment records, and meeting URLs. Check organization status, subscription time boundaries, session ACTIVE status and PUBLIC visibility at the source; hiding cards in React is insufficient. All application routes are reserved organization slugs at both API and database boundaries.

Starter and Core receive the fixed default profile: identity, approved introduction/contact fields and dynamic class/session listings. Studio adds three code-rendered templates with fixed section order. Configuration uses a discriminated, versioned schema for approved text, media IDs, contact fields and section visibility. Reject unknown fields, raw HTML and unapproved URL protocols. Store draft and published configuration separately; publish atomically with optimistic revision checking. Template version changes require a migration/adapter and retain a rollback path. Downgrades preserve private advanced drafts but render only the default entitled website.

Catalog cards always query the session domain. Do not duplicate sessions in template JSON. Generate canonical URLs from a configured trusted public origin, page-specific titles/descriptions, Open Graph and Twitter metadata. Organization/session absence returns a real 404. Public cache invalidation accompanies publish, catalog status, subscription and suspension changes; preview and private data always use no-store. Do not statically export these SSR routes.

Media uses organization-owned object storage metadata. Validate file type from content, limit size, sanitize names and strip unnecessary image metadata. Upload intents are short-lived and scoped; completion checks ownership. Public assets may use a CDN; private assets require signed delivery. Custom domain ownership and DNS automation are reserved for a later milestone.

Acceptance: three template fixtures, mobile layout and accessibility checks, server-rendered HTML with dynamic metadata, no hidden sessions or protected fields, tenant-safe media, invalid schema rejection, downgrade behavior, atomic publish and stale revision rejection.
