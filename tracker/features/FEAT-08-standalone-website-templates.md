# FEAT-08 — Six distinct templates and standalone website versions

## Behavior

The studio sidebar's **My Website** entry retains the template → content → preview/publish workflow. The gallery now offers **Template 1–6**, without discipline filters or labels.

The six original layouts are editorial, dark full-bleed poster, organic collage, immersive centered photography, journal masthead, and modular grid. Their heroes have separate HTML source files and distinct section/card treatments.

Owners can edit the introductory text, story, and closing invitation; upload or select up to **five images total**; add, remove, and reorder up to **12 sections**; and create up to **nine cards per section**. Cards optionally reference an image from the same five-image library. Removing an image clears dependent card references. The first image is the cover and another image can be promoted to cover. Cards use at most three desktop columns, two tablet columns, and one phone column, with incomplete rows centered.

Preview creates a fresh, private standalone HTML version and opens it in a new tab. The editor can also refresh its embedded preview and explicitly indicates when that preview has older changes. Preview does not publish or replace a saved draft. Publish first saves the current draft, renders all assets, writes an immutable version, and only then commits the public release in the database. Missing images fail publication without replacing the previous release. A download button retrieves the published self-contained HTML.

## Reference review

The supplied [ThemeForest yoga results](https://themeforest.net/search/yoga) listed Kriya, Ativo, Ashtanga, Asana, Hatha, and Yoku at the top when reviewed. The listing and these author demos informed the original implementation:

- [Ativo Pilates Modern](https://ativo.vamtam.com/pilates-modern/): bold cover photography, large typography, strong color accents.
- [Yoku](https://demo.goodlayers.com/yoku/landing/): organic compositions, studio/teaching content, modular sections.
- [Asana](https://highseastudio.com/demo/asana-wp/): prominent cover, image-led cards, class-oriented content structure.

No ThemeForest theme was purchased, copied, or installed. The six implementations use original HTML/CSS and bundled Unsplash sample photos; photo sources are documented in `progressrooms-api/app/modules/websites/assets/README.md`.

## Rendering and storage

There is **one authoritative server renderer**, in `progressrooms-api/app/modules/websites/rendering.py`. It is used by the template gallery, private preview, publication, and legacy public-page rendering. The frontend does not maintain a second renderer.

```
progressrooms-api/
  app/modules/websites/
    schemas.py               # Limits, legacy normalization, image references
    catalog.py               # Six designs and editable starter content
    rendering.py             # Escaped HTML, embedded assets, version storage
    templates/
      template_1.html ... template_6.html
      site.css
    assets/                  # Five bundled sample photographs
  generated-websites/        # WEBSITE_EXPORT_DIR; ignored by Git
    <organization UUID>/
      previews/<version UUID>/index.html + manifest.json
      versions/<version UUID>/index.html + manifest.json
    examples/template-1/index.html ... template-6/index.html
```

Every `index.html` contains the entire page, inline CSS, and embedded image bytes. There are no script bundles, external fonts/stylesheets, runtime API calls, or React hydration. The HTML can be copied to another machine or static host, or opened directly in a browser. All class links are absolute URLs to the configured platform origin; viewing the landing page is independent, while booking/classes still require the live platform.

The public Next.js `/{orgSlug}` route is a server route handler that returns the complete committed HTML document, without a Next.js page shell. It currently reads that release through the API, so **the live application URL still requires the servers**. The exported file itself does not. Independent public hosting can serve the generated version directory directly. `/{orgSlug}/classes` continues to use existing public class/session data.

Release metadata, published content, draft content, and version history occupy separately named entries in the existing `organization_websites.custom_sections` JSON column. No schema migration is required. Old template codes are normalized to Template 1–6. The old editor's content is upgraded with editable starter sections; deliberately empty arrays from the new editor are preserved. Uncommitted disk artifacts are never selected as public releases.

## API

- `GET /public/website-templates`: canonical template metadata and starter content.
- `GET /public/website-templates/{code}/preview`: complete sample HTML.
- `GET /public/website-assets/{filename}`: allowlisted built-in photos.
- `GET /website-workspace`: authenticated editable studios.
- `GET/PUT /organizations/{id}/website`: private editor state/draft.
- `POST /organizations/{id}/website/image`: supported image upload, up to 5 MB.
- `POST /organizations/{id}/website/preview`: validated content → private HTML version.
- `POST /organizations/{id}/website/publish`: publish the saved draft and retain a version.
- `GET /organizations/{id}/website/download/{version}`: authenticated download of an actual published version.
- `GET /public/organizations/{slug}/website-html`: current committed HTML, or legacy SSR output.

Owner/admin/instructor role checks use the existing tenant dependency. New uploaded filenames carry their tenant ID; cross-tenant embedding is rejected. Free-form user text is escaped. Arbitrary remote-image downloads are rejected; only legacy Unsplash stock URLs have a bounded, nonredirecting single-host import path.

## Configuration

The API reads these settings from environment variables or `.env`:

```
WEBSITE_PUBLIC_ORIGIN=https://progressrooms.com
WEBSITE_MEDIA_DIR=/persistent/website-images
WEBSITE_EXPORT_DIR=/persistent/generated-websites
```

Use the actual production web origin before publishing so downloaded class links point to the right domain. Both storage directories must be durable, backed up, and shared by API replicas. Existing release bytes are immutable; changing the origin or templates requires a new publication to update an exported site. Do not expose the entire export root on a static server: its `previews` subfolders are private. Serve only selected published `versions` directories. Old versions/private previews currently require an operational retention policy; automated cleanup is not implemented.

Frontend `NEXT_PUBLIC_API_URL` identifies the public API. Optional `API_URL` can identify the internal API origin for the public server route.

Generate example folders without touching any studio account:

```
cd progressrooms-api
.venv/bin/python -m scripts.websites.export_samples --origin http://localhost:3000 --name 'Sahil Yoga Studio' --slug sahil-yoga-studio
```

## Verification

- Full backend suite: **37 tests pass**.
- Frontend: `tsc --noEmit` passes.
- Tests cover all templates; five-image/nine-card caps; duplicate and dangling image references; SSRF/path restrictions; escaped content; self-contained image/CSS output; private previews; immutable releases; download boundaries; cross-tenant access; and preservation of the live release when image export fails.
- Browser visual checks: six-design gallery plus full-size collage, immersive, journal, and grid layouts. The editor's mobile preview measured 375px document width and scroll width, with cards in one column and no horizontal overflow. A fresh preview opened in a new tab with the studio's current content. Full device and tablet acceptance remains a manual check.
- Direct `file://` browser automation was blocked by browser policy. Offline independence was verified structurally (complete HTML, embedded images, inline CSS, no scripts or runtime resources); a direct-file browser run remains a manual check.

Manual acceptance:

1. Open My Website; verify six numbered designs with visibly different layouts.
2. Choose a template, edit story fields, add/remove images, and promote another image to cover.
3. Reach five images; verify adding a sixth is disabled and rejected by the API.
4. Add a section and nine cards; verify a tenth is disabled/rejected. Use images from the existing library.
5. Preview; verify a new tab opens with the latest unsaved content. Check desktop, tablet, and phone layouts.
6. Save draft and reload; verify content and card/image references persist without changing the public site.
7. Publish and download HTML. Open the HTML from Finder in Chrome with the development servers stopped; verify the entire page including images is visible. Class links should target the configured live platform.
8. Republish another edit; verify the old version remains unchanged and the live URL displays the new version.

## Independent builder application

The editor now lives in sibling `progressrooms-builder`, with its own package, build, CSS and Next server. Dashboard entry points use plain anchors to `/website-builder`; the former `/dashboard/website` route redirects there. Main-app rewrites forward that path and its assets to `WEBSITE_BUILDER_ORIGIN` (default port 3001). Same-origin routing retains existing bearer-token login without cross-origin token transfers.

The builder shell and public catalogue render on the server. Studio-specific details continue to load through authenticated browser API requests. Interactive editing hydrates only in the builder; generated public websites still have no client runtime. See `progressrooms-builder/README.md` for independent production deployment and ingress routing.

Validation: independent production build passed, main frontend TypeScript passed, all 37 backend tests passed. HTTP inspection confirmed all six templates in server HTML and builder-scoped assets. Browser navigation from the dashboard's My Website link and back succeeded with the existing studio session. Repetitive arrows were removed from editor actions and template card/story links; straight CTA arrows remain only in poster/grid designs.
