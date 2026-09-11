# Multi-tenancy

`organizations` is the tenant boundary for individual instructors and studios. Global identities, plans and template definitions are exceptions; business children have an organization key. Composite foreign keys bind child and parent to the same tenant even when both supplied UUIDs exist. The database schema documents every relation.

Every private request authenticates a live user session, resolves an active membership for the path organization, checks organization status, then applies the operation's role/assignment and entitlement rules. Query predicates include the organization key. A platform administrator uses explicitly audited platform endpoints, not an implicit bypass of tenant endpoints. Students use own-user enrollment relationships and never inherit staff access.

Foundation uses application-enforced authorization plus database referential integrity. PostgreSQL row-level security is not claimed. A deployment uses a limited application role, separate migration credentials and no database network exposure. Future RLS requires explicit transaction-local tenant context and pool-reset tests before enabling it.

Tests must exercise two valid tenants: reading another UUID, assigning a foreign member/session/pricing/student, instructor scope, student-to-staff denial and unauthorized platform access. Query filters, join predicates, background jobs and public serializers all require the same ownership discipline.
