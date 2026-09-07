# FEAT-04: Admin Operations Portal

- **Feature ID**: FEAT-04
- **Status**: ✅ COMPLETED & VERIFIED
- **Date**: 2026-09-07
- **Inspiration**: `aerialyogawithshivani/src/components/dashboard`

---

## 1. Overview
The Admin Operations Portal (`/dashboard`) adopts the navigation structure, nature gradients, and operational tabs of the `aerialyogawithshivani` client panel.

## 2. Key Modules & Tabs Implemented
1. **Deep Forest Sanctuary Sidebar**:
   - Studio title & badge (`Sahil Yoga Studio • Admin Operations`).
   - Nature gradient background (`#0C2417` -> `#133623` -> `#0D291A`).
   - Live website quick-preview link (`/sahil-yoga-studio`).
   - Active user profile card with role and Logout action.
2. **Operational Tabs**:
   - 👥 **Students & Directory**:
     - Live search by student name or email.
     - Status filter: `All Statuses`, `Active`, `Expiring Soon`.
     - Student cards showing phone, active plan, attendance count (e.g. 8/12 classes), and status badge.
     - Action button to log attendance directly from the student card.
   - ✨ **Class Batches & Schedules**:
     - Weekly timetable grid of recurring sessions (e.g. *Morning Hatha Flow*, *Aerial Yoga Conditioning*, *Evening Restorative Yin*).
     - Instructor assignment, schedule time, student cap, and active status.
     - "Create New Batch" action button with modal ready for dynamic scheduling.
   - 💳 **Memberships & Passes**:
     - Pricing passes breakdown (Monthly Recurring Passes, 10-Class Drop-in Pack).
     - Pricing figures, duration, session allowances, and subscriber counts.
   - 🗓️ **Attendance Tracker**:
     - Session selector dropdown with live time and instructor badge.
     - Date picker selector.
     - Attendee checklist with instant toggle buttons (**"Attended"** [green check] vs **"Absent"** [gray cross]).
     - Real-time toast feedback on status change.
   - 💬 **Student Queries**:
     - Inquiries feed with student name, question, submission timestamp, and status.
     - "Mark Resolved" action.
   - 📊 **Analytics & Revenue**:
     - Key metrics: Monthly Recurring Revenue (MRR), Active Students, Overall Attendance Rate (91.4%), Class Completion.
     - Interactive visual breakdowns.
   - ⚙️ **Settings**:
     - Studio branding details, timezone (`Asia/Kolkata`), public URL toggle, and custom domain setup.

## 3. Files Implemented & Modified
- `progressrooms-web/src/app/(dashboard)/dashboard/page.tsx`
- `progressrooms-web/src/app/(dashboard)/dashboard/website/page.tsx`

## 4. Verification & Testing Steps
1. Navigate to `http://localhost:3000/dashboard` (or use the one-click owner login from `/login`).
2. **Test Tab Navigation**:
   - Click each tab in the sidebar: *Students & Attendance*, *Classes & Schedules*, *Memberships & Pricing*, *Attendance Tracker*, *Student Queries*, *Analytics & Revenue*, *Studio Settings*.
   - Confirm each view switches smoothly with appropriate nature styling.
3. **Test Student Filtering & Search**:
   - In *Students & Attendance*, type "Aarav" into the search bar. Observe that only Aarav Patel is shown. Clear the search.
   - Select "Expiring Soon" in the status dropdown: verify Rohan Verma is filtered.
4. **Test Attendance Tracker**:
   - Switch to the *Attendance Tracker* tab.
   - Click the status toggle button next to any student (e.g., toggle Aarav Patel from "Attended" to "Absent" and back).
   - Observe the toast confirmation: *"Attendance updated: ATTENDED"* / *"ABSENT"*.
5. **Test Student Support Queries**:
   - Switch to the *Student Queries* tab.
   - Review pending questions from students.
6. **Test Live Public Studio Link**:
   - In the sidebar header or Settings tab, click the leaf icon or "View Live Website".
   - Confirm it opens `/sahil-yoga-studio` in the nature theme.
