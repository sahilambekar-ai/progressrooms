# ProgressRooms API Specification

Base URL: `/api/v1`

## 1. Authentication (`/auth`)
- `POST /auth/request-otp`: Request Email OTP for login or signup.
  - Body: `{ "email": "user@example.com" }`
- `POST /auth/verify-otp`: Verify OTP and exchange for JWT bearer token.
  - Body: `{ "email": "user@example.com", "otp": "123456" }`
  - Response: `{ "access_token": "...", "token_type": "bearer", "user": { ... } }`
- `GET /auth/me`: Fetch current authenticated user and organization memberships.

## 2. Public Platform & Websites (`/public`)
- `GET /public/organizations/{org_slug}`: Public SSR payload for teacher/studio website.
- `GET /public/organizations/{org_slug}/sessions`: Active public sessions list.
- `GET /public/organizations/{org_slug}/sessions/{session_slug}`: Dedicated SSR session detail, instructor info, requirements, and pricing.

## 3. Teacher & Studio Management (`/organizations/{org_id}`)
- `GET /organizations/{org_id}`: Organization profile & subscription details.
- `PUT /organizations/{org_id}`: Update organization metadata.
- `GET /organizations/{org_id}/members`: List instructors & admins.
- `POST /organizations/{org_id}/members`: Invite instructor.
- `GET /organizations/{org_id}/class-types`: List class types.
- `POST /organizations/{org_id}/class-types`: Create class type.
- `GET /organizations/{org_id}/sessions`: List sessions.
- `POST /organizations/{org_id}/sessions`: Create session (with instructors, pricing, schedule rules).
- `GET /organizations/{org_id}/occurrences`: Filter calendar occurrences by date range `[start_date, end_date]`.
- `POST /organizations/{org_id}/occurrences/{occurrence_id}/reschedule`: Reschedule occurrence with change log.
- `POST /organizations/{org_id}/occurrences/{occurrence_id}/cancel`: Cancel occurrence.
- `POST /organizations/{org_id}/occurrences/{occurrence_id}/attendance`: Mark attendance for enrolled students.
- `GET /organizations/{org_id}/website`: Get website configuration.
- `PUT /organizations/{org_id}/website`: Update website template, hero, and theme.

## 4. Student Portal (`/student`)
- `GET /student/enrollments`: Active and historical session enrollments.
- `GET /student/upcoming-classes`: Next 7-30 days of scheduled occurrences.
- `GET /student/classes/{occurrence_id}/meeting-url`: Protected video meeting link (active 15 mins prior to class).

## 5. Commerce & Payments (`/commerce`)
- `POST /commerce/orders`: Create an order for a session.
  - Body: `{ "session_id": "...", "organization_id": "..." }`
- `POST /commerce/payments/verify`: Verify Razorpay payment signature and activate enrollment.
  - Body: `{ "order_id": "...", "razorpay_order_id": "...", "razorpay_payment_id": "...", "razorpay_signature": "..." }`
- `POST /commerce/webhooks/razorpay`: Razorpay server-to-server webhook endpoint.

## 6. Super Admin (`/admin`)
- `GET /admin/organizations`: Paginated list of all platform organizations.
- `GET /admin/metrics`: Platform revenue, active trials, total teachers, total students.
- `POST /admin/plans`: Create/update subscription plans and feature flags.
