# FEAT-07 — Studio and teacher websites

## Delivered

Studio navigation includes **My Website** at `/dashboard/website`. Owners, administrators, and instructors with an active organization membership can use the editor. Students and unrelated tenants cannot access its API.

Six fixed, responsive templates:

- Yoga: Still (arched photography) and Earth (wide landscape).
- Music: Studio (dark split layout) and Collective (warm editorial poster).
- Education: Paper (editorial serif) and Spark (playful rounded layout).

The fixed fields are headline, introduction, story, and one hero image. Images can be uploaded (PNG/JPEG/WebP, maximum 5 MB) or provided by HTTPS URL. Studio identity comes from the existing account. Template switching preserves content. There are no added pages, sections, or drag-and-drop controls.

Drafts are saved server-side inside the existing `organization_websites.custom_sections` JSON field under `website_draft`. They never appear in public payloads. Publishing copies the validated saved draft into the existing published website columns. No schema migration is needed. The six template registry rows are created as needed.

Public routes:

- `/{orgSlug}`: single-page studio website.
- `/{orgSlug}/classes`: existing public active sessions with pricing, schedules, and existing session-detail/enrollment links.

An unpublished new website redirects to its classes page. The prior hard-coded organization/session fallback is removed from these routes. Public data failures do not display fabricated sessions. Public website requests bypass caching so publication is immediately visible.

## Implementation

Frontend: `src/components/website/{templates.ts,StudioWebsite.tsx,website.module.css}`, dashboard website editor, studio sidebar link, tenant landing page and new classes route, website types and public fetch policy.

Backend: `app/modules/websites/router.py` adds authenticated workspace lookup, draft read/write, publish, image upload/delivery, and fixed-template/content validation. Existing tenant role dependencies enforce access.

## Verification

1. Sign in using a studio account and open **My Website** from the left sidebar.
2. Filter by Yoga, Music, and Education; each shows two distinct templates.
3. Select a template and choose **Add your details**. Edit text or upload a supported image. Check the live preview.
4. Toggle desktop/mobile previews. Every Explore classes link targets this studio's classes route.
5. Save a draft, reload, and verify persistence. Public content remains unchanged.
6. Publish, open View live, and verify the edited template and content. Follow Explore classes and verify existing studio sessions.
7. Save another draft; published content remains unchanged until publishing again.
8. Submit a blank headline, unsafe image URL, unsupported image, or image larger than 5 MB; verify rejection.
9. A student or a member of another studio cannot read or edit this studio's drafts.

Automated checks: TypeScript `tsc --noEmit`; 15 passing backend tests across `test_websites.py` and `test_tenant_isolation.py`. Coverage includes all template codes, invalid fields, private drafts and publication, role checks, cross-tenant denial, image retrieval/path restrictions, and size/type rejection. Browser verified gallery, content fields, mobile preview, sidebar entry, and navigation to existing classes.

## Hosting

Set `NEXT_PUBLIC_API_URL` to the deployed API's HTTPS `/api/v1` address. Set `WEBSITE_MEDIA_DIR` to durable shared storage (default local development path: `uploads/websites`). All API replicas must share that volume, and it must be backed up; ephemeral container disks are unsuitable. Image objects have random names and immutable cache headers. Production deployment itself was not performed.
