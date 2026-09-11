# Product overview

ProgressRooms is an operating platform for people and organizations that teach scheduled classes. The platform joins catalog management, scheduling, student access, commerce and a public website. Yoga, music, dance, professional training and coaching are examples of customer content; none becomes a special case in business logic.

## Users and value

| User | Job to complete | Successful outcome |
| --- | --- | --- |
| Independent teacher | Publish and manage a teaching business | One organization, one owner who can teach, a public page and a schedule without studio-specific setup burden. |
| Studio owner / administrator | Coordinate staff, sessions and revenue | Organization-wide calendar, controlled staff access, students, orders, entitlements and website settings. |
| Instructor | Conduct assigned classes | Relevant roster and calendar, protected meeting access and reliable attendance. |
| Student | Find, buy and attend a class | Public discovery, email OTP, preserved enrollment intent, verified payment and clear access period. |
| Platform operator | Operate the SaaS | Audited organization support, plan administration and operational visibility. |

## Vocabulary

An organization is the tenant. A class type is an organization-defined category. A session is the offering or program purchased by a student. A schedule rule generates individual class occurrences. An enrollment is access to a session. A platform subscription grants an organization product capabilities; it does not represent a student's purchase.

## Release sequence and completion rule

Architecture is completed before feature implementation. The first delivery milestone implements identity, organizations, roles, plans, trial subscriptions and database foundations. Catalog, scheduling, public session pages, commerce, student dashboard, advanced templates and background automation follow in that order. Their designs in this folder are intentional target contracts, not claims that these features are already live. The project implementation plan and verification report record actual delivery status.

A module is complete only with its design, schema migration, server-side authorization, relevant seed data, automated checks and an exercised user flow. A mock dashboard or successful build alone does not prove an operational payment or scheduling system.

## Product rules

The four initial plan names are Starter, Core, Studio and Progress AI. Starter is a 30-day trial; Core and Studio are paid product tiers; Progress AI displays Coming Soon and has no checkout. Public organization routes use `/{organization_slug}` and session routes use `/{organization_slug}/sessions/{session_slug}`. Public content is rendered on the server. The initial student authentication mechanism is email OTP.

Studio advanced websites select among three fixed, versioned layouts. Customers edit approved content and images, not arbitrary page structures or executable markup. AI generation, custom domains, WhatsApp and broad marketplace discovery are later possibilities.

## Experience direction

Use a calm nature-inspired visual language: warm off-white surfaces, forest and sage tones, restrained botanical detail, generous spacing and readable type. Status, focus and errors must have sufficient contrast and text labels. Prioritize mobile discovery and enrollment; teacher dashboards need usable dense tables and calendars. Public pages should communicate class value before administrative features. Loading, empty, expired, denied and pending-payment states are deliberate screens, not blank placeholders.

## Product outcomes to measure later

Measure teacher signup-to-first-published-session conversion, student discovery-to-verified-purchase conversion, failed checkout recovery, enrollment renewal, classes conducted and administrative time saved. Keep platform subscription revenue separate from student class purchase GMV. Collect product events without exposing roster data or provider credentials.
