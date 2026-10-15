# FEAT-17 — Studio storefront and student purchases

## Product behavior

Each active studio has two public destinations, whether it has one teacher or many:

- `/{studio-slug}`: studio home; published website, or a starter home when no website has been published.
- `/{studio-slug}/explore`: searchable classes, memberships and passes. Existing `/classes` listings redirect here. Class detail URLs continue to work.

The studio slug is the unique readable name already assigned to the studio. No teacher code appears in these URLs. Students can still log in directly at `/login`.

Classes and passes already default to active when created. Public Explore includes active, public, undeleted classes and active, undeleted passes. Explicitly private classes remain private. Passes show their currently available included classes; a pass without available classes cannot be purchased.

Students choose a studio-defined offering with a fixed price, session allowance and validity. Pricing is always read on the server. Free offerings can be confirmed without a payment gateway. Session allowance is shared across every class in a purchased pass. Studio staff retain their existing creation and management permissions.

Browsing needs no account. The header shows Log in or a circular account initial linking to the user's dashboard. Login and in-form student registration preserve the selected purchase. Signed-in users proceed directly to checkout. Checkout is a one-time purchase; it does not introduce automatic renewals.

Verified payment activates enrollment and studio membership in one transaction. Prices, session allowance, validity and included class IDs are frozen at order creation. Payment verification locks the order, validates the provider order and captured payment amount/currency, and is idempotent. Signed payment-captured webhooks can recover activation after the browser closes. Failed verification can be retried in the browser; payment details are retained in session storage for that offering until confirmation succeeds.

The student dashboard now uses real authenticated API data for purchases, shared remaining credits, expiry and upcoming classes. Meeting access checks active enrollment, expiry, remaining credits and the join window. Attendance cannot consume credits beyond the pass allowance.

## Implementation

API: `app/modules/websites/router.py`, `app/modules/websites/rendering.py`, `app/modules/commerce/{router,service}.py`, `app/models/commerce.py`, `app/modules/student/router.py`, `app/modules/attendance/router.py`.

Web: tenant home route, Explore route, legacy listing redirect, `StudioExplore`, `StudioAccount`, `StoreCheckout`, `EnrollmentModal`, `SessionDetailClient`, login/registration return handling, student dashboard, and `public/studio-account.js`.

Database: `012_public_storefront`, following `011_require_teacher_codes`. Adds purchase snapshots to orders and a purchase-order reference to enrollment; preserves the existing unique primary order enrollment link. Applied to the local development database.

## Verification

Automated coverage in `tests/test_storefront.py`: pass purchase and multi-class activation, price/credit snapshots, repeat payment verification, shared credit exhaustion, inactive catalog filtering, checkout availability recheck, required login, mutually exclusive offering IDs, explicitly gated development checkout, free enrollment, signed webhook recovery and replay. Existing website rendering tests now expect Explore links.

Backend suite: 68 passing tests. TypeScript check and production build run. Browser smoke checks: studio home and visible login, Explore class/pass catalog, pass purchase summary, and anonymous checkout redirect preserving the selected pass.

## Manual acceptance

1. Open `/demo-yoga-studio` and follow Explore classes; confirm the URL is `/demo-yoga-studio/explore` and the home page remains a distinct destination.
2. Create an active public class and an active pass attached to classes through the existing staff dashboard. Refresh Explore and check name, price, allowance, validity and included classes.
3. Search by name and switch between All offerings, Classes and Passes. Deactivate an offering and confirm it disappears; attempt an earlier buy link and confirm the server rejects an unavailable offering.
4. Signed out, buy a pass and continue. Confirm the login URL retains its selection. Log in as a student or register through the form link; confirm the purchase summary is restored.
5. In explicitly enabled local development mode with mock Razorpay keys, confirm checkout; no actual funds are charged. In a configured Razorpay test environment, complete test checkout and confirm the captured payment activates enrollment.
6. Open `/student`: confirm the purchase appears once with its included classes. Attendance in different included classes should reduce the same remaining allowance. Retry verification and confirm no duplicate enrollment is created.
7. Change the original offering's price/allowance after order creation and verify the purchase retains its original terms.
8. Log in, revisit studio home and Explore, and confirm the circular account initial links to the dashboard. Verify expired or exhausted purchases cannot open meeting links.

## Deployment requirements

Apply `alembic upgrade head`. Configure Razorpay API credentials and a non-mock webhook secret; configure automatic payment capture and the `/api/v1/commerce/webhooks/razorpay` endpoint for `payment.captured`. Keep `DEV_TEST_LOGIN_ENABLED` disabled outside local development. Live provider payments have not been exercised with real credentials. No production deployment was performed.
