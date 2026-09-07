# ProgressRooms User Flows

## 1. Critical End-to-End Flow: Discovery to Class Attendance

```text
Visitor arrives at progressrooms.com/{organization_slug}
       │
       ▼
Views Public Website (SSR rendered with teacher branding & active sessions)
       │
       ▼
Selects a Session (navigates to /{organization_slug}/sessions/{session_slug})
       │
       ▼
Clicks "Enroll Now" -> Prompted for Email OTP Login
       │
       ▼
Logs in (User account created/authenticated, JWT session issued)
       │
       ▼
Order generated on backend (Status: PENDING)
       │
       ▼
Razorpay Checkout modal opens with Order ID & Session Price
       │
       ▼
Student completes payment -> Razorpay sends signature & webhook
       │
       ▼
Backend verifies signature / webhook -> Order marked PAID
       │
       ▼
session_enrollments activated (Status: ACTIVE, sets valid_until or total_sessions)
       │
       ▼
Student navigates to /student dashboard -> Sees upcoming occurrences
       │
       ▼
15 minutes before class -> "Join Class" button unlocks Zoom meeting URL
       │
       ▼
Class finishes -> Teacher opens attendance roster, marks student "ATTENDED"
       │
       ▼
Credit decremented (for package) or logged (for monthly)
```

## 2. Teacher Onboarding & Trial Flow
1. Teacher signs up with email OTP.
2. Creates Organization with name, slug, timezone, currency.
3. Automatically assigned **Starter** plan with a 30-day trial (`trial_starts_at = now()`, `trial_ends_at = now() + 30 days`).
4. Teacher defines Class Type (`Yoga`), creates a Session (`Morning Flow`), and adds Schedule Rules (Monday, Wednesday, Friday at 07:00 AM).
5. Background engine generates next 30 days of `class_occurrences`.
6. Session is published to `progressrooms.com/{organization_slug}`.
