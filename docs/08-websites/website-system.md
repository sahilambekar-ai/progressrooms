# ProgressRooms Website System

## 1. Routing Architecture
- Public URL: `progressrooms.com/{organization_slug}`
- Dedicated Session Page: `progressrooms.com/{organization_slug}/sessions/{session_slug}`
- Custom Domains: Reserved domain records in `organization_domains` mapped to the organization.

## 2. Server-Side Rendering (SSR)
- Public routes are rendered on the server via Next.js Server Components.
- Delivers instantaneous LCP, full SEO crawlability (OpenGraph, Twitter cards, schema.org Course markup), and dynamic metadata.

## 3. Template System
1. **Default Template**: Available to Starter and Core plans. Clean, single-page profile with bio, class type filters, session cards, schedule pills, and pricing.
2. **Template A (Minimalist Elegance)**: Available to Studio plan. Clean typography, high-contrast hero, grid layout.
3. **Template B (Studio Active / Energy)**: Bold color blocks, hero video/banner, interactive timetable, instructor highlights.
4. **Template C (Modern Academy)**: Curriculum breakdown, multi-course carousel, student reviews, FAQ accordion.
